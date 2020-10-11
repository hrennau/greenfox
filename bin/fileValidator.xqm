(:
 : -------------------------------------------------------------------------
 :
 : fileValidator.xqm - validates file resources against a file shape
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "conditionalConstraint.xqm",
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

import module namespace dtree="http://www.greenfox.org/ns/xquery-functions/doc-tree" 
at "docTreeConstraint.xqm";

import module namespace expr="http://www.greenfox.org/ns/xquery-functions/value" 
at "valueConstraint.xqm";
    
import module namespace expair="http://www.greenfox.org/ns/xquery-functions/value-pair" 
at "valuePairConstraint.xqm";

(: Deprecated :)
import module namespace concord="http://www.greenfox.org/ns/xquery-functions/concord" 
at "concordConstraint.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates the target resources of a file shape against a file shape.
 : Steps: (a) determine and validate target resources, (b) validate each
 : target resource against the file shape.
 :
 : @param shapeElem an element representing the file shape
 : @param context processing context
 : @return validation results
 :)
declare function f:validateFile($shapeElem as element(gx:file), $context as map(*)) 
        as element()* {
    let $_DEBUG := f:DEBUG_CONTEXT($shapeElem/@id, $i:DEBUG_LEVEL, $context)  
    
    (: Determine target and evaluate target constraints :)
    let $targetPathsAndTargetValidationResults := f:getTargetPaths($shapeElem, $context)
    let $targetPaths := $targetPathsAndTargetValidationResults[. instance of xs:anyAtomicType]
    let $targetValidationResults := $targetPathsAndTargetValidationResults[. instance of element()]
    
    (: Check instances :)
    let $instanceResults := 
        for $targetPath at $pos in $targetPaths
        return f:validateFileInstance($targetPath, $shapeElem, $pos, $context)
    
    (: Merge results :)        
    let $results := ($targetValidationResults, $instanceResults)
    return
        $results
};

(:~
 : Validates a file resource against a file shape. The context is still 
 : refering to the previous resource. The context is adapted, and validation
 : of the file resource against the file shape is launched.
 :
 : @param contextURI the file path
 : @param shapeElem the file shape
 : @param position position of the file resource in the sequence of file resources
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFileInstance($contextURI as xs:string, 
                                        $shapeElem as element(gx:file),
                                        $position as xs:integer?,
                                        $context as map(*)) 
        as element()* {
    (: Update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $contextURI)
    let $context := i:adaptContext($contextURI, $shapeElem, $context)
    let $_DEBUG := f:DEBUG_CONTEXT($shapeElem/@id || '_DOCNR_' || $position, $i:DEBUG_LEVEL, $context)
    let $results := f:validateFileConstraints($shapeElem, $context)
    return $results
};

(:~
 : Validates a file resource or a focus node from a file resource against 
 : a schema element containing the elements against which to validate. 
 : The contained elements may be constraint elements, and/or focus node 
 : elements, and/or file shape elements. The containing element may be a 
 : file shape element, or a focus node element, or a clause element from 
 : a composite constraint (if, then, elseIf, else). 
 :
 : The file resource and (optionally) the current focus node is described
 : by the _targetInfo entry of the context.
 :
 : @param fileConstraints the element containing the elements against which 
 :   to validate
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFileConstraints($fileConstraints as element(),                                                                                                    
                                           $context as map(xs:string, item()*))
        as element()* {
    let $childComponents := $fileConstraints/*[not(@deactivated eq 'true')]
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
    let $focusNodeResults := $focusNodes/i:validateFocusNode(., $context)
    let $coreConstraintResults := 
        for $constraintElem in $coreConstraints return
        
        typeswitch($constraintElem)
        case element(gx:targetSize) return () (: Already processed ... :)            
        case element(gx:fileDate) return i:validateFileDate($constraintElem, $context)                
        case element(gx:fileSize) return i:validateFileSize($constraintElem, $context)
        case element(gx:fileName) return i:validateFileName($constraintElem, $context)            
        case element(gx:mediatype) return i:validateMediatype($constraintElem, $context)     
        case element(gx:docTree) return dtree:validateDocTreeConstraint($constraintElem, $context)  
        case element(gx:hyperdocTree) return dtree:validateDocTreeConstraint($constraintElem, $context)        
        
        case element(gx:value) return expr:validateValueConstraint($constraintElem, $context)
        case element(gx:values) return expr:validateValueConstraint($constraintElem, $context)
        case element(gx:foxvalue) return expr:validateValueConstraint($constraintElem, $context)        
        case element(gx:foxvalues) return expr:validateValueConstraint($constraintElem, $context)
        case element(gx:valuePair) return expair:validateValuePairConstraint($constraintElem, $context)
        case element(gx:valuePairs) return expair:validateValuePairConstraint($constraintElem, $context)   
        case element(gx:foxvaluePair) return expair:validateValuePairConstraint($constraintElem, $context)
        case element(gx:foxvaluePairs) return expair:validateValuePairConstraint($constraintElem, $context)            
        case element(gx:valuesCompared) return expair:validateValuePairConstraint($constraintElem, $context)            
        case element(gx:foxvaluesCompared) return expair:validateValuePairConstraint($constraintElem, $context)        
        case element(gx:links) return i:validateLinks($constraintElem, $context)            
        case element(gx:docSimilar) return i:validateDocSimilar($constraintElem, $context)
        case element(gx:xsdValid) return i:xsdValidate($constraintElem, $context)        
        case element(gx:ifMediatype) return 
            let $contextURI := $context?_targetInfo?contextURI return
              $constraintElem[i:matchesMediatype((@eq, @in/tokenize(.)), $contextURI)]/f:validateFileConstraints(., $context)                
        case element(gx:xpath) return i:validateExpressionValue($constraintElem, $context)
        case element(gx:foxpath) return i:validateExpressionValue($constraintElem, $context)            
        case element(gx:contentCorrespondence) return concord:validateConcord($constraintElem, $context)
        case element(gx:conditional) return i:validateConditionalConstraint($constraintElem, f:validateFileConstraints#2, $context)
        
        default return 
            error(QName((), 'UNEXPECTED_COMPONENT_IN_FILE_SHAPE'), 
                  concat('Unexpected shape or constraint element, name: ', $constraintElem/name()))
    let $extensionConstraintResults := 
        $extensionConstraints/f:validateExtensionConstraint(., $context)         
    return (
        $resourceShapeResults, 
        $focusNodeResults,
        $coreConstraintResults,
        $extensionConstraintResults
    )        
};        

(:~
 : Validates a file resource or a focus node from a file resource against
 : a focus node element.
 :
 : The focus node element maps the file resource to a set of focus nodes,
 : which must be validated against the constraints, shapes and focus node
 : elements contained by the focus node element.
 :
 : The mapping of the file resource or (current) focus node to focus nodes 
 : is defined by an XPath expression (@xpath). Note that in the future 
 : also other types of mapping may be supported.
 :
 : @param focusNodeElem element representing a focus node
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateFocusNode($focusNodeElem as element(),
                                     $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    let $useContextNode := ($contextNode, $contextDoc)[1]
    return
        
    let $xpath := $focusNodeElem/@xpath
    let $exprValue :=    
        let $evaluationContext := $context?_evaluationContext
        let $contextItem := ($useContextNode, $contextURI)[1]
        return
            if ($xpath) then i:evaluateXPath($xpath, $contextItem, $evaluationContext, true(), true())
            else error(QName((), 'SCHEMA_ERROR'), 'Missing expression')
    let $focusNodes := $exprValue[. instance of node()]   
    
    (: Validation results - target size :)
    let $results_target := $focusNodeElem/i:validateTargetCount(., (), $focusNodes, $context)

    (: Other validation results :)
    let $results_other :=
        for $focusNode in $focusNodes
        let $context := i:updateEvaluationContext_focusNode($focusNode, $context)
        let $focusNodeDoc :=
            if ($focusNode/ancestor::node() intersect $contextDoc) then $contextDoc
            else $focusNode/root()
        return f:validateFileConstraints($focusNodeElem, $context)
    return
        ($results_target, $results_other)
};

(: 
(:~
 : Validates a conditional constraint.
 :
 : @param constraintElem an element declaring the condition of a conditional constraint
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateConditionalConstraint($constraintElem as element(gx:conditional), 
                                                 $context as map(*))
        as element()* {
    
    let $if := $constraintElem/gx:if[1]
    let $then := $constraintElem/gx:then[1]
    let $elseif := $constraintElem/gx:elseIf
    let $else := $constraintElem/gx:else[1]
    
    let $ifResults := $if/f:validateFileConstraints(., $context)
    let $ifTrue := every $result in $ifResults satisfies $result/self::gx:green
    return (
        trace($ifResults/f:whitenResults(.), '++++++ WHITENED_RESULTS: '),
        if ($ifTrue) then $then/f:validateFileConstraints(., $context)        
        else $else/f:validateFileConstraints(., $context)
    )        
};

(:~
 : Transforms results so that 'red', 'yellow' and 'green' is
 : marked as not describing validity, as they have been produced in
 : order to determine a condition.
 :)
declare function f:whitenResults($results as element()*)
        as element()* {
    for $result in $results
    return
        typeswitch($result)
        case element(gx:red) return element gx:whiteRed {$result/(@*, node())}
        case element(gx:green) return element gx:whiteGreen {$result/(@*, node())}
        case element(gx:yellow) return element gx:whiteYellow {$result/(@*, node())}
        default return $result
};        
 :)


