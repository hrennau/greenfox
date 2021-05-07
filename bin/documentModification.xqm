(:
 : -------------------------------------------------------------------------
 :
 : documentModification.xqm - functions modifying a document
 :
 : The functions are used by the DocSimilar constraint validator in order
 : to "normalize" the documents to be compared according to modifier elements.
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "docSimilarConstraintReports.xqm",
   "greenfoxUtil.xqm",
   "resourceAccess.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";
declare namespace fox="http://www.foxpath.org/ns/annotations";

(:~
 : Applies a set of modifiers to a document.
 :
 : @param doc the document
 : @param modifiers elements specifying a modification of a document
 : @param fn_itemSelector a function for selecting the target nodes of a modifier
 : @return the transformed node
 :)
declare function f:applyDocModifiers(
                        $doc as node(),
                        $modifiers as element()*,
                        $options as map(xs:string, item()*),                              
                        $fn_itemSelector as function(node(), element()) as node()*)
        as node() {
    if (empty($modifiers) and not($options?skipXmlBase) and not($options?skipPrettyWS)) then $doc else
    
    (: Function $fn_writeOperation.
       Writes a map describing the modifications defined by a modifier :)
    let $fn_writeOperation := function($doc, $modifier) as map(*)? {
        let $nodes := $fn_itemSelector($doc, $modifier)
        return
            if (not($nodes)) then () else   
                let $atts := $nodes[self::attribute()]
                let $elems := $nodes except $atts
                return
                    map:merge((
                       map:entry('type', $modifier/local-name(.)),
                       map:entry('operation', $modifier),
                       map:entry('atts', $atts)[$atts],
                       map:entry('elems', $elems)[$elems]                            
                    ))    
    }
    let $selectedModifiers := $modifiers[not(self::gx:sortDoc)]
    
    (: $modification - a map describing all modifications except 'sortDoc' :)
    let $modification := if (not($selectedModifiers)) then () else
    
        (: $operations - an array of maps describing operations :)
        let $operations := array{ $selectedModifiers/$fn_writeOperation($doc, .) }
        
        let $atts := $operations ! array:flatten(.) ! ?atts
        let $elems := $operations ! array:flatten(.) ! ?elems
        return
            map:merge((
                map:entry('operations', $operations),
                map:entry('atts', $atts),
                map:entry('elems', $elems)
            ))
    
    (: $functions - a map returning for each operation type the appropriate function :)    
    let $functions := if (empty($modification)) then () else
        let $types := ($modification?operations ! array:flatten(.) ! ?type) => distinct-values()
        return
            map:merge((
                map:entry('ignoreValue', f:applyDocModifiers_ignoreValue#2)[$types = 'ignoreValue'],
                map:entry('roundItem', f:applyDocModifiers_roundItem#2) [$types = 'roundItem'],
                map:entry('editItem',  f:applyDocModifiers_editItem#2)[$types = 'editItem'],
                map:entry('renameItem',  f:applyDocModifiers_renameItem#2)[$types = 'renameItem'],
                map:entry('renamespaceItem',  f:applyDocModifiers_renamespaceItem#2)[$types = 'renamespaceItem']
        ))  
    return
        f:applyDocModifiersRC($doc, $modification, $functions, $options)
};

(:~
 : Recursive helper function of 'applyDocModifiers'.
 :
 : @param n the node to be transformed
 : @param targets a map associating modification types with data
 : @param functions a map associating modification types with functions
 : @return the transformed node
 :)
declare function f:applyDocModifiersRC($n,
                                       $modification as map(xs:string, item()*)?,
                                       $functions as map(xs:string, function(*))?,
                                       $options as map(xs:string, item()*))
        as node()* {
    typeswitch($n)
    case document-node() return 
        document {$n/node() ! f:applyDocModifiersRC(., $modification, $functions, $options)}
        
    (: Element :)
    
    (: $operations - maps describing the operations which apply to this element :)
    case element() return
        let $operations :=
            if (not($n intersect $modification?elems)) then ()
            else ($modification?operations ! array:flatten(.))[?elems intersect $n]
        return  
            (: No operations? just copy node an continue with content :)
            if (empty($operations)) then
                element {node-name($n)} {
                    $n/@* ! f:applyDocModifiersRC(., $modification, $functions, $options),
                    $n/node() ! f:applyDocModifiersRC(., $modification, $functions, $options)
                }
            (: Skip item! :)
            else if ($operations?type = 'skipItem') then ()
            
            (: Modify! :)
            else
                (: Segregate operations - renaming operations versus all other :)
                let $operation_renameItem := $operations[?type eq 'renameItem']
                let $operation_renamespaceItem := $operations[?type eq 'renamespaceItem']
                let $operations := $operations[not(?type = ('renameItem', 'renamespaceItem'))]

                (: Determine item name (possibly renamed) :)
                let $nodeName :=
                    if (empty(($operation_renameItem, $operation_renamespaceItem))) then $n/node-name(.)
                    else
                        let $localName :=
                            if (empty($operation_renameItem)) then $n/local-name(.) 
                            else                            
                                $functions('renameItem')($n, $operation_renameItem?operation)
                        let $namespace := 
                            if (empty($operation_renamespaceItem)) then $n/namespace-uri(.) 
                            else                            
                                $functions('renamespaceItem')($n, $operation_renamespaceItem?operation)                        
                        return QName($namespace, $localName)
                return                        
                    element {$nodeName} {
                        (: Possibly the only modifications have been renamings, therefore if ... :)
                        if (empty($operations)) then (
                            $n/@* ! f:applyDocModifiersRC(., $modification, $functions, $options),
                            $n/node() ! f:applyDocModifiersRC(., $modification, $functions, $options)                        
                        )
                        else
                            let $operation := $operations[1]
                            return $functions($operation?type)($n, $operation?operation)
                    }
                
    (: Base attribute :)                
    case attribute(xml:base) | attribute(fox:base-added) return 
        $n[not($options?skipXmlBase)]
        
    (: Attribute :)        
    case attribute() return
        let $operations :=
            if (not($n intersect $modification?atts)) then ()
            else ($modification?operations ! array:flatten(.))[?atts intersect $n]
        return 
            if (empty($operations)) then $n
            else if ($operations?type = 'skipItem') then ()
            else f:applyDocModifiersToNode($n, $operations, $functions)
(:            
            (: No operations? just copy node an continue with content :)        
            if (empty($operations)) then $n
            
            (: Skip item! :)            
            else if ($operations?type = 'skipItem') then ()
            
            (: Modify! :)            
            else 
                (: Segregate operations - renaming operations versus all other :)
                let $operation_renameItem := $operations[?type eq 'renameItem']
                let $operation_renamespaceItem := $operations[?type eq 'renamespaceItem']
                let $operations := $operations[not(?type = ('renameItem', 'renamespaceItem'))]

                (: Determine item name (possibly renamed) :)
                let $nodeName :=
                    if (empty(($operation_renameItem, $operation_renamespaceItem))) then $n/node-name(.)
                    else
                        let $localName :=
                            if (empty($operation_renameItem)) then $n/local-name(.) 
                            else                            
                                $functions('renameItem')($n, $operation_renameItem?operation)
                        let $namespace := 
                            if (empty($operation_renamespaceItem)) then $n/namespace-uri(.) 
                            else                            
                                $functions('renamespaceItem')($n, $operation_renamespaceItem?operation)                        
                        return QName($namespace, $localName)
                return            
                    attribute {$nodeName} {
                        (: Possibly the only modifications have been renamings, therefore if ... :)
                        if (empty($operations)) then $n
                        else
                            let $operation := $operations[1]
                            return $functions($operation?type)($n, $operation?operation)
                        }
:)                
    (: Text :)                
    case text() return
        if (not($options?skipPrettyWS)) then $n 
        else if ($n/(not(matches(., '\S')) and ../*)) then ()
        else $n
    
    default return $n                            
};

declare function f:applyDocModifiersToNode($node as node(),
                                           $operations as map(*)+,
                                           $functions as map(*)?)
        as node()* {
        
    let $operation := head($operations)
    let $operationType := $operation?type
    return
        if ($operationType eq 'skipItem') then () else
        
    let $tail := tail($operations)
    let $fn_construct := function($node, $name, $content) {
        typeswitch($node)
        case element() return element {$name} {$content} 
        case attribute() return attribute {$name} {$content}
        default return error()    
    }
    
    let $newNode :=
        if ($operationType = ('renameItem', 'renamespaceItem')) then
            let $localName :=
                if (not($operationType eq 'renameItem')) then $node/local-name(.) 
                else $functions($operationType)($node, $operation?operation)
            let $namespace := 
                if (not($operationType eq 'renamespaceItem')) then $node/namespace-uri(.) 
                else $functions($operationType)($node, $operation?operation)                        
            let $qname := QName($namespace, $localName)
            return $fn_construct($node, $qname, $node)
            
        else
            let $nodeContent := $functions($operationType)($node, $operation?operation)
            return $fn_construct($node, $node/node-name(.), $nodeContent)
    return
        if (empty($tail)) then $newNode
        else f:applyDocModifiersToNode($newNode, $tail, $functions) 
};        


declare function f:applyDocModifiers_renameItem($node as node(),
                                                $mod as element(gx:renameItem))
        as xs:string {
    let $newName := $mod/@newName 
    return if ($newName) then $newName else
    
    let $lname := $node/local-name(.)        
    let $from  := $mod/@replaceSubstring
    let $to := $mod/@replaceWith
    let $useString := $mod/@useString/tokenize(.)
    let $r1 := if ($from and $to) then replace($lname, $from, $to) else $lname
    let $r2 := if (empty($useString)) then $r1 else i:applyUseString($r1, $useString)                            
    return $r2
};        

declare function f:applyDocModifiers_renamespaceItem(
                            $node as node(),
                            $mod as element(gx:renamespaceItem))
        as xs:string? {
    let $newNamespace := $mod/@newNamespace
    return if ($newNamespace) then $newNamespace else
    
    let $namespace := $node/namespace-uri(.)        
    let $from  := $mod/@replaceSubstring
    let $to := $mod/@replaceWith
    let $useString := $mod/@useString/tokenize(.)
    let $r1 := if ($from and $to) then replace($namespace, $from, $to) else $namespace
    let $r2 := if (empty($useString)) then $r1 else i:applyUseString($r1, $useString)                            
    return $r2
};        

declare function f:applyDocModifiers_editItem($node as node(),
                                              $mod as element(gx:editItem))
        as xs:string {
    let $from  := $mod/@replaceSubstring
    let $to := $mod/@replaceWith
    let $useString := $mod/@useString/tokenize(.)
    let $r1 := if ($from and $to) then replace($node, $from, $to) else $node
    let $r2 := if (empty($useString)) then $r1 else i:applyUseString($r1, $useString)                            
    return $r2
};        

declare function f:applyDocModifiers_roundItem($node as node(),
                                               $mod as element(gx:roundItem))
        as xs:string {
    let $scale := $mod/@scale/number(.)  
    let $value := $node/number(.)
    let $newValue := round($value div $scale, 0) * $scale
    return string($newValue)        
};        

declare function f:applyDocModifiers_ignoreValue($node as node(),
                                                 $mod as element(gx:ignoreValue))
        as xs:string {
    ''        
};        

(:~
 : Modify document, sorting the contents of selected or all elements alphabetically.
 :
 : @param doc the document to be edited
 : @param sortElems whitespace separated list of name patterns (applied to local names)
 : @return the sorted document
 :)
declare function f:sortDoc($doc as node(), $sortDoc as element(gx:sortDoc)*)
        as node() {
        
    (: Sort by local name :)
    let $doc1 :=        
        let $elemNames_byLocalName := 
            (($sortDoc[@orderBy eq 'localName']/@localNames => string-join(' '))[string()]) => tokenize()        
        return
            let $elemNamesRegex_byLocalName := $elemNames_byLocalName ! f:glob2regex(.)
            return f:sortDoc_localNameRC($doc, $elemNamesRegex_byLocalName)
            
    (: Sort by child name :)
    let $doc2 :=        
        let $specs := $sortDoc[@orderBy eq 'keyValue'][1]
        return
            if (empty($specs)) then $doc1 else

            let $spec := $specs[1]
            let $elemNames := $spec/@localNames/tokenize(.)  
            let $elemNamesRegex := $elemNames ! f:glob2regex(.)
            let $keySortedLocalName := $spec/@keySortedLocalName
            let $keyLocalName := $spec/@keyLocalName
            return f:sortDoc_childValueRC($doc, $elemNamesRegex, $keySortedLocalName, $keyLocalName)
            
    return $doc2            
};

(:~
 : Implements alphabetical sorting of elements. If $sortElemsRegex is
 : not empty, only those elements are edited which have a matching local name.
 :
 : @param n a node to be processed
 : @param sortElemsRegex regular expressions describing the elements to be edited
 : @return the edited content 
 :)
declare function f:sortDoc_localNameRC($n as node(), $sortElemsRegex as xs:string*)
        as node() {
    typeswitch($n)
    case document-node() return 
        document {$n/node() ! f:sortDoc_localNameRC(., $sortElemsRegex)}
    case element() return
        let $children :=
            if (empty($sortElemsRegex) or 
                (some $regex in $sortElemsRegex satisfies $n/matches(local-name(.), $regex))) then
                $n/* => sort((), function($e) {$e/(local-name(.) || namespace-uri(.))})
            else $n/*
        (: let $_DEBUG := trace($children/local-name(.) => string-join(', '), '_CHILD_NAMES: ') :)            
        return
            element {node-name($n)} {
                $n/@*,
                $n/(node() except *),
                $children ! f:sortDoc_localNameRC(., $sortElemsRegex)
            }
    default return $n            
};        

(:~
 : Implements a sorting of elements by key value. If $sortElemsRegex is
 : not empty, an element is not edited unless it has a local name matching
 : one of the regulare expressions in $sortElemsRegex.
 :
 : An element is not edited if it does not have two or more child elements with
 : a name matching $elemName. If it does contain such child elements, these
 : are resorted by the value of the child or attribute with name $keyItemName.
 :
 : @param n a node to be processed
 : @param sortElemsRegex regular expressions describing the elements to be edited
 : @return the edited content 
 :)
declare function f:sortDoc_childValueRC($n as node(), 
                                        $sortElemsRegex as xs:string*,
                                        $keySortedLocalName as xs:string,
                                        $keyLocalName as xs:string)
        as node() {
    typeswitch($n)
    case document-node() return 
        document {$n/node() ! f:sortDoc_childValueRC(., $sortElemsRegex, $keySortedLocalName, $keyLocalName)}
    case element() return
        let $children :=
            if (empty($sortElemsRegex) or
                (some $regex in $sortElemsRegex satisfies 
                    $n/matches(local-name(.), $regex))) then
                let $elems := $n/*[local-name(.) eq $keySortedLocalName]
                return
                    if (count($elems) le 1) then $n/*
                    else
                        let $elem1 := $elems[1]
                        let $childrenBefore := $n/*[. << $elem1]
                        let $childrenAfter := $n/*[. >> $elem1] except $elems
                        let $elemsSorted :=
                            for $elem in $elems
                            order by $elem/f:findAttOrChild(., $keyLocalName)/string()
                            return $elem
                        return ($childrenBefore, $elemsSorted, $childrenAfter)                            
            else $n/*
        return
            element {node-name($n)} {
                $n/@*,
                $n/(node() except *),
                $children ! f:sortDoc_childValueRC(., $sortElemsRegex, $keySortedLocalName, $keyLocalName)
            }
    default return $n            
};        

(:~
 : An alternative implementation of 'applyDocModifiers'.
 :)
declare function f:applyDocModifiers_update(
                              $doc as node(),
                              $modifiers as element()*,
                              $options as map(xs:string, item()*), 
                              $fn_itemSelector as function(node(), element()) as node()*)
        as node() {
    if (empty($modifiers) and not($options?skipXmlBase) and not($options?skipPrettyWS)) then $doc else
    
    copy $node_ := $doc
    modify (
        if (not($options?skipPrettyWS)) then ()
        else
            let $delNodes := $node_//text()[not(matches(., '\S'))][../*]
            return
                if (empty($delNodes)) then () else delete node $delNodes
        ,
        (: @xml:base attributes are removed :)
        if (not($options?skipXmlBase)) then () else
            let $xmlBaseAtts := $node_//@xml:base
            return
                if (empty($xmlBaseAtts)) then ()
                else
                    let $delNodes := $xmlBaseAtts/(., ../@fox:base-added)
                    return delete node $delNodes
        ,
        for $modifier in $modifiers
        return
            typeswitch($modifier)
            
            (: Sorting already done :)
            case element(gx:sort) return ()
            
            (: Ignore items :)
            case $skipItem as element(gx:skipItem) return
                let $selected := $fn_itemSelector($node_, $skipItem)            
                return
                    if (empty($selected)) then () else delete node $selected
                    
            (: Ignore item string value :)
            case $skipItem as element(gx:ignoreValue) return
                let $selected := $fn_itemSelector($node_, $skipItem)            
                return
                    if (empty($selected)) then () else 
                        for $sel in $selected[self::attribute() or not(*)] return
                            replace value of node $sel with ''
                    
            (: Round numeric values :)
            case $roundItem as element(gx:roundItem) return
                let $selected := $fn_itemSelector($node_, $roundItem)            
                return
                    if (empty($selected)) then () 
                    else
                        let $scale := $roundItem/@scale/number(.)  
                        
                        for $node in $selected
                        let $value := $node/number(.)
                        let $newValue := round($value div $scale, 0) * $scale
                        return replace value of node $node with $newValue
              
            (: Edit item text (string replacement) :)
            case $editItem as element(gx:editItem) return
                let $selected := $fn_itemSelector($node_, $editItem)
                return
                    if (empty($selected)) then ()
                    else
                        let $from  := $editItem/@replaceSubstring
                        let $to := $editItem/@replaceWith
                        let $useString := $editItem/@useString/tokenize(.)
                        
                        for $sel in $selected
                        let $newValue := 
                            if ($from and $to) then replace($sel, $from, $to) else $sel
                        let $newValue :=
                            if (empty($useString)) then $newValue else i:applyUseString($newValue, $useString)                            
                        return
                            if ($sel eq $newValue) then () else
                                replace value of node $sel with $newValue
            default return ()
    )
    return $node_
    
};    
