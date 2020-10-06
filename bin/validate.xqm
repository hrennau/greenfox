(:
 : -------------------------------------------------------------------------
 :
 : validate.xqm - validates a file system tree against a greenfox schema.
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="validate" type="item()" func="validateOp">     
         <param name="gfox" type="docFOX" fct_minDocCount="1" fct_maxDocCount="1" sep="WS" pgroup="input"/>
         <param name="domain" type="xs:string?"/>
         <param name="params" type="xs:string?"/>
         <param name="reportType" type="xs:string?" fct_values="sum1, sum2, sum3, red, white, wresults, rresults, std" default="sum2"/>
         <param name="ccfilter" type="nameFilter?"/>         
         <param name="fnfilter" type="nameFilter?"/>
         <param name="format" type="xs:string?" default="xml"/>
         <pgroup name="input" minOccurs="1"/>         
      </operation>
    </operations>  
:)  

module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_constants.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "compile.xqm",
   "greenfoxSchemaValidator.xqm",    
   "log.xqm",
   "greenfoxEditUtil.xqm",
   "systemValidator.xqm",
   "uriUtil.xqm",
   "validationReportWriter.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Implements the operation 'validate'.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:validateOp($request as element())
        as item() {
        
    (: Preliminary checks :)        
    let $gfoxSource := tt:getParams($request, 'gfox')/*    
    let $_CHECK := f:check_greenfoxSchemaRoot($gfoxSource)
    
    (: Collect parameters :)
    let $gfoxSourceURI := $gfoxSource/root()/document-uri(.)
    let $domain := tt:getParams($request, 'domain')    
    let $params := tt:getParams($request, 'params')
    let $reportType := tt:getParams($request, 'reportType')
    let $ccfilter := tt:getParams($request, 'ccfilter')
    let $fnfilter := tt:getParams($request, 'fnfilter')    
    let $reportFormat := tt:getParams($request, 'format')
    let $reportOptions := map{'ccfilter': $ccfilter, 'fnfilter': $fnfilter}

    (: Compile greenfox schema :)
    let $gfoxAndContext := f:compileGreenfox($gfoxSource, $params, $domain)
    let $context := $gfoxAndContext?context
    let $gfoxVarsSubstituted := $gfoxAndContext?schemaPrelim
    let $gfoxCompiled := $gfoxAndContext?schemaCompiled
    (:
    let $gfox := $gfoxAndContext[. instance of element()]
    let $context := $gfoxAndContext[. instance of map(*)]
     :)
    let $xsdInvalidSchemaReport := f:xsdValidateSchema($gfoxSource, $gfoxVarsSubstituted)
    return if ($xsdInvalidSchemaReport) then $xsdInvalidSchemaReport else

    (: let $_LOG := i:DEBUG_FILE($gfoxCompiled, 0, 'GFOX.xml'):)
    
    (: Validate greenfox schema :)
    let $gfoxErrors := f:validateGreenfox($gfoxCompiled)
    return if ($gfoxErrors) then $gfoxErrors else

    (: Validate greenfox schema against meta schema :)
    let $invalidSchemaReport := () (: i:metaValidateSchema($gfoxSource) :)
    return if ($invalidSchemaReport) then $invalidSchemaReport else
    
    (: Validate system :)
    let $report := i:validateSystem($gfoxCompiled, $context, $reportType, $reportFormat, $reportOptions)
    return $report
};        

(:~
 : Checks if the greenfox schema has the expected root element, raises
 : an error otherwise.
 :
 : @param elem root element of what should be a greenfox schema
 : @return throws an error with diagnostic message
 :)
declare function f:check_greenfoxSchemaRoot($gfox as element())
        as empty-sequence() {
    if ($gfox/self::element(gx:greenfox)) then () else
        
    let $namespace := $gfox/namespace-uri(.)
    let $lname := $gfox/local-name(.)
    let $msgParts := (
        if ($lname ne 'greenfox') then
            'the local name must be "greenfox", but is: "' || $lname || '";' else (),
        if ($namespace ne $i:URI_GX) then
            concat('the namespace URI must be "', $i:URI_GX, '", but is: "' || $namespace || '";') else ()
    )
    let $errorCode := 'INVALID_ARG'
    let $msg := string-join(('Not a greenfox schema;', $msgParts, 'aborted.'), ' ')                    
    return error(QName('', $errorCode), $msg)        
};

(:~
 : Checks if the greenfox schema is XSD valid.
 :
 : @param gfox the schema
 : @param gfoxVarsSubstituted copy of the schema with variables substituted
 : @return an error report, or the empty sequence if no errors were found
 :)
declare function f:xsdValidateSchema($gfox as element(), 
                                     $gfoxVarsSubstituted)
        as element(gx:invalidSchema)? {

    (:
    let $greenfoxXsd := (resolve-uri('') || '/../../xsd/greenfox.xsd')
                        ! file:path-to-native(.)   (: URI turned into path :)
                        ! f:normalizeAbsolutePath(.)
     :)
    let $greenfoxXsd := (resolve-uri('') || '/../../xsd/greenfox.xsd')
                        ! f:normalizeAbsolutePath(.)
                        ! file:path-to-native(.)   (: URI turned into path :)
                        
    let $gfoxSourceURI := $gfox/root()/document-uri(.)
    let $report := 
        let $useXsd :=
            if ($gfox//(@* except @domain)[matches(., '\{\i\c*\}')]) then
                let $gfoxVarsSubstitutedText := serialize($gfoxVarsSubstituted, map{'method': 'xml'})
                (: let $_WRITE := file:write('GFOX_VAR_SUBST.xml', $gfoxVarsSubstitutedText ! parse-xml(.), map{'method': 'xml'}):)
                return $gfoxVarsSubstitutedText
            else
                $gfox
        return
            validate:xsd-report($useXsd, $greenfoxXsd)
    return 
        if ($report/status eq 'valid') then () else 
            f:xsdReportToXsdGreenfoxReport($report, $gfoxSourceURI)
};

declare function f:xsdReportToXsdGreenfoxReport($report as element(), $schemaURI as xs:string)
        as element(gx:invalidSchema)? {
    let $msgs :=
        for $msg in $report/(* except status)
        return
            <gx:message>{
                $msg/@line,
                $msg/@column,
                $msg/@level[. ne 'Error'],
                $msg/string()
            }</gx:message>
    return            
        <gx:invalidSchema validation="xsd" name="{$schemaURI}">{
            $msgs
        }</gx:invalidSchema>        
            
};        
