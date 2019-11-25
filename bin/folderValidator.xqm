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
    "foxpathEvaluator.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a folder or a folder subset. Input element $gxFolder may be
 : a folder or a folder subset.
 :
 : @param gxFolder a folder shape or a folder subset shape
 : @param context the validation context
 : @return errors found
 :)
declare function f:validateFolder($gxFolder as element(), $context as map(*)) 
        as element()* {
    let $contextPath := $context?_contextPath
    let $folderPaths :=
        let $path := $gxFolder/@path
        let $foxpath := $gxFolder/@foxpath
        return
            if ($path) then concat($contextPath, '/', $gxFolder/@path)[file:exists(.)]
            else i:evaluateFoxpath($foxpath, $contextPath)
    let $instanceCount := count($folderPaths)   
    let $countErrors := i:validateInstanceCount($gxFolder, $instanceCount)
    let $instanceErrors :=
        for $folderPath in $folderPaths
        return f:validateFolderInstance($folderPath, $gxFolder, $context)
    let $subsetErrors :=
        for $gxFolderSubset in $gxFolder/gx:folderSubset
        let $subsetLabel := $gxFolderSubset/@subsetLabel
        let $foxpath := $gxFolderSubset/@foxpath
        let $subsetPaths := (
            for $folderPath in $folderPaths
            return i:evaluateFoxpath($foxpath, $folderPath) 
        )[. = $folderPaths]
        let $subsetInstanceCount := count($subsetPaths)
        let $countErrors := i:validateInstanceCount($gxFolderSubset, $subsetInstanceCount)
        let $instanceErrors :=
            for $subsetPath in $subsetPaths
            return f:validateFolderInstance($subsetPath, $gxFolderSubset, $context)
        return ($countErrors, $instanceErrors)
    let $errors := ($countErrors, $instanceErrors, $subsetErrors)
    return
        <gx:folderSetErrors>{
            $gxFolder/@id/attribute folderID {.},
            $gxFolder/@label/attribute folderLabel {.},
            attribute count {count($errors)},
            $errors
        }</gx:folderSetErrors>[$errors]
};

declare function f:validateFolderInstance($folderPath as xs:string, $gxFolder as element(), $context as map(*)) 
        as element()* {
    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $folderPath)
    
    (: determine member files and folders :)
    let $members := file:list($folderPath, true(), '*')
    let $memberFiles := $members[file:is-file(concat($folderPath, '/', .))]
    let $memberFolders := $members[file:is-dir(.)]

    (: perform validations :)
    let $errors := (
        (: validate - container members :)
        for $child in $gxFolder/*
        return
            typeswitch($child)
            case $file as element(gx:file) return i:validateFile($file, $context)
            case $folder as element(gx:folder) return i:validateFolder($folder, $context)
            case $folderContent as element(gx:folderContent) return f:validateFolderContent($folderPath, $folderContent, $context)
            case element(gx:folderSubset) return ()
            default return error()
    )
    return
        <gx:folderErrors>{
            $gxFolder/@id/attribute folderID {.},
            $gxFolder/@label/attribute folderLabel {.},
            attribute count {count($errors)},
            attribute folderPath {$folderPath},
            $errors
        }</gx:folderErrors>
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
                    <gx:error class="folder">{
                        $folderContent/@id/attribute folderContentID {.},
                        $folderContent/@label/attribute folderContentLabel {.},
                        attribute code {"missing-files"},
                        attribute folderPath {$folderPath},
                        attribute filePaths {$missingFiles},
                        attribute msg {$msgFolderContent}
                    }</gx:error>
                    [exists($missingFiles)]
            ,
            (: validate - expected files (@includes=no-other) :)
            if (not($includes = 'no-other')) then ()
            else
                let $unexpectedFiles := $memberFiles[not(. = $expectedFiles)]
                return
                    <gx:error class="folder">{
                        $folderContent/@id/attribute folderContentID {.},
                        $folderContent/@label/attribute folderContentLabel {.},
                        attribute code {"unexpected-files"},
                        attribute folderPath {$folderPath},
                        attribute filePaths {$unexpectedFiles}
                    }</gx:error>
                    [exists($unexpectedFiles)]    )
    return $errors
};




