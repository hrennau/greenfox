(:
 : -------------------------------------------------------------------------
 :
 : linkConstraint.xqm - validates against a link constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateLinks($shape as element(), 
                                 $contextItem as item()?,
                                 $contextFilePath as xs:string,
                                 $contextDoc as document-node()?,
                                 $context as map(xs:string, item()*))
        as element()* {

    let $focusPath :=
        if ($contextItem instance of node() and not($contextItem is $contextDoc)) then
            $contextItem/f:datapath(.)
        else ()
    let $contextInfo := map:merge((
        $contextFilePath ! map:entry('filePath', .),
        $focusPath ! map:entry('nodePath', .)
    ))

    let $recursive := $shape/@recursive
    let $results :=
        if ($recursive eq 'true') then
            f:validateRecursiveLinksResolvable($contextItem, $contextFilePath, $shape, $context, $contextInfo)
        else
            f:validateLinksResolvable($contextItem, $shape, $context, $contextInfo)   
    return
        $results
};

(:~
 : Validates a LinkResolvable constraint with parameter 'recursive' equal to false.
 :
 : @param contextNode the context node
 : @param valueShape the value shape containing the constraint
 : @param context general context information
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateLinksResolvable($contextNode as node(),
                                           $valueShape as element(),
                                           $context as map(xs:string, item()*),
                                           $contextInfo as map(xs:string, item()*))
        as element()* {
           
    let $resultAdditionalAtts := ()        
    let $resultOptions := ()
    
    let $exprValue := f:resolveLinkExpression($contextNode, $valueShape, $context)    
    let $filepath := $contextInfo?filepath        
    let $mediatype := $valueShape/@mediatype
    let $errors :=    
        for $linkValue in $exprValue
        let $baseUri := (
            $linkValue[. instance of node()]/ancestor-or-self::*[1]/base-uri(.),
            $filepath
        )[1]
        let $uri := resolve-uri($linkValue, $baseUri)
        return
            if ($mediatype eq 'xml') then $linkValue[not(doc-available($uri))]
            else if ($mediatype = ('json', 'text')) then            
                let $text := if (not(unparsed-text-available($uri))) then ()
                             else unparsed-text($uri)
                return
                    if (not($text)) then $linkValue
                    else
                        let $jdoc := try {json:parse($text)} catch * {()}
                        return $linkValue[not($jdoc)]

            else
                $linkValue[not(file:exists($uri))]
    let $colour := if (exists($errors)) then 'red' else 'green'
    let $values := if (empty($errors)) then () else $errors ! string(.) => f:extractValues_linkConstraint($valueShape)
    return (
        f:validationResult_links($colour, $valueShape, $exprValue, 
                                 $resultAdditionalAtts, $values, 
                                 $contextInfo, $resultOptions),
        f:validateLinkCount(count($exprValue), $exprValue, $valueShape, $contextInfo)
    )                                 
};

(:~
 : Validates a LinkResolvable constraint with parameter 'recursive' equal to true.
 :
 : @param exprValue expression value producing the links
 : @param valueShape the value shape containing the constraint
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateRecursiveLinksResolvable($contextNode as node(),
                                                    $filepath as xs:string,
                                                    $valueShape as element(),
                                                    $context as map(xs:string, item()*),
                                                    $contextInfo as map(xs:string, item()*))
        as item()* {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $docsAndErrors := f:validateRecursiveLinksResolvableRC($contextNode, $filepath, $valueShape, $context, (), ())
    let $docs := $docsAndErrors?doc
    let $errors := $docsAndErrors[?error eq 'true']
    
    let $colour := if (exists($errors)) then 'red' else 'green'
    let $values := if (empty($errors)) then () else $errors ! <gx:value where="{?filepath}">{?linkValue}</gx:value>
    return (
        f:validationResult_links($colour, $valueShape, (), 
                                 $resultAdditionalAtts, $values, 
                                 $contextInfo, $resultOptions),
        f:validateLinkCount(count($docsAndErrors), $docsAndErrors?uri, $valueShape, $contextInfo)
    )        
};

(:~
 : Validates a LinkResolvable constraint.
 :
 : @param exprValue expression value producing the links
 : @param valueShape the value shape containing the constraint
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateRecursiveLinksResolvableRC($contextNode as node(),
                                                      $filepath as xs:string,
                                                      $valueShape as element(),
                                                      $context as map(xs:string, item()*),
                                                      $pathsSofar as xs:string*,
                                                      $errorsSofar as xs:string*)
        as item()* {
           
    let $exprValue := f:resolveLinkExpression($contextNode, $valueShape, $context)
    let $mediatype := $valueShape/@mediatype
    let $targetsAndErrors :=   
        for $linkValue in $exprValue
        let $baseUri := (
            $linkValue[. instance of node()]/ancestor-or-self::*[1]/base-uri(.),
            $filepath
        )[1]
        let $uri := resolve-uri($linkValue, $baseUri)
        where not($uri = ($pathsSofar, $errorsSofar))
        return
            if ($mediatype = 'json') then            
                if (not(unparsed-text-available($uri))) then 
                    map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                else
                    let $text := unparsed-text($uri)
                    let $jdoc := try {json:parse($text)} catch * {()}
                    return 
                        if (not($jdoc)) then 
                            map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                        else 
                            map{'uri': $uri, 'doc': $jdoc}
                        
            else  
                if (not(doc-available($uri))) then 
                    map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                else 
                    map{'uri': $uri, 'doc': doc($uri)}
    
    let $errorInfos := $targetsAndErrors[?error eq 'true'][not(?uri = $errorsSofar)]
    let $targetInfos := $targetsAndErrors[?doc][not(?uri = $pathsSofar)]
    
    let $newErrors := $errorInfos?uri[not(. = $errorsSofar)]    
    let $newPaths := $targetInfos?uri
    let $nextDocs := $targetInfos?doc
    
    let $newPathsSofar := ($pathsSofar, $newPaths)
    let $newErrorsSofar := ($errorsSofar, $newErrors)
    return (
        $errorInfos,
        $targetInfos,
        $targetInfos ! f:validateRecursiveLinksResolvableRC(?doc, ?uri, $valueShape, $context, $newPathsSofar, $newErrorsSofar)
    )
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
declare function f:validateLinkCount($valueCount as xs:integer,
                                     $exprValue as item()*,
                                     $valueShape as element(),
                                     $contextInfo as map(xs:string, item()*))
        as element()? {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    for $cmp in $valueShape/(@count, @minCount, @maxCount)
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown count comparison operator: ', $cmp))
    return        
        if ($cmpTrue($valueCount, $cmp)) then  
            f:validationResult_linkCount('green', $valueShape, $cmp, $valueCount, 
                                         $resultAdditionalAtts, (), $contextInfo, $resultOptions)
        else 
            let $values := f:extractValues_linkConstraint($exprValue, $valueShape)
            return
                f:validationResult_linkCount('red', $valueShape, $cmp, $exprValue, 
                                             $resultAdditionalAtts, $values, $contextInfo, $resultOptions)
};


(:~
 : Creates a validation result for a LinkResolvable constraint.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param exprValue expression value producing the links
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_links($colour as xs:string,
                                          $valueShape as element(),
                                          $exprValue as item()*,
                                          $additionalAtts as attribute()*,
                                          $additionalElems as element()*,
                                          $contextInfo as map(xs:string, item()*),
                                          $options as map(*)?)
        as element() {
    let $exprAtt := $valueShape/@xpath        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^link', '') ! lower-case(.)    
    let $constraintConfig := 
        map{'constraintComp': 'LinkResovableConstraint', 'atts': ('mediatype')}
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valueShape/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-linkResolvable')
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, 'link', ())
        else i:getErrorMsg($valueShape, 'link', ())
    let $elemName := 
        switch($colour)
        case 'red' return 'gx:red'
        default return concat('gx:', $colour)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute valueShapeID {$valueShapeId},  
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
declare function f:validationResult_linkCount($colour as xs:string,
                                              $valueShape as element(),
                                              $constraint as node()*,
                                              $exprValue as item()*,
                                              $additionalAtts as attribute()*,
                                              $additionalElems as element()*,
                                              $contextInfo as map(xs:string, item()*),
                                              $options as map(*)?)
        as element() {
    let $exprAtt := $valueShape/@xpath        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^link', '') ! lower-case(.)    
    let $constraint1 := $constraint[1]
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(count) return map{'constraintComp': 'LinkCount', 'atts': ('count')}
        case attribute(minCount) return map{'constraintComp': 'LinkMinCount', 'atts': ('minCount')}
        case attribute(maxCount) return map{'constraintComp': 'LinkMaxCount', 'atts': ('maxCount')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valueShape/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-', $constraint1/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePathe {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, $constraint/local-name(.), ())
        else i:getErrorMsg($valueShape, $constraint/local-name(.), ())
    let $elemName := 'gx:' || $colour
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute valueShapeID {$valueShapeId},  
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

(:~
 : Creates 'gx:value' elements describing constraint violating items.
 :
 : @param exprValue the expression value
 : @param valueShape value shape declaring the constraint
 : @return sequence of 'gx:value' elements describing constraint violating expression value items
 :)
declare function f:extractValues_linkConstraint($exprValue as item()*, $valueShape as element())
        as element()* {
    let $reporterXPath := $valueShape/@reporterXPath        
    return
        if ($reporterXPath) then
            for $item in $exprValue
            let $rep := i:evaluateSimpleXPath($reporterXPath, $item)    
            return
                <gx:value>{$rep}</gx:value>
        else
            for $item in $exprValue
            return
                typeswitch($item)
                case xs:anyAtomicType | attribute() return string($item) ! <gx:value>{.}</gx:value>
                case element() return
                    if ($item/not((@*, *))) then string ($item) ! <gx:value>{.}</gx:value>
                    else <gx:valueNodePath>{i:datapath($item)}</gx:valueNodePath>
                default return ()                
};        

(:~
 : Resolves the link expression in the context of a document to a value.
 :
 : @param doc document in the context of which the expression must be resolved
 : @param valueShape the value shape specifying the link constraints
 : @param context context for evaluations
 : @return the expression value
 :)
declare function f:resolveLinkExpression($doc as document-node(),
                                         $valueShape as element(),
                                         $context as map(xs:string, item()*))
        as item()* {
    let $mediatype := $valueShape/@mediatype    
    let $expr := $valueShape/@xpath
    let $exprLang := 'xpath'
    let $evaluationContext := $context?_evaluationContext    
    let $exprValue :=
        switch($exprLang)
        case 'xpath' return
            i:evaluateXPath($expr, $doc, $evaluationContext, true(), true())
        default return error(QName((), 'SCHEMA_ERROR'), "'Missing attribute - <links> element must have an 'xpath' attribute")
    return $exprValue        
};        
