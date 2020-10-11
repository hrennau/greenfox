(:
 : -------------------------------------------------------------------------
 :
 : extensionValidator.xqm - validates against an extension constraint component
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_request.xqm",
   "tt/_foxpath.xqm",
   "tt/_reportAssistent.xqm",
   "tt/_errorAssistent.xqm",
   "tt/_log.xqm",
   "tt/_nameFilter.xqm",
   "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "evaluationContextManager.xqm",
   "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates an extension constraint.
 :
 : @param constraintElem the constraint element
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateExtensionConstraint($constraintElem as element(),
                                               $context as map(xs:string, item()*))
                                            
        as element()* {
        
    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    return
        
    let $constraintComponent := f:getExtensionConstraintComponents($constraintElem)        
    let $constraintElemName := $constraintComponent/@constraintElementName
    let $paramNames := $constraintComponent/gx:param/@name
    let $evaluationContext := $context?_evaluationContext
    let $reqDocs := $context?_reqDocs
    
    let $useParams :=
        let $paramNamesElemStyle := $constraintElem/gx:param/@name
        let $atts := $constraintElem/@*
        return (
            $constraintElem/gx:param,
            for $paramName in $paramNames[not(. = $paramNamesElemStyle)]
            let $attValue := $atts[local-name(.) eq $paramName]
            return $attValue ! <gx:param name="{$paramName}">{string(.)}</gx:param>
    )
    (:
    let $reqBindings :=
        let $potentialBindings := i:getPotentialBindings()
        return f:getRequiredBindings($potentialBindings, (), (), $constraintComponent, (), (), (), $context)

    let $context := f:prepareEvaluationContext($context, $reqBindings, $contextURI, 
        $reqDocs?xdoc, $reqDocs?jdoc, $reqDocs?csvdoc, $reqDocs?htmldoc, $reqDocs?linesdoc, $useParams)  
    :)
    
    let $context := f:updateEvaluationContext_params($useParams, $context)    
    let $xpath := $constraintComponent/(@validatorXPath, gx:validatorXPath)[1]
    let $foxpath := $constraintComponent/(@validatorFoxpath, gx:validatorFoxpath)[1]
    let $exprValue := 
        if ($xpath) then f:evaluateXPath($xpath, $contextNode, $context?_evaluationContext, true(), true())
        else if ($foxpath) then f:evaluateFoxpath($xpath, $contextURI, $context?_evaluationContext, true())
        else error()
    let $isValidAndErrors := if (empty($exprValue)) then true()
                             else if ($exprValue instance of xs:boolean) then $exprValue
                             else (false(), $exprValue)
    let $isValid := $isValidAndErrors[1]
    let $errorValues := tail($isValidAndErrors)
    
    let $msg := $constraintElem/@msg/f:editMsg(., $useParams)
    let $msgOk := $constraintElem/@msgOK/f:editMsg(., $useParams)
    let $nodePath := $contextNode/i:datapath(.)
    
    let $constraintIdentAtts := (
        'ExtensionConstraint' ! attribute constraintComp {.},
        $constraintElem/local-name(.) ! attribute extensionConstraintName {.},
        $constraintElem/node-name(.) ! i:qnameToURI(.) ! attribute extensionConstraintIRI {.},
        $constraintElem/@id/attribute constraintComponentID {.},
        $constraintElem/@label/attribute constraintLabel {.}
    )        
    let $paramAttsAndElems := (
        $constraintElem/@*[local-name(.) = $paramNames],
        $constraintElem/gx:param
    )
    let $paramAtts := $paramAttsAndElems[. instance of attribute()]
    let $paramElems := $paramAttsAndElems[. instance of element()]
    return
        if ($isValid) then
            <gx:green>{
                $msgOk ! attribute msg {.},
                $constraintIdentAtts,
                $nodePath ! attribute nodePath {.},
                $paramAtts,
                $paramElems
            }</gx:green>
        else
            <gx:red>{
                $msg ! attribute msg {.},
                $constraintIdentAtts,
                $nodePath ! attribute nodePath {.},                
                $paramAtts,
                $paramElems,
                $errorValues ! <gx:value>{.}</gx:value>                
            }</gx:red>
};  

(:~
 : Returns the extension constraints contained in a list of constraint declarations.
 :
 : @param constraints constraint definitions
 : @return the extension constraints
 :)
declare function f:getExtensionConstraints($constraints as element()*) as element()* {
    $constraints except $constraints/self::gx:*
    (: $constraints/self::*[not(namespace-uri(.) eq $f:URI_GX)] :)
};

(:~
 : Returns the extension constraint components referenced by a given set of constraint 
 : definitions.
 :
 : @param constraintElems constraint elements, among which there may be extension constraint elements
 : @return the extension constraint components referenced by the extension constraint elements
 :)
declare function f:getExtensionConstraintComponents($constraintElems as element()*) 
        as element()* {
    let $extensionConstraintElems := f:getExtensionConstraints($constraintElems)
    return if (not($extensionConstraintElems)) then () else
    (
    let $extensionConstraintComponents := 
        $extensionConstraintElems[1]/ancestor::gx:greenfox/gx:constraintComponents/gx:constraintComponent
    for $extensionConstraintElem in $extensionConstraintElems
    let $extensionConstraintName := $extensionConstraintElem/node-name(.)
    let $refExtensionConstraintComponent := $extensionConstraintComponents
        [@constraintElementName/resolve-QName(., ..) = $extensionConstraintName]
    return 
        if (empty($refExtensionConstraintComponent)) then 
            (: The error should never occur, as the greenfox validator should report the problem before starting any validation :)
            error(QName((), 'INVALID_SCHEMA'), concat('Invalid schema, extension constraint component not found; ',
                  'extension constraint component URI: ', i:qnameToURI($extensionConstraintName)))
        else $refExtensionConstraintComponent
    )/.        
};

(:~
 : Edits a message, replacing occurrences of $foo with the parameter value
 : of parameter $foo.
 :
 : @param msg the message
 : @param params parameters available for substituting variable references
 : @return the edited message
 :)
declare function f:editMsg($msg as xs:string?, $params as element(gx:param)*)
        as xs:string? {
    if (not($msg) or not(contains($msg, '$'))) then $msg else
    
    let $parts := replace($msg, '^(.*?)\$(\i\c*)(.*)', '$1~~~$2~~~$3')[not(. eq $msg)] ! tokenize(., '~~~')
    return
        if (empty($parts)) then $msg else
        let $param := $params[@name eq $parts[2]]
        return
            concat(
                $parts[1],
                if (not($param)) then concat('$', $parts[2]) else $param/normalize-space(.),
                $parts[3] ! f:editMsg(., $params)
            )
};

