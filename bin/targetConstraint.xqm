(:
 : -------------------------------------------------------------------------
 :
 : targetConstraint.xqm - functions checking the result of resolving the target declaration of a resource shape
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at
    "constants.xqm",
    "greenfoxUtil.xqm",
    "resourceAccess.xqm",
    "log.xqm" ;

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at
    "linkValidation.xqm";

import module namespace vr="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at
    "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n s    v a l i d a t i n g    t a r g e t    c o n s t r a i n t s
 :
 : ============================================================================ :)
(:~
 : Validates the target constraints. These may be count constraints, as well as 
 : link constraints.
 :
 : @param resourceShape the resource shape
 : @param targetResources the target resources selected by the target declaration
 : @param ldo Link Definition Object used as a target declaration
 : @param lros Link Resolution Objects obtained when resolving a link definition
 : @param context the processing context
 : @return validation results describing conformance to or violations of target constraints
 :) 
declare function f:validateTargetConstraints($resourceShape as element(), 
                                             $targetResources as item()*,   
                                             $ldo as map(*)?,
                                             $lros as map(*)*,
                                             $context as map(xs:string, item()*))
        as element()* {
    (: Validate the simple target size constraints :)
    let $countResults := f:validateTargetCount($resourceShape, $ldo, $lros, $targetResources, $context)
    
    (: Validate any link constraints :)
    let $linkResults := f:validateLinkConstraints($resourceShape, $ldo, $lros, $context)
    
    return ($countResults, $linkResults)
};        

(:~
 : Validates the results of resolving a Link Definition used as target declaration.
 :
 : @param constraint definition of a target constraint
 : @targetCount the number of focus resources belonging to the target of the shape
 : @return validation results describing conformance to or violations of target count constraints
 :) 
declare function f:validateLinkConstraints($resourceShape as element(),
                                           $ldo as map(*)?,
                                           $lros as map(*)*,
                                           $context as map(xs:string, item()*))
        as element()* {
    if (empty($lros)) then () else
       
    let $constraintElem := $resourceShape/gx:targetSize
    let $contextInfo := map:merge((map:entry('filePath', $context?_contextPath)))
    return 
        link:validateLinkConstraints($lros, $ldo, $constraintElem, $contextInfo)
};

(:~
 : Validates the target count of a resource shape or a focus node.
 :
 : @param resourceShape resource shape owning the target declaration
 : @param targetItems the target resources obtained by resolving the target declaration
 : @param context the processing context
 : @return validation results obtained for the target count constraints
 :) 
declare function f:validateTargetCount($resourceShape as element(), 
                                       $ldo as map(*)?,
                                       $lros as map(*)*,
                                       $targetItems as item()*,
                                       $context as map(xs:string, item()*))
        as element()* {
    let $contextPath := $context?_contextPath        
    let $constraintElem := $resourceShape/gx:targetSize        
    let $targetCount := count($targetItems)        
    let $results := (
        let $constraint := $constraintElem/@count
        return if (not($constraint)) then () else
        
        let $checkValue := $constraint/xs:integer(.)
        let $ok := $targetCount eq $checkValue
        let $colour := if ($ok) then 'green' else 'red'
        return
            vr:validationResult_targetCount($colour, $ldo, $resourceShape, $constraintElem,  
                $constraint, $targetItems, $contextPath)
        ,
        let $constraint := $constraintElem/@minCount
        return if (not($constraint)) then () else
        
        let $checkValue := $constraint/xs:integer(.)
        let $ok := $targetCount ge $checkValue
        let $colour := if ($ok) then 'green' else 'red'
        return
            vr:validationResult_targetCount($colour, $ldo, $resourceShape, $constraintElem, 
                $constraint, $targetItems, $contextPath)
        ,        
        let $constraint := $constraintElem/@maxCount
        return if (not($constraint)) then () else
        
        let $checkValue := $constraint/xs:integer(.)
        let $ok := $targetCount le $checkValue
        let $colour := if ($ok) then 'green' else 'red'
        return
            vr:validationResult_targetCount($colour, $ldo, $resourceShape, $constraintElem, 
                $constraint, $targetItems, $contextPath)
    )
    return $results
};
