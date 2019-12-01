(:
 : -------------------------------------------------------------------------
 :
 : validate.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="validate" type="node()" func="validateOp">     
         <param name="gfox" type="docFOX" fct_minDocCount="1" fct_maxDocCount="1" sep="WS" pgroup="input"/>
         <param name="params" type="xs:string?"/>
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
    "systemValidator.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:validateOp($request as element())
        as element() {
    let $gfoxSource := tt:getParams($request, 'gfox')/* 
    let $params := tt:getParams($request, 'params')
    let $gfoxAndContext := f:compileGfox($gfoxSource, i:externalContext($params))
    let $gfox := $gfoxAndContext[. instance of element()]
    let $_LOG := f:logFile($gfox, 'GFOX.xml')
    let $context := $gfoxAndContext[. instance of map(*)]
    let $gfoxErrors := f:validateGreenFox($gfox)
    return
        if ($gfoxErrors) then $gfoxErrors else
        
    let $validationReport := i:validateSystem($gfox, $context)
    let $validationReport :=
        <gx:validationReport countErrors="{count($validationReport//gx:error)}" validationTime="{current-dateTime()}">{
           $gfox/@greenfoxURI,
           for $error in $validationReport//gx:error
           order by $error/@id
           return $error
        }</gx:validationReport>
    return
        $validationReport/i:harmonizePrefixes(., $f:URI_GX, $f:PREFIX_GX) 
};        
