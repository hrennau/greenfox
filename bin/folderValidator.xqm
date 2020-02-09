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
    "greenfoxTarget.xqm",
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
declare function f:validateFolder($gxFolder as element(), $context as map(xs:string, item()*)) 
        as element()* {
    let $contextPath := $context?_contextPath
    let $components := $gxFolder/*[not(@deactivated eq 'true')]
    let $targetDecl := $gxFolder/(@foxpath, @path)[1]
    let $targetPaths := f:getTargetPaths($gxFolder, $context)
    
    (: check: targetSize :)                    
    let $targetCount := count($targetPaths)
    let $contextPathLabel := replace($contextPath, '\\', '/')
    (:
        if ($targetCount eq 1) then $targetPaths
        else replace($contextPath, '\\', '/')
     :)        
    let $targetCountResults := 
        let $constraint := $components/self::gx:targetSize
        return
            if (not($constraint)) then ()
            else    
                $components/self::gx:targetSize                
                                /i:validateTargetCount(., $targetPaths, $contextPathLabel, $targetDecl)
    let $instanceResults := $targetPaths ! f:validateFolderInstance(., $gxFolder, $context)
        
    let $subsetResults :=
        for $gxFolderSubset in $components/self::gx:folderSubset
        let $subsetComponents := $gxFolderSubset/*[not(@deactivated eq 'true')]
        let $subsetLabel := $gxFolderSubset/@subsetLabel
        let $foxpath := $gxFolderSubset/@foxpath
        let $subsetTargetDecl := $foxpath
        
        let $subsetTargetPaths := (
            for $targetPath in $targetPaths
            return i:evaluateFoxpath($foxpath, $targetPath) 
        )[. = $targetPaths] => distinct-values()
        let $subsetTargetCount := count($subsetTargetPaths)        
        let $targetCountResults := 
            let $constraint := $subsetComponents/self::gx:targetSize   
            return
                if (not($constraint)) then ()
                else
                    $subsetComponents/self::gx:targetSize/i:validateTargetCount(., $subsetTargetCount, $contextPath, $subsetTargetDecl)
        let $instanceResults := $subsetTargetPaths ! f:validateFolderInstance(., $gxFolderSubset, $context)
        return ($targetCountResults, $instanceResults)
    let $results := ($targetCountResults, $instanceResults, $subsetResults)
    return
        $results 
};

(:~
 : Validates a folder instance against the folder shape.
 :)
declare function f:validateFolderInstance($folderPath as xs:string, 
                                          $gxFolder as element(), 
                                          $context as map(*)) 
        as element()* {
    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $folderPath)
    let $components := $gxFolder/*[not(@deactivated eq 'true')]
    
    (: collect results :)
    let $results := (
        (: validate - member resources :)
        let $resourceShapeResults := (
            $components/self::gx:file/i:validateFile(., $context),
            $components/self::gx:folder/i:validateFolder(., $context)
        )
        (: validate - value shapes :)
        let $valueShapeResults :=
            for $child in $components[not((self::gx:targetSize, self::gx:folderSubset, self::gx:file, self::gx:folder))]
            let $error :=
                typeswitch($child)
                case $folderContent as element(gx:folderContent) return f:validateFolderContent($folderPath, $folderContent, $context)
                case $lastModified as element(gx:lastModified) return i:validateLastModified($folderPath, $lastModified, $context)
                case $folderName as element(gx:folderName) return i:validateFileName($folderPath, $folderName, $context)
                case $foxpath as element(gx:foxpath) return i:validateExpressionValue($foxpath, $folderPath, $folderPath, (), $context)                
                default return error(QName((), 'UNEXPECTED_VALUE_SHAPE'), concat('Unexpected value shape, name: ', name($child)))
            return
                if ($error) then $error/i:augmentErrorElement(., (attribute folderPath {$folderPath}), 'first')
                else
                    <gx:green>{
                        attribute constraintComp {$child/local-name()},                    
                        $child/@id/attribute constraintID {.},
                        $child/@label/attribute constraintLabel {.},
                        attribute folderPath {$folderPath}
                    }</gx:green>
        return ($resourceShapeResults, $valueShapeResults)                    
    )
    return
        $results
};
