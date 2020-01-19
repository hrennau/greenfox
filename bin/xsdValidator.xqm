(:
 : -------------------------------------------------------------------------
 :
 : xsdValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:xsdValidate($filePath as xs:string, $constraint as element(gx:xsdValid), $context as map(*))
        as element()* {
    let $_DEBUG := trace($filePath, '### XSD VALIDATOR FILE PATH: ') return
    
    if (not(doc-available($filePath))) then 
        <gx:error msg="XSD validation requires XML file, but file is not XML">{
                  attribute constraintComponent {"xsdValid"},
                  $constraint/@xsdFoxpath,
                  $constraint/@id/attribute constraintID {.},
                  $constraint/@label/attribute constraintLabel {.}
        }</gx:error>
    else
        
    let $doc := doc($filePath)
    let $expr := $constraint/@xsdFoxpath
    let $evaluationContext := $context?_evaluationContext
    let $_DEBUG := trace($evaluationContext?domain, 'DOMAIN: ')
    let $xsdPaths := 
        let $value := f:evaluateFoxpath($expr, $filePath, $evaluationContext, true())
(:        
        let $exprContext := $context
        let $requiredBindings := map:keys($context)
        let $exprAugmented := i:finalizeQuery($xsdFoxpath, $requiredBindings)
        let $value := f:evaluateFoxpath($exprAugmented, $filePath, $exprContext)
:)        
        return (
            for $v in $value return
                if (file:is-dir($v)) then file:list($v, false(), '*.xsd') ! concat($v, '/', .)
                else $v
        )
    return
        if (empty($xsdPaths)) then
            <gx:error msg="No XSDs found">{
                      attribute constraintComponent {"xsdValid"},
                      $constraint/@xsdFoxpath,
                      $constraint/@id/attribute constraintID {.},
                      $constraint/@label/attribute constraintLabel {.}
            }</gx:error>
        else
        
    let $xsdRoots := 
        for $xsdPath in $xsdPaths
        return
            if (not(doc-available($xsdPath))) then error() else doc($xsdPath)
                
    (: _TO_DO_ - elaborate error element in case XSDs are not XSD :)
    return
        if (some $xsdRoot in $xsdRoots satisfies 
            not($xsdRoot/descendant-or-self::xs:schema)) then 
                <gx:error msg="xsdFoxpath yields non-XSD node">{
                  attribute constraintComponent {"xsdValid"},
                  $constraint/@xsdFoxpath,
                  $constraint/@id/attribute constraintID {.},
                  $constraint/@label/attribute constraintLabel {.}
                }</gx:error>
        else

    let $rootElem := $doc/*
    let $namespace := $rootElem/namespace-uri(.)
    let $lname := $rootElem/local-name(.)

    let $elementDecl :=
            $xsdRoots/xs:schema/xs:element[@name eq $lname]
                                          [not($namespace) and not(../@targetNamespace)
                                           or
                                           $namespace eq ../@targetNamespace]
    return
        (: _TO_DO_ - elaborate error elements in case of XSD match issues :)
        if (count($elementDecl) eq 0) then
            <gx:error msg="{concat('No XSD element declaration found for this document; namespace=', $namespace, '; local name: ', $lname)}">{
                attribute constraintComponent {"xsdValid"},
                $constraint/@xsdFoxpath,
                $constraint/@id/attribute constraintID {.},
                $constraint/@label/attribute constraintLabel {.}
             }</gx:error>
                      
        else if (count($elementDecl) gt 1) then
            <gx:error msg="{concat('More than 1 XSD element declarations found for this document; namespace=', $namespace, '; local name: ', $lname)}">{
                attribute constraintComponent {"xsdValid"},
                $constraint/@xsdFoxpath,
                $constraint/@id/attribute constraintID {.},
                $constraint/@label/attribute constraintLabel {.}            
            }</gx:error>
        else 
        
    let $schema := $elementDecl/base-uri(.)    
    let $report := validate:xsd-report($doc, $schema)
    return
        if ($report//status eq 'valid') then ()
        else
            <gx:error>{
                $constraint/@msg,
                attribute constraintComponent {"xsdValid"},
                attribute filePath {$filePath},                
                $constraint/@xsdFoxpath,
                $constraint/@id/attribute constraintID {.},
                $constraint/@label/attribute constraintLabel {.},            
                $report/message/<gx:xsdMessage>{@*, node()}</gx:xsdMessage>
            }</gx:error>
};


