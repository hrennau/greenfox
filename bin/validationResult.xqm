(:
 : -------------------------------------------------------------------------
 :
 : validationReportEditor.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 

module namespace f="http://www.greenfox.org/ns/xquery-functions/validation-result";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at
    "greenfoxUtil.xqm",
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

declare function f:validationResultValues($value as item()*,
                                          $constraintElem as element(),
                                          $contextDoc as node()?)
        as element()* {
    let $nodePath := function($item) {trace(i:datapath($item), '_DATAPATH: ')[$item/ancestor::node() intersect $contextDoc]}        
    for $item in $value
    return
        typeswitch(trace($item, '_ITEM: ')  )
        case xs:anyAtomicType return string($item) ! <gx:value>{.}</gx:value>
        case element() return
            if ($item/not((@*, *))) then 
                string ($item) ! <gx:value>{$nodePath($item) ! attribute nodePath {.}, $item}</gx:value>
            else $nodePath($item) ! <gx:valueNodePath>{.}</gx:valueNodePath>
        case attribute() return
            <gx:value>{attribute nodePath {trace($nodePath($item), '_NODEPATH: ')}, string($item)}</gx:value>
        default return ()                
};     

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         t a r g e t    c o u n t    c o n s t r a i n t s
 :
 : ===============================================================================
 :)

(:~
 : Writes a validation result, for constraint components FileName*, FileSize*,
 : LastModified*.
 :
 : @param colour the colour of the result
 : @param constraintElem the element containing the attributes declaring the constraint
 : @param constraint the main attribute declaring the constraint 
 : @param actualValue the actual value of the file property
 : @param additionalAtts additional attributes to be included in the result
 : @return an element representing a 'red' or 'green' validation result
 :)
declare function f:validationResult_fileProperties($colour as xs:string,
                                                   $constraintElem as element(),
                                                   $constraint as attribute(),
                                                   $context as map(xs:string, item()*),
                                                   $actualValue as item(),
                                                   $additionalAtts as attribute()*) 
        as element() {
    let $contextURI := $context?_targetInfo?contextURI        
    let $constraintComp :=
        $constraintElem/i:firstCharToUpperCase(local-name(.)) ||
        $constraint/i:firstCharToUpperCase(local-name(.))
        
    let $resourcePropertyName :=
        switch(local-name($constraintElem))
        case 'fileName' return 'File name'
        case 'fileSize' return 'File size'
        case 'lastModified' return 'Last modified time'
        default return error()
        
    let $compare :=
        switch(local-name($constraint))
        case 'eq' return 'be equal to'
        case 'ne' return 'not be equal to'
        case 'lt' return 'be less than'
        case 'le' return 'be less than or equal to'        
        case 'gt' return 'be greater than'
        case 'ge' return 'be greater than or equal to'        
        case 'like' return 'match the pattern'
        case 'notLike' return 'not match the pattern'
        case 'matches' return 'match the regex'
        case 'notMatches' return 'not match the regex'
        default return 'satisfy'
        
    let $elemName := 'gx:' || $colour    
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else 
            i:getErrorMsg($constraintElem, 
                          $constraint/local-name(.), 
                          concat($resourcePropertyName, ' should ', $compare,
                          " '", $constraint, "'"))
    let $values := f:validationResultValues($actualValue, $constraintElem)
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintId := $constraintElem/@id || '-' || $constraint/local-name(.)
    return
    
        element {$elemName} {
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},   
            $contextURI ! attribute filePath {.},
            $constraint,
            $additionalAtts,
            $values
        }                                          
};

(:~
 : Creates a validation result for a LinkResolvable constraint. The result
 : reports the outcome obtained for a single context point, which may be
 : a document URI or a link context node.
 :
 : @param ldo link definition element
 : @param constraintElem constraint element, defining constraints which may override
 :   any constraints specified by the link definition element
 : @param linkContextItem the link context item
 : @param lros Link Resolution objects obtained for a single context point
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_linkResolvable($ldo as map(*)?,
                                                   $lros as map(*)*,
                                                   $constraintElem as element(),
                                                   $linkContextItem as node(),
                                                   $contextInfo as map(xs:string, item()*),
                                                   $options as map(*)?)
        as element() {

    (: Successful and failing link resolutions :)
    let $failures := $lros[?errorCode]
    let $successes := $lros[not(?errorCode)]    
    let $colour := if (exists($failures)) then 'red' else 'green'
    
    (: Link description attributes :)
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    let $recursiveAtt := $linkDefAtts/self::attribute(recursive)
    
    (: Values - link values of failing links :)
    let $values := 
        if (empty($failures)) then () else
            $failures ! 
            <gx:value>{
                attribute where {?contextURI} [$recursiveAtt eq 'true'],
                ?errorCode ! attribute errorCode {.},
                ?targetURI            
            }</gx:value>
    
    (: Counts of successful and failing link resolutions :)
    let $countResolved := attribute countResolved {count($successes)} 
    let $countUnresolved := attribute countUnresolved {count($failures)}
    
    (: Error codes :)
    let $errorCodes := ($lros?errorCode => distinct-values() => string-join('; '))[string()]
    
    (: Component identification :)
    let $constraintComp := 'LinkResolvable'
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $valueShapeId := $constraintElem/@valueShapeID
    let $constraintId := concat(($valueShapeId, $resourceShapeId)[1], '-linkResolvable')
    
    (: Data location :)
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    let $linkContextPath := $linkContextItem[. instance of node()] ! i:datapath(.)

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
            $linkContextPath[string()] ! attribute linkContextNodePath {.},
            $countUnresolved,
            $countResolved,   
            $linkDefAtts,

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
declare function f:validationResult_linkCount($colour as xs:string,
                                              $ldo as map(*)?,
                                              $lros as map(*)*,
                                              $constraintElem as element(),
                                              $constraintAtt as attribute(),                                             
                                              $valueCount as item()*,
                                              $contextNode as node()?,
                                              $contextInfo as map(xs:string, item()*),
                                              $options as map(*)?)
        as element() {
    let $constraintConfig :=
        typeswitch($constraintAtt)
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
        case attribute(countTargetResourcesPerContextPoint)    return map{'constraintComp': 'LinkTargetResourcesPerContextPointCount',    'atts': ('countAllTargetResourcesPerContextPoint')}
        case attribute(minCountTargetResourcesPerContextPoint) return map{'constraintComp': 'LinkTargetResourcesPerContextPointMinCount', 'atts': ('minCountAllTargetResourcesPerContextPoint')}
        case attribute(maxCountTargetResourcesPerContextPoint) return map{'constraintComp': 'LinkTargetResourcesPerContextPointMaxCount', 'atts': ('maxCountAllTargetResourcesPerContextPoint')}
        case attribute(countTargetDocsPerContextPoint)    return map{'constraintComp': 'LinkTargetDocsPerContextPointCount',    'atts': ('countAllTargetDocsPerContextPoint')}
        case attribute(minCountTargetDocsPerContextPoint) return map{'constraintComp': 'LinkTargetDocsPerContextPointMinCount', 'atts': ('minCountAllTargetDocsPerContextPoint')}
        case attribute(maxCountTargetDocsPerContextPoint) return map{'constraintComp': 'LinkTargetDocsPerContextPointMaxCount', 'atts': ('maxCountAllTargetDocsPerContextPoint')}
        case attribute(countTargetNodesPerContextPoint)    return map{'constraintComp': 'LinkTargetNodesPerContextPointCount',    'atts': ('countAllTargetNodesPerContextPoint')}
        case attribute(minCountTargetNodesPerContextPoint) return map{'constraintComp': 'LinkTargetNodesPerContextPointMinCount', 'atts': ('minCountAllTargetNodesPerContextPoint')}
        case attribute(maxCountTargetNodesPerContextPoint) return map{'constraintComp': 'LinkTargetNodesPerContextPointMaxCount', 'atts': ('maxCountAllTargetNodesPerContextPoint')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := 
        let $explicit := $constraintElem/@*[local-name(.) = $standardAttNames]
        return
            (: make sure the constraint attribute is included, even if it is a default constraint :)
            ($explicit, $constraintAtt[not(. intersect $explicit)])
    let $valueCountAtt := attribute valueCount {$valueCount} 
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintElemId := $constraintElem/@id
    let $constraintId := concat($constraintElemId, '-', $constraintAtt/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    let $contextNodeDataPath := $contextNode/i:datapath(.)

    (: Link description attributes :)
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    (: Error codes :)
    let $errorCodes := ($lros?errorCode => distinct-values() => string-join('; '))[string()]
    
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraintAtt/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraintAtt/local-name(.), ())
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
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         t a r g e t    c o u n t    c o n s t r a i n t s
 :
 : ===============================================================================
 :)
(:~
 : Creates a validation result for constraint components TargetCount, TargetMinCount, 
 : TargetMaxCount.
 :
 : @param constraint element defining the constraint
 : @param colour the kind of results - green or red
 : @param msg a message overriding the message read from the constraint element
 : @param constraintComp string identifying the constraint component
 : @param constraint an attribute specifying a constraint (e.g. @minCount=...)
 : @param the actual number of target instances
 : @return a result element 
 :)
declare function f:validationResult_targetCount(
                                    $colour as xs:string,
                                    $ldo as map(*)?,
                                    $resourceShape as element(),
                                    $constraintElem as element(gx:targetSize),
                                    $constraintAtt as attribute(),
                                    $targetItems as item()*,
                                    $targetContextPath as xs:string)
        as element() {
    let $actCount := count($targetItems)        
    let $elemName := if ($colour eq 'green') then 'gx:green' else 'gx:red'
    let $constraintComp := 'Target' || $constraintAtt/i:firstCharToUpperCase(local-name(.))
    let $msg :=
        if ($colour eq 'green') then $constraintElem/i:getOkMsg(., $constraintAtt/local-name(.), ())
        else $constraintElem/i:getErrorMsg(., $constraintAtt/local-name(.), ())
        
    (: Link description attributes :)
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    (: Values :)
    let $values :=
        if (not($colour = ('red', 'yellow'))) then ()
        else f:validationResultValues($targetItems, $constraintElem)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute filePath {$targetContextPath},
            attribute constraintComp {$constraintComp},
            $constraintElem/@id/attribute constraintID {. || '-' || $constraintAtt/local-name(.)},                    
            $constraintElem/@resourceShapeID,
            $constraintAtt,
            attribute valueCount {$actCount},
            attribute targetContextPath {$targetContextPath},
            $linkDefAtts,
            $values
        }
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
 :         F o l d e r S i m i l a r    c o n s t r a i n t
 :
 : ===============================================================================
 :)
 
(:~
 : Writes a validation result for a FolderSimilar constraint.
 :
 : @param colour indicates success or error
 : @param ldo Link Definition Object, used to identify the target folders
 : @param constraintElem the element declaring the constraint
 : @param values values violating the constraint
 : @return validation result
 :) 
declare function f:validationResult_folderSimilar(
                                          $colour as xs:string,
                                          $targetFolder as xs:string,
                                          $ldo as map(*)?,                                          
                                          $constraintElem as element(gx:folderSimilar),
                                          $values as element()*)
        as element() {
    let $elemName := 'gx:' || $colour
    let $constraintComponent := 'FolderSimilarConstraint'
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintId := $constraintElem/@id
 
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, 'folderSimilar', ())
        else i:getErrorMsg($constraintElem, 'folderSimilar', ())
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    let $modifiers := $constraintElem/<gx:modifiers>{*}</gx:modifiers>[*]
        
    return
        element {$elemName}{
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComponent},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},
            attribute targetURI {$targetFolder},
            $linkDefAtts,
            $modifiers,
            $values
        }        
};
 
(:~
 : Creates a validation result for constraint components TargetCount, TargetMinCount, 
 : TargetMaxCount.
 :
 : @param colour the kind of results - green or red
 : @param ldo Link Definition Object, used to identify the target folders 
 : @param constraintElem the element declaring the constraint
 : @param constraintAtt an attribute specifying a constraint (e.g. @minCount=...)
 : @param targetItems the items representing target resources 
 : @param targetContextPath  
 : @return a result element 
 :)
declare function f:validationResult_folderSimilar_count(
                                    $colour as xs:string,
                                    $ldo as map(*)?,
                                    $constraintElem as element(gx:folderSimilar),
                                    $constraintAtt as attribute(),
                                    $targetItems as item()*,
                                    $targetContextPath as xs:string)
        as element() {
    let $actCount := count($targetItems)        
    let $elemName := if ($colour eq 'green') then 'gx:green' else 'gx:red'
    let $constraintComp := 'FolderSimilarTarget' || $constraintAtt/i:firstCharToUpperCase(local-name(.))
    let $msg :=
        if ($colour eq 'green') then $constraintElem/i:getOkMsg(., $constraintAtt/local-name(.), ())
        else $constraintElem/i:getErrorMsg(., $constraintAtt/local-name(.), ())
        
    (: Link description attributes :)
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    (: Values :)
    let $values :=
        if (not($colour = ('red', 'yellow'))) then ()
        else f:validationResultValues($targetItems, $constraintElem)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute filePath {$targetContextPath},
            attribute constraintComp {$constraintComp},
            $constraintElem/@id/attribute constraintID {. || '-' || $constraintAtt/local-name(.)},                    
            $constraintElem/@resourceShapeID,
            $constraintAtt,
            attribute valueCount {$actCount},
            $linkDefAtts,
            $values
        }
};

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         E x p r e s s i o n   c o n s t r a i n t
 :
 : ===============================================================================
 :)
declare function f:validationResult_expression($constraintElem as element(),
                                               $colour as xs:string,
                                               $exprValue as item()*,    
                                               $violations as item()*,
                                               $expr as xs:string,
                                               $exprLang as xs:string,                                               
                                               $constraint as node(),
                                               $additionalAtts as attribute()*,
                                               $additionalElems as element()*,
                                               $contextInfo as map(xs:string, item()*),
                                               $options as map(*)?)
        as element() {
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraint)
    
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(eq) return map{'constraintComp': 'ExpressionEq', 'atts': ('eq', 'useDatatype', 'quant')}
        case attribute(ne) return map{'constraintComp': 'ExpressionNe', 'atts': ('ne', 'useDatatype', 'quant')}
        case attribute(lt) return map{'constraintComp': 'ExpressionLt', 'atts': ('lt', 'useDatatype', 'quant')}        
        case attribute(le) return map{'constraintComp': 'ExpressionLe', 'atts': ('le', 'useDatatype', 'quant')}        
        case attribute(gt) return map{'constraintComp': 'ExpressionGt', 'atts': ('gt', 'useDatatype', 'quant')}        
        case attribute(ge) return map{'constraintComp': 'ExpressionGe', 'atts': ('ge', 'useDatatype', 'quant')}
        case element(gx:in) return map{'constraintComp': 'ExpressionIn', 'atts': ('useDatatype')}
        case element(gx:notin) return map{'constraintComp': 'ExpressionNotin', 'atts': ('useDatatype')}
        case element(gx:contains) return map{'constraintComp': 'ExpressionContains', 'atts': ('useDatatype')}
        
        case attribute(datatype) return map{'constraintComp': 'ExpressionDatatype', 'atts': ('datatype', 'useDatatype', 'quant')}
        case attribute(matches) return map{'constraintComp': 'ExpressionMatches', 'atts': ('matches', 'useDatatype', 'quant')}
        case attribute(notMatches) return map{'constraintComp': 'ExpressionNotMatches', 'atts': ('notMatches', 'useDatatype', 'quant')}
        case attribute(like) return map{'constraintComp': 'ExpressionLike', 'atts': ('like', 'useDatatype', 'quant')}        
        case attribute(notLike) return map{'constraintComp': 'ExpressionNotLike', 'atts': ('notLike', 'useDatatype', 'quant')}
        case attribute(length) return map{'constraintComp': 'ExpressionLength', 'atts': ('length', 'quant')}
        case attribute(minLength) return map{'constraintComp': 'ExpressionMinLength', 'atts': ('minLength', 'quant')}        
        case attribute(maxLength) return map{'constraintComp': 'ExpressionMaxLength', 'atts': ('maxLength', 'quant')}        
        case attribute(itemsUnique) return map{'constraintComp': 'ExprValueItemsUnique', 'atts': ('itemsUnique')}
        default return error()
    let $constraintIdBase := $constraintElem/@id
    let $constraintId := concat($constraintIdBase, '-', $constraint/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $constraintElem/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    let $msg := i:getResultMsg($colour, $constraintElem, trace($constraint/local-name(.), '_CONSTRAINT_NAME: '), ())
    let $elemName := i:getResultElemName($colour)
    let $quantifier := $constraintElem/(@quant, 'all')[1]
    let $quantifierAtt := $quantifier ! attribute quantifier {.}
    let $values := 
        let $items := if ($violations) then $violations
                      else if ($colour eq 'red' and $quantifier eq 'some') then $exprValue
                      else ()
        return 
            if (empty($items)) then () else
                f:validationResultValues($items, $constraintElem, $contextInfo?doc)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            (: $constraintId ! attribute constraintID {.}, :)            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $filePath,
            $focusNode,
            $standardAtts,
            $additionalAtts,
            $valueCountAtt,            
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            $quantifierAtt,
            $values,
            $additionalElems
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
declare function f:validationResult_expression_counts($colour as xs:string,
                                                      $constraintElem as element(),
                                                      $constraint as attribute(),
                                                      $valueCount as item()*,
                                                      $context as map(xs:string, item()*),
                                                      $additionalAtts as attribute()*)
        as element() {
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraint)
        
    let $targetInfo := $context?_targetInfo        
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(count)    return map{'constraintComp': 'ExpressionCount',    'atts': ('count')}
        case attribute(minCount) return map{'constraintComp': 'ExpressionMinCount', 'atts': ('minCount')}        
        case attribute(maxCount) return map{'constraintComp': 'ExpressionMaxCount', 'atts': ('maxCount')}        
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $constraintElem/@*[local-name(.) = $standardAttNames]
    let $valueCountAtt := attribute valueCount {$valueCount} 
    
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintElemId := $constraintElem/@id
    let $constraintId := concat($constraintElemId, '-', $constraint/local-name(.))
    let $filePath := $targetInfo?contextURI ! attribute filePath {.}
    let $focusNode := $targetInfo?focusNodePath ! attribute nodePath {.}    
    let $msg := i:getResultMsg($colour, $constraintElem, $constraint/local-name(.), ())
    let $elemName := i:getResultElemName($colour)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},            
            (: attribute constraintID {$constraintId}, :)
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $filePath,
            $focusNode,
            $standardAtts,
            $valueCountAtt,
            $additionalAtts            
        }       
};

(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of an Expression Pair constraint.
 : Such an exceptional condition is, for example, a failure to parse 
 . the context resource into a node.
 :
 : @param constraintElem an element declaring an ExpressionPair constraint
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param context processing context
 : @return a red validation result
 :)
declare function f:validationResult_expression_exception(
                                            $constraintElem as element(),
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $context as map(xs:string, item()*))
        as element() {
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)
        
    let $targetInfo := $context?_targetInfo        
    let $constraintComp := 'Expression'        
    let $constraintId := $constraintElem/@id
    let $filePathAtt := $targetInfo?contextURI ! attribute filePath {.}
    let $focusNodeAtt := $targetInfo?focusNodePath ! attribute nodePath {.}
    let $msg := $exception
    return
        element {'gx:red'} {
            attribute exception {$msg},            
            attribute constraintComp {$constraintComp},            
            (: attribute constraintID {$constraintId}, :)
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $addAtts,
            $filePathAtt,
            $focusNodeAtt
        }
       
};


(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         E x p r e s s i o n   P a i r    c o n s t r a i n t
 :
 : ===============================================================================
 :)

(:~
 : Constructs a validation result obtained from an ExpressionPair constraint.
 :
 : @param colour describes the success status - success, failure, warning
 : @param violations items violating the constraint
 : @param cmp operator of comparison
 : @param valuePair an element declaring an ExpressionValue Constraint
 : @contextInfo informs about the focus document and focus node
 :)
declare function f:validationResult_expressionPair($colour as xs:string,
                                                   $violations as item()*,
                                                   $cmp as xs:string,
                                                   $expressionPair as element(),
                                                   $contextInfo as map(xs:string, item()*),
                                                   $additionalAtts as attribute()*)
        as element() {
    let $constraintId := $expressionPair/../@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $cmpAtt := $cmp ! attribute valueRelationship {.}
    let $useDatatypeAtt := $expressionPair/@useDatatype ! attribute useDatatype {.}
    let $flagsAtt := $expressionPair/@flags[string()] ! attribute flags {.}
    let $quantifierAtt := ($expressionPair/@quant, 'all')[1] ! attribute quantifier {.}
    let $constraintComp := 'ExpressionPair-' || $cmp
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($expressionPair, $cmp, ())
        else i:getErrorMsg($expressionPair, $cmp, ())
    let $elemName := concat('gx:', $colour)
    let $expr1Lang := 'xpath'
    let $expr2Lang := 'xpath'    
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            $filePathAtt,
            $focusNodeAtt,
            $expressionPair/@expr1XP ! attribute expr1 {.},
            attribute expr1Lang {$expr1Lang},            
            $expressionPair/@expr2XP ! attribute expr2 {.},
            attribute expr2Lang {$expr2Lang},
            $cmpAtt,
            $useDatatypeAtt,
            $flagsAtt,
            $quantifierAtt,
            $additionalAtts,
            $violations ! <gx:value>{.}</gx:value>
        }
       
};

(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of an Expression Pair constraint.
 : Such an exceptional condition is, for example, a failure to parse 
 . the context resource into a node.
 :
 : @param constraintElem an element declaring an ExpressionPair constraint
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param contextInfo informs about the focus document and focus node
 : @return a red validation result
 :)
declare function f:validationResult_expressionPair_exception(
                                            $constraintElem as element(),
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $contextInfo as map(xs:string, item()*))
        as element() {
    let $constraintComp := 'ExpressionPair'        
    let $constraintId := $constraintElem/@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $msg := $exception
    return
        element {'gx:red'} {
            attribute exception {$msg},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            $addAtts,
            $filePathAtt,
            $focusNodeAtt
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
declare function f:validationResult_expressionPair_counts($colour as xs:string,
                                                          $valuePair as element(),
                                                          $constraint as attribute(),
                                                          $valueCount as item()*,
                                                          $contextItem1 as item()?,
                                                          $contextInfo as map(xs:string, item()*),
                                                          $additionalAtts as attribute()*)
        as element() {
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(count1)    return map{'constraintComp': 'ExpressionPairValue1Count',    'atts': ('count1')}
        case attribute(minCount1) return map{'constraintComp': 'ExpressionPairValue1MinCount', 'atts': ('minCount1')}        
        case attribute(maxCount1) return map{'constraintComp': 'ExpressionPairValue1MaxCount', 'atts': ('maxCount1')}        
        case attribute(count2)    return map{'constraintComp': 'ExpressionPairValue2Count',    'atts': ('count2')}
        case attribute(minCount2) return map{'constraintComp': 'ExpressionPairValue2MinCount', 'atts': ('minCount2')}        
        case attribute(maxCount2) return map{'constraintComp': 'ExpressionPairValue2MaxCount', 'atts': ('maxCount2')}        
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valuePair/@*[local-name(.) = $standardAttNames]
    let $valueCountAtt := attribute valueCount {$valueCount} 
    
    let $resourceShapeId := $valuePair/@resourceShapeID
    let $constraintElemId := $valuePair/@id
    let $constraintId := concat($constraintElemId, '-', $constraint/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    
    let $contextItem1Att :=
        if (empty($contextItem1)) then ()
        else 
            let $attValue := if (not($contextItem1 instance of node())) then $contextItem1
                             else if (not($contextItem1/*)) then $contextItem1
                             else $contextItem1/i:datapath(.)
            return attribute contextItem1 {$attValue}                             

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
            $valueCountAtt,
            $contextItem1Att,
            $additionalAtts            
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

(:~
 : ===============================================================================
 :
 :     U t i l i t i e s   
 :
 : ===============================================================================
 :)

declare function f:validateResult_linkDefAtts($ldo as map(*)?,
                                              $constraintElem as element()?)
        as attribute()* {
    let $exprAtts := ( 
        $constraintElem/@linkName ! attribute linkName {.},
        ($constraintElem/@foxpath, $ldo?foxpath ! attribute foxpath {.})[1],
        ($constraintElem/@hrefXP, $ldo?hrefXP ! attribute hrefXP {.})[1],    
        ($constraintElem/@uriXP, $ldo?uriXP ! attribute uriXP {.})[1],        
        ($constraintElem/@linkXP, $ldo?linkXP ! attribute linkXP {.})[1],        
        ($constraintElem/@linkContextXP, $ldo?linkContextXP ! attribute linkContextXP {.})[1],
        ($constraintElem/@linkTargetXP, $ldo?linkTargetXP ! attribute linkTargetXP {.})[1],
        ($constraintElem/@recursive, $ldo?recursive ! attribute recursive {.})[1]
    )
    return $exprAtts
        
};        

