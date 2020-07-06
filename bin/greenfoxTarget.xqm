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
    
import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkResolution.xqm";
    
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
    let $targetPathsEtc := f:resolveTargetDeclaration($resourceShape, $context)
    let $targetPaths := $targetPathsEtc?targetPaths
    let $ldo := $targetPathsEtc?ldo
    return if (not(($constraintElem, $ldo?constraints))) then $targetPaths else
    
    (: Perform validation of target paths :)
    let $lros := $targetPathsEtc?lros
    let $validationResults := i:validateTargetConstraints(
                                        $resourceShape,
                                        $targetPaths,
                                        $ldo, 
                                        $lros,
                                        $context)
    (: Return target paths and validation results :)                                        
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
 : by a foxpath expression (@foxpath) or by a link definition
 : (@hrefXP, @recursive).
 :
 : The path is appended to the context path. The foxpath is
 : evaluated. Link definitions are resolved.
 :
 : Whether Link Resolution Objects are returned depends on the kind 
 : of target declaration:
 : - if path of foxpath: no reports
 : - if link definition: with Link Resolution Objects
 : 
 : @param resourceShape a file or folder shape
 : @param context a map of variable bindings
 : @return the target paths :)
declare function f:resolveTargetDeclaration($resourceShape as element(), 
                                            $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $contextPath := $context?_contextPath    
    let $urisAndLros :=       
        let $path := $resourceShape/@path
        let $foxpath := $resourceShape/@foxpath
        let $link := $resourceShape/(@linkName, @hrefXP, @uriXP, @linkReflectionBase)         
        return
            if ($path) then map{'targetPaths': f:getTargetPaths_path($path, $resourceShape, $context)}
            else if ($foxpath) then map{'targetPaths': f:getTargetPaths_foxpath($foxpath, $resourceShape, $context)}
            else if ($link) then f:getTargetPaths_link($resourceShape, $context)            
            else error()
    return $urisAndLros
};        

(:~
 : Returns the target paths of a resource shape, identified by a plain path 
 : expression. Note that the plain path may contain wildcards.
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
        if ($resourceShape/self::gx:folder) 
        then i:fox-resource-is-dir#1 
        else i:fox-resource-is-file#1
    return    
        concat($contextPath, '\', $path)
        [i:fox-resource-exists(.)]
        [$isExpectedResourceKind(.)]        
};

(:~
 : Returns the target paths of a resource shape, identified by a foxpath
 : expression.
 :
 : @param foxpath foxpath expression producing the target paths
 : @param resourceShape the resource shape
 : @param context the processing context
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
 : Returns the target paths of a resource shape, identified by a Link
 : Definition; also returns the Link Resolution Objects, which are
 : map items.
 :
 : @param resourceShape the resource shape
 : @param context the processing context
 : @return the target paths corresponding to the link targets
 :)
declare function f:getTargetPaths_link($resourceShape as element(),
                                       $context as map(xs:string, item()*))
        as item()* {
    let $contextURI := $context?_contextPath
    let $contextNode := $context?_reqDocs?doc
    let $ldo := link:getLinkDefObject($resourceShape, $context)
    let $lros := link:resolveLinkDef($ldo, 'lro', $contextURI, $contextNode, $context, ()) 
    let $isExpectedResourceKind := 
        if ($resourceShape/self::gx:folder) then i:fox-resource-is-dir#1 
        else i:fox-resource-is-file#1    
    let $uris := $lros[not(?errorCode)]?targetURI 
                 [$isExpectedResourceKind(.)] 
                 => distinct-values()
    return map{'targetPaths': $uris, 'ldo': $ldo, 'lros': $lros}    
};        
