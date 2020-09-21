(:
 : -------------------------------------------------------------------------
 :
 : fileValidator.xqm - validates file resources against a file shape
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at

    "docSimilarConstraint.xqm",
    "evaluationContextManager.xqm",
    "expressionValueConstraint.xqm",
    "extensionValidator.xqm",
    "focusNodeValidator.xqm",
    "greenfoxTarget.xqm",
    "linkConstraint.xqm",    
    "mediatypeConstraint.xqm",
    "resourcePropertiesConstraint.xqm",    
    "xsdValidator.xqm";

import module namespace dcont="http://www.greenfox.org/ns/xquery-functions/doc-content" 
at "docContentConstraint.xqm";

import module namespace concord="http://www.greenfox.org/ns/xquery-functions/concord" 
at "concordConstraint.xqm";

import module namespace expr="http://www.greenfox.org/ns/xquery-functions/value" 
at "valueConstraint.xqm";
    
import module namespace expair="http://www.greenfox.org/ns/xquery-functions/value-pair" 
at "valuePairConstraint.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates the target resources of a file shape against the file shape.
 : Steps: (a) determine and validate target resources, (b) validate each
 : target resource against the file shape.
 :
 : @param fileShape the file shape
 : @param context processing context
 : @return validation results
 :)
declare function f:validateFile($fileShape as element(gx:file), $context as map(*)) 
        as element()* {
    let $_DEBUG := f:DEBUG_CONTEXT($fileShape/@id, $context)  
    
    (: Determine target and evaluate target constraints :)
    let $targetPathsAndTargetValidationResults := f:getTargetPaths($fileShape, $context)
    let $targetPaths := $targetPathsAndTargetValidationResults[. instance of xs:anyAtomicType]
    let $targetValidationResults := $targetPathsAndTargetValidationResults[. instance of element()]
    
    (: Check instances :)
    let $instanceResults := 
        for $targetPath at $pos in $targetPaths
        return f:validateFileInstance($targetPath, $fileShape, $pos, $context)
    
    (: Merge results :)        
    let $results := ($targetValidationResults, $instanceResults)
    return
        $results
};

(:~
 : Validates a file resource against a file shape.
 :
 : @param contextURI the file path
 : @param fileShape the file shape
 : @param position position of the file resource in the sequence of file resources
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFileInstance($contextURI as xs:string, 
                                        $fileShape as element(gx:file),
                                        $position as xs:integer?,
                                        $context as map(*)) 
        as element()* {
    (: Update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $contextURI)
    let $context := i:adaptContext($contextURI, $fileShape, $context)
    let $_DEBUG := f:DEBUG_CONTEXT($fileShape/@id || '_DOCNR_' || $position, $context)
    let $contextDoc := $context?_reqDocs?doc
    let $results := f:validateFileInstanceComponents($contextURI, $contextDoc, $contextDoc, $fileShape, $context)
    return $results
};

declare function f:validateFileInstanceComponents($contextURI as xs:string,
                                                  $contextDoc as document-node()?,
                                                  $contextNode as node()?,                                                  
                                                  $fileShape as element(),                                                                                                    
                                                  $context as map(*))
        as element()* {
    let $contextItem := ($contextNode, $contextURI)[1]
    
    let $childComponents := $fileShape/*[not(@deactivated eq 'true')]
    
    let $files := $childComponents/self::gx:file
    let $folders := $childComponents/self::gx:folder
    let $focusNodes := $childComponents/self::gx:focusNode
    
    let $constraints := $childComponents except ($files, $folders, $focusNodes)
    let $extensionConstraints := f:getExtensionConstraints($constraints)
    let $coreConstraints := $constraints except $extensionConstraints

    let $resourceShapeResults := (
        $files/i:validateFile(., $context),
        $folders/i:validateFolder(., $context)
    )
    let $focusNodeResults := $focusNodes/i:validateFocusNode($contextURI, ., $contextItem, $contextDoc, $context)
    let $coreConstraintResults := 
        for $constraintElem in $coreConstraints return
        
        typeswitch($constraintElem)
        case element(gx:targetSize) return () (: Already processed ... :)            
        case element(gx:fileDate) return i:validateFileDate($constraintElem, $context)                
        case element(gx:fileSize) return i:validateFileSize($constraintElem, $context)
        case element(gx:fileName) return i:validateFileName($constraintElem, $context)            
        case element(gx:mediatype) return i:validateMediatype($constraintElem, $context)     
        case element(gx:docContent) return dcont:validateDocContentConstraint($contextURI, $contextDoc, $contextNode, $constraintElem, $context)            
        case element(gx:values) return expr:validateValueConstraint($contextURI, $contextDoc, $contextNode, $constraintElem, $context)            
        case element(gx:foxvalues) return expr:validateValueConstraint($contextURI, $contextDoc, $contextNode, $constraintElem, $context)            
        case element(gx:valuePairs) return expair:validateValuePairConstraint($contextURI, $contextDoc, $contextNode, $constraintElem, $context)            
        case element(gx:foxvaluePairs) return expair:validateValuePairConstraint($contextURI, $contextDoc, $contextNode, $constraintElem, $context)            
        case element(gx:valuesCompared) return expair:validateValuePairConstraint($contextURI, $contextDoc, $contextNode, $constraintElem, $context)            
        case element(gx:foxvaluesCompared) return expair:validateValuePairConstraint($contextURI, $contextDoc, $contextNode, $constraintElem, $context)            
        case element(gx:links) return i:validateLinks($contextURI, $contextDoc, $contextItem, $constraintElem, $context)            
        case element(gx:docSimilar) return i:validateDocSimilar($contextURI, $contextDoc, $contextItem, $constraintElem, $context)
        case element(gx:xsdValid) return i:xsdValidate($contextURI, $constraintElem, $context)
        
        case element(gx:ifMediatype) return $constraintElem
                     [i:matchesMediatype((@eq, @in/tokenize(.)), $contextURI)]
                      /f:validateFileInstanceComponents($contextURI, $contextDoc, $contextNode, ., $context)                
        case element(gx:xpath) return i:validateExpressionValue($contextURI, $constraintElem, $contextItem, $contextDoc, $context)
        case element(gx:foxpath) return i:validateExpressionValue($contextURI, $constraintElem, $contextItem, $contextDoc, $context)            
        case element(gx:contentCorrespondence) return concord:validateConcord($contextURI, $contextDoc, $contextItem, $constraintElem, $context)
                
        default return 
            error(QName((), 'UNEXPECTED_COMPONENT_IN_FILE_SHAPE'), 
                  concat('Unexpected shape or constraint element, name: ', $constraintElem/name()))
    let $extensionConstraintResults := 
        $extensionConstraints/f:validateExtensionConstraint($contextURI, $contextDoc, $contextNode, ., $context)         
    return (
        $resourceShapeResults, 
        $focusNodeResults,
        $coreConstraintResults,
        $extensionConstraintResults
    )        
};        

(:~
 : Validates a resource node against a focus node shape.
 :
 : The focus node shape maps the resource node to a set of focus nodes,
 : which must be validated against the constraints and shapes defined
 : by child elements of the focus node shape.
 :
 : The mapping of the resource node to focus nodes is defined by an
 : XPath expression (@xpath). Note that in the future, also other types
 : of mapping may be supported.
 :
 : @param contextURI the file path of the file resource containing the focus node
 : @param focusNodeShape a set of constraints which apply to the focus node
 : @param nodeContextItem the node to be validated
 : @param contextDoc the document containing the node to be validated
 : @param context the processing context
 : @return a set of results
 :)
declare function f:validateFocusNode($contextURI as xs:string,
                                     $focusNodeShape as element(), 
                                     $nodeContextItem as node()?,                                     
                                     $contextDoc as document-node()?,
                                     $context as map(xs:string, item()*))
        as element()* {
    let $xpath := $focusNodeShape/@xpath
    let $foxpath := $focusNodeShape/@foxpath        
    let $exprValue :=    
        let $evaluationContext := $context?_evaluationContext
        let $contextItem := ($nodeContextItem, $contextURI)[1]
        return
            if ($xpath) then 
                i:evaluateXPath($xpath, $contextItem, $evaluationContext, true(), true())
                
            (: Foxpath based focus node shape conceptually not yet fully evaluated;
               considered, but for the time being not yet supported               
            else if ($foxpath) then  
                f:evaluateFoxpath($foxpath, $contextURI, $evaluationContext, true())
             :)
             
            else error(QName((), 'SCHEMA_ERROR'), 'Missing expression')
    let $focusNodes := $exprValue[. instance of node()]   
    
    (: Validation results - target size :)
    let $results_target :=
        $focusNodeShape/i:validateTargetCount(., (), $focusNodes, $context)

    (: Other validation results :)
    let $results_other :=
        for $focusNode in $focusNodes
        let $context := i:updateEvaluationContext_focusNode($focusNode, $context)
        (: let $_DEBUG := f:DEBUG_CONTEXT($focusNodeShape/@id || '-AFTER_UPD_FOCUSNODE', $context) :)
        let $focusNodeDoc :=
            if ($focusNode/ancestor::node() intersect $contextDoc) then $contextDoc
            else $focusNode/root()
        return
            f:validateFileInstanceComponents($contextURI, 
                                             $focusNodeDoc,
                                             $focusNode,
                                             $focusNodeShape,                                             
                                             $context)
    return
        ($results_target, $results_other)
};


