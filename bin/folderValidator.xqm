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
    "expressionEvaluator.xqm",
    "expressionValueConstraint.xqm",
    "fileValidator.xqm",
    "folderContentValidator.xqm",
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
                                attribute contextPath {$contextPath},
                                attribute navigationPath {$navigationPath}
                                ), 'first')    
            return
                if ($errors) then $errors
                else
                    <gx:green>{
                        attribute constraintComponent {$constraint/local-name()},                    
                        attribute contextPath {$contextPath},
                        attribute navigationPath {$navigationPath},
                        $constraint/@id/attribute constraintID {.},
                        $constraint/@label/attribute constraintLabel {.}
                    }</gx:green>

    let $instancePerceptions := $targetPaths ! f:validateFolderInstance(., $gxFolder, $context)
        
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
                                          attribute contextPath {$contextPath},
                                          attribute navigationPath {$subsetNavigationPath}
                                      ), 'first')
                return    
                    if ($errors) then $errors
                    else
                        <gx:green>{
                            attribute constraintComponent {$constraint/local-name()},                        
                            attribute contextPath {$contextPath},
                            attribute navigationPath {$navigationPath},
                            attribute folderSubsetNavigationPath {$subsetNavigationPath},
                            $constraint/@id/attribute constraintID {.},
                            $constraint/@label/attribute constraintLabel {.}
                        }</gx:green>
        
        let $instancePerceptions := $subsetTargetPaths ! f:validateFolderInstance(., $gxFolderSubset, $context)
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
    
    (: collect perceptions :)
    let $perceptions := (
        (: validate - member resources :)
        let $resourceShapePerceptions := (
            $components/self::gx:file/i:validateFile(., $context),
            $components/self::gx:folder/i:validateFolder(., $context)
        )
        (: validate - value shapes :)
        let $valueShapePerceptions :=
            for $child in $components[not((self::gx:targetSize, self::gx:folderSubset, self::gx:file, self::gx:folder))]
            let $error :=
                typeswitch($child)
                case $foxpath as element(gx:foxpath) return i:validateExpressionValue($foxpath, $folderPath, $exprContext)
                case $folderContent as element(gx:folderContent) return f:validateFolderContent($folderPath, $folderContent, $context)
                case $lastModified as element(gx:lastModified) return i:validateLastModified($folderPath, $lastModified, $context)
                case $folderName as element(gx:folderName) return i:validateFileName($folderPath, $folderName, $context)    
                default return error(QName((), 'UNEXPECTED_VALUE_SHAPE'), concat('Unexpected value shape, name: ', name($child)))
            return
                if ($error) then $error/i:augmentErrorElement(., (attribute folderPath {$folderPath}), 'first')
                else
                    <gx:green>{
                        attribute constraintComponent {$child/local-name()},                    
                        attribute folderPath {$folderPath},
                        $child/@id/attribute constraintID {.},
                        $child/@label/attribute constraintLabel {.}
                    }</gx:green>
        return ($resourceShapePerceptions, $valueShapePerceptions)                    
    )
    return
        $perceptions
};

(:
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
:)



