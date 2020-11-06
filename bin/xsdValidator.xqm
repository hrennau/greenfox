(:
 : -------------------------------------------------------------------------
 :
 : xsdValidator.xqm - validates a resource against XSDs
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "expressionEvaluator.xqm",
   "greenfoxUtil.xqm";
    
import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:xsdValidate($constraintElem as element(gx:xsdValid), 
                               $context as map(*))
        as element()* {
    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    let $useContextNode := ($contextNode, $contextDoc)[1]
    return

    (: Exception - no context document :)
    if (not($useContextNode)) then
        let $msg := "XSD validation requires XML file, but file is not XML"
        return
            result:validationResult_xsdValid_exception($constraintElem, $msg, (), $context)
    else
      
    let $doc := $useContextNode (: i:fox-doc-no-base-xml($contextURI) :)
    let $expr := $constraintElem/@xsdFOX
    let $evaluationContext := $context?_evaluationContext
    let $xsdPaths := 
        let $value := f:evaluateFoxpath($expr, $contextURI, $evaluationContext, true())
        return (
            for $v in $value 
            return
                if (i:fox-resource-is-dir($v)) then 
                    i:resourceChildResources($v, '*.xsd')
                else $v
        )
    return
        if (empty($xsdPaths)) then
            let $msg := "No XSDs found"
            return
                result:validationResult_xsdValid_exception($constraintElem, $msg, (), $context)
        else
        
    let $xsdRoots := 
        for $xsdPath in $xsdPaths
        return
            if (not(i:fox-doc-available($xsdPath))) then error() 
            else i:fox-doc($xsdPath)
                
    (: _TO_DO_ - elaborate error element in case XSDs are not XSD :)
    return
        if (some $xsdRoot in $xsdRoots satisfies 
            not($xsdRoot/descendant-or-self::xs:schema)) then 
            
                let $msg := "xsdFoxpath yields non-XSD node"
                return
                    result:validationResult_xsdValid_exception($constraintElem, $msg, (), $context)
        else

    let $rootElem := $doc/descendant-or-self::*[1]
    let $validationTargets := $rootElem/f:selectValidationTargetNodes($constraintElem/@selectXP, ., $context)
    
    for $validationTarget in $validationTargets
    let $namespace := $validationTarget/namespace-uri(.)
    let $lname := $validationTarget/local-name(.)

    let $elementDecl :=
        $xsdRoots/xs:schema/xs:element[@name eq $lname]
                                      [not($namespace) and not(../@targetNamespace)
                                       or $namespace eq ../@targetNamespace]
    return
        (: _TO_DO_ - elaborate error elements in case of XSD match issues :)
        if (count($elementDecl) eq 0) then
            let $msg := concat('No XSD element declaration found for this document; ',
                               'namespace=', $namespace, '; local name: ', $lname)
            return
                result:validationResult_xsdValid_exception($constraintElem, $msg, (), $context)
        else if (count($elementDecl) gt 1) then
            let $msg := concat('More than 1 XSD element declarations found for this document; ',
                               'namespace=', $namespace, '; local name: ', $lname)
            return                                    
                result:validationResult_xsdValid_exception($constraintElem, $msg, (), $context)
        else 
        
    (: let $schema := $elementDecl/base-uri(.) :)    
    let $schema := $elementDecl/ancestor::xs:schema    
    let $report := validate:xsd-report($validationTarget, $schema)
    let $colour := if ($report//status eq 'valid') then 'green' else 'red'
    return
        result:validationResult_xsdValid($colour, $constraintElem, $report, $context)
};

(:~
 : Returns the nodes to be validated.
 :
 : @param selectXP an XPath expression selecting the nodes
 : @param contextItem the current congtext item
 : @param context the processing context
 : @return the validation target nodes
 :) 
declare function f:selectValidationTargetNodes($selectXP as xs:string?, 
                                               $contextItem as item(), 
                                               $context as map(xs:string, item()*))
        as node()* {
    if (not($selectXP)) then $contextItem else
 
    let $nodes := i:evaluateXPath($selectXP, $contextItem, $context?_evaluationContext, true(), true())
    return $nodes
};        

