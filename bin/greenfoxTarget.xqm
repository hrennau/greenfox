(:
 : -------------------------------------------------------------------------
 :
 : greenfoxTarget.xqm - functions for determining the target of a resource shape
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "greenfoxUtil.xqm",
    "linkConstraint.xqm",
    "resourceAccess.xqm",
    "targetConstraint.xqm",
    "log.xqm" ;
    
import module namespace vr="http://www.greenfox.org/ns/xquery-functions/validation-result" at
    "validationResult.xqm";
    
import module namespace link="http://www.greenfox.org/ns/xquery-functions/link-resolver" at
    "linkResolver.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~ 
 : Returns the target paths of a resource shape, as well as the results of validating
 : the set of target resources against target constraints.
 :
 : @param resourceShape the resource shape owning the target declaration
 : @param context the processing context
 : @return target file paths, and results of validating the target against target constraints
 :) 
declare function f:getTargetPaths($resourceShape as element(),
                                  $context as map(xs:string, item()*))
        as item()* {   
    
    (: Retrieve target paths :)
    let $constraintElem := $resourceShape/gx:targetSize
    let $targetPathsAndLros := f:resolveTargetDeclaration($resourceShape, $context)
    let $targetPaths := $targetPathsAndLros[. instance of xs:anyAtomicType]
    return if (not($constraintElem)) then $targetPaths else
    
    (: Perform validation of target paths :)
    let $lros := $targetPathsAndLros[. instance of map(*)]
    let $validationResults := f:validateTargetConstraints(
                                        $resourceShape,
                                        $targetPaths, 
                                        $lros,
                                        $context)
    (: Returntarget paths and validation results :)                                        
    return
        ($targetPaths, $validationResults)
};

(: ============================================================================
 :
 :     f u n c t i o n s    r e t r i e v i n g    t a r g e t    p a t h s
 :
 : ============================================================================ :)
(:~
 : Returns the target paths of a resource shape, optionally also
 : Link Resolution Objects. 
 :
 : The target is identified either by a path (@path) or
 : by a foxpath expression (@foxpath), or by an expression
 : producing link targets (@linkXP, @linkRecursive).
 :
 : The path is appended to the context path. The foxpath is
 : evaluated. Link targets are resolved.
 :
 : Whether evaluation reports are returned depends on the kind 
 : of target declaration:
 : - if path of foxpath: no reports
 : - if links or recursive links: with reports
 : 
 : @param resourceShape a file or folder shape
 : @param context a map of variable bindings
 : @return the target paths :)
declare function f:resolveTargetDeclaration($resourceShape as element(), 
                                            $context as map(xs:string, item()*))
        as item()* {
    let $contextPath := $context?_contextPath  
    
    (: Adhoc addition of $filePath and $fileName :)
    let $evaluationContext := $context?_evaluationContext
    let $evaluationContext := map:put($evaluationContext, QName((),'filePath'), $contextPath)
    let $evaluationContext := map:put($evaluationContext, QName((), 'fileName'), replace($contextPath, '.*[/\\]', ''))
    let $context := map:put($context, '_evaluationContext', $evaluationContext)
    
    let $targetPathsAndEvaluationReports :=        
        let $path := $resourceShape/@path
        let $foxpath := $resourceShape/@foxpath
        let $isLinkTarget := $resourceShape/exists((@linkXP))
        let $rel := $resourceShape/@rel        
        return
            if ($path) then f:getTargetPaths_path($path, $resourceShape, $context)
            else if ($foxpath) then f:getTargetPaths_foxpath($foxpath, $resourceShape, $context)
            else if ($isLinkTarget) then f:getTargetPaths_linkTargets($resourceShape, $context)
            else if ($rel) then f:getTargetPaths_rel($resourceShape, $context)            
            else error()
    return $targetPathsAndEvaluationReports
};        

(:~
 : Evaluates the target path given by a plain path expression.
 :
 : @param path plain path expression
 : @param resourceShape the resource shape 
 : @param context the processing context
 : @return the target path
 :)
declare function f:getTargetPaths_path($path as xs:string, 
                                       $resourceShape as element(),
                                       $context as map(xs:string, item()*))
        as xs:string* {
    let $contextPath := $context?_contextPath        
    let $isExpectedResourceKind := 
        (: if ($resourceShape/self::gx:folder) then file:is-dir#1 else file:is-file#1 :)
        if ($resourceShape/self::gx:folder) then i:fox-resource-is-dir#1 else i:fox-resource-is-file#1
    return    
        concat($contextPath, '\', $path)[i:fox-resource-exists(.)]
        [$isExpectedResourceKind(.)]        
};

(:~
 : Evaluates the target paths which are the items of a foxpath
 : expression value.
 :
 : @param foxpath foxpath expression producing the target paths
 : @param resourceShape the resource shape
 : @param contextPath file path of the context item
 : @param context the processing context
 : 
 : @return the target paths corresponding to the link targets
 :)
declare function f:getTargetPaths_foxpath($foxpath as xs:string, 
                                          $resourceShape as element(),
                                          $context as map(xs:string, item()*))
        as xs:string* {
    let $contextPath := $context?_contextPath        
    let $isExpectedResourceKind := 
        if ($resourceShape/self::gx:folder) then i:fox-resource-is-dir#1 else i:fox-resource-is-file#1
    let $evaluationContext := $context?_evaluationContext        
    return    
        i:evaluateFoxpath($foxpath, $contextPath, $evaluationContext, true())       
        [$isExpectedResourceKind(.)]
};

(:~
 : Evaluates the target paths obtained by resolving links. The function returns 
 : a sequence of Link Resolution Objects.
 :
 : @param resourceShape resource shape element, with attribute providing the target declaration 
 : @param context processing context
 : @return the URIs of link values successfully resolved, and link reports 
 :  for all link values
 :)
declare function f:getTargetPaths_linkTargets(
                                  $resourceShape as element(),
                                  $context as map(xs:string, item()*))
        as item()* {
    let $constraintElem := $resourceShape/gx:targetSize        
    let $linkContextXP := $resourceShape/@contextXP
    let $linkXP := $resourceShape/@linkXP
    let $recursive := $resourceShape/@linkRecursive/xs:boolean(.)
    
    let $contextPath := $context?_contextPath    
    let $isExpectedResourceKind := 
        if ($resourceShape/self::gx:folder) then i:fox-resource-is-dir#1 
        else i:fox-resource-is-file#1
    let $targetMediatype :=
        if ($resourceShape/@mediatype) then $resourceShape/@mediatype
        else if ($recursive) then 'xml'
        else if ($constraintElem/(@linksResolvable, 
                                  @countTargetDocs, @minCountTargetDocs, @maxCountTargetDocs,
                                  @countTargetNodes, @minCountTargetNodes, @maxCountTargetNodes)) then 'xml'
        else ()    
    let $doc := $context?_reqDocs?doc
    return
        if (not($doc)) then  
            map{'type': 'linkResolutionReport',
                'errorCode': 'context_document_not_nodetree', 
                'contextURI': $contextPath}
        else
    let $reports := link:resolveUriLinks($contextPath, $doc, $linkContextXP, $linkXP, (), $targetMediatype, $recursive, $context)        
    let $uris := $reports[not(?errorCode)]?targetURI [$isExpectedResourceKind(.)] => distinct-values()
    return ($uris, $reports)   
};

declare function f:getTargetPaths_rel(
                                  $resourceShape as element(),
                                  $context as map(xs:string, item()*))
        as item()* {
    let $constraintElem := $resourceShape/gx:targetSize        
    let $rel := $resourceShape/@rel
    let $contextPath := $context?_contextPath
    let $isExpectedResourceKind := 
        if ($resourceShape/self::gx:folder) then i:fox-resource-is-dir#1 
        else i:fox-resource-is-file#1
    let $lros := i:resolveRelationship($rel, 'lro', $constraintElem, $contextPath, $context)        
    let $uris := $lros[not(?errorCode)]?targetURI [$isExpectedResourceKind(.)] => distinct-values()
    return ($uris, $lros)    
};        
