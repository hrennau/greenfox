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

    (: Adhoc addition of $filePath and $fileName :)
    (:
    let $evaluationContext := $context?_evaluationContext
    let $evaluationContext := map:put($evaluationContext, QName((),'filePath'), $filePath)
    let $evaluationContext := map:put($evaluationContext, QName((), 'fileName'), replace($filePath, '.*[/\\]', ''))
    let $context := map:put($context, '_evaluationContext', $evaluationContext)
     :)
     
    (: Determine items representing the documents with which to compare;
       each item should be either a node or a URI :)
    let $targets := f:validateDocSimilar_targets($filePath, $constraintElem, $context)

    (: Check the number of items representing the documents with which to compare :)
    let $results_count := f:validateDocSimilarCount($targets, $constraintElem, $contextInfo)
    
    (: Check the similarity :)
    let $results_comparison := 
        f:validateDocSimilar_similarity($contextItem, $targets, $constraintElem, $contextInfo)
        
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
declare function f:validateDocSimilar_targets($filePath as xs:string,
                                              $constraintElem as element(),
                                              $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $foxpath := $constraintElem/@foxpath
    return    
        if ($foxpath) then f:evaluateFoxpath($foxpath, $filePath, $evaluationContext, true())
        else 
            let $ldo :=
                if ($constraintElem/@linkName) then $constraintElem/@linkName/link:linkDefObject(., $context)
                else link:parseLinkDef($constraintElem)
            return
                if (empty($ldo)) then error((), 
                    concat('docSimilar constraint element does not identify link targets; ',
                           'use @foxpath, @link or link defining attributes like @hrefXP'))
                else
                    link:resolveLinkDef($ldo, 'doc', $filePath, (), $context)
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
            'keepXmlBase': false()
        }
    (: Currently, the options cannot be controlled by schema parameters;
       this will be changed when the need arises
     :)
    
    let $redReport := $constraintElem/@redReport
    
    let $otherDocs :=
        for $rep in $otherDocReps 
        return
            typeswitch($rep)
            case node() return $rep
            case xs:anyAtomicType return 
                if (i:fox-doc-available($rep)) then i:fox-doc($rep) 
                else error(QName((), 'UNEXPECTED_ERROR'), concat('Document cannot be parsed: ', $rep))  
                (: _TO_DO_ - create red result :)
            default return ()

    (: Check document similarity :)
    let $comparisonReports :=
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
        let $d1 := f:normalizeDocForComparison($contextItem, $constraintElem/*, $normOptions, $otherDoc)
        let $d2 := f:normalizeDocForComparison($otherDoc, $constraintElem/*, $normOptions, $contextItem)
        let $isDocSimilar := deep-equal($d1, $d2)
        let $colour := if ($isDocSimilar) then 'green' else 'red'
        let $report := f:docSimilarConstraintReports($constraintElem, $d1, $d2, $colour)
        return
            map:merge((
                map:entry('colour', $colour),
                map:entry('otherDocIdentity', $otherDocIdentity),
                if (not($report)) then () else map:entry('report', $report)
            ))

    return
        let $colour := if (some $r in $comparisonReports satisfies $r?colour eq 'red') then 'red' else 'green'
        let $otherDocIdentities := 
            if ($colour eq 'red') then $comparisonReports[?colour eq 'red'] ! ?otherDocIdentity
            else $comparisonReports?otherDocIdentity
        return
            f:validationResult_docSimilar($colour, 
                                          $constraintElem, 
                                          $constraintElem/(@foxpath, @linkName)[1], 
                                          $comparisonReports,
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
                                               $comparisonReports as map(xs:string, item()*)*,
                                               $targetDocURIs as xs:string*,
                                               $additionalAtts as attribute()*,
                                               $additionalElems as element()*,
                                               $contextInfo as map(xs:string, item()*))
        as element() {
    let $elemName := 'gx:' || $colour
    let $constraintComponent := 'DocSimilarConstraint'
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintId := $constraintElem/@id
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}    
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraint/local-name(.), ())
        
    let $reports := $comparisonReports[?report] ! 
            <gx:report targetDocURI="{?targetDocURIs}">{?report}</gx:report>
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
            $targetDocURIs ! <gx:targetDocURI>{.}</gx:targetDocURI>,
            $additionalElems,
            if (empty($reports)) then () else
                <gx:reports>{$reports}</gx:reports>
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
    let $exprAtt := $constraintElem/(@foxpath, @hrefXP)        
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
