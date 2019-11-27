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

declare function f:validateFileSize($filePath as xs:string, $fileSize as element(gx:fileSize), $context)
        as element()* {
    let $constraintId := $fileSize/@id
    let $constraintLabel := $fileSize/@label
    
    let $lt := $fileSize/@lt
    let $gt := $fileSize/@gt
    let $le := $fileSize/@le
    let $ge := $fileSize/@ge
    let $eq := $fileSize/@eq
    
    let $actValue := file:size($filePath)
    
    let $errors := (
        (: count errors
           ============ :)
        if (empty($lt) or $actValue lt $lt/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $lt, $actValue, ())
        ,
        if (empty($gt) or $actValue gt $gt/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $gt, $actValue, ())
        ,
        if (empty($le) or $actValue le $le/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $le, $actValue, ())
        ,
        if (empty($ge) or $actValue ge $ge/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $ge, $actValue, ())
        ,
        if (empty($eq) or $actValue eq $eq/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $eq, $actValue, ())
        ,
        ()
    )
    return
        <gx:fileSizeErrors count="{count($errors)}">{$errors}</gx:fileSizeErrors>
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

declare function f:constructError_fileSize($constraintId as attribute()?,
                                           $constraintLabel as attribute()?,
                                           $constraint as attribute(),
                                           $actualValue as xs:integer,
                                           $additionalAtts as attribute()*) 
        as element(gx:error) {
    let $code := 'file-size-not-' || local-name($constraint)
    let $msg := concat('File size not ', local-name($constraint), ' check value = ', $constraint)
    return
    
        <gx:error class="fileSize" code="{$code}">{
            $constraintId,
            $constraintLabel,
            $constraint,
            attribute actValue {$actualValue},
            attribute message {$msg},
            $additionalAtts        
        }</gx:error>                                                  
};
