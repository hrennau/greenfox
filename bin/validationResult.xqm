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


