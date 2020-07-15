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
    "folderSimilarConstraint.xqm",
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
    let $targetPathsAndTargetValidationResults := f:getTargetPaths($gxFolder, $context)
    let $targetPaths := $targetPathsAndTargetValidationResults[. instance of xs:anyAtomicType]
    let $targetValidationResults := $targetPathsAndTargetValidationResults[. instance of element()]
    
    (: Check instances :)                            
    let $instanceResults := $targetPaths ! f:validateFolderInstance(., $gxFolder, $context)
    let $results := ($targetValidationResults, $instanceResults)
    return
        $results 
};

(:~
 : Validates a folder instance against a folder shape.
 :
 : @param folderPath the file system path of the folder
 : @param gxFolder a folder shape
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFolderInstance($folderPath as xs:string, 
                                          $folderShape as element(), 
                                          $context as map(*)) 
        as element()* {
    (: update context :)
    let $context := map:put($context, '_contextPath', $folderPath)
    let $context := i:adaptContext($folderPath, $folderShape, $context)
        
    let $childComponents := $folderShape/*[not(@deactivated eq 'true')]
    
    let $files := $childComponents/self::gx:file
    let $folders := $childComponents/self::gx:folder
    let $focusNodes := $childComponents/self::gx:focusNode
    
    let $constraints := $childComponents except ($files, $folders, $focusNodes)
    let $extensionConstraints := f:getExtensionConstraints($constraints)
    let $coreConstraints := $constraints except $extensionConstraints
    
    (: collect results :)
    let $results := (
    
        (: validate - member resources :)
        let $resourceShapeResults := (
            $files/i:validateFile(., $context),
            $folders/i:validateFolder(., $context)
        )
        
        (: validate - constraints and value shapes :)
        let $valueShapeResults :=
            for $constraint in $constraints[not(self::gx:targetSize)]
            let $error :=
                typeswitch($constraint)
                case $folderContent as element(gx:folderContent) return f:validateFolderContent($folderPath, $folderContent, $context)
                case $folderSimilar as element(gx:folderSimilar) return f:validateFolderSimilar($folderPath, $folderSimilar, $context)
                case $lastModified as element(gx:lastModified) return i:validateLastModified($folderPath, $lastModified, $context)
                case $folderName as element(gx:folderName) return i:validateFileName($folderPath, $folderName, $context)
                case $foxpath as element(gx:foxpath) return i:validateExpressionValue($folderPath, $foxpath, $folderPath, (), $context)                
                default return error(QName((), 'UNEXPECTED_VALUE_SHAPE'), concat('Unexpected value shape, name: ', name($constraint)))
            return
                if ($error) then $error/i:augmentErrorElement(., (attribute folderPath {$folderPath}), 'first')
                else (
                    error(QName((), 'SYSTEM_ERROR'), 'Unexpected event: validation without result'),
                    <gx:green>{
                        attribute constraintComp {$constraint/local-name()},                    
                        $constraint/@id/attribute constraintID {.},
                        $constraint/@label/attribute constraintLabel {.},
                        attribute folderPath {$folderPath}
                    }</gx:green>
                )
        return ($resourceShapeResults, $valueShapeResults)                    
    )
    return
        $results
};
