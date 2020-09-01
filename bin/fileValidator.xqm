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
    
import module namespace expair="http://www.greenfox.org/ns/xquery-functions/expression-pair" 
at "expressionPairConstraint.xqm";

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
        for $constraint in $coreConstraints
        return
            typeswitch($constraint)
            case $targetSize as element(gx:targetSize) return () (: Already processed ... :)                
            case $lastModified as element(gx:lastModified) return 
                i:validateLastModified($contextURI, $lastModified, $context)
            case $fileSize as element(gx:fileSize) return 
                i:validateFileSize($contextURI, $fileSize, $context)
            case $fileName as element(gx:fileName) return 
                i:validateFileName($contextURI, $fileName, $context)
            case $mediatype as element(gx:mediatype) return 
                i:validateMediatype($contextURI, $mediatype, $context)     
            case $docContent as element(gx:docContent) return 
                dcont:validateDocContentConstraint($contextURI, $contextDoc, $contextNode, $docContent, $context)            
            case $values as element(gx:values) return 
                expr:validateValueConstraint($contextURI, $contextDoc, $contextNode, $values, $context)            
            case $xpath as element(gx:xpath) return 
                i:validateExpressionValue($contextURI, $xpath, $contextItem, $contextDoc, $context)
            case $foxpath as element(gx:foxpath) return 
                i:validateExpressionValue($contextURI, $foxpath, $contextItem, $contextDoc, $context)            
            case $xsdValid as element(gx:xsdValid) return 
                i:xsdValidate($contextURI, $xsdValid, $context)
            case $links as element(gx:links) return 
                i:validateLinks($contextURI, $contextDoc, $contextItem, $links, $context)            
            case $docSimilar as element(gx:docSimilar) return 
                i:validateDocSimilar($contextURI, $contextDoc, $contextItem, $docSimilar, $context)
            case $expressionPairs as element(gx:expressionPairs) return 
                expair:validateExpressionPairConstraint($contextURI, $contextDoc, $contextNode, $expressionPairs, $context)            
            case $concord as element(gx:contentCorrespondence) return 
                concord:validateConcord($contextURI, $contextDoc, $contextItem, $concord, $context)
            case $ifMediatype as element(gx:ifMediatype) return
                $ifMediatype
                [i:matchesMediatype((@eq, @in/tokenize(.)), $contextURI)]
                /f:validateFileInstanceComponents($contextURI, $contextDoc, $contextNode, ., $context)
            default return 
                error(QName((), 'UNEXPECTED_COMPONENT_IN_FILE_SHAPE'), 
                      concat('Unexpected shape or constraint element, name: ', $constraint/name()))
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


