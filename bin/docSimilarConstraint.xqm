(:
 : -------------------------------------------------------------------------
 :
 : docSimilarConstraint.xqm - validates a resource against a DocSimilar constraint
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

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm",
   "linkResolution.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";
declare namespace fox="http://www.foxpath.org/ns/annotations";

(:~
 : Validates a DocSimilar constraint and supplementary constraints.
 : Supplementary constraints refer to the number of items representing
 : the documents with which to compare.
 :
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return validation results, red and/or green
 :)
declare function f:validateDocSimilar($constraintElem as element(gx:docSimilar),                                      
                                      $context as map(xs:string, item()*))
        as element()* {

    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    let $useContextNode := ($contextNode, $contextDoc)[1]
    return

    (: Exception - no context document :)
    if (not($useContextNode)) then
        result:validationResult_docSimilar_exception($constraintElem, (),
            'Context resource could not be parsed', (), $context)
    else

    (: Link resolution :)
    let $ldo := link:getLinkDefObject($constraintElem, $context)
    let $lros := 
        let $options := map{'targetMediatype': 'xml'}
        return
            link:resolveLinkDef($ldo, 'lro', $contextURI, $useContextNode, $context, $options) 
            [not(?targetURI ! i:fox-resource-is-dir(.))]   (: ignore folders :)
        
    (: Check link constraints :)
    let $results_link := link:validateLinkConstraints($lros, $ldo, $constraintElem, $context) 
    
    (: Check similarity :)
    let $results_comparison := 
        f:validateDocSimilar_similarity($useContextNode, $lros, $constraintElem, $context)
        
    return ($results_link, $results_comparison)
};   

(:~
 : Validates document similarity. The node to compare with other nodes is given
 : by 'contextNode', which is either the current document or a focus node from it.
 :
 : @param contextNode the node to compare with other nodes
 : @param targetDocReps the documents with which to compare
 : @param constraintElem the schema element declaring the constraint
 : @param contextInfo information about the resource context
 : @return validation results, red or green
 :)
declare function f:validateDocSimilar_similarity(
                                      $contextNode as node(),
                                      $lros as map(*)*,
                                      $constraintElem as element(),
                                      $context as map(xs:string, item()*))
        as element()* {
        
    (: Normalization options.
         Currently, the options cannot be controlled by schema parameters;
         this will be changed when the need arises :)
    let $normOptions := map{'skipPrettyWS': true(), 'keepXmlBase': false()}        
    
    let $redReport := $constraintElem/@redReport
    
    (: Check document similarity :)
    let $results :=
        (: For each Link Resolution objects :)
        for $lro in $lros
        (: let $_DEBUG := trace(i:DEBUG_LROS($lros), '_LROS: ') :)
        
        (: Check for link error :)
        return
            if ($lro?errorCode) then
                result:validationResult_docSimilar_exception($constraintElem, $lro, (), (), $context)
            else
            
        (: Context node :)
        let $linkContextNode := ($lro?contextItem[. instance of node()], $contextNode)[1]
        
        (: Fetch target nodes :)
        let $linkTargetNodes := 
            if (map:contains($lro, 'targetNodes')) then $lro?targetNodes
            else if (map:contains($lro, 'targetDoc')) then $lro?targetDoc
            else $lro?targetURI[i:fox-doc-available(.)] ! i:fox-doc(.) 
        return
            (: Exception - no target doc :)
            if (not($linkTargetNodes)) then            
                let $msg :=
                    if ($lro?targetURI ! i:fox-resource-exists(.)) then 
                        'Similarity target resource cannot be parsed'
                    else 'Similarity target resource not found'
                return
                    result:validationResult_docSimilar_exception(
                        $constraintElem, $lro, $msg, (), $context)  
            (: Target doc available :)
            else
                    
        (: Perform comparison :)
        for $targetNode in $linkTargetNodes
        let $targetURI := $lro?targetURI
        let $d1 := f:normalizeDocForComparison($linkContextNode, $constraintElem/*, $normOptions, $targetNode)
        let $d2 := f:normalizeDocForComparison($targetNode, $constraintElem/*, $normOptions, $linkContextNode)
        let $isDocSimilar := deep-equal($d1, $d2)
        let $colour := if ($isDocSimilar) then 'green' else 'red'
        let $reports := f:docSimilarConstraintReports($constraintElem, $d1, $d2, $colour)
        return
            result:validationResult_docSimilar(
                $colour, $constraintElem, $reports, $targetURI, (), $context)
                
    return $results
};

(: ============================================================================
 :
 :     D o c u m e n t    n o r m a l i z a t i o n
 :
 : ============================================================================ :)
(:~
 : Normalization of a node prior to comparison with another node.
 :
 : @param node the node to be normalized
 : @param normItems configuration items prescribing modifications
 : @param normOptions options controlling the normalization
 : @param otherNode the node with whith to compare
 : @return the normalized node
 :)
declare function f:normalizeDocForComparison($node as node(), 
                                             $normItems as element()*,
                                             $normOptions as map(xs:string, item()*),
                                             $otherNode as node())
        as node()? {
    let $skipPrettyWS := $normOptions?skipPrettyWS
    let $keepXmlBase := $normOptions?keepXmlBase
    
    let $selectedItems := 
        function($tree, $modifier) as node()* {
            let $itemXP := $modifier/@itemXP
            return
                if ($itemXP) then
                    xquery:eval($itemXP, map{'': $tree})
                else
            let $kind := $modifier/@kind
            let $localName := $modifier/@localName
            let $namespace := $modifier/@namespace
            let $parentLocalName := $modifier/@parentLocalName
            let $parentNamespace := $modifier/@parentNamespace
            let $testXP := $modifier/@testXP
                
            let $candidates := if ($kind eq 'attribute') then $tree//@* else $tree//*
            let $selected :=
               $candidates
               [not($localName) or local-name() eq $localName]
               [not(@namespace) or namespace-uri(.) eq $namespace]
               [not($parentLocalName) or ../local-name(.) eq $parentLocalName]
               [not(@parentNamespace) or ../namespace-uri(.) eq $parentNamespace]
               [not($testXP) or boolean(f:evaluateSimpleXPath($testXP, .))]
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
        (: @xml:base attributes are removed :)
        if ($keepXmlBase) then () else
            let $xmlBaseAtts := $node_//@xml:base
            return
                if (empty($xmlBaseAtts)) then ()
                else
                    let $delNodes := $xmlBaseAtts/(., ../@fox:base-added)
                    return delete node $delNodes
        ,
        for $normItem in $normItems
        return
            typeswitch($normItem)
            
            (: Ignore items :)
            case $skipItem as element(gx:skipItem) return
                let $selected := $selectedItems($node_, $skipItem)            
                return
                    if (empty($selected)) then () else delete node $selected
                    
            (: Round numeric values :)
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
              
            (: Edit item text (string replacement) :)
            case $editItem as element(gx:editItem) return
                let $selected := $selectedItems($node_, $editItem)
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
                                replace value of node $sel with trace( $newValue , '_REPLACE_WITH_NEW_VALUE: ')
            default return ()
    )
    return $node_
};
