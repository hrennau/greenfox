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
    let $targetCountPerceptions := 
        let $constraint := $components/self::gx:targetSize
        return
            if (not($constraint)) then () else
            let $errors :=    
                $components/self::gx:targetSize                
                                /i:validateTargetCount(., $targetCount)
                                /i:augmentErrorElement(., (
                                attribute contextFilePath {$contextPath},
                                attribute navigationPath {$navigationPath}
                                ), 'first')    
            return
                if ($errors) then $errors
                else
                    <gx:green>{
                        attribute contextPath {$contextPath},
                        attribute navigationPath {$navigationPath},
                        attribute constraintComponent {$constraint/local-name()},
                        $constraint/@id/attribute constraintID {.},
                        $constraint/@label/attribute constraintLabel {.}
                    }</gx:green>

    let $instancePerceptions :=
        for $targetPath in $targetPaths
        return f:validateFolderInstance($targetPath, $gxFolder, $context)
        
    let $subsetPerceptions :=
        for $gxFolderSubset in $components/self::gx:folderSubset
        let $subsetComponents := $gxFolderSubset/*[not(@deactivated eq 'true')]
        let $subsetLabel := $gxFolderSubset/@subsetLabel
        let $foxpath := $gxFolderSubset/@foxpath
        let $subsetNavigationPath := $foxpath
        
        let $subsetTargetPaths := (
            for $targetPath in $targetPaths
            return i:evaluateFoxpath($foxpath, $targetPath) 
        )[. = $targetPaths] => distinct-values()
        let $subsetTargetCount := count($subsetTargetPaths)        
        let $targetCountPerceptions := 
            let $constraint := $subsetComponents/self::gx:targetSize   
            return
                if (not($constraint)) then () else
                let $errors :=
                    $subsetComponents/self::gx:targetSize/i:validateTargetCount(., $subsetTargetCount)
                                      /i:augmentErrorElement(., (
                                          attribute contextFilePath {$contextPath},
                                          attribute navigationPath {$subsetNavigationPath}
                                      ), 'first')
                return    
                    if ($errors) then $errors
                    else
                        <gx:green>{
                            attribute contextPath {$contextPath},
                            attribute folderSubsetNavigationPath {$subsetNavigationPath},
                            attribute constraintComponent {$constraint/local-name()},
                            $constraint/@id/attribute constraintID {.},
                            $constraint/@label/attribute constraintLabel {.}
                        }</gx:green>
        
        let $instancePerceptions :=
            for $subsetTargetPath in $subsetTargetPaths
            return f:validateFolderInstance($subsetTargetPath, $gxFolderSubset, $context)
        return ($targetCountPerceptions, $instancePerceptions)
    let $perceptions := ($targetCountPerceptions, $instancePerceptions, $subsetPerceptions)
    return
        $perceptions
};

declare function f:validateFolderInstance($folderPath as xs:string, $gxFolder as element(), $context as map(*)) 
        as element()* {
    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $folderPath)
    let $components := $gxFolder/*[not(@deactivated eq 'true')]
    
    let $exprContext := map{}
    
    (: perform validations :)
    let $perceptions := (
        (: validate - container members :)
        for $child in $components
        let $childIsShape := $child/(self::gx:file, self::gx:folder)
        let $error :=
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
        return
            if ($error) then $error/i:augmentErrorElement(., (attribute folderPath {$folderPath}), 'first')
            else if ($childIsShape) then ()
            else
                <gx:green>{
                    attribute folderPath {$folderPath},
                    attribute constraintComponent {$child/local-name()},
                    $child/@id/attribute constraintID {.},
                    $child/@label/attribute constraintLabel {.}
                }</gx:green>
    )
    return
        $perceptions
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
    return 
        $errors
};




