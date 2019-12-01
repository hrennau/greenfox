(:
 : -------------------------------------------------------------------------
 :
 : folderValidator.xqm - Document me!
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
    let $components := $gxFolder/*[not(@deactivated eq 'true')]
    let $navigationPath := $gxFolder/(@foxpath, @path)[1]
    let $targetPaths :=
        let $path := $gxFolder/@path
        let $foxpath := $gxFolder/@foxpath
        return
            if ($path) then concat($contextPath, '\', $gxFolder/@path)[file:exists(.)][file:is-dir(.)]
            else 
                let $value := i:evaluateFoxpath($foxpath, $contextPath)[file:is-dir(.)]
                return
                    if ($value instance of element(errors)) then error()
                    else $value
                    
    (: check: targetSize :)                    
    let $targetCount := count($targetPaths)   
    let $targetCountErrors := $components/self::gx:targetSize/i:validateTargetCount(., $targetCount)
                              /i:augmentErrorElement(., (
                                  attribute contextFilePath {$contextPath},
                                  attribute navigationPath {$navigationPath}
                              ), 'first')
    
    
    let $instanceErrors :=
        for $targetPath in $targetPaths
        return f:validateFolderInstance($targetPath, $gxFolder, $context)
    let $subsetErrors :=
        for $gxFolderSubset in $components/self::gx:folderSubset
        let $subsetLabel := $gxFolderSubset/@subsetLabel
        let $foxpath := $gxFolderSubset/@foxpath
        let $subsetTargetPaths := (
            for $targetPath in $targetPaths
            return i:evaluateFoxpath($foxpath, $targetPath) 
        )[. = $targetPaths] => distinct-values()
        let $subsetTargetCount := count($subsetTargetPaths)
        let $targetCountErrors := i:validateTargetCount($gxFolderSubset, $subsetTargetCount)
        let $instanceErrors :=
            for $subsetTargetPath in $subsetTargetPaths
            return f:validateFolderInstance($subsetTargetPath, $gxFolderSubset, $context)
        return ($targetCountErrors, $instanceErrors)
    let $errors := ($targetCountErrors, $instanceErrors, $subsetErrors)
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
    let $components := $gxFolder/*[not(@deactivated eq 'true')]
    
    let $exprContext := map{}
    
    (: perform validations :)
    let $errors := (
        (: validate - container members :)
        for $child in $components
        return
            typeswitch($child)
            case $foxpath as element(gx:foxpath) return i:validateExpressionValue($foxpath, $folderPath, $exprContext)
            case $file as element(gx:file) return i:validateFile($file, $context)
            case $folder as element(gx:folder) return i:validateFolder($folder, $context)
            case $folderContent as element(gx:folderContent) return f:validateFolderContent($folderPath, $folderContent, $context)
            case $lastModified as element(gx:lastModified) return i:validateLastModified($folderPath, $lastModified, $context)
            case $folderName as element(gx:folderName) return i:validateFileName($folderPath, $folderName, $context)            
            case element(gx:folderSubset) return ()
            case element(gx:targetSize) return ()
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
    let $closed := ($folderContent/@closed, 'false')[1]
    let $quant := ($folderContent/@quant, 'all')[1]
    let $msgFolderContent := $folderContent/@msg
    
    (: determine member files and folders :)
    let $members := file:list($folderPath, true(), '*')
    let $memberFiles := $members[file:is-file(concat($folderPath, '/', .))]
    let $memberFolders := $members[file:is-dir(.)]

    (: perform validations :)
    let $errors := (
        if (empty($expectedFiles)) then () else
            (: validate - missing files? :)
            if ($quant = 'all')
            then 
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
            else if (exists($expectedFiles[. = $memberFiles])) then ()
            else
                <gx:error class="folder">{
                    $folderContent/@id/attribute folderContentID {.},
                    $folderContent/@label/attribute folderContentLabel {.},
                    attribute code {"missing-some-of-expected-files"},
                    attribute folderPath {$folderPath},
                    attribute filePaths {$expectedFiles},
                    attribute msg {$msgFolderContent}
                }</gx:error>
            ,
            (: validate - expected files? :)
            if (not($closed = 'true')) then ()
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




