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
    
    let $min := $lastModified/@min/attribute minValue {.}
    let $max := $lastModified/@max/attribute maxValue {.}
    
    let $actValue := file:last-modified($filePath) ! string(.)
    
    let $errors := (
        (: count errors
           ============ :)
        if (empty($min) or $actValue ge $min) then () else
            f:constructError_lastModified($constraintId, $constraintLabel, $min, $actValue, ())
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
    let $code :=
        if ($constraint/local-name(.) eq 'minValue') then 'last-modified-too-early'
        else if ($constraint/local-name(.) eq 'maxValue') then 'last-modified-too-late'
        else error()
    let $msg :=
        if ($constraint/local-name(.) eq 'minValue') then 'Last-modified time before expected minimum value.'
        else if ($constraint/local-name(.) eq 'maxValue') then 'Last-modified time after expected maximum value.'
        else error()
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
