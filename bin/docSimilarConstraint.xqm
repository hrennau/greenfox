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
    let $results_count := f:validateDocSimilarCount($targetLros, $constraintElem, $contextInfo)
    
    (: Check the similarity :)
    let $results_comparison := 
        f:validateDocSimilar_similarity($contextItem, $targetLros, $constraintElem, $contextInfo)
        
    return
        ($results_count, $results_comparison)
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
    let $lros := link:resolveLinkDef($ldo, 'lro', $filePath, $contextItem[. instance of node()], $context)
    return
        map{'ldo': $ldo, 'lros': $lros}
};

(:~
 : Validates document similarity.
 :
 : @param contextItem the context item
 : @param targetDocReps the documents with which to compare
 : @param constraintElem the schema element declaring the constraint
 : @param contextInfo information about the resource context
 : @return validation results, red or green
 :)
declare function f:validateDocSimilar_similarity($contextItem as node(),
                                                 $targetDocReps as item()*,
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
    
    (: Provide the documents with which to compare :)
    let $targetDocs :=
        for $rep in $targetDocReps 
        return
            typeswitch($rep)
            case $lro as map(*) return
                if ($lro?targetDoc) then $lro?targetDoc
                else if ($lro?targetURI) then
                    let $targetUri := $lro?targetURI
                    return
                        if (i:fox-doc-available($targetUri)) then i:fox-doc($targetUri) 
                        else error(QName((), 'UNEXPECTED_ERROR'), concat('Document cannot be parsed: ', $targetUri))  
                        (: _TO_DO_ - create red result :)
                else error()    
            (:    
            case node() return $rep
            case xs:anyAtomicType return 
                if (i:fox-doc-available($rep)) then i:fox-doc($rep) 
                else error(QName((), 'UNEXPECTED_ERROR'), concat('Document cannot be parsed: ', $rep))  
                (: _TO_DO_ - create red result :)
            :)
            default return error()

    (: Check document similarity :)
    let $results :=
        for $targetDoc at $pos in $targetDocs
        let $targetDocRep := $targetDocReps[$pos]
        let $targetDocIdentity := (
            if ($targetDocRep instance of map(*)) then $targetDocRep?targetURI
            else if ($targetDocRep instance of xs:anyAtomicType) then $targetDocRep
            else
                let $baseUri := $targetDocRep/i:fox-base-uri(.)
                let $datapath := i:datapath($targetDocRep)
                return
                    concat($baseUri, '#', $datapath)
        )
        let $d1 := f:normalizeDocForComparison($contextItem, $constraintElem/*, $normOptions, $targetDoc)
        let $d2 := f:normalizeDocForComparison($targetDoc, $constraintElem/*, $normOptions, $contextItem)
        let $isDocSimilar := deep-equal($d1, $d2)
        let $colour := if ($isDocSimilar) then 'green' else 'red'
        let $reports := f:docSimilarConstraintReports($constraintElem, $d1, $d2, $colour)
        return
            f:validationResult_docSimilar($colour, 
                                          $constraintElem, 
                                          $reports,
                                          $targetDocIdentity, 
                                          $contextInfo)
    return $results
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
            f:validationResult_docSimilarCount('green', $constraintElem, $cmp, $valueCount, (), $contextInfo, $resultOptions)
        else 
            let $values := 
                for $v in $exprValue
                let $rep :=
                    typeswitch($v)
                    case map(*) return $v?targetURI
                    case xs:anyAtomicType return string($v)
                    default return ()
                where $rep
                return $rep ! <gx:value>{.}</gx:value>
            return
                f:validationResult_docSimilarCount('red', $constraintElem, $cmp, $valueCount, $values, $contextInfo, $resultOptions)
};

(: ============================================================================
 :
 :     f u n c t i o n s    c r e a t i n g    v a l i d a t i o n    r e s u l t s
 :
 : ============================================================================ :)

(:~
 : Creates a validation result for a DocSimilar constraint.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param constraintElem the schema element declarating the constraint
 : @param comparisonReports optional reports of document differences
 : @param targetDocURI the URI of the target document of the comparison
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)

declare function f:validationResult_docSimilar($colour as xs:string,
                                               $constraintElem as element(gx:docSimilar),
                                               $comparisonReports as element()*,
                                               $targetDocURI as xs:string?,
                                               $contextInfo as map(xs:string, item()*))
        as element() {
    let $elemName := 'gx:' || $colour
    let $constraintComponent := 'DocSimilarConstraint'
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintId := $constraintElem/@id
    
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, 'similar', ())
        else i:getErrorMsg($constraintElem, 'similar', ())
    let $reports :=
        if (not($comparisonReports)) then () else
            <gx:reports>{
                $comparisonReports
            }</gx:reports>
    let $modifiers :=
        if (not($constraintElem/*)) then () else
        <gx:modifiers>{
            $constraintElem/*
        }</gx:modifiers>
        
    let $reports := $comparisonReports
    return
        element {$elemName}{
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComponent},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},    
            attribute targetDocURI {$targetDocURI},
            $filePath,
            $focusNode,            
            $modifiers,
            $reports
        }        
};

(:~
 : Creates a validation result for a DocSimilar count related constraint (DocSimilarCount,
 : DocSimilarMinCount, DocSimilarMaxCount).
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param constraintElem element declaring the constraint
 : @param constraintAtt attribute declaring the constraint
 : @param valueCount the actual number of comparison targets
 : @param values describes the comparison targets (e.g. URIs) 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_docSimilarCount($colour as xs:string,
                                                    $constraintElem as element(),
                                                    $constraintAtt as attribute(),
                                                    $valueCount as xs:integer,
                                                    $values as element()*,
                                                    $contextInfo as map(xs:string, item()*),
                                                    $options as map(*)?)
        as element() {
    let $atts := $constraintAtt
    let $constraintName := $constraintAtt/local-name()
    let $constraintComp := 'DocSimilar' || f:firstCharToUpperCase($constraintName)
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintElemId := $constraintElem/@id
    let $constraintId := concat($constraintElemId, '-', $constraintName)
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraintName, ())
        else i:getErrorMsg($constraintElem, $constraintName, ())
    let $elemName := 'gx:' || $colour
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            $filePath,
            $focusNode,
            $atts,
            attribute valueCount {$valueCount},
            $values
        }       
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
