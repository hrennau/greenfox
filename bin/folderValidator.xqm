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
declare function f:validateFolderInstance($contextURI as xs:string, 
                                          $folderShape as element(), 
                                          $context as map(*)) 
        as element()* {
    (: update context :)
    let $context := map:put($context, '_contextPath', $contextURI)
    let $context := i:adaptContext($contextURI, $folderShape, $context)
        
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
            for $constraintElem in $constraints[not(self::gx:targetSize)] return
            typeswitch($constraintElem)
            case element(gx:lastModified) return i:validateLastModified($constraintElem, $context)
            case element(gx:folderName) return i:validateFileName($constraintElem, $context)
            case element(gx:foxvalues) return value:validateValueConstraint($contextURI, (), (), $constraintElem, $context)
            case element(gx:foxvaluePairs) return vpair:validateValuePairConstraint($contextURI, (), (), $constraintElem, $context)
            case element(gx:foxvaluesCompared) return vpair:validateValuePairConstraint($contextURI, (), (), $constraintElem, $context)
            case element(gx:folderContent) return f:validateFolderContent($contextURI, $constraintElem, $context)
            case element(gx:folderSimilar) return f:validateFolderSimilar($contextURI, $constraintElem, $context)
            case element(gx:foxpath) return i:validateExpressionValue($contextURI, $constraintElem, $contextURI, (), $context)                
            default return error(QName((), 'UNEXPECTED_VALUE_SHAPE'), concat('Unexpected value shape, name: ', name($constraintElem)))
        return ($resourceShapeResults, $valueShapeResults)                    
    )
    return
        $results
};
