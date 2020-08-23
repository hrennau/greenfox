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
at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at
    "greenfoxUtil.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at
    "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates the last modified time of a resource.
 :
 : @param filePath the file path of the resource
 : @param constraint an element containing attributes declaring the constraints
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateLastModified($filePath as xs:string, 
                                        $constraintElem as element(gx:lastModified), 
                                        $context as map(*))
        as element()* {
    let $constraintId := $constraintElem/@id
    let $constraintLabel := $constraintElem/@label
    
    let $lt := $constraintElem/@lt
    let $gt := $constraintElem/@gt
    let $le := $constraintElem/@le
    let $ge := $constraintElem/@ge
    let $eq := $constraintElem/@eq
    let $like := $constraintElem/@like
    let $notLike := $constraintElem/@notLike
    let $matches := $constraintElem/@matches
    let $notMatches := $constraintElem/@notMatches
    
    let $flags := string($constraintElem/@flags)
    
    (: let $actValue := file:last-modified($filePath) ! string(.) :)
    let $actValue := i:resourceLastModified($filePath) ! string(.)
    
    let $results := 
        for $facet in ($lt, $gt, $le, $ge, $eq, $like, $notLike, $matches, $notMatches)
        let $violation :=
            switch($facet/local-name(.))
            case 'lt' return $actValue >= $facet
            case 'le' return $actValue > $facet
            case 'gt' return $actValue <= $facet
            case 'ge' return $actValue < $facet
            case 'eq' return $actValue != $facet
            case 'matches' return not(matches($actValue, $matches, $flags))
            case 'notMatches' return matches($actValue, $notMatches, $flags)
            case 'like' return not(matches($actValue, $like/f:glob2regex(.), $flags))
            case 'notLike' return matches($actValue, $notLike/f:glob2regex(.), $flags)            
            default return error()
        let $colour := if ($violation) then 'red' else 'green'
        let $additionalAtts := (
            if (not($facet/local-name(.) = ('like', 'notLike', 'matches', 'notMatches'))) then ()
            else attribute flags {$flags}
        )
        return   
            result:validationResult_fileProperties($colour, $constraintElem, $facet, $filePath, $actValue, $additionalAtts)
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
declare function f:validateFileSize($filePath as xs:string, 
                                    $constraintElem as element(gx:fileSize), 
                                    $context as map(*))
        as element()* {
    let $constraintId := $constraintElem/@id
    let $constraintLabel := $constraintElem/@label

    let $eq := $constraintElem/@eq
    let $ne := $constraintElem/@ne
    let $lt := $constraintElem/@lt
    let $le := $constraintElem/@le    
    let $gt := $constraintElem/@gt
    let $ge := $constraintElem/@ge
    
    let $actValue := i:resourceFileSize($filePath)
    
    let $results := 
        for $facet in ($lt, $gt, $le, $ge, $eq)
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
        let $additionalAtts := ()
        return   
            result:validationResult_fileProperties($colour, $constraintElem, $facet, $filePath, $actValue, $additionalAtts)
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
declare function f:validateFileName($filePath as xs:string, 
                                    $constraintElem as element(gx:fileName), 
                                    $context as map(*))
        as element()* {
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

    let $actValue := i:resourceName($filePath)
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
        let $additionalAtts := (
            attribute case {$case},
            if (not($facet/local-name(.) = ('like', 'notLike', 'matches', 'notMatches'))) then ()
            else attribute flags {$flags}
        )
        return   
            result:validationResult_fileProperties($colour, $constraintElem, $facet, $filePath, $actValue, $additionalAtts)
    return $results                        
};

(:
(:~
 : Writes a validation result, for constraint components FileName*, FileSize*,
 : LastModified*.
 :
 : @param colour the colour of the result
 : @param constraintElem the element containing the attributes declaring the constraint
 : @param constraint the main attribute declaring the constraint 
 : @param actualValue the actual value of the file property
 : @param additionalAtts additional attributes to be included in the result
 : @return an element representing a 'red' or 'green' validation result
 :)
declare function f:constructError_fileProperties($filePath as xs:string,
                                                 $colour as xs:string,
                                                 $constraintElem as element(),
                                                 $constraint as attribute(),
                                                 $actualValue as item(),
                                                 $additionalAtts as attribute()*) 
        as element() {
    let $constraintComp :=
        $constraintElem/f:firstCharToUpperCase(local-name(.)) ||
        $constraint/f:firstCharToUpperCase(local-name(.))
        
    let $resourcePropertyName :=
        switch(local-name($constraintElem))
        case 'fileName' return 'File name'
        case 'fileSize' return 'File size'
        case 'lastModified' return 'Last modified time'
        default return error()
        
    let $compare :=
        switch(local-name($constraint))
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
        default return 'satisfy'
        
    let $elemName := 'gx:' || $colour    
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else 
            i:getErrorMsg($constraintElem, 
                          $constraint/local-name(.), 
                          concat($resourcePropertyName, ' should ', $compare,
                          " '", $constraint, "'"))
    let $values := result:validationResultValues($actualValue, $constraintElem)
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintId := $constraintElem/@id || '-' || $constraint/local-name(.)
    return
    
        element {$elemName} {
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},   
            $filePath ! attribute filePath {.},
            $constraint,
            $additionalAtts,
            $values
        }                                          
};
:)