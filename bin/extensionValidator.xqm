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
                                               $reqDocs as map(xs:string, document-node()?),
                                               $context as map(xs:string, item()*))
                                            
        as element()* {
    let $constraintComponent := f:getExtensionConstraintComponents($constraint)        
    let $constraintElemName := trace($constraint/@constraintElementName, '###CONSTRAINT_ELEM_NAME: ')
    let $paramNames := trace($constraint/gx:param/@name, '###CONSTRAINT_PARAM: ')
    let $evaluationContext := trace($context?_evaluationContext, '###ECONTEXT: ')
    
    let $reqBindings :=
        let $potentialBindings := ('this', 'doc', 'jdoc', 'csvdoc', 'domain', 'filePath', 'fileName')
        return trace( f:getRequiredBindings($potentialBindings, $constraintComponent) , '___EXTENSION_CONSTRAINT_REQ_BINDINGS: ')

    let $context := 
        let $evaluationContext :=
            map:merge((
                $context?_evaluationContext,
                if (not($reqBindings = 'doc')) then () else map:entry(QName('', 'doc'), $reqDocs?xdoc),
                if (not($reqBindings = 'jdoc')) then () else map:entry(QName('', 'jdoc'), $reqDocs?jdoc),
                if (not($reqBindings = 'csvdoc')) then () else map:entry(QName('', 'csvdoc'), $reqDocs?csvdoc),
                if (not($reqBindings = 'this')) then () else map:entry(QName('', 'this'), $contextItem),
                if (not($reqBindings = 'domain')) then () else map:entry(QName('', 'domain'), $context?_domainPath),
                if (not($reqBindings = 'filePath')) then () else map:entry(QName('', 'filePath'), $contextFilePath),
                if (not($reqBindings = 'fileName')) then () else map:entry(QName('', 'fileName'), replace($contextFilePath, '.*[\\/]', '')),
                (: Add parameter bindings :)
                (: _TO_DO_ Support datatypes (xs:integer, ...) :)
                for $param in $constraint/gx:param return $param/map:entry(QName('', @name), string(.)) 
            ))    
        return map:put($context, '_evaluationContext', $evaluationContext)
    
    let $xpath := $constraintComponent/gx:xpath
    let $foxpath := $constraintComponent/gx:foxpath
    let $exprValue := 
        if ($xpath) then f:evaluateXPath($xpath, $contextItem, $context?_evaluationContext, true(), true())
        else error()
    let $isValidAndErrors := if (empty($exprValue)) then true()
                             else if ($exprValue instance of xs:boolean) then $exprValue
                             else (false(), $exprValue)
    let $isValid := $isValidAndErrors[1]
    let $errorValues := tail($isValidAndErrors)
    
    let $msg := $constraint/@msg
    let $msgOk := $constraint/@msgOk
    let $constraintIdentAtts := (
        'ExtensionConstraintComponent' ! attribute constraintComponent {.},
        $constraint/local-name(.) ! attribute extensionComponentKindName {.},
        $constraint/node-name(.) ! i:qnameToURI(.) ! attribute extensionComponentKindURI {.},
        $constraint/@id/attribute constraintComponentID {.},
        $constraint/@label/attribute constraintLabel {.}
    )        
    return
        if ($isValid) then
            <gx:green>{
                $msgOk,
                $constraintIdentAtts,
                $constraint/gx:param/<gx:param>{@*, node()}</gx:param>               
            }</gx:green>
        else
            <gx:error>{
                $msg,
                $constraintIdentAtts,
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
