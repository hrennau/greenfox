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
        as xs:string* {
    let $isExpectedResourceKind :=
        let $isDir := $resourceShape/self::gx:folder
        return function($r) {if ($isDir) then file:is-dir($r) else file:is-file($r)}
    let $contextPath := $context?_contextPath  
    
    (: _TO_DO_ cleanup - adhoc addition of $filePath and $fileName :)
    let $evaluationContext := $context?_evaluationContext
    let $evaluationContext := map:put($evaluationContext, QName((),'filePath'), $contextPath)
    let $evaluationContext := map:put($evaluationContext, QName((), 'fileName'), replace($contextPath, '.*[/\\]', ''))
    
    let $targetPaths :=
        let $path := $resourceShape/@path
        let $foxpath := $resourceShape/@foxpath
        return
            if ($path) then 
                concat($contextPath, '\', $resourceShape/@path)
                [file:exists(.)]
                [$isExpectedResourceKind(.)]
            else 
                i:evaluateFoxpath($foxpath, $contextPath, $evaluationContext, true())
                [$isExpectedResourceKind(.)]
    return $targetPaths        
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
