(:~
 : -------------------------------------------------------------------------
 :
 : fileProperitesConstraint.xqm - functions checking the name, size or last 
 :   modified time of a resource
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "greenfoxUtil.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates the last modified time of a resource.
 :
 : @param filePath the file path of the resource
 : @param constraint an element containing attributes declaring the constraints
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFileDate($constraintElem as element(gx:fileDate), 
                                    $context as map(*))
        as element()* {
    let $contextURI := $context?_targetInfo?contextURI        
    let $constraintId := $constraintElem/@id
    let $constraintLabel := $constraintElem/@label
    
    let $eq := $constraintElem/@eq
    let $ne := $constraintElem/@ne
    let $lt := $constraintElem/@lt
    let $gt := $constraintElem/@gt
    let $le := $constraintElem/@le
    let $ge := $constraintElem/@ge
    let $like := $constraintElem/@like
    let $notLike := $constraintElem/@notLike
    let $matches := $constraintElem/@matches
    let $notMatches := $constraintElem/@notMatches    
    let $flags := string($constraintElem/@flags)
    
    let $actValue := i:resourceLastModified($contextURI) ! string(.)
    
    let $results := 
        for $cmp in ($eq, $lt, $gt, $le, $ge, $eq, $like, $notLike, $matches, $notMatches)
        let $violation :=
            switch($cmp/local-name(.))
            case 'eq' return $actValue != $cmp
            case 'ne' return $actValue = $cmp            
            case 'lt' return $actValue >= $cmp
            case 'le' return $actValue > $cmp
            case 'gt' return $actValue <= $cmp
            case 'ge' return $actValue < $cmp
            case 'matches' return not(matches($actValue, $matches, $flags))
            case 'notMatches' return matches($actValue, $notMatches, $flags)
            case 'like' return not(matches($actValue, $like/f:glob2regex(.), $flags))
            case 'notLike' return matches($actValue, $notLike/f:glob2regex(.), $flags)            
            default return error()
        let $colour := if ($violation) then 'red' else 'green'
        return   
            result:validationResult_fileProperties($colour, $constraintElem, $cmp, $actValue, (), $context)
    return $results                        
};

(:~
 : Validates the file size of a resource.
 :
 : @param filePath the file path of the resource
 : @param constraint an element containing attributes declaring the constraints
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFileSize($constraintElem as element(gx:fileSize), 
                                    $context as map(*))
        as element()* {
    let $contextURI := $context?_targetInfo?contextURI        
    let $constraintId := $constraintElem/@id
    let $constraintLabel := $constraintElem/@label

    let $eq := $constraintElem/@eq
    let $ne := $constraintElem/@ne
    let $lt := $constraintElem/@lt
    let $le := $constraintElem/@le    
    let $gt := $constraintElem/@gt
    let $ge := $constraintElem/@ge
    
    let $actValue := i:resourceFileSize($contextURI)
    
    let $results := 
        for $facet in ($eq, $ne, $lt, $gt, $le, $ge)
        let $violation :=
            switch($facet/local-name(.))
            case 'eq' return $actValue != $facet
            case 'ne' return $actValue = $facet
            case 'lt' return $actValue >= $facet
            case 'le' return $actValue > $facet
            case 'gt' return $actValue <= $facet
            case 'ge' return $actValue < $facet
            default return error()
        let $colour := if ($violation) then 'red' else 'green'
        return   
            result:validationResult_fileProperties($colour, $constraintElem, $facet, $actValue, (), $context)
    return $results                        
};

(:~
 : Validates the name of a resource.
 :
 : @param filePath the file path of the resource
 : @param constraint an element containing attributes declaring the constraints
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFileName($constraintElem as element(gx:fileName), 
                                    $context as map(*))
        as element()* {
    let $contextURI := $context?_targetInfo?contextURI        
    let $constraintId := $constraintElem/@id
    let $constraintLabel := $constraintElem/@label
    
    let $eq := $constraintElem/@eq
    let $ne := $constraintElem/@ne    
    let $like := $constraintElem/@like
    let $notLike := $constraintElem/@notLike    
    let $matches := $constraintElem/@matches
    let $notMatches := $constraintElem/@notMatches
    
    let $flags := ($constraintElem/@flags, '')[1]
    let $case := ($constraintElem/@case/xs:boolean(.), false())[1]

    let $actValue := i:resourceName($contextURI)
    let $actValueED := if ($case) then $actValue else lower-case($actValue)
    let $results := 
        for $facet in ($eq, $ne, $like, $notLike, $matches, $notMatches)
        let $facetED := if ($case) then $facet else lower-case($facet)
        let $violation :=
            switch($facet/local-name(.))
            case 'eq' return $actValueED ne $facetED
            case 'ne' return $actValueED eq $facetED
            case 'like' return not(matches($actValueED, f:glob2regex($facetED), $flags))
            case 'notLike' return matches($actValueED, f:glob2regex($facetED), $flags)
            case 'matches' return not(matches($actValueED, $facetED, $flags))
            case 'notMatches' return matches($actValueED, $facetED, $flags)
            default return error()
        let $colour := if ($violation) then 'red' else 'green'
        return   
            result:validationResult_fileProperties($colour, $constraintElem, $facet, $actValue, (), $context)
    return $results                        
};

