(:
 : -------------------------------------------------------------------------
 :
 : shapeTarget.xqm - functions for determining the target of a resource shape
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "greenfoxUtil.xqm",
   "linkConstraint.xqm",
   "resourceAccess.xqm",
   "targetConstraint.xqm",
   "log.xqm" ;
    
import module namespace vr="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";
    
import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkResolution.xqm",
   "linkValidation.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare variable $f:DBG_SHAPE_TARGET_LEVEL as xs:integer := 1;
declare variable $f:DBG_SHAPE_TARGET_FOO_NAMES := 'NEVER' ! tokenize(.) ! tt:pattern2Regex(.);
declare variable $f:DBG_SHAPE_TARGET_FILE := 'DEBUG_link_definition.txt';

(:~ 
 : Returns the target paths of a resource shape, as well as validation results related to
 : the outcome of resolving the target declaration.
 :
 : @param resourceShape the resource shape owning the target declaration
 : @param context the processing context
 : @return target file paths, and results of validating the target against target constraints
 :) 
declare function f:getTargetPaths($resourceShape as element(),
                                  $context as map(xs:string, item()*))
        as item()* {   
    
    (: Retrieve target paths, optionally also ldo and lros :)
    let $constraintElem := $resourceShape/gx:targetSize
    let $targetPathsEtc := f:resolveTargetDeclaration($resourceShape, $context)
    let $targetPaths := $targetPathsEtc?targetPaths
    let $ldo := $targetPathsEtc?ldo
    (: let $_DEBUG := trace(i:DEBUG_LDO($ldo), '_LDO: ') :)
    
    (: No link definition -> return target paths :)
    return if (not(($constraintElem, $ldo?constraints))) then $targetPaths else
    
    (: Perform validation of target paths :)
    let $lros := $targetPathsEtc?lros
    (: let $_DEBUG := trace(i:DEBUG_LROS($lros), '_LROS: ') :)
    let $validationResults := 
        i:validateTargetConstraints(
            $resourceShape, $targetPaths, $ldo, $lros, $context)
                    
    (: Return target paths and validation results :)                                        
    return ($targetPaths, $validationResults)
};

(: ============================================================================
 :
 :     f u n c t i o n s    r e t r i e v i n g    t a r g e t    p a t h s
 :
 : ============================================================================ :)
(:~
 : Resolves the target declaration of a resource shape, returning a map with
 : an entry containing the resource paths and optional entries containing 
 : a Link Definition Object and Link Resolution Objects.
 :
 : The target is identified either by a URI (@uri) or by a foxpath expression 
 : (@navigateFOX) or by a link definition (@hrefXP, @recursive, ...).
 :
 : The path is appended to the context path. The foxpath is
 : evaluated. Link definitions are resolved.
 :
 : Whether Link Resolution Objects are returned depends on the kind 
 : of target declaration:
 : - if URI: no Link Resolution Objects
 : - if Foxpath and no link constraints: no Link Resolution Objects
 : - otherwise: with Link Resolution Objects
 : 
 : @param resourceShape a file or folder shape
 : @param context a map of variable bindings
 : @return a map with mandatory field 'targetPaths' and optional fields 'ldo' and 'lros' 
 :)
declare function f:resolveTargetDeclaration($resourceShape as element(), 
                                            $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $urisAndLros :=
        let $uri := $resourceShape/@uri
        let $foxpath := $resourceShape/@navigateFOX
        let $link := $resourceShape/(@navigateFOX, @uri, @linkName, @hrefXP, @uriXP, @uriTemplate, @linkReflectionBase)         
        return
            (: URI :)
            if ($uri and empty($resourceShape/gx:targetSize/link:getLinkConstraintAtts(.))) then
                map{'targetPaths': f:getTargetPaths_uri($uri, $resourceShape, $context)}
            (: Foxpath (and no link constraints :)
            else if ($foxpath and empty($resourceShape/gx:targetSize/link:getLinkConstraintAtts(.))) then 
                map{'targetPaths': f:getTargetPaths_foxpath($foxpath, $resourceShape, $context)}
            (: Link definition :)                
            else if ($link) then 
                f:getTargetPaths_link($resourceShape, $context)      
            (: Missing target declaration :)
            else 
                error()
    (: let $_DEBUG := trace($urisAndLros?lros => f:DEBUG_LROS() , '_LROS: ') :)              
    return $urisAndLros
};        

(:~
 : Returns the target paths of a resource shape, identified by a plain path 
 : expression. Note that the plain path may contain wildcards.
 :
 : @param path plain path expression
 : @param resourceShape the resource shape 
 : @param context the processing context
 : @return the target paths
 :)
 (:
declare function f:getTargetPaths_path($path as xs:string, 
                                       $resourceShape as element(),
                                       $context as map(xs:string, item()*))
        as xs:string* {
    let $contextPath := $context?_targetInfo?contextURI
    let $isExpectedResourceKind := 
        if ($resourceShape/self::gx:folder) 
        then i:fox-resource-is-dir#1 
        else i:fox-resource-is-file#1
    return    
        concat($contextPath, '/', $path)
        [i:fox-resource-exists(.)]
        [$isExpectedResourceKind(.)]        
};
:)

(:~
 : Returns the target paths of a resource shape, identified by a plain path 
 : expression. Note that the plain path may contain wildcards.
 :
 : @param path plain path expression
 : @param resourceShape the resource shape 
 : @param context the processing context
 : @return the target paths
 :)
declare function f:getTargetPaths_uri($uri as xs:string, 
                                      $resourceShape as element(),
                                      $context as map(xs:string, item()*))
        as xs:string* {
    let $contextUri := $context?_targetInfo?contextURI ! f:addToUriTrailingSlash(.)
    let $kind := $resourceShape/local-name(.)
    return i:existentResourceUri($uri, $contextUri, $kind)        
};

(:~
 : Returns the target paths of a resource shape, identified by a foxpath
 : expression.
 :
 : Note. This function is only called if the constraint element does
 : not declare link constraints, in which case the Foxpath will
 : be treated as Link Definition and resolved by standard Link
 : Resolution.
 :
 : @param foxpath Foxpath expression returning the target paths
 : @param resourceShape the resource shape
 : @param context the processing context
 : @return the target pathss
 :)
declare function f:getTargetPaths_foxpath($foxpath as xs:string, 
                                          $resourceShape as element(),
                                          $context as map(xs:string, item()*))
        as xs:string* {
    let $contextURI := $context?_targetInfo?contextURI        
    let $isExpectedResourceKind := 
        if ($resourceShape/self::gx:folder) 
        then i:fox-resource-is-dir#1 
        else i:fox-resource-is-file#1
    let $evaluationContext := $context?_evaluationContext        
    return    
        i:evaluateFoxpath($foxpath, $contextURI, $evaluationContext, true())       
        [$isExpectedResourceKind(.)]
};

(:~
 : Returns the results of resolving a Link Definition used as target
 : declaration of a resource shape. The results are returned as a map 
 : with fields 'targetPaths' containing the target paths, 'ldo' 
 : containing the Link Definition Object and 'lros' containing the 
 : Link Resolution Objects.
 :
 : @param resourceShape the resource shape
 : @param context the processing context
 : @return a map with fields 'targetPaths', 'ldo' and 'lros'
 :)
declare function f:getTargetPaths_link($resourceShape as element(),
                                       $context as map(xs:string, item()*))
        as item()* {
    let $contextURI := $context?_targetInfo?contextURI
    let $contextNode := $context?_reqDocs?doc
    let $ldo := link:getLinkDefObject($resourceShape, $context)
    let $lros := link:resolveLinkDef($ldo, 'lro', $contextURI, $contextNode, $context, ()) 
    let $isExpectedResourceKind := 
        if ($resourceShape/self::gx:folder) 
        then i:fox-resource-is-dir#1 
        else i:fox-resource-is-file#1    
    let $uris := $lros[not(?errorCode)]
                 ?targetURI[$isExpectedResourceKind(.)] 
                 => distinct-values()
    return map{'targetPaths': $uris, 'ldo': $ldo, 'lros': $lros}    
};        
