(:
 : -------------------------------------------------------------------------
 :
 : validate.xqm - validates a file system tree against a greenfox schema.
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="validate" type="node()" func="validateOp">     
         <param name="gfox" type="docFOX" fct_minDocCount="1" fct_maxDocCount="1" sep="WS" pgroup="input"/>
         <param name="domain" type="xs:string?"/>
         <param name="params" type="xs:string?"/>
         <param name="reportType" type="xs:string?" fct_values="white, red, whiteTree, redTree, std" default="redTree"/>
         <param name="format" type="xs:string?" default="xml"/>
         <pgroup name="input" minOccurs="1"/>         
      </operation>
    </operations>  
:)  

module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "compile.xqm",
    "log.xqm",
    "greenfoxEditUtil.xqm",
    "greenFoxValidator.xqm",
    "systemValidator.xqm",
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
        as element() {
    let $domain := tt:getParams($request, 'domain')
    return
        if ($domain and not(file:exists($domain))) then
            error(QName((), 'DOMAIN_NOT_FOUND'),
                concat("Domain folder not found: '", $domain, "'; aborted.'"))
        else
        
    let $gfoxSource := tt:getParams($request, 'gfox')/* 
    return
        if (not($gfoxSource/self::element(gx:greenfox))) then
            f:raiseError_notGreenfoxSchema($gfoxSource) else
    let $gfoxSourceURI := $gfoxSource/root()/document-uri(.)
    let $params := tt:getParams($request, 'params')
    let $reportType := tt:getParams($request, 'reportType')
    let $reportFormat := tt:getParams($request, 'format')
    let $reportOptions := map{}
    
    let $gfoxAndContext := f:compileGreenfox($gfoxSource, i:externalContext($params, $domain))
    let $gfox := $gfoxAndContext[. instance of element()]
    let $_LOG := f:logFile($gfox, 'GFOX.xml')
    let $context := $gfoxAndContext[. instance of map(*)]
    let $gfoxErrors := f:validateGreenfox($gfox)
    return if ($gfoxErrors) then $gfoxErrors else

    let $invalidSchemaReport := i:metaValidateSchema($gfoxSource)
    return if ($invalidSchemaReport) then $invalidSchemaReport else
    
    let $report := i:validateSystem($gfox, $context, $reportType, $reportFormat, $reportOptions)
    return $report
};        

(:~
 : Raises an error in response to a schema which does not have
 : the expected root element name.
 :
 : @param elem root element of what should be a greenfox schema
 : @return throws an error with diagnostic message
 :)
declare function f:raiseError_notGreenfoxSchema($elem as element())
        as empty-sequence() {
    let $namespace := $elem/namespace-uri(.)
    let $lname := $elem/local-name(.)
    let $msgParts := (
        if ($lname ne 'greenfox') then
            'the local name must be "greenfox", but is: "' || $lname || '";' else (),
        if ($namespace ne $i:URI_GX) then
            concat('the namespace URI must be "', $i:URI_GX, '", but is: "' || $namespace || '";') else ()
    )
    let $msg := string-join(('Not a greenfox schema;', $msgParts, 'aborted.'), ' ')                    
    return error(QName('', 'INVALID_ARG'), $msg)        
};        