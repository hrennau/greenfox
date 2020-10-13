(:
 : -------------------------------------------------------------------------
 :
 : greenfoxValidator.xqm - validates a greenfox schema
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
   "tt/_nameFilter.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions"  
at "constants.xqm",
   "fileValidator.xqm",
   "greenfoxUtil.xqm",
   "uriUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateGreenfox($schema as element(gx:greenfox)) 
        as element()* {
    let $domain := $schema/gx:domain/@path
    let $_CHECK_DOMAIN := f:check_domainFolderExists($schema)

    let $potentialBindings_base := ('this', 'doc', 'xdoc', 'jdoc', 'csvdoc', 'fileName', 'filePath', 'domain', 'domainName')

    let $errors := (
        (: Collect XPath expressions :)
        let $xpathExpressions := (
            for $xpath in $schema//gx:xpath[not(ancestor-or-self::*[@deactivated eq 'true'])]
            return $xpath/(
                @expr,
                @*[matches(local-name(.), 'XPath$', 'i')][not(matches(local-name(.), 'foxpath$', 'i'))]
            ),             
            for $foxpath in $schema//gx:foxpath[not(ancestor-or-self::*[@deactivated eq 'true'])]
            return $foxpath/(
                @*[matches(local-name(.), 'XPath$', 'i')][not(matches(local-name(.), 'foxpath$', 'i'))]
            ),             
            $schema//gx:focusNode[not(ancestor-or-self::*[@deactivated eq 'true'])]/@xpath,
            $schema//gx:linkDef/(@linkContextXP, @linkTargetXP, @hrefXP, @uriXP, @linkXP),
            $schema//gx:constraintComponent/(@validatorXPath, gx:validatorXPath)
        )
        
        for $expr in $xpathExpressions
        
        (: Determine potential bindings :)        
        let $potentialBindings := 
            if ($expr/(self::gx:validatorXPath, self::attribute(validatorXPath))) then
                let $paramNames := $expr/parent::gx:constraintComponent/gx:param/@name
                return
                    ($potentialBindings_base, $paramNames) => distinct-values()
            else $potentialBindings_base
        return
            try {
                (: Add prolog :)
                let $requiredBindings := i:determineRequiredBindingsXPath($expr, $potentialBindings)
                let $augmentedExpr := i:finalizeQuery($expr, $requiredBindings)
                
                (: Try parsing :)
                let $plan := xquery:parse($augmentedExpr)
                return ()
            } catch * {
                let $exprDisp := normalize-space($expr)
                return
                    <gx:red code="INVALID_XPATH" 
                            msg="Invalid XQuery expression" 
                            expr="{$exprDisp}" 
                            file="{base-uri($expr/..)}" 
                            loc="{$expr/f:greenfoxLocation(.)}">{
                        $err:code ! attribute err:code {.},
                        $err:description ! attribute err:description {.},
                        $err:value ! attribute err:value {.},
                        ()
                    }</gx:red>
            }         
        ,
        (: Collect Foxpath expressions :)
        let $foxpathExpressions := (
            for $foxpath in $schema//gx:foxpath[not(ancestor-or-self::*[@deactivated eq 'true'])]
            return $foxpath/(
                @expr,
                @*[matches(local-name(.), 'Foxpath$', 'i')]
            ),             
            for $xpath in $schema//gx:xpath[not(ancestor-or-self::*[@deactivated eq 'true'])]
            return $xpath/(
                @*[matches(local-name(.), 'Foxpath$', 'i')]
            ),             
            $schema//gx:focusNode[not(ancestor-or-self::*[@deactivated eq 'true'])]/@foxpath,
            $schema//gx:linkDef/@foxpath,
            $schema//gx:constraintComponent/(@validatorFoxpath, gx:validatorFoxpath)
        )
        
        for $expr in $foxpathExpressions
        
        (: Determine potential bindings :)        
        let $potentialBindings := 
            if ($expr/(self::gx:validatorFoxpath, self::attribute(validatorFoxpath))) then
                let $paramNames := $expr/parent::gx:constraintComponent/gx:param/@name
                return
                    ($potentialBindings_base, $paramNames) => distinct-values()
            else $potentialBindings_base
        return
            try {
                (: Add prolog :)
                let $requiredBindings := i:determineRequiredBindingsFoxpath($expr, $potentialBindings)
                let $augmentedExpr := i:finalizeQuery($expr, $requiredBindings)
                
                (: Try parsing :)
                let $plan := f:parseFoxpath($augmentedExpr)
                return ()
            } catch * {
                let $exprDisp := normalize-space($expr)
                return
                    <gx:red code="INVALID_FOXPATH" 
                            msg="Invalid Foxpath expression" 
                            expr="{$exprDisp}" 
                            file="{base-uri($expr/..)}" 
                            loc="{$expr/f:greenfoxLocation(.)}">{
                        $err:code ! attribute err:code {.},
                        $err:description ! attribute err:description {.},
                        $err:value ! attribute err:value {.},
                        ()
                    }</gx:red>
            }                
(:        
        let $foxpathExpressions := $gfox/descendant-or-self::*[not(ancestor-or-self::*[@deactivated eq 'true'])]/@foxpath
        for $expr in $foxpathExpressions        
        let $plan := f:parseFoxpath($expr)
        
        return
            if ($plan/self::*:errors) then
                <gx:red code="INVALID_FOXPATH" msg="Invalid foxpath expression" expr="{$expr}" file="{base-uri($expr/..)}" loc="{$expr/f:greenfoxLocation(.)}">{
                    $plan
                }</gx:red>
:)                
    )
    return
        <gx:invalidGreenfox countErrors="{count($errors)}" xmlns:err="http://www.w3.org/2005/xqt-errors">{$errors}</gx:invalidGreenfox>[$errors]
};

(:~
 : Validates the input schema against the greenfox meta schema.
 :
 :)
declare function f:metaValidateSchema($gfoxSource as element(gx:greenfox))
        as element(gx:invalidSchema)? {
    let $gfoxSourceURI := $gfoxSource/root()/document-uri(.)
    
    let $metaGfoxPath := $i:PATH_METASCHEMA
                         ! f:normalizeAbsolutePath(.)
                         ! file:path-to-native(.)   (: URI turned into path :)    
    let $metaGfoxSource := doc($metaGfoxPath)/*
    
    let $paramGfox := i:pathToNative($gfoxSourceURI) 
    let $metaGfoxAndContext := f:compileGreenfox($metaGfoxSource, 'gfox=' || $paramGfox, ())
    let $metaGfox := $metaGfoxAndContext[. instance of element()]
    let $metaContext := $metaGfoxAndContext[. instance of map(*)]
    let $metaReportType := 'red'
    let $metaReportFormat := 'xml'
    let $metaReportOptions := map{}
    let $metaReport := i:validateSystem($metaGfox, $metaContext, $metaReportType, $metaReportFormat, $metaReportOptions)   
    return
        if ($metaReport//gx:red) then 
            <gx:invalidSchema schemaURI="{$gfoxSourceURI}">{$metaReport}</gx:invalidSchema> 
        else ()        
};

declare function f:greenfoxLocation($node as node()) as xs:string {
    (
        for $node in $node/ancestor-or-self::node()
        let $index := 1 + $node/count(preceding-sibling::*[node-name(.) eq $node/node-name(.)])
        return
            if ($node/self::attribute()) then $node/concat('@', local-name(.))
            else if ($node/self::element()) then $node/concat(local-name(.), '[', $index, ']')
            else ''            
    ) => string-join('/')
};

(:~
 : Checks if the domain folder exists, raises an error otherwise.
 :
 : @param domain the domain folder
 : @return throws an error with diagnostic message
 :)
declare function f:check_domainFolderExists($gfox as element(gx:greenfox))
        as empty-sequence() {
    let $domain := $gfox//gx:domain/@path
    let $domainUri := i:pathToUriCompatible($domain)
    return
        if (starts-with($domain, 'basex://')) then
            let $value := f:evaluateFoxpath($domain, (), map{}, false())
            return
                if (exists($value)) then () 
                else
                    let $errorCode := 'DOMAIN_NOT_FOUND'
                    let $msg := concat("Domain database not found: '", $domain, "'; aborted.'")
                    return error(QName((), $errorCode), $msg)
        else
        if (not(i:fox-resource-exists($domainUri))) then
            let $errorCode := 'DOMAIN_NOT_FOUND'
            let $msg := concat("Domain folder not found: '", $domain, "'; aborted.'")
            return error(QName((), $errorCode), $msg)
        else if (i:fox-resource-is-file($domainUri)) then
            let $errorCode := 'DOMAIN_IS_NOT_A_FOLDER'
            let $msg := concat("Domain folder not found: '", $domain, "'; aborted.'")
            return error(QName((), $errorCode), $msg)
        else ()
};


