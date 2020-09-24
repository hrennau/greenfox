(:
 : -------------------------------------------------------------------------
 :
 : folderValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at  "tt/_request.xqm",
    "tt/_foxpath.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at  "expressionEvaluator.xqm",
    "expressionValueConstraint.xqm",
    "fileValidator.xqm",
    "folderContentValidator.xqm",
    "folderSimilarConstraint.xqm",
    "greenfoxTarget.xqm",
    "greenfoxUtil.xqm";
    
import module namespace value="http://www.greenfox.org/ns/xquery-functions/value" 
at "valueConstraint.xqm";    
    
import module namespace vpair="http://www.greenfox.org/ns/xquery-functions/value-pair" 
at "valuePairConstraint.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a folder or a folder subset. Input element $gxFolder may be
 : a folder or a folder subset.
 :
 : @param gxFolder a folder shape or a folder subset shape
 : @param context the validation context
 : @return errors found
 :)
declare function f:validateFolder($shapeElem as element(), 
                                  $context as map(xs:string, item()*)) 
        as element()* {
    let $targetPathsAndTargetValidationResults := f:getTargetPaths($shapeElem, $context)
    let $targetPaths := $targetPathsAndTargetValidationResults[. instance of xs:anyAtomicType]
    let $targetValidationResults := $targetPathsAndTargetValidationResults[. instance of element()]
    
    (: Check instances :)     
    let $instanceResults := 
        for $targetPath at $pos in $targetPaths
        return f:validateFolderInstance($targetPath, $shapeElem, $pos, $context)
    let $results := ($targetValidationResults, $instanceResults)
    return
        $results 
};

(:~
 : Validates a folder resource against a folder shape. The context is still 
 : refering to the previous resource. The context is adapted, and validation
 : of the folder resource against the folder shape is launched.
 :
 : @param contextURI the file path
 : @param shapeElem the file shape
 : @param position position of the file resource in the sequence of file resources
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFolderInstance($contextURI as xs:string, 
                                          $shapeElem as element(gx:folder),
                                          $position as xs:integer?,
                                          $context as map(*)) 
        as element()* {
    (: Update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $contextURI)
    let $context := i:adaptContext($contextURI, $shapeElem, $context)
    let $results := f:validateFolderConstraints($shapeElem, $context)
    return $results
};

(:~
 : Validates a folder instance against a folder shape.
 :
 : @param folderPath the file system path of the folder
 : @param gxFolder a folder shape
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFolderConstraints($folderConstraints as element(), 
                                             $context as map(*)) 
        as element()* {
    (: update context :)
    let $childComponents := $folderConstraints/*[not(@deactivated eq 'true')]
    
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
            for $constraintElem in $constraints[not(self::gx:targetSize)] return
            typeswitch($constraintElem)
            case element(gx:fileDate) return i:validateFileDate($constraintElem, $context)
            case element(gx:fileName) return i:validateFileName($constraintElem, $context)
            case element(gx:foxvalue) return value:validateValueConstraint($constraintElem, $context)
            case element(gx:foxvalues) return value:validateValueConstraint($constraintElem, $context)
            case element(gx:foxvaluePairs) return vpair:validateValuePairConstraint($constraintElem, $context)
            case element(gx:foxvaluesCompared) return vpair:validateValuePairConstraint($constraintElem, $context)
            case element(gx:folderContent) return f:validateFolderContent($constraintElem, $context)
            case element(gx:folderSimilar) return f:validateFolderSimilar($constraintElem, $context)
            case element(gx:conditional) return i:validateConditionalConstraint($constraintElem, f:validateFolderConstraints#2, $context)
            case element(gx:foxpath) return i:validateExpressionValue($constraintElem, $context)            
            default return error(QName((), 'UNEXPECTED_VALUE_SHAPE'), concat('Unexpected value shape, name: ', name($constraintElem)))
        return ($resourceShapeResults, $valueShapeResults)                    
    )
    return
        $results
};
