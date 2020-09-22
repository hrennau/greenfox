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
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:xsdValidate($constraint as element(gx:xsdValid), 
                               $context as map(*))
        as element()* {
    let $contextURI := $context?_targetInfo?contextURI
    return
    
    if (not(i:fox-doc-available($contextURI))) then 
        let $msg := "XSD validation requires XML file, but file is not XML"
        return
            f:constructResult_xsdValid('red', $msg, $contextURI, $constraint, ())
    else
      
    let $doc := i:fox-doc-no-base-xml($contextURI)
    let $expr := $constraint/@xsdFoxpath
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
                f:constructResult_xsdValid('red', $msg, $contextURI, $constraint, ())            
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
                    f:constructResult_xsdValid('red', $msg, $contextURI, $constraint, ())
        else

    let $rootElem := $doc/*
    let $namespace := $rootElem/namespace-uri(.)
    let $lname := $rootElem/local-name(.)

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
                f:constructResult_xsdValid('red', $msg, $contextURI, $constraint, ())
        else if (count($elementDecl) gt 1) then
            let $msg := concat('More than 1 XSD element declarations found for this document; ',
                               'namespace=', $namespace, '; local name: ', $lname)
            return                                    
                f:constructResult_xsdValid('red', $msg, $contextURI, $constraint, ())
        else 
        
    (: let $schema := $elementDecl/base-uri(.) :)    
    let $schema := $elementDecl/ancestor::xs:schema    
    let $report := validate:xsd-report($doc, $schema)
    return
        if ($report//status eq 'valid') then
            f:constructResult_xsdValid('green', (), $contextURI, $constraint, ())
        else            
            f:constructResult_xsdValid('red', (), $contextURI, $constraint, $report)
};

declare function f:constructResult_xsdValid($colour as xs:string,
                                            $msg as xs:string?,
                                            $contextURI as xs:string,                                            
                                            $constraintElem as element(),
                                            $report as element()?)
        as element() {
    let $elemName := 'gx:' || $colour
    return
        element {$elemName}{
            $msg ! attribute msg {.},
            attribute filePath {$contextURI},                
            attribute constraintComponent {"XsdValid"},
            $constraintElem/@id/attribute constraintID {.},
            $constraintElem/@label/attribute constraintLabel {.},            
            $constraintElem/@resourceShapeID/attribute resourceShapeID {.},                
            $constraintElem/@xsdFoxpath,
            if ($colour eq 'green') then ()
            else $report/message/<gx:xsdMessage>{@*, node()}</gx:xsdMessage>
         }
        
};        


