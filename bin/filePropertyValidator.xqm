(:
 : -------------------------------------------------------------------------
 :
 : lastModifiedValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateLastModified($filePath as xs:string, $lastModified as element(gx:lastModified), $context)
        as element()* {
    let $constraintId := $lastModified/@id
    let $constraintLabel := $lastModified/@label
    
    let $lt := $lastModified/@lt
    let $gt := $lastModified/@gt
    let $le := $lastModified/@le
    let $ge := $lastModified/@ge
    let $eq := $lastModified/@eq
    
    let $actValue := file:last-modified($filePath) ! string(.)
    
    let $errors := (
        (: count errors
           ============ :)
        if (empty($lt) or $actValue lt $lt) then () else
            f:constructError_lastModified($constraintId, $constraintLabel, $lt, $actValue, ())
        ,
        if (empty($gt) or $actValue gt $gt) then () else
            f:constructError_lastModified($constraintId, $constraintLabel, $gt, $actValue, ())
        ,
        if (empty($le) or $actValue le $le) then () else
            f:constructError_lastModified($constraintId, $constraintLabel, $le, $actValue, ())
        ,
        if (empty($ge) or $actValue ge $ge) then () else
            f:constructError_lastModified($constraintId, $constraintLabel, $ge, $actValue, ())
        ,
        if (empty($eq) or $actValue eq $eq) then () else
            f:constructError_lastModified($constraintId, $constraintLabel, $eq, $actValue, ())
        ,
        ()
    )
    return
        <gx:lastModifiedErrors count="{count($errors)}">{$errors}</gx:lastModifiedErrors>
        [$errors]
        
};

declare function f:constructError_lastModified($constraintId as attribute()?,
                                               $constraintLabel as attribute()?,
                                               $constraint as attribute(),
                                               $actualValue as xs:string,
                                               $additionalAtts as attribute()*) 
        as element(gx:error) {
    let $code := 'last-modified-not-' || local-name($constraint)
    let $msg := concat('Last-modified time not ', local-name($constraint), ' check value = ', $constraint)
    return
    
        <gx:error class="lastModified" code="{$code}">{
            $constraintId,
            $constraintLabel,
            $constraint,
            attribute actValue {$actualValue},
            attribute message {$msg},
            $additionalAtts        
        }</gx:error>                                                  
};
