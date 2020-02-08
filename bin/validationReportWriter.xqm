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
                                         $results as element()*, 
                                         $reportType as xs:string, 
                                         $format as xs:string,
                                         $options as map(*))
        as item()* {
    switch($reportType)
    case "white" return f:writeValidationReport_raw($reportType, $gfox, $domain, $context, $results, $format, $options)
    case "red" return f:writeValidationReport_raw($reportType, $gfox, $domain, $context, $results, $format, $options)
    case "whiteTree" return f:writeValidationReport_whiteTree($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "redTree" return f:writeValidationReport_redTree($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "std" return f:writeValidationReport_whiteTree($gfox, $domain, $context, $results, $reportType, $format, $options)    
    default return error(QName((), 'INVALID_ARG'), concat('Unexpected validation report type: ', "'", $reportType, "'",
        '; value must be one of: raw, whiteTree, redTree.'))
};

declare function f:writeValidationReport_raw(
                                        $reportType as xs:string,
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $format as xs:string,
                                        $options as map(*))
        as item()* {
    let $gfoxSourceURI := $gfox[1]/@xml:base
    let $gfoxSchemaURI := $gfox[1]/@greenfoxURI
    let $useResults := 
        if ($reportType eq 'white') then $results 
        else if ($reportType eq 'red') then $results[self::gx:red, self::gx:yellow, self::gx:error]
        else error()
    let $report :=    
        <gx:validationReport domain="{f:getDomainDescriptor($domain)}"
                             countErrors="{count($results/(self::gx:red, self::gx:error))}" 
                             validationTime="{current-dateTime()}"
                             greenfoxDocumentURI="{$gfoxSourceURI}" 
                             greenfoxSchemaURI="{$gfoxSchemaURI}"
                             reportType="{$reportType}"
                             reportMediatype="application/xml">{
            for $result in $useResults
            order by 
                switch ($result/local-name(.)) 
                        case 'red' return 1
                        case 'error' return 1
                        case 'yellow' return 2 
                        case 'green' return 3 
                        default return 4,
                $result/(@filePath, @folderPath)[1]                        
            return $result
        }</gx:validationReport>
    return
        $report/f:finalizeReport(.)
};

declare function f:writeValidationReport_whiteTree(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $gfoxSourceURI := $gfox[1]/@xml:base
    let $gfoxSchemaURI := $gfox[1]/@greenfoxURI
    let $resourceDescriptors :=        
        for $result in $results        
        let $resourceIdentifier := $result/(@filePath, @folderPath)[1]
        let $resourceIdentifierType := $resourceIdentifier/local-name(.)        
        group by $resourceIdentifier
        let $resourceIdentifierAtt :=
            if (not($resourceIdentifier)) then () else
                let $attName := if (file:is-file($resourceIdentifier)) then 'file' else 'folder'
                return
                    attribute {$attName} {$resourceIdentifier}
        let $red := $result/(self::gx:red, self::gx:error)
        let $yellow := $result/self::gx:yellow
        let $green := $result/self::gx:green
        let $other := $result except ($red, $green)
        let $removeAtts :=('filePath', 'folderPath')
        return
            if ($red) then 
                <gx:redResource>{
                    $resourceIdentifierAtt, 
                    $result/self::gx:error/f:removeAtts(., $removeAtts),
                    $result/self::gx:yellow/f:removeAtts(., $removeAtts),
                    $result/self::gx:green/f:removeAtts(., $removeAtts)
                }</gx:redResource>
            else if ($yellow) then 
                <gx:yellowResource>{
                    $resourceIdentifierAtt/self::gx:yellow/f:removeAtts(., $removeAtts), 
                    $result/self::gx:green/f:removeAtts(., $removeAtts)
                }</gx:yellowResource> 
            else if ($green) then 
                <gx:greenResource>{
                    $resourceIdentifierAtt, 
                    $result/f:removeAtts(., $removeAtts)
                }</gx:greenResource>
            else error()
    let $redResources := $resourceDescriptors/self::gx:redResource
    let $yellowResources := $resourceDescriptors/self::gx:yellowResource    
    let $greenResources := $resourceDescriptors/self::gx:greenResource
    let $report :=
        <gx:validationReport domain="{f:getDomainDescriptor($domain)}"
                             countErrors="{count($results/self::gx:error)}"
                             countWarnings="{count($results/self::gx:yellow)}"
                             countRedResources="{count($redResources)}"
                             countYellowResources="{count($yellowResources)}"                             
                             countGreenResources="{count($greenResources)}"
                             validationTime="{current-dateTime()}"
                             greenfoxDocumentURI="{$gfoxSourceURI}" 
                             greenfoxSchemaURI="{$gfoxSchemaURI}"
                             reportType="{$reportType}"
                             reportMediatype="application/xml">{
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

(:~
 : Writes a 'redTree' report.
 :
 :)
declare function f:writeValidationReport_redTree(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $options := map{}
    let $whiteTree := f:writeValidationReport_whiteTree($gfox, $domain, $context, $results, 'redTree', 'xml', $options)        
    let $redTree := f:whiteTreeToRedTree($whiteTree, $options)
    return $redTree
};

(:~
 : Transforms a 'whiteTree' tree report into a 'redTree' report.
 :
 : @param whiteTree a 'whiteTree' report
 : @param options options controlling the report
 : @return the 'redTree' report
 :) 
declare function f:whiteTreeToRedTree($whiteTree as element(gx:validationReport), 
                                      $options as map(*))
        as element(gx:validationReport) {
    f:whiteTreeToRedTreeRC($whiteTree, $options)        
};

(:~
 : Recursive helper function of 'f:whiteTreeToRedTree'.
 :
 : @param n as node from the 'whiteTree' report
 : @param options options controlling the report
 : @return the representation of the node in the 'redTree' report
 :)
declare function f:whiteTreeToRedTreeRC($n as node(), $options as map(*))
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n ! f:whiteTreeToRedTreeRC(., $options)}
    case element(gx:green) return ()        
    case element(gx:greenResources) return ()

    case element(gx:yellowResources) | element(gx:redResources) return 
        if (not($n//(gx:yellow, gx:red, gx:error))) then ()
        else
            element {node-name($n)} {
                $n/@* ! f:whiteTreeToRedTreeRC(., $options),
                $n/node() ! f:whiteTreeToRedTreeRC(., $options)            
            }

    case element() return
        element {node-name($n)} {
            $n/@* ! f:whiteTreeToRedTreeRC(., $options),
            $n/node() ! f:whiteTreeToRedTreeRC(., $options)            
        }
    case attribute(reportType) return attribute reportType {'redTree'}        
    default return $n        
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

