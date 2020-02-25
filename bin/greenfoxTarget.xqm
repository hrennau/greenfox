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
 : Returns the target paths of a resource shape.
 :
 : The target is identified either by a path (@path)
 : or by a foxpath expression (@foxpath). The path is
 : appended to the context path. The foxpath is
 : evaluated.
 :
 : @param resourceShape a file or folder shape
 : @param context a map of variable bindings
 : @return the target paths :)
declare function f:getTargetPaths($resourceShape as element(), $context as map(xs:string, item()*))
        as item()* {
    let $isExpectedResourceKind := if ($resourceShape/self::gx:folder) then file:is-dir#1 else file:is-file#1
    let $contextPath := $context?_contextPath  
    
    (: _TO_DO_ cleanup - adhoc addition of $filePath and $fileName :)
    let $evaluationContext := $context?_evaluationContext
    let $evaluationContext := map:put($evaluationContext, QName((),'filePath'), $contextPath)
    let $evaluationContext := map:put($evaluationContext, QName((), 'fileName'), replace($contextPath, '.*[/\\]', ''))
    let $context := map:put($context, '_evaluationContext', $evaluationContext)
    
    let $targetPathsAndErrorInfos :=
        let $path := $resourceShape/@path
        let $foxpath := $resourceShape/@foxpath
        let $linkTargets := $resourceShape/@linkXPath
        let $recursiveLinkTargets := $resourceShape/@recursiveLinkXPath
        let $pathsAndErrorInfos := (
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
        let $paths := $pathsAndErrorInfos[. instance of xs:anyAtomicType][$isExpectedResourceKind(.)]
        let $errorInfos := $pathsAndErrorInfos[. instance of map(*)]
        return
            ($paths, $errorInfos)
    return $targetPathsAndErrorInfos        
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
 : Evaluates the target paths which are link targets.
 :
 : @param xpath XPath expression producing the links values
 : @param contextPath file path of the context item
 : @param evaluationContext XPath evaluation context
 : @return the target paths corresponding to the link targets, and error describing maps
 :)
declare function f:getTargetPaths_linkTargets($xpath as xs:string, 
                                              $contextPath as xs:string, 
                                              $context as map(xs:string, item()*))
        as item()* {
    if (not(doc-available($contextPath))) then () else        
    let $doc :=  doc($contextPath)
    let $targetAndErrorMaps := i:resolveLinks($xpath, $doc, $contextPath, (), false(), $context)
    let $uris := $targetAndErrorMaps[?doc]?uri
    let $errorMaps := $targetAndErrorMaps[not(?error)]
    return ($uris, $errorMaps)
    
(:        
    let $linkMaps := f:resolveLinksRC($expr, $contextNode, $filepath, $mediatype, $recursive, $context, (), ())
    return
        $linkMaps
        
        let $exprValue := i:evaluateXPath($xpath, $doc, $evaluationContext, true(), true())
        return
            for $item in $exprValue
            return
                if ($item instance of node()) then 
                    resolve-uri($item, $item/ancestor-or-self::*[1]/base-uri(.))
                else 
                    string($item)
:)                    
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
(:        
    f:getTargetPaths_recursiveLinkTargetsRC($xpath, $contextPath, $evaluationContext, ())
 :)    
};

(:~
 : Recursive helper function of `getTargetPaths_recursiveLinkTargets`.
 :
 : @param xpath XPath expression producing the links values
 : @param contextPath file path of the context item
 : @param evaluationContext XPath evaluation context
 : @param sofar the paths already found
 : @return the target paths corresponding to the link targets
 :)
declare function f:getTargetPaths_recursiveLinkTargetsRC($xpath as xs:string, 
                                                         $contextPath as xs:string, 
                                                         $evaluationContext as map(xs:QName, item()*),
                                                         $sofar as xs:string*)
        as xs:string* {
    let $newPaths := f:getTargetPaths_linkTargets($xpath, $contextPath, $evaluationContext)[not(. = $sofar)]
    let $newSofar := ($sofar, $newPaths)
    let $newPathsR :=
        $newPaths ! 
        f:getTargetPaths_recursiveLinkTargetsRC($xpath, ., $evaluationContext, $newSofar) [not(. = $newSofar)]
    return ($sofar, $newPaths, $newPathsR) => distinct-values() => sort()           
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
            f:constructResult_targetCount($constraint, $colour, (), 'TargetCount', $condition, 
                $targetItems, $contextPath, $navigationSpec)
        ,
        let $condition := $constraint/@minCount
        return if (not($condition)) then () else
        
        let $value := $condition/xs:integer(.)
        let $ok := $value le $targetCount
        let $colour := if ($ok) then 'green' else 'red'
        return
            f:constructResult_targetCount($constraint, $colour, (), 'TargetMinCount', $condition, 
                $targetItems, $contextPath, $navigationSpec)
        ,        
        let $condition := $constraint/@maxCount
        return if (not($condition)) then () else
        
        let $value := $condition/xs:integer(.)
        let $ok := $value ge $targetCount
        let $colour := if ($ok) then 'green' else 'red'
        return
            f:constructResult_targetCount($constraint, $colour, (), 'TargetMaxCount', $condition, 
                $targetItems, $contextPath, $navigationSpec)
    )
    return $results
};

(:~
 : Constructs results for constraints targetCount, targetMinCount, targetMaxCount.
 :
 : @param constraint element defining the constraint
 : @param colour the kind of results - green or red
 : @param msg a message overriding the message read from the constraint element
 : @param constraintComp string identifying the constraint component
 : @param condition an attribute specifying a condition (e.g. @minCount=...)
 : @param the actual number of target instances
 : @return a result element 
 :)
declare function f:constructResult_targetCount($constraint as element(gx:targetSize),
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
