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
    "fileValidator.xqm",
    "foxpathEvaluator.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFolder($gxFolder as element(gx:folder), $context as map(*)) 
        as element()* {
    let $contextPath := $context?_contextPath
    let $folderPaths :=
        let $path := $gxFolder/@path
        let $foxpath := $gxFolder/@foxpath
        return
            if ($path) then concat($contextPath, '/', $gxFolder/@path)
            else i:evaluateFoxpath($foxpath, $contextPath)
    for $folderPath in $folderPaths
    return
        f:validateFolderInstance($folderPath, $gxFolder, $context)
};

declare function f:validateFolderInstance($folderPath as xs:string, $gxFolder as element(gx:folder), $context as map(*)) 
        as element()* {
    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $folderPath)
    
    (: determine member files and folders :)
    let $members := file:list($folderPath, true(), '*')
    let $memberFiles := $members[file:is-file(concat($folderPath, '/', .))]
    let $memberFolders := $members[file:is-dir(.)]

    (: perform validations :)
    let $errors := (
        (: validate - resource set :)
        if ($gxFolder/@mandatory eq 'true') then
            if (not(file:exists($folderPath))) then
                <gx:error class="folder" code="folder-not-found" folderPath="{$folderPath}"/>
            else if (not(file:is-dir($folderPath))) then
                <gx:error class="folder" code="not-a-folder" folderPath="{$folderPath}"/>
            else (),
            
        (: validate - container members :)
        for $child in $gxFolder/*
        return
            typeswitch($child)
            case $file as element(gx:file) return i:validateFile($file, $context)
            case $folder as element(gx:folder) return i:validateFolder($folder, $context)
            case $folderContent as element(gx:folderContent) return f:validateFolderContent($folderPath, $folderContent, $context)
            default return error()
    )
    return
        <gx:folderErrors count="{count($errors)}" folderPath="{$folderPath}">{$errors}</gx:folderErrors>
        [$errors]
};

declare function f:validateFolderContent($folderPath as xs:string, $folderContent as element(gx:folderContent), $context as map(*)) 
        as element()* {
    (: determine expectations :)
    let $expectedFiles := $folderContent/@files/tokenize(.) 
    let $includes := $folderContent/@includes/tokenize(.)
    let $msgFolderContent := $folderContent/@msg
    
    (: determine member files and folders :)
    let $members := file:list($folderPath, true(), '*')
    let $memberFiles := $members[file:is-file(concat($folderPath, '/', .))]
    let $memberFolders := $members[file:is-dir(.)]

    (: perform validations :)
    let $errors := (
        if (empty($expectedFiles)) then () else
            (: validate - expected files (@includes=all) :)
            if (not($includes = 'all')) then () 
            else            
                let $missingFiles := $expectedFiles[not(. = $memberFiles)]
                return
                    <gx:error class="folder" code="missing-files" folderPath="{$folderPath}" filePaths="{$missingFiles}" msg="{$msgFolderContent}"/>
                    [exists($missingFiles)]
            ,
            (: validate - expected files (@includes=no-other) :)
            if (not($includes = 'no-other')) then ()
            else
                let $unexpectedFiles := $memberFiles[not(. = $expectedFiles)]
                return
                    <gx:error class="folder" code="unexpected-files" folderPath="{$folderPath}" filePaths="{$unexpectedFiles}"/>
                    [exists($unexpectedFiles)]
    )
    return
        <gx:folderErrors count="{count($errors)}" folderPath="{$folderPath}">{$errors}</gx:folderErrors>
        [$errors]
};




