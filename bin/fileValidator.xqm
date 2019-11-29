(:
 : -------------------------------------------------------------------------
 :
 : domainValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_foxpath.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "expressionValueConstraint.xqm",
    "filePropertiesConstraint.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFile($gxFile as element(gx:file), $context as map(*)) 
        as element()* {
    let $contextPath := $context?_contextPath
    let $targetPaths :=
        let $path := $gxFile/@path
        let $foxpath := $gxFile/@foxpath
        return
            if ($path) then concat($contextPath, '\', $gxFile/@path)[file:exists(.)][file:is-file(.)]
            else trace( f:evaluateFoxpath($foxpath, $contextPath) , 'FOXPATH_VALUE: ')
    let $targetCount := count($targetPaths)   
    let $targetCountErrors := i:validateTargetCount($gxFile, $targetCount)
    let $instanceErrors :=        
        for $targetPath in $targetPaths
        return
            f:validateFileInstance($targetPath, $gxFile, $context)
            
    let $errors := ($targetCountErrors, $instanceErrors)
    return
        <gx:fileSetErrors>{
            $gxFile/@id/attribute fileID {.},
            $gxFile/@label/attribute fileLabel {.},
            attribute count {count($errors)},
            $errors
        }</gx:fileSetErrors>[$errors]
            
};

declare function f:validateFileInstance($filePath as xs:string, $gxFile as element(gx:file), $context as map(*)) 
        as element()* {
    (: let $_LOG := trace($filePath, 'FILE_PATH: ') :) 

    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $filePath)
    
    let $doc :=
        if ($gxFile/gx:xpath) then
            if (doc-available($filePath)) then doc($filePath)/* else ()
        else ()
    
    (: perform validations :)
    let $errors := (
        for $child in $gxFile/*
        let $raw :=
            typeswitch($child)
            case $xpath as element(gx:xpath) return i:validateExpressionValue($xpath, $doc, $context)
            case $lastModified as element(gx:lastModified) return i:validateLastModified($filePath, $lastModified, $context)
            case $fileSize as element(gx:fileSize) return i:validateFileSize($filePath, $fileSize, $context)
            case $fileName as element(gx:fileName) return i:validateFileName($filePath, $fileName, $context)
            default return error()
        return
            $raw//gx:error/i:augmentErrorElement(., attribute filePath {$filePath}, 'first')
    )
    return
        <gx:fileErrors>{
            $gxFile/@id/attribute fileID {.},
            $gxFile/@label/attribute fileLabel {.},
            attribute count {count($errors)},
            attribute filePath {$filePath},
            $errors
        }</gx:fileErrors>
        [$errors]
};
