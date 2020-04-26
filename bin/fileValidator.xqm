(:
 : -------------------------------------------------------------------------
 :
 : domainValidator.xqm - validates file resources against a file shape
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

import module namespace concord="http://www.greenfox.org/ns/xquery-functions/concord" at

    "concordConstraint.xqm";

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
    let $targetPathsAndTargetValidationResults := f:getTargetPaths($fileShape, $context, $fileShape/gx:targetSize)
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
 : @param filePath the file path
 : @param gxFile the file shape
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFileInstance($filePath as xs:string, 
                                        $fileShape as element(gx:file),
                                        $position as xs:integer?,
                                        $context as map(*)) 
        as element()* {
    (: let $_LOG := trace($filePath, 'FILE_PATH: ') :) 

    (: Update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $filePath)
    
    (: Determine "in-scope components" 
       - all components to be evaluated in the context of this file resource :)
    let $componentsMap := i:getEvaluationContextScope($filePath, $fileShape, $context)
    
    let $resourceShapes := $componentsMap?resourceShapes
    let $focusNodes := $componentsMap?focusNodes
    let $coreConstraints := $componentsMap?coreConstraints
    let $extensionConstraints := $componentsMap?extensionConstraints
    let $extensionConstraintComponents := $componentsMap?extensionConstraintComponents
    let $constraints := ($coreConstraints, $extensionConstraints)
    
    (: Required bindings are a subset of potential bindings :)
    let $reqBindingsAndDocs := 
        f:getRequiredBindingsAndDocs(
            $filePath, 
            $fileShape, 
            $coreConstraints, 
            $extensionConstraints, 
            $extensionConstraintComponents,
            $resourceShapes,
            $focusNodes,
            $context)
            
    let $reqBindings := $reqBindingsAndDocs?requiredBindings
    let $reqDocs := 
        map:merge((
            $reqBindingsAndDocs?xdoc ! map:entry('xdoc', .),
            $reqBindingsAndDocs?jdoc ! map:entry('jdoc', .),
            $reqBindingsAndDocs?csvdoc ! map:entry('csvdoc', .),
            $reqBindingsAndDocs?htmldoc ! map:entry('htmldoc', .)
        ))        
    
    (: Update the evaluation context so that it contains an entry for each
       variable reference found in the in-scope components :)
    let $context := f:prepareEvaluationContext($context, $reqBindings, $filePath, 
        $reqDocs?xdoc, $reqDocs?jdoc, $reqDocs?csvdoc, $reqDocs?htmldoc, ())        
    let $_DEBUG := f:DEBUG_CONTEXT($fileShape/@id || '_DOCNR_' || $position, $context)
    
    let $contextDoc := ($reqDocs?xdoc, $reqDocs?jdoc, $reqDocs?csvdoc, $reqDocs?htmldoc)[1]        
    let $results := f:validateFileInstanceComponents($filePath, $fileShape, $contextDoc, $contextDoc, $context)
    return $results
};

declare function f:validateFileInstanceComponents($filePath as xs:string,
                                                  $component as element(),
                                                  $nodeContextItem as node()?,                                                                                                    
                                                  $contextDoc as document-node()?, 
                                                  $context as map(*))
        as element()* {
    let $contextItem := ($nodeContextItem, $filePath)[1]        
    let $childComponents := $component/*[not(@deactivated eq 'true')]
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
    let $focusNodeResults := $focusNodes/i:validateFocusNode($filePath, ., $contextItem, $contextDoc, $context)
    let $coreConstraintResults :=
        for $constraint in $coreConstraints
        return
            typeswitch($constraint)
            case $targetSize as element(gx:targetSize) return () (: Already processed ... :)                
            case $lastModified as element(gx:lastModified) return i:validateLastModified($filePath, $lastModified, $context)
            case $fileSize as element(gx:fileSize) return i:validateFileSize($filePath, $fileSize, $context)
            case $fileName as element(gx:fileName) return i:validateFileName($filePath, $fileName, $context)
            case $mediatype as element(gx:mediatype) return i:validateMediatype($filePath, $mediatype, $context)     
            case $xpath as element(gx:xpath) return i:validateExpressionValue($filePath, $xpath, $contextItem, $contextDoc, $context)
            case $foxpath as element(gx:foxpath) return i:validateExpressionValue($filePath, $foxpath, $contextItem, $contextDoc, $context)            
            case $links as element(gx:links) return i:validateLinks($filePath, $links, $contextItem, $contextDoc, $context)                
            case $xsdValid as element(gx:xsdValid) return i:xsdValidate($filePath, $xsdValid, $context)
            case $docSimilar as element(gx:docSimilar) return i:validateDocSimilar($filePath, $docSimilar, $contextItem, $contextDoc, $context)
            case $concord as element(gx:contentCorrespondence) return concord:validateConcord($filePath, $concord, $contextItem, $contextDoc, $context)
            
            case $ifMediatype as element(gx:ifMediatype) return
                $ifMediatype
                [i:matchesMediatype((@eq, @in/tokenize(.)), $filePath)]
                /f:validateFileInstanceComponents($filePath, ., $nodeContextItem, $contextDoc, $context)
            
            default return 
                error(QName((), 'UNEXPECTED_COMPONENT_IN_FILE_SHAPE'), 
                      concat('Unexpected shape or constraint element, name: ', $constraint/name()))
        let $extensionConstraintResults := 
            $extensionConstraints/f:validateExtensionConstraint($filePath, ., $contextItem, $contextDoc, $context)
         
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
 : @param filePath the file path of the file resource containing the focus node
 : @param focusNodeShape a set of constraints which apply to the focus node
 : @param nodeContextItem the node to be validated
 : @param contextDoc the document containing the node to be validated
 : @param context the processing context
 : @return a set of results
 :)
declare function f:validateFocusNode($filePath as xs:string,
                                     $focusNodeShape as element(), 
                                     $nodeContextItem as node()?,                                     
                                     $contextDoc as document-node()?,
                                     $context as map(xs:string, item()*))
        as element()* {
    let $xpath := $focusNodeShape/@xpath
    let $foxpath := $focusNodeShape/@foxpath        
    let $exprValue :=    
        let $evaluationContext := $context?_evaluationContext
        let $contextItem := ($nodeContextItem, $filePath)[1]
        return
            if ($xpath) then 
                i:evaluateXPath($xpath, $contextItem, $evaluationContext, true(), true())
                
            (: Foxpath based focus node shape conceptually not yet fully evaluated;
               considered, but for the time being not yet supported               
            else if ($foxpath) then  
                f:evaluateFoxpath($foxpath, $filePath, $evaluationContext, true())
             :)
             
            else error(QName((), 'SCHEMA_ERROR'), 'Missing expression')
    let $focusNodes := $exprValue[. instance of node()]   
    
    (: Validation results - target size :)
    let $results_target :=
        $focusNodeShape/gx:targetSize
        /i:validateTargetCount(., $focusNodes, $filePath, ($xpath, $foxpath)[1])

    (: Other validation results :)
    let $results_other :=
        for $focusNode in $focusNodes
        let $focusNodeDoc :=
            if ($focusNode/ancestor::node() intersect $contextDoc) then $contextDoc
            else $focusNode/root()
        return
            f:validateFileInstanceComponents($filePath, 
                                             $focusNodeShape, 
                                             $focusNode, 
                                             $focusNodeDoc, 
                                             $context)
    return
        ($results_target, $results_other)
};


