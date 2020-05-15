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
    "validationResult.xqm",
    "log.xqm" ;
    
import module namespace link="http://www.greenfox.org/ns/xquery-functions/link-resolver" at
    "linkResolver.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~ 
 : Returns the target paths of a resource shape, as well as the results of validating
 : the set of target resources against target constraints.
 :
 : @param resourceShape the resource shape owning the target declaration
 : @param context the processing context
 : @param targetConstraints an element representing target constraints
 : @return target file paths, and results of validating the target file paths against target constraints
 :) 
declare function f:getTargetPaths($resourceShape as element(),
                                  $context as map(xs:string, item()*),
                                  $targetConstraints as element(gx:targetSize)?)
        as item()* {     
    (: Retrieve target paths :)
    let $targetPathsAndEvaluationReports := f:getTargetPaths($resourceShape, $context)
    let $targetPaths := $targetPathsAndEvaluationReports[. instance of xs:anyAtomicType]
    return if (not($targetConstraints)) then $targetPaths else
    
    (: Perform validation of target paths :)
    let $evaluationReports := $targetPathsAndEvaluationReports[. instance of map(*)]
    let $contextPath := $context?_contextPath
    let $targetDeclaration := $resourceShape/(@path, @foxpath, @linkXP, @recursiveLinkXP)
    let $validationResults := f:validateTargetConstraints(
                                        $targetConstraints, 
                                        $targetDeclaration, 
                                        $targetPaths, 
                                        $contextPath, 
                                        $evaluationReports)
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
 : evaluation reports. 
 :
 : The target is identified either by a path (@path) or
 : by a foxpath expression (@foxpath), or by an expression
 : producing link targets (@linkXP, @recursiveLinkXP).
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
declare function f:getTargetPaths($resourceShape as element(), 
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
        let $linkTargets := $resourceShape/(@linkXP, @recursiveLinkXP)[1]
        let $linkTargetsRecursive := $linkTargets instance of attribute(recursiveLinkXP)
        return
            if ($path) then 
                f:getTargetPaths_path($path, $resourceShape, $context)
            else if ($foxpath) then
                f:getTargetPaths_foxpath($foxpath, $resourceShape, $context)
            else if ($linkTargets) then
                f:getTargetPaths_linkTargets($linkTargets, $linkTargetsRecursive, $resourceShape, $context)
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
        (: if ($resourceShape/self::gx:folder) then file:is-dir#1 else file:is-file#1 :)
        if ($resourceShape/self::gx:folder) then i:fox-resource-is-dir#1 else i:fox-resource-is-file#1
    let $evaluationContext := $context?_evaluationContext        
    return    
        i:evaluateFoxpath($foxpath, $contextPath, $evaluationContext, true())       
        [$isExpectedResourceKind(.)]
};

(:~
 : Evaluates the target paths which are recursive link targets. The path producing
 : expression is recursively applied to the documents obtained by resolving the links.
 : The function returns the URIs of successfully resolved links, as well as link
 : reports for all links, both successfully and not successfully resolved.
 :
 : @param xpath XPath expression producing the links values
 : @param contextPath file path of the context item
 : @param context processing context
 : @return the URIs of link values successfully resolved, and link reports 
 :  for all link values
 :)
declare function f:getTargetPaths_linkTargets(
                                  $xpath as xs:string, 
                                  $recursive as xs:boolean,
                                  $resourceShape as element(),
                                  $context as map(xs:string, item()*))
        as item()* {
    let $contextPath := $context?_contextPath        
    let $isExpectedResourceKind := 
        (: if ($resourceShape/self::gx:folder) then file:is-dir#1 else file:is-file#1 :)
        if ($resourceShape/self::gx:folder) then i:fox-resource-is-dir#1 else i:fox-resource-is-file#1
    let $contextMediatype := ($resourceShape/ancestor::gx:file[1]/@mediatype, 'xml')[1]
    let $targetMediatype :=
        if ($resourceShape/@mediatype) then $resourceShape/@mediatype
        else if ($recursive) then 'xml'
        else ()
    
    let $doc :=
        (: _TO_DO_ Replace with retrieval from $context?_reqDocs :)
        if ($contextMediatype eq 'xml') then
            if (not(i:fox-doc-available($contextPath))) then () 
            else i:fox-doc($contextPath)
        else if ($contextMediatype eq 'json') then
            if (not(i:fox-unparsed-text-available($contextPath, ()))) then ()
            else
                let $text := i:fox-unparsed-text($contextPath, ())
                return
                    try{json:parse($text)} catch * {()}
    return
        if (not($doc)) then  
            map{'type': 'linkResolutionReport',
                'errorCode': 'context_document_not_' || $contextMediatype, 
                'filepath': $contextPath}
        else
    (:
    let $reports := i:resolveLinks(
        $xpath, $doc, $contextPath, $targetMediatype, $recursive, $context)
     :)    
    let $reports := link:resolveUriLinks($contextPath, $doc, (), $xpath, (), $targetMediatype, $recursive, $context)
        
        
    let $uris := $reports[not(?errorCode)]?uri [$isExpectedResourceKind(.)]
    return ($uris, $reports)   
};

