(:
 : -------------------------------------------------------------------------
 :
 : domainValidator.xqm - Document me!
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
    "tt/_nameFilter.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "docSimilarConstraint.xqm",
    "evaluationContextManager.xqm",
    "expressionValueConstraint.xqm",
    "extensionValidator.xqm",
    "filePropertiesConstraint.xqm",
    "focusNodeValidator.xqm",
    "greenfoxTarget.xqm",
    "linkConstraint.xqm",    
    "mediatypeConstraint.xqm",
    "xsdValidator.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFile($gxFile as element(gx:file), $context as map(*)) 
        as element()* {
    let $_DEBUG := f:DEBUG_CONTEXT($gxFile/@id, $context)        
    let $targetPathsAndTargetValidationResults := f:getTargetPaths($gxFile, $context, $gxFile/gx:targetSize)
    let $targetPaths := $targetPathsAndTargetValidationResults[. instance of xs:anyAtomicType]
    let $targetValidationResults := $targetPathsAndTargetValidationResults[. instance of element()]
    
    (: Check instances :)
    let $instanceResults := 
        for $targetPath at $pos in $targetPaths
        return f:validateFileInstance($targetPath, $gxFile, $pos, $context)
    
    (: Merge results :)        
    let $results := ($targetValidationResults, $instanceResults)
    return
        $results
};

(:~
 : Validates a file against a file shape.
 :
 : @param filePath the file path
 : @param gxFile the file shape
 : @param context the evaluation context
 : @return validation results
 :)
declare function f:validateFileInstance($filePath as xs:string, 
                                        $gxFile as element(gx:file),
                                        $position as xs:integer?,
                                        $context as map(*)) 
        as element()* {
    (: let $_LOG := trace($filePath, 'FILE_PATH: ') :) 

    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $filePath)
    let $context := map:put($context, '_contextName', $filePath ! replace(., '.*\\', ''))
    let $componentsMap := i:getEvaluationContextScope($filePath, $gxFile)
    
    let $resourceShapes := $componentsMap?resourceShapes
    let $focusNodes := $componentsMap?focusNodes
    let $coreConstraints := $componentsMap?coreConstraints
    let $extensionConstraints := $componentsMap?extensionConstraints
    let $extensionConstraintComponents := $componentsMap?extensionConstraintComponents
    let $constraints := ($coreConstraints, $extensionConstraints)
    
    (: Required bindings are a subset of potential bindings :)
    let $reqBindingsAndDocs := f:getRequiredBindingsAndDocs(
                               $filePath, 
                               $gxFile, 
                               $coreConstraints, 
                               $extensionConstraints, 
                               $extensionConstraintComponents,
                               $resourceShapes,
                               $focusNodes)
    let $reqBindings := $reqBindingsAndDocs?requiredBindings
    (: If expressions reference documents, these are stored in a map :)
    let $reqDocs := 
        map:merge((
            $reqBindingsAndDocs?xdoc ! map:entry('xdoc', .),
            $reqBindingsAndDocs?jdoc ! map:entry('jdoc', .),
            $reqBindingsAndDocs?csvdoc ! map:entry('csvdoc', .),
            $reqBindingsAndDocs?htmldoc ! map:entry('htmldoc', .)
        ))        
    
    (: the document types are mutually exclusive - $doc is the 
       only document obtained (if any) :)
    let $context := f:prepareEvaluationContext($context, $reqBindings, $filePath, 
        $reqDocs?xdoc, $reqDocs?jdoc, $reqDocs?csvdoc, $reqDocs?htmldoc, ())
        
    let $_DEBUG := f:DEBUG_CONTEXT($gxFile/@id || '_DOCNR_' || $position, $context)
    
    let $contextDoc := ($reqDocs?xdoc, $reqDocs?jdoc, $reqDocs?csvdoc, $reqDocs?htmldoc)[1]        
    let $contextItem := ($contextDoc, $filePath)[1]
    let $results := f:validateFileInstanceComponents($filePath, $gxFile, $contextItem, $contextDoc, $context)
    return $results
};

declare function f:validateFileInstanceComponents($filePath as xs:string,
                                                  $component as element(),
                                                  $contextItem as item(),                                                                                                    
                                                  $contextDoc as document-node()?, 
                                                  $context as map(*))
        as element()* {
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
            case $targetSize as element(gx:targetSize) return ()                
            case $lastModified as element(gx:lastModified) return i:validateLastModified($filePath, $lastModified, $context)
            case $fileSize as element(gx:fileSize) return i:validateFileSize($filePath, $fileSize, $context)
            case $fileName as element(gx:fileName) return i:validateFileName($filePath, $fileName, $context)
            case $mediatype as element(gx:mediatype) return i:validateMediatype($filePath, $mediatype, $context)     
            case $xpath as element(gx:xpath) return i:validateExpressionValue($filePath, $xpath, $contextItem, $contextDoc, $context)
            case $foxpath as element(gx:foxpath) return i:validateExpressionValue($filePath, $foxpath, $contextItem, $contextDoc, $context)            
            case $links as element(gx:links) return i:validateLinks($filePath, $links, $contextItem, $contextDoc, $context)                
            case $xsdValid as element(gx:xsdValid) return i:xsdValidate($filePath, $xsdValid, $context)
            case $docSimilar as element(gx:docSimilar) return i:validateDocSimilar($filePath, $docSimilar, $contextItem, $contextDoc, $context)
            
            case $ifMediatype as element(gx:ifMediatype) return
                $ifMediatype
                [i:matchesMediatype((@eq, @in/tokenize(.)), $filePath)]
                /f:validateFileInstanceComponents($filePath, ., $contextItem, $contextDoc, $context)
            
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

declare function f:validateFocusNode($filePath as xs:string,
                                     $focusNodeShape as element(), 
                                     $contextItem as item()?,                                     
                                     $contextDoc as document-node()?,
                                     $context as map(xs:string, item()*))
        as element()* {
    let $exprValue :=    
        let $xpath := $focusNodeShape/@xpath
        let $foxpath := $focusNodeShape/@foxpath
        let $evaluationContext := $context?_evaluationContext
        return
            if ($xpath) then 
                i:evaluateXPath($xpath, $contextItem, $evaluationContext, true(), true())
            else if ($foxpath) then  
                f:evaluateFoxpath($foxpath, $contextItem, $evaluationContext, true())
            else error(QName((), 'SCHEMA_ERROR'), 'Missing expression')
    let $results :=
        for $contextItem in $exprValue
        return
            f:validateFileInstanceComponents($filePath, $focusNodeShape, $contextItem, $contextDoc, $context)
    return
        $results
};


