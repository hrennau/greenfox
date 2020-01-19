(:
 : -------------------------------------------------------------------------
 :
 : validationReportEditor.xqm - Document me!
 :
 : -------------------------------------------------------------------------
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
 : Writes a validation report.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:writeValidationReport($gfox as element(gx:greenfox)+,
                                         $domain as element(gx:domain),
                                         $context as map(xs:string, item()*),
                                         $perceptions as element()*, 
                                         $reportType as xs:string, 
                                         $format as xs:string,
                                         $options as map(*))
        as item()* {
    switch($reportType)
    case "raw" return f:writeValidationReport_raw($gfox, $domain, $context, $perceptions, $reportType, $format, $options)
    case "std" return f:writeValidationReport_std($gfox, $domain, $context, $perceptions, $reportType, $format, $options)
    default return error()
};

declare function f:writeValidationReport_raw(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $perceptions as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as item()* {
    let $gfoxSourceURI := $gfox[1]/@xml:base
    let $gfoxSchemaURI := $gfox[1]/@greenfoxURI
    let $report :=    
        <gx:validationReport domain="{f:getDomainDescriptor($domain)}"
                             countErrors="{count($perceptions/self::gx:error)}" 
                             validationTime="{current-dateTime()}"
                             greenfoxSchemaDoc="{$gfoxSourceURI}" 
                             greenfoxSchemaURI="{$gfoxSchemaURI}">{
            for $perception in $perceptions
            order by $perception/@id
            return $perception
        }</gx:validationReport>
    return
        $report/f:finalizeReport(.)
};

declare function f:writeValidationReport_std(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $perceptions as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $gfoxSourceURI := $gfox[1]/@xml:base
    let $gfoxSchemaURI := $gfox[1]/@greenfoxURI
    let $resourceDescriptors :=        
        for $perception in $perceptions        
        let $resourceIdentifier := $perception/(@filePath, @folderPath, @contextPath)[1]
        let $resourceIdentifierType := $resourceIdentifier/local-name(.)        
        group by $resourceIdentifier
        let $resourceIdentifierAtt :=
            if (not($resourceIdentifier)) then () else
                let $attName := if (file:is-file($resourceIdentifier)) then 'file' else 'folder'
                return
                    attribute {$attName} {$resourceIdentifier}
        let $red := $perception/self::gx:error
        let $yellow := $perception/self::gx:yellow
        let $green := $perception/self::gx:green
        let $other := $perceptions except ($red, $green)
        (: let $_DEBUG := trace($perception/name() , 'PERCEPTION_NAME: ') :)
        let $removeAtts :=('filePath', 'folderPath', 'contextPath')
        return
            if ($red) then 
                <gx:redResource>{
                    $resourceIdentifierAtt, 
                    $perception/self::gx:error/f:removeAtts(., $removeAtts),
                    $perception/self::gx:yellow/f:removeAtts(., $removeAtts),
                    $perception/self::gx:green/f:removeAtts(., $removeAtts)
                }</gx:redResource>
            else if ($yellow) then 
                <gx:yellowResource>{
                    $resourceIdentifierAtt/self::gx:yellow/f:removeAtts(., $removeAtts), 
                    $perception/self::gx:green/f:removeAtts(., $removeAtts)
                }</gx:yellowResource> 
            else if ($green) then 
                <gx:greenResource>{
                    $resourceIdentifierAtt, 
                    $perception/f:removeAtts(., $removeAtts)
                }</gx:greenResource>
            else error()
    let $redResources := $resourceDescriptors/self::gx:redResource
    let $yellowResources := $resourceDescriptors/self::gx:yellowResource    
    let $greenResources := $resourceDescriptors/self::gx:greenResource
    let $report :=
        <gx:validationReport domain="{f:getDomainDescriptor($domain)}"
                             countErrors="{count($perceptions/self::gx:error)}"
                             countWarnings="{count($perceptions/self::gx:yellow)}"
                             countRedResources="{count($redResources)}"
                             countYellowResources="{count($yellowResources)}"                             
                             countGreenResources="{count($greenResources)}"
                             validationTime="{current-dateTime()}"
                             greenfoxSchemaDoc="{$gfoxSourceURI}" 
                             greenfoxSchemaURI="{$gfoxSchemaURI}"
                             reportType="{$reportType}"
                             reportFormat="{$format}">{
            <gx:redResources>{
                attribute count {count($redResources)},
                $redResources
            }</gx:redResources>,
            <gx:yellowResources>{
                attribute count {count($redResources)},
                $yellowResources
            }</gx:yellowResources>,
            <gx:greenResources>{
                attribute count {count($greenResources)},
                $greenResources
            }</gx:greenResources>
        }</gx:validationReport>
    return
        $report/f:finalizeReport(.)
};

declare function f:removeAtts($elem as element(),
                             $attName as xs:string+) 
        as element() {
    element {node-name($elem)} {
        $elem/@*[not(local-name(.) = $attName)],
        $elem/node()
    }
};
declare function f:finalizeReport($report as node()) as node() {
    f:finalizeReportRC($report)
};

declare function f:finalizeReportRC($n as node()) as node()? {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:finalizeReportRC(.)}
    case element() return
        let $normName := if (not($n/namespace-uri($n) eq $i:URI_GX)) then node-name($n)
                         else QName($i:URI_GX, string-join(($i:PREFIX_GX, $n/local-name(.)), ':'))
        return
            element {$normName} {
                $n/@* ! f:finalizeReportRC(.),
                in-scope-prefixes($n)[string()] ! namespace {.} {namespace-uri-for-prefix(., $n)},
                $n/node() ! f:finalizeReportRC(.)
            }
    case text() return
        if ($n/../* and not($n/matches(., '\S'))) then () else $n
    default return $n
};

(:~
 : Returns a string describing the domain.
 :)
declare function f:getDomainDescriptor($domain as element(gx:domain))
        as xs:string {
    $domain/@path/replace(., '\\', '/')        
};

