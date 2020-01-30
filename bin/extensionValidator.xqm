(:
 : -------------------------------------------------------------------------
 :
 : extensionValidator.xqm - validates against an extension constraint component
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
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateExtensionConstraint($constraint as element(), 
                                               $contextItem as item()?,
                                               $contextFilePath as xs:string,
                                               $contextDoc as document-node()?,
                                               $context as map(xs:string, item()*))
                                            
        as element()* {
    let $constraintComponent := f:getExtensionConstraintComponents($constraint)        
    let $constraintElemName := $constraint/@constraintElementName
    let $paramNames := $constraint/gx:param/@name
    let $evaluationContext := $context?_evaluationContext
    let $reqDocs := $context?_reqDocs
    
    let $reqBindings :=
        let $potentialBindings := ('this', 'doc', 'jdoc', 'csvdoc', 'domain', 'filePath', 'fileName')
        return f:getRequiredBindings($potentialBindings, $constraintComponent)

    let $context := f:prepareEvaluationContext($context, $reqBindings, $contextFilePath, 
        $reqDocs?xdoc, $reqDocs?jdoc, $reqDocs?csvdoc, $constraint/gx:param)  

    let $xpath := $constraintComponent/gx:xpathExpr
    let $foxpath := $constraintComponent/gx:foxpathExpr
    let $exprValue := 
        if ($xpath) then f:evaluateXPath($xpath, $contextItem, $context?_evaluationContext, true(), true())
        else if ($foxpath) then f:evaluateFoxpath($xpath, $contextItem, $context?_evaluationContext, true())
        else error()
    let $isValidAndErrors := if (empty($exprValue)) then true()
                             else if ($exprValue instance of xs:boolean) then $exprValue
                             else (false(), $exprValue)
    let $isValid := $isValidAndErrors[1]
    let $errorValues := tail($isValidAndErrors)
    
    let $msg := $constraint/@msg/string(.)
    let $msgOk := $constraint/@msgOK/string(.)
    let $nodePath := if (not($contextItem instance of node())) then () else $contextItem/i:datapath(.)
    
    let $constraintIdentAtts := (
        'ExtensionConstraint' ! attribute constraintComp {.},
        $constraint/local-name(.) ! attribute extensionConstraintName {.},
        $constraint/node-name(.) ! i:qnameToURI(.) ! attribute extensionConstraintIRI {.},
        $constraint/@id/attribute constraintComponentID {.},
        $constraint/@label/attribute constraintLabel {.}
    )        
    return
        if ($isValid) then
            <gx:green>{
                $msgOk ! attribute msg {.},
                $constraintIdentAtts,
                $nodePath ! attribute nodePath {.},
                $constraint/gx:param/<gx:param>{@*, node()}</gx:param>               
            }</gx:green>
        else
            <gx:error>{
                $msg ! attribute msg {.},
                $constraintIdentAtts,
                $nodePath ! attribute nodePath {.},                
                $constraint/gx:param/<gx:param>{@*, node()}</gx:param>,
                $errorValues ! <gx:value>{.}</gx:value>                
            }</gx:error>
};  

(:~
 : Returns the extension constraint components referenced by a given set of constraint definitions.
 :
 : @param constraints constraint definitions
 : @return the extension constraint components referenced by the constraint definitions
 :)
declare function f:getExtensionConstraintComponents($constraints as element()*) as element()* {
    let $extensionConstraints := f:getExtensionConstraints($constraints)
    return if (not($extensionConstraints)) then () else
    (
    let $extensionConstraintComponents := $extensionConstraints[1]/ancestor::gx:greenfox/gx:constraintComponents/gx:constraintComponent
    for $extensionConstraint in $extensionConstraints
    let $extensionConstraintName := $extensionConstraint/node-name(.)
    let $refExtensionConstraintComponent := $extensionConstraintComponents[@constraintElementName/resolve-QName(., ..) = $extensionConstraintName]
    return 
        if (empty($refExtensionConstraintComponent)) then 
            (: The error should never occur, as the greenfox validator should report the problem before starting any validation :)
            error(QName((), 'INVALID_SCHEMA'), concat('Invalid schema, extension constraint component not found; ',
                  'extension constraint component URI: ', i:qnameToURI($extensionConstraintName)))
        else $refExtensionConstraintComponent
    )/.        
};

(:~
 : Returns the extension constraints contained in a list of constraint definitions.
 :
 : @param constraints constraint definitions
 : @return the extension constraints
 :)
declare function f:getExtensionConstraints($constraints as element()*) as element()* {
    $constraints/self::*[not(namespace-uri(.) eq $f:URI_GX)]
};
