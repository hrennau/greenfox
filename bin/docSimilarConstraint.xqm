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
    "docSimilarConstraintReports.xqm",
    "greenfoxUtil.xqm",
    "resourceAccess.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" at
    "validationResult.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkDefinition.xqm",
    "linkResolution.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";
declare namespace fox="http://www.foxpath.org/ns/annotations";


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

    (: Determine the targets of document comparison; each item should be a node or a URI :)
    let $targets := f:validateDocSimilar_targets($contextItem, $filePath, $constraintElem, $context)
    let $targetLdo := $targets?ldo
    let $targetLros := $targets?lros

    (: Check the number of items representing the documents with which to compare :)
    let $results_link := link:validateLinkConstraints($targetLros, $targetLdo, $constraintElem, $contextInfo) 
    
    (: Check the similarity :)
    let $results_comparison := 
        f:validateDocSimilar_similarity($contextItem, $targetLros, $constraintElem, $contextInfo)
        
    return
        ($results_link, $results_comparison)
};   

(:~
 : Returns the items representing the targets of document comparison. The items may be 
 : nodes or URIs.
 :
 : @param filePath filePath of the context document
 : @param constraintElem the element declaring the DocSimilar constraint
 : @param context the processing context
 :)
declare function f:validateDocSimilar_targets($contextItem as item(),
                                              $filePath as xs:string,
                                              $constraintElem as element(),
                                              $context as map(xs:string, item()*))
        as item()* {
    (: Link definition object :)
    let $ldo := link:getLinkDefObject($constraintElem, $context)
    
    (: Link resolution objects :)
    let $lros := trace(link:resolveLinkDef($ldo, 'lro', $filePath, $contextItem[. instance of node()], $context) , '_LROS: ')
    return
        map{'ldo': $ldo, 'lros': $lros}
};

(:~
 : Validates document similarity. The node to compare with other nodes is given
 : by 'contextItem', which is either the current document or a focus node from it.
 :
 : @param contextItem the context item
 : @param targetDocReps the documents with which to compare
 : @param constraintElem the schema element declaring the constraint
 : @param contextInfo information about the resource context
 : @return validation results, red or green
 :)
declare function f:validateDocSimilar_similarity($contextItem as node(),
                                                 $lros as map(*)*,
                                                 $constraintElem as element(),
                                                 $contextInfo as map(xs:string, item()*))
        as element()* {
    (: Normalization options :)
    (: Currently, the options cannot be controlled by schema parameters;
       this will be changed when the need arises
     :)
    let $normOptions :=
        map{
            'skipPrettyWS': true(),
            'keepXmlBase': false()
        }        
    
    let $redReport := $constraintElem/@redReport
    
    (: Check document similarity :)
    let $results :=
        for $lro in $lros return
        
        (: Link error :)
        if ($lro?errorCode) then
            result:validationResult_docSimilar('red', 
                $constraintElem, 
                (),
                $lro?targetURI, 
                attribute exception {$lro?errorCode},
                $contextInfo)

        else
        
        (: Get target node or document :)
        let $targetDoc :=
            if ($lro?targetNodes) then $lro?targetNodes[1]
            else if ($lro?targetDoc) then $lro?targetDoc
            else if ($lro?targetURI) then
                let $targetUri := $lro?targetURI
                where i:fox-doc-available($targetUri)
                return i:fox-doc($targetUri) 
        return
            (: Error - no target document (parsing failed) :)
            if (not($targetDoc)) then            
                result:validationResult_docSimilar('red', 
                    $constraintElem, 
                    (),
                    $lro?targetURI, 
                    attribute exception {"Target document cannot be parsed"},
                    $contextInfo)

            else
                (: Perform comparison :)
                let $targetDocIdentity := $lro?targetURI
                let $d1 := f:normalizeDocForComparison($contextItem, $constraintElem/*, $normOptions, $targetDoc)
                let $d2 := f:normalizeDocForComparison($targetDoc, $constraintElem/*, $normOptions, $contextItem)
                let $isDocSimilar := deep-equal($d1, $d2)
                let $colour := if ($isDocSimilar) then 'green' else 'red'
                let $reports := f:docSimilarConstraintReports($constraintElem, $d1, $d2, $colour)
                return
                    (: Write result :)
                    result:validationResult_docSimilar($colour, 
                                          $constraintElem, 
                                          $reports,
                                          $targetDocIdentity, 
                                          (),
                                          $contextInfo)
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
            let $targetXPath := $modifier/@targetXPath
            return
                if ($targetXPath) then
                    xquery:eval($targetXPath, map{'': $tree})
                else
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
