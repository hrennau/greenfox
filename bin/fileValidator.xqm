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
    "xpathValidator.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFile($gxFile as element(gx:file), $context as map(*)) 
        as element()* {
    let $contextPath := $context?_contextPath
    let $filePaths :=
        let $path := $gxFile/@path
        let $foxpath := $gxFile/@foxpath
        return
            if ($path) then concat($contextPath, '/', $gxFile/@path)
            else f:evaluateFoxpath($foxpath, $contextPath)
    for $filePath in $filePaths
    return
        f:validateFileInstance($filePath, $gxFile, $context)
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
        return
            typeswitch($child)
            case $xpath as element(gx:xpath) return i:validateXPath($doc, $xpath, $context)
            default return error()
    )
    return
        <gx:fileErrors count="{count($errors)}" filePath="{$filePath}">{$errors}</gx:fileErrors>
        [$errors]
};
