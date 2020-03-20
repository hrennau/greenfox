(:
 : -------------------------------------------------------------------------
 :
 : docSimilarConstraint.xqm - validates a resource against a DocSimilar constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm",
    "resourceAccess.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a DocSimilar constraint and accompanying constraints.
 : Accompanying constraints refer to the number of items representing
 : the documents with which to compare.
 :
 : @param filepath the file path of the resource currently investigated
 : @param constraintElem an element representing the constraints
 : @param node the node to be validated (not necessarily the root node)
 : @param doc the document node of the node tree representing the resource
 : @param context the processing context 
 : @return validation results, red and/or green
:)
declare function f:validateDocSimilar($filePath as xs:string,
                                      $constraintElem as element(gx:docSimilar),
                                      $contextItem as node(),
                                      $contextDoc as document-node()?,
                                      $context as map(xs:string, item()*))
        as element()* {

    (: The focus path identifies the location of the initial context item
       (empty sequence if the initial context item is the root of the 
       context document :)
    let $focusPath :=
        if ($contextItem instance of node() and not($contextItem is $contextDoc)) then
            $contextItem/f:datapath(.)
        else ()

    (: The "context info" gives access to the context file path and the focus path :)        
    let $contextInfo := map:merge((
        $filePath ! map:entry('filePath', .),
        $focusPath ! map:entry('nodePath', .)
    ))

    (: Adhoc addition of $filePath and $fileName :)
    let $evaluationContext := $context?_evaluationContext
    let $evaluationContext := map:put($evaluationContext, QName((),'filePath'), $filePath)
    let $evaluationContext := map:put($evaluationContext, QName((), 'fileName'), replace($filePath, '.*[/\\]', ''))
    let $context := map:put($context, '_evaluationContext', $evaluationContext)

    (: Determine items representing the documents with which to compare;
       each item should be either a node or a URI :)
    let $otherDocReps := f:validateDocSimilar_otherDocReps($filePath, $constraintElem, $context)

    (: Check the number of items representing the documents with which to compare :)
    let $results_count := 
        f:validateDocSimilarCount($otherDocReps, $constraintElem, $contextInfo)
    
    (: Check the similarity :)
    let $results_comparison := 
        f:validateDocSimilar_similarity($contextItem, $otherDocReps, $constraintElem, $contextInfo)
        
    return
        ($results_count, $results_comparison)
};   

(:~
 : Returns the items representing the other documents with which to compare.
 : The items may be nodes or URIs.
 :
 : @param filePath filePath of the context document
 : @param constraintElem the element representing the DocumentSimilar constraint
 : @param context the processing context
 :)
declare function f:validateDocSimilar_otherDocReps($filePath as xs:string,
                                                   $constraintElem as element(),
                                                   $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $otherFoxpath := $constraintElem/@otherFoxpath 
    return    
        if ($otherFoxpath) then 
            f:evaluateFoxpath($otherFoxpath, $filePath, $evaluationContext, true())
        else error()
};

(:~
 : Validates a link count related constraint (LinkCountMinCount, LinkCountMaxCount, LinkCountCount).
 : It is not checked if the links can be resolved - only their number is considered.
 :
 : @param exprValue expression value producing the links
 : @param cmp link count related constraint
 : @param valueShape the value shape containing the constraint
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateDocSimilar_similarity($contextItem as node(),
                                                 $otherDocReps as item()*,
                                                 $constraintElem as element(),
                                                 $contextInfo as map(xs:string, item()*))
        as element()* {
    let $normOptions :=
        map{
            'skipPrettyWS': true(),
            'skipXmlBase': true()
        }
    let $skipPrettyWS := true()
    
    let $otherDocs :=
        for $rep in $otherDocReps 
        return
            typeswitch($rep)
            case node() return $rep
            case xs:anyAtomicType return 
                if (i:fox-doc-available($rep)) then i:fox-doc($rep) 
                else error()  (: _TO_DO_ - create red result :)
            default return ()

    (: Check document similarity :)
    let $results_comparison_data :=
        for $otherDoc at $pos in $otherDocs
        let $otherDocRep := $otherDocReps[$pos]
        let $otherDocIdentity := (
            if ($otherDocRep instance of xs:anyAtomicType) then $otherDocRep
            else
                let $baseUri := $otherDocRep/i:fox-base-uri(.)
                let $datapath := i:datapath($otherDocRep)
                return
                    concat($baseUri, '#', $datapath)
        )
        let $d1 := f:normalizeDocForComparison($contextItem, $constraintElem/*, $normOptions)
        let $d2 := f:normalizeDocForComparison($otherDoc, $constraintElem/*, $normOptions)
        let $isDocSimilar := deep-equal($d1, $d2)
        let $colour := if ($isDocSimilar) then 'green' else 'red'
        return
            map{'colour': $colour, 
                'otherDocIdentity': $otherDocIdentity}
            (: f:validationResult_docSimilar($colour, $constraintElem, $constraintElem/@otherFoxpath, $otherDocIdentity, (), ()) :)
    return
        let $colour := if (some $r in $results_comparison_data satisfies $r?colour eq 'red') then 'red' else 'green'
        let $otherDocIdentities := 
            if ($colour eq 'red') then $results_comparison_data[?colour eq 'red'] ! ?otherDocIdentity
            else $results_comparison_data?otherDocIdentity
        return
            f:validationResult_docSimilar($colour, 
                                          $constraintElem, 
                                          $constraintElem/@otherFoxpath, 
                                          $otherDocIdentities, (), (), $contextInfo)    
};


(:~
 : Validates a link count related constraint (LinkCountMinCount, LinkCountMaxCount, LinkCountCount).
 : It is not checked if the links can be resolved - only their number is considered.
 :
 : @param exprValue expression value producing the links
 : @param cmp link count related constraint
 : @param valueShape the value shape containing the constraint
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateDocSimilarCount($exprValue as item()*,
                                           $constraintElem as element(),
                                           $contextInfo as map(xs:string, item()*))
        as element()* {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $valueCount := count($exprValue)
    let $countConstraints :=
        let $explicit := $constraintElem/(@count, @minCount, @maxCount)
        return
            if ($explicit) then $explicit else attribute count {1}
    for $cmp in $countConstraints
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown count comparison operator: ', $cmp))
    return        
        if ($cmpTrue($valueCount, $cmp)) then  
            f:validationResult_docSimilarCount('green', $constraintElem, $cmp, $valueCount, 
                                               $resultAdditionalAtts, (), $contextInfo, $resultOptions)
        else 
            let $values := $exprValue ! xs:string(.) ! <gx:value>{.}</gx:value>
            return
                f:validationResult_docSimilarCount('red', $constraintElem, $cmp, $exprValue, 
                                                   $resultAdditionalAtts, $values, $contextInfo, $resultOptions)
};

(: ============================================================================
 :
 :     f u n c t i o n s    c r e a t i n g    v a l i d a t i o n    r e s u l t s
 :
 : ============================================================================ :)

(:~
 : Writes a validation result for a DocSimilar constraint.
 :
 : @param colour indicates success or error
 : @param constraintElem the element representing the constraint
 : @param constraint an attribute representing the main properties of the constraint
 : @param reasons strings identifying reasons of violation
 : @param additionalAtts additional attributes to be included in the validation result
 :) 
declare function f:validationResult_docSimilar($colour as xs:string,
                                               $constraintElem as element(gx:docSimilar),
                                               $constraint as attribute(),
                                               $otherDocIdentities as xs:string*,
                                               $additionalAtts as attribute()*,
                                               $additionalElems as element()*,
                                               $contextInfo as map(xs:string, item()*))
        as element() {
    let $elemName := 'gx:' || $colour
    let $constraintComponent :=
        $constraintElem/f:firstCharToUpperCase(local-name(.)) ||
        $constraint/f:firstCharToUpperCase(local-name(.))
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintId := $constraintElem/@id
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}    
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraint/local-name(.), ())
        
    return
        element {$elemName}{
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComponent},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},    
            $filePath,
            $focusNode,            
            $additionalAtts,
            $constraintElem/*,
            if (not($colour eq 'red')) then () else
                $otherDocIdentities ! <gx:value>{.}</gx:value>,
            $additionalElems
        }        
};

(:~
 : Creates a validation result for a LinkCount related constraint (LinkMinCount,
 : LinkMaxCount, LinkCount.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param valueShape the shape declaring the constraint
 : @param exprValue expression value producing the links
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_docSimilarCount($colour as xs:string,
                                                    $constraintElem as element(),
                                                    $constraint as attribute(),
                                                    $exprValue as item()*,
                                                    $additionalAtts as attribute()*,
                                                    $additionalElems as element()*,
                                                    $contextInfo as map(xs:string, item()*),
                                                    $options as map(*)?)
        as element() {
    let $exprAtt := $constraintElem/(@otherFoxpath, @otherXPath)        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^other', '') ! lower-case(.)     
    let $constraint1 := $constraint[1]
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(count) return map{'constraintComp': 'DocSimilarCount', 'atts': ('count')}
        case attribute(minCount) return map{'constraintComp': 'DocSimilarMinCount', 'atts': ('minCount')}
        case attribute(maxCount) return map{'constraintComp': 'DocSimilarMaxCount', 'atts': ('maxCount')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := 
        let $explicit := $constraintElem/@*[local-name(.) = $standardAttNames]
        return
            (: make sure the constraint attribute is included, even if it is a default constraint :)
            ($explicit, $constraint[not(. intersect $explicit)])
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintElemId := $constraintElem/@id
    let $constraintId := concat($constraintElemId, '-', $constraint1/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraint/local-name(.), ())
    let $elemName := 'gx:' || $colour
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            $filePath,
            $focusNode,
            $standardAtts,
            $useAdditionalAtts,
            $valueCountAtt,            
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            $additionalElems
        }       
};


(: ============================================================================
 :
 :     D o c u m e n t    n o r m a l i z a t i o n
 :
 : ============================================================================ :)
declare function f:normalizeDocForComparison($node as node(), 
                                             $normItems as element()*,
                                             $normOptions as map(xs:string, item()*))
        as node()? {
    let $skipPrettyWS := $normOptions?skipPrettyWS
    let $skipXmlBase := $normOptions?skipXmlBase
    
    let $selectedItems := 
        function($tree, $modifier) as node()* {
            let $kind := $modifier/@kind
            let $localName := $modifier/@localName
            let $namespace := $modifier/@namespace
            let $parentLocalName := $modifier/@parentLocalName
            let $parentNamespace := $modifier/@parentNamespace
                
            let $candidates := if ($kind eq 'attribute') then $tree//@* else $tree//*
            let $selected :=
               $candidates[not($localName) or local-name() eq $localName]
               [not(@namespace) or namespace-uri(.) eq $namespace]
               [not($parentLocalName) or ../local-name(.) eq $parentLocalName]
               [not(@parentNamespace) or ../namespace-uri(.) eq $parentNamespace]
            return $selected
        }
    return
    
    copy $node_ := $node
    modify (
        if (not($skipPrettyWS)) then ()
        else
            let $delNodes := $node_//text()[not(matches(., '\S'))][../*]
            return
                if (empty($delNodes)) then () else delete node $delNodes
        ,
        if (not($skipXmlBase) or not($node_//@xml:base)) then ()
        else
            let $delNodes := $node_//@xml:base
            return
                if (empty($delNodes)) then () else delete node $delNodes
        ,
        for $normItem in $normItems
        return
            typeswitch($normItem)
            case $skipItem as element(gx:skipItem) return
                let $selected := $selectedItems($node_, $skipItem)            
                return
                    if (empty($selected)) then () else delete node $selected
            case $roundItem as element(gx:roundItem) return
                let $selected := $selectedItems($node_, $roundItem)            
                return
                    if (empty($selected)) then () 
                    else
                        let $scale := $roundItem/@scale/number(.)  
                        
                        for $node in $selected
                        let $value := $node/number(.)
                        let $newValue := round($value div $scale, 0) * $scale
                        return replace value of node $node with $newValue
                        
            case $editText as element(gx:editText) return
                let $selected := $selectedItems($node_, $editText)
                return
                    if (empty($selected)) then ()
                    else
                        let $from  := $editText/@replaceSubstring
                        let $to := $editText/@replaceWith
                        
                        for $sel in $selected
                        let $newValue :=
                            if ($from and $to) then replace($sel, $from, $to)
                            else ()
                        return
                            if (empty($newValue)) then () else
                                replace value of node $sel with $newValue
            default return ()
    )
    return $node_
};




