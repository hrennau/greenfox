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
    let $nodePath := 
        function($item) {
            let $dpath := i:datapath($item)
            let $prefix := 
                if ($item/ancestor::node() intersect $contextDoc) then () 
                    else ($item/base-uri(.) || '#')
            return $prefix || $dpath
        }        
    let $mapNodePath := 
        function($map) {
            let $node := $map?item[. instance of node()] return
            if (not($node)) then () else
            let $dpath := $node/i:datapath(.)
            let $prefix := 
                if ($node/ancestor::node() intersect $contextDoc) then () 
                else ($node/base-uri(.) || '#')
             return $prefix || $dpath
        }        
    for $item in $value
    return
        typeswitch($item)
        case xs:anyAtomicType return string($item) ! <gx:value>{.}</gx:value>
        case element() return
            if ($item/not((@*, *))) then
                string ($item) ! <gx:value>{$nodePath($item) ! attribute nodePath {.}, string($item)}</gx:value>
            else $nodePath($item) ! <gx:valueNodePath>{.}</gx:valueNodePath>
        case attribute() return
            <gx:value>{attribute nodePath {$nodePath($item)}, string($item)}</gx:value>
        case map(xs:string, item()*) return
            let $dpath := $mapNodePath($item)
            return
                <gx:value>{$dpath ! attribute nodePath {.}, attribute cannotConvertTo {$item?type}, string($item?item)}</gx:value>
        default return ()                
};     

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         f i l e    p r o p e r t i e s    c o n s t r a i n t s
 :
 : ===============================================================================
 :)

(:~
 : Writes a validation result, for constraint components FileName*, FileSize*,
 : FileDate*.
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
                                                   $constraintNode as attribute(),
                                                   $actualValue as item(),
                                                   $additionalAtts as attribute()*,
                                                   $context as map(xs:string, item()*)) 
        as element() {
    let $resourceShapeId := $constraintElem/@resourceShapeID        
    let $resourceShapePath := $constraintElem/@resourceShapePath    
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)        
    let $contextURI := $context?_targetInfo?contextURI        
    let $constraintComp :=
        $constraintElem/i:firstCharToUpperCase(local-name(.)) ||
        $constraintNode/i:firstCharToUpperCase(local-name(.))
        
    let $fn_msg := function() {
        concat(
        switch(local-name($constraintElem))
        case 'fileName' return 'File name'
        case 'fileSize' return 'File size'
        case 'fileDate' return 'File date'
        default return error(),    
        ' must ',
        switch(local-name($constraintNode))
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
        default return 'satisfy',
        " '", $constraintNode, "'")}
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.), $fn_msg(), (), ())
    let $values := f:validationResultValues($actualValue, $constraintElem)
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $flags := $constraintElem/@flags
    let $case := $constraintElem/@case
    return
    
        element {f:resultElemName($colour)} {
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComp},
            $constraintPath ! attribute constraintPath {.},
            $resourceShapePath ! attribute resourceShapePath {.},
            attribute resourceShapeID {$resourceShapeId},            
            $contextURI ! attribute filePath {.},
            $constraintNode,
            $flags ! attribute flags {.},
            $case ! attribute case {.},
            $additionalAtts,
            $values
        }                                          
};

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         m e d i a t y p e    c o n s t r a i n t s
 :
 : ===============================================================================
 :)

(:~
 : Writes a validation result for a mediatype constraint.
 :
 : @param colour indicates success or error
 : @param constraintElem the element representing the constraint
 : @param constraintNode an attribute representing the constraint facet
 : @param context the processing context
 : @param additionalAtts additional attributes to be included in the validation result
 :) 
declare function f:validationResult_mediatype($colour as xs:string,
                                              $constraintElem as element(gx:mediatype),
                                              $constraintNode as attribute(),
                                              $context as map(xs:string, item()*),
                                              $additionalAtts as attribute()*)
        as element() {
    let $resourceShapeId := $constraintElem/@resourceShapeID        
    let $resourceShapePath := $constraintElem/@resourceShapePath    
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)        
    let $contextURI := $context?_targetInfo?contextURI        
    let $constraintComponent :=
        $constraintElem/i:firstCharToUpperCase(local-name(.)) ||
        $constraintNode/i:firstCharToUpperCase(local-name(.))
        ! replace(., '\.', '') ! replace(., 'm(in|ax)', 'M$1')
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.))
    return
        element {f:resultElemName($colour)}{
            $contextURI ! attribute filePath {.},        
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComponent},
            $constraintPath ! attribute constraintPath {.},
            $resourceShapePath ! attribute resourceShapePath {.},
            $resourceShapeId ! attribute resourceShapeID {.},            
            $constraintNode,
            $additionalAtts
        }        
};

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         d o c    c o n t e n t    c o n s t r a i n t s
 :
 : ===============================================================================
 :)

declare function f:validationResult_docContent_counts($colour as xs:string,
                                                      $constraintElem as element(),
                                                      $constraintNode as node(),
                                                      $contextNode as node(),
                                                      $valueCount as xs:integer,   
                                                      $nodeTrail as xs:string,
                                                      $additionalAtts as attribute()*,
                                                      $context as map(xs:string, item()*))
        as element() {
    let $contextURI := $context?_targetInfo?contextURI
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath    
    let $constraintPath := i:getSchemaConstraintPath($constraintNode) 
    let $constraintComponent :=
        $constraintElem/i:firstCharToUpperCase(local-name(.)) || (
        if ($constraintNode/self::attribute()) then $constraintNode/i:firstCharToUpperCase(local-name(.))
        else 'Count')
    let $nodePath := $contextNode/i:datapath(.)
    let $implicitCount := 1[not($constraintNode/self::attribute())]
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.))
    return
        element {f:resultElemName($colour)} {
            $contextURI ! attribute filePath {.},
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComponent},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            $constraintNode[self::attribute()],
            $implicitCount ! attribute implicitCount {1},
            $valueCount ! attribute valueCount {.},
            $nodePath ! attribute nodePath {.},
            $nodeTrail ! attribute nodeTrail {.},
            $additionalAtts            
        }       
};

declare function f:validationResult_docContent_closed($colour as xs:string,
                                                      $constraintElem as element(),
                                                      $constraintNode as node(),
                                                      $contextNode as node(),
                                                      $unexpectedNode as node()?,   
                                                      $nodeTrail as xs:string,
                                                      $additionalAtts as attribute()*,
                                                      $context as map(xs:string, item()*))
        as element() {
    let $contextURI := $context?_targetInfo?contextURI
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath    
    let $constraintPath := i:getSchemaConstraintPath($constraintNode) 
    let $constraintComponent := 'DocContentClosed'
    let $nodePath := $contextNode/i:datapath(.)
    let $unexpectedNodeLocalName := $unexpectedNode/local-name(.)
    let $unexpectedNodeNamespace := $unexpectedNode/namespace-uri(.)[string()]
    let $unexpectedAttNamePrefix := if ($unexpectedNode/self::attribute()) then 'unexpectedAttribute' 
                                    else 'unexpectedElement'
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.))
    return
        element {f:resultElemName($colour)} {
            $contextURI ! attribute filePath {.},
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComponent},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            $constraintNode[self::attribute()],
            $unexpectedNodeLocalName ! attribute {$unexpectedAttNamePrefix || 'Name'} {$unexpectedNodeLocalName},
            $unexpectedNodeNamespace ! attribute {$unexpectedAttNamePrefix || 'Namespace'} {$unexpectedNodeNamespace},
            $nodePath ! attribute nodePath {.},
            $nodeTrail ! attribute nodeTrail {.},
            $additionalAtts            
        }       
};


(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of a DocContent constraint.
 : Such an exceptional condition is, for example, a failure to parse 
 . the context resource into a node tree.
 :
 : @param constraintElem an element declaring a DocContentconstraint
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param context processing context
 : @return a red validation result
 :)
declare function f:validationResult_docContent_exception(
                                            $constraintElem as element(),
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $context as map(xs:string, item()*))
        as element() {
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)
        
    let $targetInfo := $context?_targetInfo        
    let $constraintComp := 'DocContent'        
    let $constraintId := $constraintElem/@id
    let $filePathAtt := $targetInfo?contextURI ! attribute filePath {.}
    let $focusNodeAtt := $targetInfo?focusNodePath ! attribute nodePath {.}
    let $msg := $exception
    return
        element gx:red {
            attribute exception {$msg},            
            attribute constraintComp {$constraintComp},            
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
 :         f o l d e r    c o n t e n t    c o n s t r a i n t s
 :
 : ===============================================================================
 :)

(:~
 : Writes a validation result for constraint component FolderContentClosed.
 :
 : @param colour the colour of the result
 : @param constraintElem the element containing the attributes and child elements declaring the constraint
 : @param paths the file paths of violating resources 
 : @param additionalAtts additional attributes to be included in the result
 : @param additionalElems additional elements to be included in the result 
 : @return an element representing a 'red' or 'green' validation result
 :)
declare function f:constructError_folderContentClosed($colour as xs:string,
                                                      $constraintElem as element(),
                                                      $constraintNode as node(),
                                                      $context as map(xs:string, item()*), 
                                                      $paths as xs:string*,
                                                      $additionalAtts as attribute()*,
                                                      $additionalElems as element()*                                                    
                                                     ) 
        as element() {
    let $resourceShapeId := $constraintElem/@resourceShapeID        
    let $resourceShapePath := $constraintElem/@resourceShapePath    
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)

    let $constraintComp := 'FolderContentClosed'
    let $elemName := 'gx:' || $colour
    let $msg := 
        if ($colour eq 'red') then i:getErrorMsg($constraintElem, 'closed', 'Unexpected folder contents.')
        else i:getOkMsg($constraintElem, 'closed', ())
    
    let $valueElems :=
        for $path in $paths
        let $kind := if (i:fox-resource-is-dir($path)) then 'folder' else 'file'
        return
            <gx:value resoureKind="{$kind}">{$path}</gx:value>
    
    return
        element {$elemName} {
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComp},
            $constraintPath ! attribute constraintPath {.},
            $resourceShapePath ! attribute resourceShapePath {.},
            attribute resourceShapeID {$resourceShapeId},            
            $additionalAtts,
            $additionalElems,
            $valueElems
        }
};

(:~
 : Writes a validation result for constraint components FolderContentMinCount and FolderContentMaxCount.
 :
 : @param colour the colour of the result
 : @param constraintElem the element containing the attributes and child elements declaring the constraint
 : @param constraint attribute representing the maximum or minimum count allowed
 : @param resourceName the resource name or name pattern used by the constraint declaration
 : @param paths the file paths of resources matching the name or name pattern 
 : @param additionalAtts additional attributes to be included in the result
 : @param additionalElems additional elements to be included in the result 
 : @return an element representing a 'red' or 'green' validation result
 :)
declare function f:constructError_folderContentCount($colour as xs:string,
                                                     $constraintElem as element(),
                                                     $constraintNode as node(),
                                                     $context as map(xs:string, item()*),                                                     
                                                     $resourceName as xs:string,
                                                     $paths as xs:string*,
                                                     $additionalAtts as attribute()*,
                                                     $additionalElems as element()*                                                    
                                                     ) 
        as element() {
    let $resourceShapePath := $constraintElem/@resourceShapePath    
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)
    
    let $elemName := 'gx:' || $colour        
    let $constraintComp :=
        $constraintElem/i:firstCharToUpperCase(local-name(.)) ||
        $constraintNode/i:firstCharToUpperCase(local-name(.))    
    let $msg := 
        if ($colour eq 'red') then i:getErrorMsg($constraintElem, 'minCount', ())
        else i:getOkMsg($constraintElem, 'minCount', ())
    let $constraintId := $constraintElem/@id
    let $resourceShapeId := $constraintElem/@resourceShapeID
    
    let $valueElems :=
        for $path in $paths
        let $kind := if (i:fox-resource-is-dir($path)) then 'folder' else 'file'
        return
            <gx:value resoureKind="{$kind}">{$path}</gx:value>
    let $actCount := count($paths)            
    
    return
        element {$elemName} {
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComp},
            (: attribute constraintID {$constraintId}, :)
            $constraintPath ! attribute constraintPath {.},
            $resourceShapePath ! attribute resourceShapePath {.},
            attribute resourceShapeID {$resourceShapeId},    
            attribute resourceName {$resourceName},
            $constraintNode[self::attribute()],
            attribute actCount {$actCount},
            $additionalAtts,
            $additionalElems,
            $valueElems[$colour eq 'red']
        }
};



(:~
 : Writes a validation result for constraint components FolderContentMinCount and FolderContentMaxCount.
 :
 : @param colour the colour of the result
 : @param constraintElem the element containing the attributes and child elements declaring the constraint
 : @param constraint attribute representing the maximum or minimum count allowed
 : @param resourceName the resource name or name pattern used by the constraint declaration
 : @param paths the file paths of resources matching the name or name pattern 
 : @param additionalAtts additional attributes to be included in the result
 : @param additionalElems additional elements to be included in the result 
 : @return an element representing a 'red' or 'green' validation result
 :)
declare function f:constructError_folderContentHash($colour as xs:string,
                                                    $constraintElem as element(),
                                                    $constraintNode as attribute(),
                                                    $constraintValue as xs:string,
                                                    $context as map(xs:string, item()*),                                                    
                                                    $resourceName as xs:string,
                                                    $foundHashKeys as xs:string*,                                                   
                                                    $fileNames as xs:string*,
                                                    $additionalAtts as attribute()*,
                                                    $additionalElems as element()*                                                    
                                                    ) 
        as element() {
    let $resourceShapeId := $constraintElem/@resourceShapeID        
    let $resourceShapePath := $constraintElem/@resourceShapePath    
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)

    let $elemName := 'gx:' || $colour
    let $constraintComp :=
        $constraintElem/i:firstCharToUpperCase(local-name(.)) ||
        $constraintNode/i:firstCharToUpperCase(local-name(.))
    let $constraintId := $constraintElem/@id
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $hashKind := $constraintNode/local-name(.)
    let $actValueAtt := attribute {concat($hashKind, 'Found')} {$foundHashKeys} [$colour eq 'red']
    let $msg := 
        if ($colour eq 'green') then 
            i:getOkMsg(($constraintNode/.., $constraintNode/../..), $hashKind, concat('Expected ', $hashKind, ' value found.'))
        else
            i:getErrorMsg(($constraintNode/.., $constraintNode/../..), $hashKind, concat('Not expected  ', $hashKind, ' value.'))
            
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComp},
            $constraintPath ! attribute constraintPath {.},
            $resourceShapePath ! attribute resourceShapePath {.},
            attribute resourceShapeID {$resourceShapeId},            
            attribute resourceName {$resourceName},
            $actValueAtt,
            attribute {$constraintNode/name()} {$constraintValue}
        }
};        

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         l i n k    r e s o l v a b l e    c o n s t r a i n t
 :
 : ===============================================================================
 :)

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
                                                   $constraintNode as node(),
                                                   $linkContextItem as item(),
                                                   $options as map(*)?,
                                                   $context as map(xs:string, item()*))
        as element() {

    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)
    let $constraintComp := 'LinkResolvable'
    
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
    
    (: Data location :)
    let $linkContextNodePath := $linkContextItem[. instance of node()] ! i:datapath(.)

    (: Message :)
    let $msg := i:getErrorMsg($constraintElem, 'resolvable', ())
    return
        element {'gx:' || $colour} {
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $linkContextNodePath[string()] ! attribute linkContextNodePath {.},            
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $errorCodes ! attribute errorCode {.},
            $countUnresolved,
            $countResolved,   
            $linkDefAtts,
            $values
        }       
};

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         l i n k    c o u n t    c o n s t r a i n t
 :
 : ===============================================================================
 :)

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
                                              $constraintNode as attribute(),                                             
                                              $valueCount as item()*,
                                              $contextNode as node()?,                                              
                                              $options as map(*)?,
                                              $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)
        
    let $constraintConfig :=
        typeswitch($constraintNode)
        case attribute(exists)                  return map{'constraintComp': 'LinkTargetExists',         'atts': ('exists')}
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
            ($explicit, $constraintNode[not(. intersect $explicit)])
    let $valueCountAtt := attribute valueCount {$valueCount} 
    let $contextNodeDataPath := $contextNode/i:datapath(.)
    
    (: Link description attributes :)
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    (: Error codes :)
    let $errorCodes := ($lros?errorCode => distinct-values() => string-join('; '))[string()]
    
    let $msg := i:getResultMsg($colour, $constraintNode/.., $constraintNode/local-name(.))
    
    (: If the constraint is part of the link definition, the path of the referencing
       constraint element is given :)
    let $constraintElemPath :=
        if ($constraintElem/@* intersect $constraintNode) then ()
        else $constraintElem/i:getSchemaConstraintPath(.) ! attribute constraintElemPath {.}
    return
        element {f:resultElemName($colour)} {
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $contextNodeDataPath ! attribute contextNodeDataPath {.},            
            attribute constraintComp {$constraintConfig?constraintComp},            
            $constraintPath ! attribute constraintPath {.},            
            $constraintElemPath,
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $errorCodes ! attribute errorCode {.},
            $linkDefAtts,
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
                                    $constraintElem as element(gx:targetSize),
                                    $constraintNode as attribute(),
                                    $ldo as map(*)?,
                                    $targetItems as item()*,
                                    $targetContextPath as xs:string,
                                    $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)
    let $constraintComp := 'Target' || $constraintNode/i:firstCharToUpperCase(local-name(.))
    
    let $actCount := count($targetItems)
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.))
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    (: Values :)
    let $values :=
        if (not($colour = ('red', 'yellow'))) then ()
        else f:validationResultValues($targetItems, $constraintElem)
    return
        element {f:resultElemName($colour)} {
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            $constraintNode,
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
                                               $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)
    let $constraintComp := 'DocSimilar'
    
    let $msg := i:getResultMsg($colour, $constraintElem, 'docSimilar')
    let $reports :=
        if (not($comparisonReports)) then () else
            <gx:reports>{$comparisonReports}</gx:reports>
    let $modifiers :=
        if (not($constraintElem/*)) then () else
            <gx:modifiers>{$constraintElem/*}</gx:modifiers>
        
    let $reports := $comparisonReports
    return
        element {f:resultElemName($colour)}{
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
        
            attribute comparisonTargetURI {$targetDocURI},
            $exception,
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
                                            $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)        
    let $constraintComp := 'DocSimilar'
    let $constraintId := $constraintElem/@id
    
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
            $exception ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $contextItemInfo,
            $targetInfo,
            $addAtts
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
                                          $constraintElem as element(gx:folderSimilar),
                                          $ldo as map(*)?,                                          
                                          $targetURI as xs:string,                                         
                                          $values as element()*,
                                          $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)
    let $constraintComp := 'FolderSimilar'
    
    let $msg := i:getResultMsg($colour, $constraintElem, 'folderSimilar')
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    let $modifiers := $constraintElem/<gx:modifiers>{*}</gx:modifiers>[*]
        
    return
        element {f:resultElemName($colour)}{
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            $linkDefAtts,
            
            attribute targetURI {$targetURI},
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
                                    $constraintElem as element(gx:folderSimilar),
                                    $constraintNode as attribute(),
                                    $ldo as map(*)?,
                                    $targetItems as item()*,
                                    $targetContextPath as xs:string,
                                    $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)
    let $constraintComp := 'FolderSimilar' || $constraintNode/i:firstCharToUpperCase(local-name(.))
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.))
    let $linkDefAtts := f:validateResult_linkDefAtts($ldo, $constraintElem)
    
    let $actCount := count($targetItems)    
    let $values := f:validationResultValues($targetItems, $constraintElem)[$colour = ('red', 'yellow')]
    return
        element {f:resultElemName($colour)} {
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            $linkDefAtts,            
            $constraintNode,
            
            attribute valueCount {$actCount},
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
declare function f:validationResult_value($colour as xs:string,
                                          $constraintElem as element(),
                                          $constraintNode as node(),
                                          $exprValue as item()*,    
                                          $violations as item()*,
                                          $expr as xs:string,
                                          $exprLang as xs:string,                                          
                                          $additionalAtts as attribute()*,
                                          $additionalElems as element()*,
                                          $options as map(*)?,
                                          $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)
     
    let $constraintConfig :=
        let $ccPrefix := if ($constraintElem/self::element(gx:foxvalue)) then 'Foxvalue' else 'Value' return
        
        typeswitch($constraintNode)
        case attribute(eq) return map{'constraintComp': $ccPrefix || 'Eq', 'atts': ('eq', 'useDatatype', 'quant')}
        case attribute(ne) return map{'constraintComp': $ccPrefix || 'Ne', 'atts': ('ne', 'useDatatype', 'quant')}
        case attribute(lt) return map{'constraintComp': $ccPrefix || 'Lt', 'atts': ('lt', 'useDatatype', 'quant')}        
        case attribute(le) return map{'constraintComp': $ccPrefix || 'Le', 'atts': ('le', 'useDatatype', 'quant')}        
        case attribute(gt) return map{'constraintComp': $ccPrefix || 'Gt', 'atts': ('gt', 'useDatatype', 'quant')}        
        case attribute(ge) return map{'constraintComp': $ccPrefix || 'Ge', 'atts': ('ge', 'useDatatype', 'quant')}
        case element(gx:in) return map{'constraintComp': $ccPrefix || 'In', 'atts': ('useDatatype')}
        case element(gx:notin) return map{'constraintComp': $ccPrefix || 'Notin', 'atts': ('useDatatype')}
        case element(gx:contains) return map{'constraintComp': $ccPrefix || 'Contains', 'atts': ('useDatatype', 'quant')}
        case element(gx:eqeq) return map{'constraintComp': $ccPrefix || 'Eqeq', 'atts': ('useDatatype', 'quant')}
        
        case attribute(datatype) return map{'constraintComp': $ccPrefix || 'Datatype', 'atts': ('datatype', 'useDatatype', 'quant')}
        case attribute(matches) return map{'constraintComp': $ccPrefix || 'Matches', 'atts': ('matches', 'useDatatype', 'quant')}
        case attribute(notMatches) return map{'constraintComp': $ccPrefix || 'NotMatches', 'atts': ('notMatches', 'useDatatype', 'quant')}
        case attribute(like) return map{'constraintComp': $ccPrefix || 'Like', 'atts': ('like', 'useDatatype', 'quant')}        
        case attribute(notLike) return map{'constraintComp': $ccPrefix || 'NotLike', 'atts': ('notLike', 'useDatatype', 'quant')}
        case attribute(length) return map{'constraintComp': $ccPrefix || 'Length', 'atts': ('length', 'quant')}
        case attribute(minLength) return map{'constraintComp': $ccPrefix || 'MinLength', 'atts': ('minLength', 'quant')}        
        case attribute(maxLength) return map{'constraintComp': $ccPrefix || 'MaxLength', 'atts': ('maxLength', 'quant')}        
        case attribute(itemsUnique) return map{'constraintComp': $ccPrefix || 'ItemsUnique', 'atts': ('itemsUnique')}
        default return error()
    let $constraintIdBase := $constraintElem/@id
    let $constraintId := concat($constraintIdBase, '-', $constraintNode/local-name(.))
    let $filePath := $context?_targetInfo?contextURI ! attribute filePath {.}
    let $focusNode := $context?_targetInfo?focusNodePath ! attribute nodePath {.}    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $constraintElem/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.))
    let $quantifier := $constraintElem/(@quant, 'all')[1]
    let $quantifierAtt := $quantifier ! attribute quantifier {.}
    let $values := 
        let $items := if (exists($violations)) then $violations
                      else if ($colour eq 'red' and $quantifier eq 'some') then $exprValue
                      else ()
        return 
            if (empty($items)) then () else
                f:validationResultValues($items, $constraintElem, $targetInfo?doc)
    return
        element {f:resultElemName($colour)} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
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
declare function f:validationResult_value_counts($colour as xs:string,
                                                 $constraintElem as element(),
                                                 $constraintNode as attribute(),
                                                 $exprValue as item()*,  
                                                 $expr as xs:string, 
                                                 $exprLang as xs:string,                                                 
                                                 $additionalAtts as attribute()*,
                                                 $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)
        
    let $targetInfo := $context?_targetInfo        
    let $constraintConfig :=
        let $ccPrefix := if ($constraintElem/self::element(gx:foxvalue)) then 'Foxvalue' else 'Value' return
        typeswitch($constraintNode)
        case attribute(count)    return map{'constraintComp': $ccPrefix || 'Count',    'atts': ('count')}
        case attribute(minCount) return map{'constraintComp': $ccPrefix || 'MinCount', 'atts': ('minCount')}        
        case attribute(maxCount) return map{'constraintComp': $ccPrefix || 'MaxCount', 'atts': ('maxCount')}        
        case attribute(exists) return map{'constraintComp': $ccPrefix || 'Exists', 'atts': ('exists')}        
        case attribute(empty) return map{'constraintComp': $ccPrefix || 'Empty', 'atts': ('empty')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $constraintElem/@*[local-name(.) = $standardAttNames]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.))
   
    let $values :=
        let $items :=
            if ($constraintNode/self::attribute(maxCount)/xs:integer(.) eq 0 or
                $constraintNode/self::attribute(empty)/xs:boolean(.) or
                $constraintNode/self::attribute(exists)/xs:boolean(.) eq false()) then $exprValue
            else ()
        return 
            if (empty($items)) then () else
                f:validationResultValues($items, $constraintElem, $targetInfo?doc)
    
    return
        element {f:resultElemName($colour)} {
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            attribute constraintComp {$constraintConfig?constraintComp},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $standardAtts,
            $valueCountAtt,
            attribute exprLang {$exprLang},
            attribute expr {$expr},            
            $additionalAtts,
            $values            
        }       
};

(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of a Value constraint.
 : Such an exceptional condition is, for example, a failure to parse 
 . the context resource into a node tree.
 :
 : @param constraintElem an element declaring Value constraints
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param context processing context
 : @return a red validation result
 :)
declare function f:validationResult_value_exception(
                                            $constraintElem as element(),
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $context as map(xs:string, item()*))
        as element() {
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)        
    let $targetInfo := $context?_targetInfo  
    let $constraintComp := if ($constraintElem/self::element(gx:foxvalue)) then 'Foxvalue' else 'Value'
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
 :         V a l u e    P a i r    c o n s t r a i n t
 :
 : ===============================================================================
 :)

(:~
 : Constructs a validation result obtained from a ValuePair constraint.
 :
 : @param colour describes the success status - success, failure, warning
 : @param violations items violating the constraint
 : @param cmp operator of comparison
 : @param valuePair an element declaring an ExpressionValue Constraint
 : @contextInfo informs about the focus document and focus node
 :)
declare function f:validationResult_valuePair($colour as xs:string,
                                              $constraintElem,
                                              $constraintNode as node(),
                                              $violations as item()*,
                                              $additionalAtts as attribute()*,
                                              $context as map(xs:string, item()*))
        as element() { 
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)
    let $constraintKind := $constraintNode/(if (self::attribute()) then string() else local-name(.))
    
    let $cmpAtt := $constraintNode ! attribute valueRelationship {.}
    let $useDatatypeAtt := $constraintElem/@useDatatype ! attribute useDatatype {.}
    let $flagsAtt := $constraintElem/@flags[string()] ! attribute flags {.}
    let $quantifierAtt := ($constraintElem/@quant, 'all')[1] ! attribute quantifier {.}
    let $constraintComp := $constraintElem/i:firstCharToUpperCase(local-name(.)) || 
                           $constraintNode/i:firstCharToUpperCase($constraintKind)
    
    let $msg := i:getResultMsg($colour, $constraintElem, $constraintKind)
    let $expr1Lang := 'xpath'
    let $expr2Lang := 'xpath'    
    
    let $values := 
        let $items := if (exists($violations)) then $violations else ()
        return 
            if (empty($items)) then () else
                f:validationResultValues($items, $constraintElem, $targetInfo?doc)
    
    return
        element {f:resultElemName($colour)} {
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
        
            $constraintElem/@expr1XP ! attribute expr1 {.},
            attribute expr1Lang {$expr1Lang},            
            $constraintElem/@expr2XP ! attribute expr2 {.},
            attribute expr2Lang {$expr2Lang},
            $cmpAtt,
            $useDatatypeAtt,
            $flagsAtt,
            $quantifierAtt,
            $additionalAtts,
            $values
        }
       
};

(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of a ValuePair constraint.
 : Such an exceptional condition is, for example, a failure to parse 
 . the context resource into a node.
 :
 : @param constraintElem an element declaring an ExpressionPair constraint
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param contextInfo informs about the focus document and focus node
 : @return a red validation result
 :)
 (:
declare function f:validationResult_valuePair_exception(
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
:)

(:~
 : Creates a validation result for a ValuePair*Count constraint (ValuePairCount1,
 : ValuePairMinCount1, ValuePairMaxCount1, ValuePairCount2, ValuePairMinCount2,
 : ValuePairMaxCount2).
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param valuePair an element declaring a Correspondence Constraint on a 
 :   pair of content values
 : @param constraint a constraint expressing attribute (e.g. @sourceMinCount)
 : @param valueCount the actual number of values 
 : @param contextInfo informs about the focus document and focus node
 : @return a validation result, red or green
 :)
declare function f:validationResult_valuePair_counts($colour as xs:string,
                                                     $constraintElem as element(),
                                                     $constraintNode as attribute(),
                                                     $exprRole as xs:string,
                                                     $expr as xs:string,
                                                     $exprLang as xs:string,
                                                     $valueCount as item()*,
                                                     $contextItem1 as item()?,
                                                     $additionalAtts as attribute()*,
                                                     $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintNode)
        
    
    let $constraintConfig :=
        let $ccPrefix := if ($constraintElem/self::element(gx:valuePair)) then 'ValuePair' 
                         else if ($constraintElem/self::element(gx:foxvaluePair)) then 'FoxvaluePair'
                         else if ($constraintElem/self::element(gx:valueCompared)) then 'ValueCompaired'
                         else if ($constraintElem/self::element(gx:foxvalueCompared)) then 'FoxvalueCompaired'
                         else error()
        return
        typeswitch($constraintNode)
        case attribute(count1)    return map{'constraintComp': $ccPrefix || 'Value1Count',    'atts': ('count1')}
        case attribute(minCount1) return map{'constraintComp': $ccPrefix || 'Value1MinCount', 'atts': ('minCount1')}        
        case attribute(maxCount1) return map{'constraintComp': $ccPrefix || 'Value1MaxCount', 'atts': ('maxCount1')}        
        case attribute(count2)    return map{'constraintComp': $ccPrefix || 'Value2Count',    'atts': ('count2')}
        case attribute(minCount2) return map{'constraintComp': $ccPrefix || 'Value2MinCount', 'atts': ('minCount2')}        
        case attribute(maxCount2) return map{'constraintComp': $ccPrefix || 'Value2MaxCount', 'atts': ('maxCount2')}        
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $constraintElem/@*[local-name(.) = $standardAttNames]
    let $valueCountAtt := attribute valueCount {$valueCount} 
    
    let $contextItem1Att :=
        if (empty($contextItem1)) then ()
        else 
            let $attValue := if (not($contextItem1 instance of node())) then $contextItem1
                             else if (not($contextItem1/*)) then $contextItem1
                             else $contextItem1/i:datapath(.)
            return attribute contextItem1 {$attValue}                             

    let $msg := i:getResultMsg($colour, $constraintElem, $constraintNode/local-name(.))
    
    return
        element {f:resultElemName($colour)} {
            $msg ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            attribute constraintComp {$constraintConfig?constraintComp},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            $exprRole ! attribute exprRole {.},
            $expr ! attribute expr {.},
            $exprLang ! attribute exprLang {.},
        
            $standardAtts,
            $valueCountAtt,
            $contextItem1Att,
            $additionalAtts            
        }       
};

(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of a ValueCompared constraint.
 : Such an exceptional condition is, for example, a failure to parse 
 . the context resource into a node tree.
 :
 : @param constraintElem an element declaring Value constraints
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param context the processing context
 : @return a red validation result
 :)
declare function f:validationResult_valuePair_exception(
                                            $constraintElem as element(),
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath    
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)
    let $constraintComp := if ($constraintElem/self::element(gx:foxvaluePair)) then 'FoxvaluePair' else 'ValuePair'
    let $filePathAtt := $targetInfo?contextURI ! attribute filePath {.}
    let $focusNodeAtt := $targetInfo?focusNodePath ! attribute nodePath {.}
    
    let $msg := $exception
    return
        element {'gx:red'} {
            $exception ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $addAtts
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
declare function f:validationResult_valueCompared_exception(
                                            $constraintElem as element(),
                                            $lro as map(*)?,        
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $context as map(xs:string, item()*))
        as element() {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $focusNodePath := $targetInfo?focusNodePath
    let $resourceShapeID := $constraintElem/@resourceShapeID
    let $resourceShapePath := $constraintElem/@resourceShapePath      
    let $constraintPath := i:getSchemaConstraintPath($constraintElem)
    let $constraintComp := $constraintElem/i:firstCharToUpperCase(local-name(.))
    let $msg := $exception
    
    let $filePathAtt := $targetInfo?contextURI ! attribute filePath {.}
    let $focusNodeAtt := $targetInfo?focusNodePath ! attribute nodePath {.}
        
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
                    case 'no_resource' return 'Comparison target resource not found'
                    case 'no_text' return 'Comparison target resource not a text file'
                    case 'not_json' return 'Comparison target resource not a valid JSON document'
                    case 'not_xml' return 'Comparison target target resource not a valid XML document'
                    case 'href_selection_not_nodes' return
                        'Link error - href expression does not select nodes'
                    case 'uri' return
                        'Target URI not a valid URI'
                    default return concat('Unexpected error code: ', $errorCode)
                else if ($lro?targetURI ! i:fox-resource-exists(.)) then 
                    'Comparison target resource cannot be parsed'
                else 
                    'Comparison target target resource not found'
        
    return
        element {'gx:red'} {
            $exception ! attribute msg {.},        
            $contextURI ! attribute filePath {.},
            $focusNodePath ! attribute focusNodePath {.},
            $constraintComp ! attribute constraintComp {.},            
            $constraintPath ! attribute constraintPath {.},            
            $resourceShapePath ! attribute resourceShapePath {.}, 
            $resourceShapeID ! attribute resourceShapeID {.},
            
            $contextItemInfo,
            $targetInfo,
            
            $addAtts
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

declare function f:resultElemName($colour as xs:string) {'gx:' || $colour};

declare function f:validateResult_linkDefAtts($ldo as map(*)?,
                                              $constraintElem as element()?)
        as attribute()* {
    let $exprAtts := ( 
        $constraintElem/@linkName ! attribute linkName {.},
        ($constraintElem/@foxpath, $ldo?foxpath)[1] ! normalize-space(.) ! attribute foxpath {.},
        ($constraintElem/@hrefXP, $ldo?hrefXP)[1] ! normalize-space(.) ! attribute hrefXP {.},    
        ($constraintElem/@uriXP, $ldo?uriXP)[1] ! normalize-space(.) ! attribute uriXP {.},        
        ($constraintElem/@linkXP, $ldo?linkXP)[1] ! normalize-space(.) ! attribute linkXP {.},        
        ($constraintElem/@linkContextXP, $ldo?linkContextXP)[1] ! normalize-space(.) ! attribute linkContextXP {.},
        ($constraintElem/@linkTargetXP, $ldo?linkTargetXP)[1] ! normalize-space(.) ! attribute linkTargetXP {.},
        ($constraintElem/@recursive, $ldo?recursive ! attribute recursive {.})[1]
    )
    return $exprAtts
        
};        

