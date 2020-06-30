(:
 : -------------------------------------------------------------------------
 :
 : validationReportEditor.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 

module namespace f="http://www.greenfox.org/ns/xquery-functions/validation-result";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxEditUtil.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Maps a value causing a constraint violation to a sequence of
 : 'value' or 'valueNodePath' elements.
 :
 : @param value the offending value
 : @param valueShape a shape or constraint element which may control the value representation
 : @return elements representing the offending value
 :) 
declare function f:validationResultValues($value as item()*, 
                                          $controller as element())
        as element()* {
    let $reporterXPath := $controller/@reporterXPath        
    return
        if ($reporterXPath) then
            for $item in $value
            let $rep := i:evaluateSimpleXPath($reporterXPath, $item)    
            return
                <gx:value>{$rep}</gx:value>
        else
            for $item in $value
            return
                typeswitch($item)
                case xs:anyAtomicType | attribute() return string($item) ! <gx:value>{.}</gx:value>
                case element() return
                    if ($item/not((@*, *))) then string ($item) ! <gx:value>{.}</gx:value>
                    else <gx:valueNodePath>{i:datapath($item)}</gx:valueNodePath>
                default return ()                
};     

(:~
 : Creates a validation result for a LinksResolvable constraint.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param ldo link definition element
 : @param constraintElem constraint element, defining constraints which may override
 :   any constraints specified by the link definition element
 : @param failures link resolution elements indicating a failed link resolution
 : @param successes link resolution elements indicating a successful link resolution
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_linksResolvable($ldo as map(*)?,
                                                    $constraintElem as element(),
                                                    $contextNode as node(),
                                                    $lros as map(*)*,
                                                    $contextInfo as map(xs:string, item()*),
                                                    $options as map(*)?)
        as element() {
        
    (: Successful and failing link resolutions :)
    let $failures := $lros[?errorCode]
    let $successes := $lros[not(?errorCode)]    
    let $colour := if (exists($failures)) then 'red' else 'green'
    
    (: Recursive flag :)
    let $recursiveAtt := ($constraintElem/@recursive, $ldo?recursive ! attribute recursive {.})[1]
    
    (: Values - link values of failing links :)
    let $values :=  
        if (empty($failures)) then () 
        else if ($recursiveAtt eq 'true') then 
            $failures ! <gx:value where="{?contextURI}">{?linkValue}</gx:value>
        else 
            $failures ! <gx:value>{?linkValue}</gx:value>
    
    (: Link description attributes :)
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    (: Counts of successful and failing link resolutions :)
    let $failures := $lros[?errorCode]
    let $successes := $lros[not(?errorCode)]    
    let $countResolved := attribute countResolved {count($successes)} 
    let $countUnresolved := attribute countUnresolved {count($failures)}
    let $errorCodes := $failures?errorCode => distinct-values() => string-join('; ')
    
    (: Link description attributes :)
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    (: Error codes :)
    let $errorCodes := ($lros?errorCode => distinct-values() => string-join('; '))[string()]
    
    (: Component identification :)
    let $constraintComp := 'LinkResolvable'
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $valueShapeId := $constraintElem/@valueShapeID
    let $constraintId := concat(($valueShapeId, $resourceShapeId)[1], '-linkResolvable')
    
    (: Data location :)
    let $filePath := $contextInfo?filePath ! attribute contextURI {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    let $contextNodeDataPath := $contextNode/i:datapath(.)

    (: Message :)
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, 'resolvable', ())
        else i:getErrorMsg($constraintElem, 'resolvable', ())
        
    return
        element {'gx:' || $colour} {
            $msg ! attribute msg {.},
            $errorCodes ! attribute errorCode {.},
            attribute constraintComp {$constraintComp},
            $constraintId ! attribute constraintID {.},
            $valueShapeId ! attribute valueShapeID {.},
            $resourceShapeId ! attribute resourceShapeID {.},
            $filePath,
            $focusNode,
            $contextNodeDataPath ! attribute contextNodeDataPath {.},
            $countUnresolved,
            $countResolved,   
            $linkDefAtts,
            $recursiveAtt,
            $values
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
declare function f:validationResult_linkCount($ldo as map(*)?,
                                              $constraintElem as element(),
                                              $constraint as attribute(),                                              
                                              $lros as map(*)*,                                              
                                              $colour as xs:string,
                                              $valueCount as item()*,
                                              $contextNode as node()?,
                                              $contextInfo as map(xs:string, item()*),
                                              $options as map(*)?)
        as element() {
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(countContextNodes)       return map{'constraintComp': 'LinkContextNodesCount',    'atts': ('countContextNodes')}
        case attribute(minCountContextNodes)    return map{'constraintComp': 'LinkContextNodesMinCount', 'atts': ('minCountContextNodes')}
        case attribute(maxCountContextNodes)    return map{'constraintComp': 'LinkContextNodesMaxCount', 'atts': ('maxCountContextNodes')}
        case attribute(countTargetResources)    return map{'constraintComp': 'LinkTargetResourcesCount',    'atts': ('countTargetResources')}
        case attribute(minCountTargetResources) return map{'constraintComp': 'LinkTargetResourcesMinCount', 'atts': ('minCountTargetResources')}
        case attribute(maxCountTargetResources) return map{'constraintComp': 'LinkTargetResourcesMaxCount', 'atts': ('maxCountTargetResources')}
        case attribute(countTargetDocs)         return map{'constraintComp': 'LinkTargetDocsCount',         'atts': ('countTargetDocs')}
        case attribute(minCountTargetDocs)      return map{'constraintComp': 'LinkTargetDocsMinCount',      'atts': ('minCountTargetDocs')}
        case attribute(maxCountTargetDocs)      return map{'constraintComp': 'LinkTargetDocsMaxCount',      'atts': ('maxCountTargetDocs')}
        case attribute(countTargetNodes)        return map{'constraintComp': 'LinkTargetNodesCount',        'atts': ('countTargetNodes')}
        case attribute(minCountTargetNodes)     return map{'constraintComp': 'LinkTargetNodesMinCount',     'atts': ('minCountTargetNodes')}
        case attribute(maxCountTargetNodes)     return map{'constraintComp': 'LinkTargetNodesMaxCount',     'atts': ('maxCountTargetNodes')}
        case attribute(countAllTargetResources)    return map{'constraintComp': 'LinkAllTargetResourcesCount',    'atts': ('countAllTargetResources')}
        case attribute(minCountAllTargetResources) return map{'constraintComp': 'LinkAllTargetResourcesMinCount', 'atts': ('minCountAllTargetResources')}
        case attribute(maxCountAllTargetResources) return map{'constraintComp': 'LinkAllTargetResourcesMaxCount', 'atts': ('maxCountAllTargetResources')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := 
        let $explicit := $constraintElem/@*[local-name(.) = $standardAttNames]
        return
            (: make sure the constraint attribute is included, even if it is a default constraint :)
            ($explicit, $constraint[not(. intersect $explicit)])
    let $valueCountAtt := attribute valueCount {$valueCount} 
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintElemId := $constraintElem/@id
    let $constraintId := concat($constraintElemId, '-', $constraint/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    let $contextNodeDataPath := $contextNode/i:datapath(.)

    (: Link description attributes :)
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    (: Error codes :)
    let $errorCodes := ($lros?errorCode => distinct-values() => string-join('; '))[string()]
    
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraint/local-name(.), ())
    let $elemName := 'gx:' || $colour
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            $errorCodes ! attribute errorCode {.},            
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            $filePath,
            $focusNode,
            $linkDefAtts,
            $contextNodeDataPath ! attribute contextNodeDataPath {.},
            $standardAtts,
            $valueCountAtt            
        }       
};

declare function f:validateResult_linkDefAtts($ldo as map(*)?,
                                              $constraintElem as element()?)
        as attribute()* {
    let $exprAtts := ( 
        $constraintElem/@link ! attribute link {.},
        ($constraintElem/@hrefXP, $ldo?hrefXP ! attribute hrefXP {.})[1],    
        ($constraintElem/@uriXP, $ldo?uriXP ! attribute uriXP {.})[1],        
        ($constraintElem/@linkXP, $ldo?linkXP ! attribute linkXP {.})[1],        
        ($constraintElem/@linkContextXP, $ldo?linkContextXP ! attribute linkContextXP {.})[1],
        ($constraintElem/@linkTargetXP, $ldo?linkTargetXP ! attribute linkTargetXP {.})[1]
    )
    return $exprAtts
        
};        

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         D o c S i m i l a r    c o n s t r a i n t
 :
 : ===============================================================================
 :)
(:~
 : Creates a validation result for a DocSimilar constraint.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param constraintElem the schema element declarating the constraint
 : @param comparisonReports reports describing document differences
 : @param targetDocURI the URI of the target document of the comparison
 : @param exception an exception event precluding normal validation
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validationResult_docSimilar($colour as xs:string,
                                               $constraintElem as element(gx:docSimilar),
                                               $comparisonReports as element()*,
                                               $targetDocURI as xs:string?,
                                               $exception as attribute(exception)?,
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
            $exception,
            $filePath,
            $focusNode,            
            $modifiers,
            $reports
        }        
};

(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of a DocSimilar constraint. Such 
 : an exceptional condition is, for example, a failure to resolve a 
 : link definition used to identify the target resource taking part 
 : in the similarity checking.
 :
 : @param constraintElem an element declaring a DocSimilar constraint 
 : @param lro Link Resolution Object describing the attempt to resolve 
 :   a link description
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param contextInfo informs about the focus document and focus node
 : @return a red validation result
 :)
declare function f:validationResult_docSimilar_exception(
                                            $constraintElem as element(),
                                            $lro as map(*)?,        
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $contextInfo as map(xs:string, item()*))
        as element() {
    let $constraintComp := 'DocSimilarConstraint'        
    let $constraintId := $constraintElem/@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $contextItemInfo :=
        if (empty($lro)) then ()
        else
            let $contextItem := $lro?contextItem
            return
                if (not($contextItem instance of node())) then ()
                else attribute contextItem {i:datapath($contextItem)}
    let $targetInfo := $lro?targetURI ! attribute targetURI {.}    
    let $msg :=
        if ($exception) then $exception
        else if (exists($lro)) then
            let $errorCode := $lro?errorCode
            return
                if ($errorCode) then
                    switch($errorCode)
                    case 'no_resource' return 'Correspondence target resource not found'
                    case 'no_text' return 'Correspondence target resource not a text file'
                    case 'not_json' return 'Correspondence target resource not a valid JSON document'
                    case 'not_xml' return 'Correspondence target resource not a valid XML document'
                    case 'href_selection_not_nodes' return
                        'Link error - href expression does not select nodes'
                    case 'uri' return
                        'Target URI not a valid URI'
                    default return concat('Unexpected error code: ', $errorCode)
                else if ($lro?targetURI ! i:fox-resource-exists(.)) then 
                    'Correspondence target resource cannot be parsed'
                else 
                    'Correspondence target resource not found'
        
    return
        element {'gx:red'} {
            attribute exception {$msg},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            $contextItemInfo,
            $targetInfo,
            $addAtts,
            $filePathAtt,
            $focusNodeAtt
        }       
};

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         C o n t e n t    C o r r e s p o n d e n c e    c o n s t r a i n t
 :
 : ===============================================================================
 :)
 
(:~
 : Constructs a validation result obtained from the validation of a Content 
 : Correspondence sconstraint.
 :
 : @param colour describes the success status - success, failure, warning
 : @param violations items violating the constraint
 : @param cmp operator of comparison
 : @param valuePair an element declaring a Correspondence Constraint on a 
 :   pair of content values
 : @contextInfo informs about the focus document and focus node
 :)
declare function f:validationResult_concord($colour as xs:string,
                                            $violations as item()*,
                                            $cmp as xs:string,
                                            $valuePair as element(),
                                            $contextInfo as map(xs:string, item()*))
        as element() {
    let $constraintId := $valuePair/@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $cmpAtt := $cmp ! attribute correspondence {.}
    let $useDatatypeAtt := $valuePair/@useDatatype ! attribute useDatatype {.}
    let $flagsAtt := $valuePair/@flags[string()] ! attribute flags {.}
    let $constraintComp := 'ContentCorrespondence-' || $cmp
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valuePair, $cmp, ())
        else i:getErrorMsg($valuePair, $cmp, ())
    let $elemName := concat('gx:', $colour)
    let $sourceExprLang := 'xpath'
    let $targetExprLang := 'xpath'    
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            $filePathAtt,
            $focusNodeAtt,
            $valuePair/@sourceXP ! attribute expr {.},
            attribute exprLang {$sourceExprLang},            
            $valuePair/@targetXP ! attribute targetExpr {.},
            attribute targetExprLang {$targetExprLang},
            $cmpAtt,
            $useDatatypeAtt,
            $flagsAtt,
            $violations ! <gx:value>{.}</gx:value>
        }
       
};

(:~
 : Creates a validation result for a ContentCorrespondenceCount related 
 : constraint (ContentCorrespondenceSourceCount, ...SourceMinCount, ...SourceMaxCount, 
 : ContentCorrespondenceTargetCount, ...TargetMinCount, ...TargetMaxCount).
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param valuePair an element declaring a Correspondence Constraint on a 
 :   pair of content values
 : @param constraint a constraint expressing attribute (e.g. @sourceMinCount)
 : @param valueCount the actual number of values 
 : @param contextInfo informs about the focus document and focus node
 : @return a validation result, red or green
 :)
declare function f:validationResult_concord_counts($colour as xs:string,
                                                   $valuePair as element(),
                                                   $constraint as attribute(),
                                                   $valueCount as item()*,
                                                   $contextInfo as map(xs:string, item()*))
        as element() {
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(countSource)    return map{'constraintComp': 'ContentCorrespondenceSourceValueCount',    'atts': ('countSource')}
        case attribute(minCountSource) return map{'constraintComp': 'ContentCorrespondenceSourceValueMinCount', 'atts': ('minCountSource')}        
        case attribute(maxCountSource) return map{'constraintComp': 'ContentCorrespondenceSourceValueMaxCount', 'atts': ('maxCountSource')}        
        case attribute(countTarget)    return map{'constraintComp': 'ContentCorrespondenceTargetValueCount',    'atts': ('countTarget')}
        case attribute(minCountTarget) return map{'constraintComp': 'ContentCorrespondenceTargetValueMinCount', 'atts': ('minCountTarget')}        
        case attribute(maxCountTarget) return map{'constraintComp': 'ContentCorrespondenceTargetValueMaxCount', 'atts': ('maxCountTarget')}        
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valuePair/@*[local-name(.) = $standardAttNames]
    let $valueCountAtt := attribute valueCount {$valueCount} 
    
    let $resourceShapeId := $valuePair/@resourceShapeID
    let $constraintElemId := $valuePair/@id
    let $constraintId := concat($constraintElemId, '-', $constraint/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valuePair, $constraint/local-name(.), ())
        else i:getErrorMsg($valuePair, $constraint/local-name(.), ())
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
            $valueCountAtt            
        }       
};

(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of a Content Correspondence 
 : constraint. Such an exceptional condition is, for example, a 
 : failure to resolve a link definition used to identify the target 
 : resource taking part in the correspondence checking.
 :
 : @param constraintElem an element declaring a DocSimilar constraint
 : @param lro Link Resolution Object describing the attempt to resolve 
 :   a link description
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param contextInfo informs about the focus document and focus node
 : @return a red validation result
 :)
declare function f:validationResult_concord_exception(
                                            $constraintElem as element(),
                                            $lro as map(*)?,        
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $contextInfo as map(xs:string, item()*))
        as element() {
    let $constraintComp := 'ContentCorrespondence'        
    let $constraintId := $constraintElem/@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $contextItemInfo :=
        if (empty($lro)) then ()
        else
            let $contextItem := $lro?contextItem
            return
                if (not($contextItem instance of node())) then ()
                else attribute contextItem {i:datapath($contextItem)}
    let $targetInfo := $lro?targetURI ! attribute targetURI {.}    
    let $msg :=
        if ($exception) then $exception
        else if (exists($lro)) then
            let $errorCode := $lro?errorCode
            return
                if ($errorCode) then
                    switch($errorCode)
                    case 'no_resource' return 'Correspondence target resource not found'
                    case 'no_text' return 'Correspondence target resource not a text file'
                    case 'not_json' return 'Correspondence target resource not a valid JSON document'
                    case 'not_xml' return 'Correspondence target resource not a valid XML document'
                    case 'href_selection_not_nodes' return
                        'Link error - href expression does not select nodes'
                    case 'uri' return
                        'Target URI not a valid URI'
                    default return concat('Unexpected error code: ', $errorCode)
                else if ($lro?targetURI ! i:fox-resource-exists(.)) then 
                    'Correspondence target resource cannot be parsed'
                else 
                    'Correspondence target resource not found'
        
    return
        element {'gx:red'} {
            attribute exception {$msg},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            $contextItemInfo,
            $targetInfo,
            $addAtts,
            $filePathAtt,
            $focusNodeAtt
        }
       
};


