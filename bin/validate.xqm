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
         <param name="params" type="xs:string?"/>
         <param name="reportType" type="xs:string?" default="std, white, whiteTree, redTree"/>
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
    let $gfoxSource := tt:getParams($request, 'gfox')/* 
    let $gfoxSourceURI := $gfoxSource/root()/document-uri(.)
    let $params := tt:getParams($request, 'params')
    let $reportType := tt:getParams($request, 'reportType')
    let $reportFormat := tt:getParams($request, 'format')
    let $reportOptions := map{}
    
    let $gfoxAndContext := f:compileGreenfox($gfoxSource, i:externalContext($params))
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

(:
(:~
 : Validates the input schema against the greenfox meta schema.
 :
 :)
declare function f:metaValidateSchema($gfoxSource as element(gx:greenfox))
        as element(gx:invalidSchema)? {
    let $gfoxSourceURI := $gfoxSource/root()/document-uri(.)        
    let $metaGfoxSource := doc('../metaschema/gfox-gfox.xml')/*
    let $metaDomain := file:path-to-native($gfoxSourceURI) 
    let $metaGfoxName := $gfoxSourceURI ! replace(., '.*/', '')
    
    let $metaContextSource := map{'domain': $metaDomain, 'gfox': $metaGfoxName}
    let $metaGfoxAndContext := f:compileGreenfox($metaGfoxSource, $metaContextSource)
    let $metaGfox := $metaGfoxAndContext[. instance of element()]
    let $metaContext := $metaGfoxAndContext[. instance of map(*)]
    let $metaReportType := 'redTree'
    let $metaReportFormat := 'xml'
    let $metaReportOptions := map{}
    let $metaReport := i:validateSystem($metaGfox, $metaContext, $metaReportType, $metaReportFormat, $metaReportOptions)   
    return
        if ($metaReport//(gx:error, gx:red)) then 
            <gx:invalidSchema schemaURI="{$gfoxSourceURI}">{$metaReport}</gx:invalidSchema> 
        else ()        
};
:)