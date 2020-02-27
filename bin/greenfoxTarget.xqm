(:
 : -------------------------------------------------------------------------
 :
 : greenfoxTarget.xqm - functions for determining the target and Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "greenfoxUtil.xqm",
    "linkConstraint.xqm",
    "validationResult.xqm",
    "log.xqm" ;
    
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
    let $targetPathsAndLinkInfos := f:getTargetPaths($resourceShape, $context)
    let $targetPaths := $targetPathsAndLinkInfos[. instance of xs:anyAtomicType]
    return if (not($targetConstraints)) then $targetPaths else
    
    (: Perform validation of target paths :)
    let $linkInfos := $targetPathsAndLinkInfos[. instance of map(*)]
    let $contextPath := $context?_contextPath
    let $targetDeclaration := $resourceShape/(@path, @foxpath, @linkXPath, @recursiveLinkXPath)
    let $validationResults := f:validateTargetConstraints(
                                        $targetConstraints, 
                                        $targetDeclaration, 
                                        $targetPaths, 
                                        $contextPath, 
                                        $linkInfos)
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
 : Returns the target paths of a resource shape.
 :
 : The target is identified either by a path (@path) or
 : by a foxpath expression (@foxpath), or by an expression
 : producing link targets (@linkXPath, @recursiveLinkXPath).
 :
 : The path is appended to the context path. The foxpath is
 : evaluated. Link targets are resolved.
 :
 : @param resourceShape a file or folder shape
 : @param context a map of variable bindings
 : @return the target paths :)
declare function f:getTargetPaths($resourceShape as element(), 
                                  $context as map(xs:string, item()*))
        as item()* {
    let $isExpectedResourceKind := if ($resourceShape/self::gx:folder) then file:is-dir#1 else file:is-file#1
    let $contextPath := $context?_contextPath  
    
    (: _TO_DO_ cleanup - adhoc addition of $filePath and $fileName :)
    let $evaluationContext := $context?_evaluationContext
    let $evaluationContext := map:put($evaluationContext, QName((),'filePath'), $contextPath)
    let $evaluationContext := map:put($evaluationContext, QName((), 'fileName'), replace($contextPath, '.*[/\\]', ''))
    let $context := map:put($context, '_evaluationContext', $evaluationContext)
    
    let $targetPathsAndLinkInfos :=
        let $path := $resourceShape/@path
        let $foxpath := $resourceShape/@foxpath
        let $linkTargets := $resourceShape/@linkXPath
        let $recursiveLinkTargets := $resourceShape/@recursiveLinkXPath
        let $pathsAndLinkInfos := (
            if ($path) then 
                f:getTargetPaths_path($path, $contextPath)
            else if ($foxpath) then
                f:getTargetPaths_foxpath($foxpath, $contextPath, $evaluationContext)
            else if ($linkTargets) then
                f:getTargetPaths_linkTargets($linkTargets, $contextPath, $context)
            else if ($recursiveLinkTargets) then
                f:getTargetPaths_recursiveLinkTargets($recursiveLinkTargets, $contextPath, $context)
            else error()
        )
        (: let $_DEBUG := if (not($linkTargets)) then () else  trace($pathsAndLinkInfos, '_PATHS_AND_LINK_INFOS: ') :)
        let $paths := $pathsAndLinkInfos[. instance of xs:anyAtomicType][$isExpectedResourceKind(.)]
        let $linkInfos := $pathsAndLinkInfos[. instance of map(*)]
        return
            ($paths, $linkInfos)
    return $targetPathsAndLinkInfos        
};        

(:~
 : Evaluates the target path given by a plain path expression.
 :
 : @param path plain path expression
 : @param contextPath file path of the context item
 : @return the target path
 :)
declare function f:getTargetPaths_path($path as xs:string, 
                                       $contextPath as xs:string)
        as xs:string* {
    concat($contextPath, '\', $path)[file:exists(.)]        
};

(:~
 : Evaluates the target paths which are the items of a foxpath
 : expression value.
 :
 : @param foxpath foxpath expression producing the target paths
 : @param contextPath file path of the context item
 : @param evaluationContext XPath evaluation context
 : @return the target paths corresponding to the link targets
 :)
declare function f:getTargetPaths_foxpath($foxpath as xs:string, 
                                          $contextPath as xs:string,
                                          $evaluationContext as map(xs:QName, item()*))
        as xs:string* {
    i:evaluateFoxpath($foxpath, $contextPath, $evaluationContext, true())        
};

(:~
 : Evaluates the target paths which are link targets. Returns all links 
 : which could be resolved to a resource, as well as for each link (whether
 : or not it could be resolved to a resource) a link describing map.
 :
 : @param xpath XPath expression producing the links values
 : @param contextPath file path of the context item
 : @param evaluationContext XPath evaluation context
 : @return the target paths corresponding to the link targets, and link info maps
 :)
declare function f:getTargetPaths_linkTargets($xpath as xs:string, 
                                              $contextPath as xs:string, 
                                              $context as map(xs:string, item()*))
        as item()* {
    if (not(doc-available($contextPath))) then 
        map{'error': 'true', 'reason': 'Document cannot be parsed', 'filepath': $contextPath}
    else        
    let $doc :=  doc($contextPath)
    let $linkMaps := i:resolveLinks($xpath, $doc, $contextPath, (), false(), $context)
    let $uris := $linkMaps[not(?error)]?uri
    return ($uris, $linkMaps)
};

(:~
 : Evaluates the target paths which are recursive link targets. The path producing
 : expression is recursively applied to the documents obtained by resolving the links.
 :
 : @param xpath XPath expression producing the links values
 : @param contextPath file path of the context item
 : @param evaluationContext XPath evaluation context
 : @return the target paths corresponding to the link targets, and error describing maps
 :)
declare function f:getTargetPaths_recursiveLinkTargets($xpath as xs:string, 
                                                       $contextPath as xs:string, 
                                                       $context as map(xs:string, item()*))
        as item()* {
    if (not(doc-available($contextPath))) then () else        
    let $doc :=  doc($contextPath)
    let $targetAndErrorMaps := i:resolveLinks($xpath, $doc, $contextPath, (), true(), $context)
    let $uris := $targetAndErrorMaps[?doc]?uri
    let $errorMaps := $targetAndErrorMaps[not(?error)]    
    return ($uris, $errorMaps)
};

(: ============================================================================
 :
 :     f u n c t i o n s    v a l i d a t i n g    t a r g e t    c o n s t r a i n t s
 :
 : ============================================================================ :)
(:~
 : Validates the target constraints. These may be count constraints, as well as a TargetLinkResolvable
 : constraint.
 :
 : @param constraints `targetSize` element representing the target constraints
 : @param targetDeclaration attribute selecting the target, which may be one of the 
 :     following - @foxpath, @path, @linkXPath, @recursiveLinkXPath
 : @param targetResources the target resources selected by the target declaration
 : @param contextPath the file path of the context in which the target was selected
 : @param targetLinkInfos maps describing all attempts at resolving a target link, successful or failed
 : @return validation results describing conformance to or violations of target constraints
 :) 
declare function f:validateTargetConstraints($constraints as element(), 
                                             $targetDeclaration as attribute(),
                                             $targetResources as item()*,                                             
                                             $contextPath as xs:string,
                                             $targetLinkInfos as map(*)*)
        as element()* {
    let $countResults := f:validateTargetCount($constraints, $targetResources, 
                                               $contextPath, $targetDeclaration)
    let $linkResults := f:validateTargetLinks($constraints, $targetDeclaration, 
                                              $contextPath, $targetLinkInfos)   
    return ($countResults, $linkResults)
};        

(:~
 : Validates the link targets obtained for a resource shape.
 :
 : @param constraint definition of a target constraint
 : @targetCount the number of focus resources belonging to the target of the shape
 : @return validation results describing conformance to or violations of target count constraints
 :) 
declare function f:validateTargetLinks($constraints as element(),
                                       $targetDeclaration as attribute(),   
                                       $contextPath as xs:string,
                                       $targetLinkInfos as map(*)*)
        as element()? {
        if (not($constraints/@targetLinkResolvable eq 'true')) then () else        
        
        let $contextInfo :=
            map:merge((
                map:entry('filePath', $contextPath)
            ))
        let $resultAdditionalAtts := ()
        let $resultOptions := ()
        let $recursive := $targetDeclaration instance of attribute(recursiveLinkXPath)
        let $targetLinkErrors := $targetLinkInfos[?error]    
        let $colour := if (exists($targetLinkErrors)) then 'red' else 'green'
        let $values :=  
            if (empty($targetLinkErrors)) then () 
            else if ($recursive) then 
                $targetLinkErrors 
                ! <gx:value where="{?filepath}">{?linkValue}</gx:value>
            else 
                $targetLinkErrors 
                ! <gx:value>{?linkValue}</gx:value>
        return
            f:validationResult_targetLinks(
                                $colour, 
                                $targetDeclaration, 
                                $constraints,
                                $targetLinkInfos,
                                $resultAdditionalAtts, 
                                $values,
                                $contextInfo, 
                                $resultOptions)        
};

(:~
 : Validates the target count of a resource shape or a focus node.
 :
 : @param constraint definition of a target constraint
 : @targetCount the number of focus resources belonging to the target of the shape
 : @return validation results describing conformance to or violations of target count constraints
 :) 
declare function f:validateTargetCount($constraint as element(), 
                                       $targetItems as item()*,
                                       $contextPath as xs:string,
                                       $navigationSpec as attribute())
        as element()* {
    let $targetCount := count($targetItems)        
    let $results := (
        let $condition := $constraint/@count
        return if (not($condition)) then () else
        
        let $value := $condition/xs:integer(.)
        let $ok := $value eq $targetCount
        let $colour := if ($ok) then 'green' else 'red'
        return
            f:validationResult_targetCount($constraint, $colour, (), 'TargetCount', $condition, 
                $targetItems, $contextPath, $navigationSpec)
        ,
        let $condition := $constraint/@minCount
        return if (not($condition)) then () else
        
        let $value := $condition/xs:integer(.)
        let $ok := $value le $targetCount
        let $colour := if ($ok) then 'green' else 'red'
        return
            f:validationResult_targetCount($constraint, $colour, (), 'TargetMinCount', $condition, 
                $targetItems, $contextPath, $navigationSpec)
        ,        
        let $condition := $constraint/@maxCount
        return if (not($condition)) then () else
        
        let $value := $condition/xs:integer(.)
        let $ok := $value ge $targetCount
        let $colour := if ($ok) then 'green' else 'red'
        return
            f:validationResult_targetCount($constraint, $colour, (), 'TargetMaxCount', $condition, 
                $targetItems, $contextPath, $navigationSpec)
    )
    return $results
};

(: ============================================================================
 :
 :     f u n c t i o n s    c r e a t i n g    v a l i d a t i o n    r e s u l t s
 :
 : ============================================================================ :)

(:~
 : Creates a validation result for constraints from TargetCount, TargetMinCount, TargetMaxCount.
 :
 : @param constraint element defining the constraint
 : @param colour the kind of results - green or red
 : @param msg a message overriding the message read from the constraint element
 : @param constraintComp string identifying the constraint component
 : @param condition an attribute specifying a condition (e.g. @minCount=...)
 : @param the actual number of target instances
 : @return a result element 
 :)
declare function f:validationResult_targetCount(
                                    $constraint as element(gx:targetSize),
                                    $colour as xs:string,
                                    $msg as attribute()?,
                                    $constraintComp as xs:string,
                                    $condition as attribute(),
                                    $targetItems as item()*,
                                    $targetContextPath as xs:string,
                                    $navigationSpec as attribute())
        as element() {
    let $actCount := count($targetItems)        
    let $elemName := if ($colour eq 'green') then 'gx:green' else 'gx:red'
    let $useMsg :=
        if ($msg) then $msg
        else if ($colour eq 'green') then 
            $constraint/i:getOkMsg($constraint, $condition/local-name(.), ())
        else 
            $constraint/i:getErrorMsg($constraint, $condition/local-name(.), ())
    let $navigationAtt :=
        let $name := 'target' || $navigationSpec/f:firstCharToUpperCase(local-name(.))
        let $name := if (contains($name, 'Xpath')) then replace($name, 'Xpath', 'XPath') else $name
        return attribute {$name} {$navigationSpec}
    let $values :=
        if (not($colour = ('red', 'yellow'))) then ()
        else i:validationResultValues($targetItems, $constraint)
    return
        element {$elemName} {
            $useMsg ! attribute msg {.},
            attribute filePath {$targetContextPath},
            attribute constraintComp {$constraintComp},
            $constraint/@id/attribute constraintID {. || '-' || $condition/local-name(.)},                    
            $constraint/@resourceShapeID,
            $condition,
            attribute valueCount {$actCount},
            attribute targetContextPath {$targetContextPath},
            $navigationAtt,
            $values
        }
};

(:~
 : Creates a validation result for a TargetLinkResolvable constraint.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param exprValue expression value producing the links
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_targetLinks(
                                    $colour as xs:string,
                                    $targetDeclaration as attribute(),
                                    $constraints as element(),
                                    $exprValue as item()*,
                                    $additionalAtts as attribute()*,
                                    $additionalElems as element()*,
                                    $contextInfo as map(xs:string, item()*),
                                    $options as map(*)?)
        as element() {
    let $exprAtt := $targetDeclaration        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^.*link', '') ! lower-case(.)    
    let $constraintConfig := 
        map{'constraintComp': 'TargetLinkResolvableConstraint', 'atts': ('mediatype')}
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $constraints/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $resourceShapeId := $constraints/@resourceShapeID
    let $constraintId := concat($resourceShapeId, '-targetLinkResolvable')
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraints, 'targetLinkResolvable', ())
        else i:getErrorMsg($constraints, 'targetLinkResolvable', ())
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


