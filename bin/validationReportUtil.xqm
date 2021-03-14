 (: -------------------------------------------------------------------------
  :
  : validationReportUtil.xqm - utility functions supporting the writing of validation reports
  :
  : -------------------------------------------------------------------------
  :)
 

module namespace f="http://www.greenfox.org/ns/xquery-functions/validation-report/util";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "compile.xqm",
   "log.xqm",
   "greenfoxEditUtil.xqm",
   "greenfoxUtil.xqm",
   "systemValidator.xqm";

import module namespace msg="http://www.greenfox.org/ns/xquery-functions/msg" 
at "msgUtil.xqm";

declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns the validation results received as input, with a comment
 : inserted before each one.
 :
 : @param resources a sequence of validation results
 : @return the results, with comments inserted
 :)
declare function f:displayResultResults($resources as element()*)
        as node()* {
    for $r in $resources
    let $file := $r/(@file, @folder)[1]
    let $file := $file ! replace(., '--', '`-`-`')
    return (
        comment {concat('&#xA;&#xA;*** ', $file, '&#xA;&#xA;    ')},
        $r
    )
        
};      

(:~
 : Finalizes a validation report.
 :
 : @param report a preliminary validation report
 : @return the finalized report
 :)
declare function f:finalizeReport($report as node()) as node() {
    f:finalizeReportRC($report)
};

(:~
 : Recursive helper function supporting function `finalizeReport`.
 :
 : @param n a node to be processed
 : @return the finalized node
 :) 
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
 : Returns a string describing the domain resource.
 :
 : @param domain a Greenfox domain element
 : @return a string describing the domain
 :)
declare function f:getDomainDescriptor($domain as element(gx:domain))
        as xs:string {
    $domain/(@uri, @path)[1]/replace(., '\\', '/')        
};

(:~
 : Returns a copy of an element with attributes removed.
 :
 : @param elem an element node
 : @param attNames the local names of attributes to be removed 
 : @return a copy of the element with the attributes removed
 :)
declare function f:removeAtts($elem as element(),
                             $attNames as xs:string+) 
        as element() {
    element {node-name($elem)} {
        $elem/@*[not(local-name(.) = $attNames)],
        $elem/node()
    }
};

(:~
 : Writes a report, 'constraintComponentStatistics'. The report yields for each
 : constraint component the URIs of the resources checked against that component, 
 : grouped by color.
 :
 : Structure, example:
 :
 : <constraintComps count="3" ...>
 :   <constraintComp name="LinkTargetDocsCount" countRed="1" countGreen="17">
 :     <redResources>
 :       <file uri="C:/projects/tspre-works/output-rest/rest-package-AlertNotification/v_2102d---r_1/cf_configuration_api.xsd">
 :           <msg>No link target document: [link-name=msgReport]</msg>
 :         </file>
 :       </redResources>
 :       <greenResources>
 :         <file uri="C:/tspre-works/output-rest/rest-package-AlertNotification/v_2102d---r_1/cf_configuration_api.xsd"/>
 :         <file uri="C:/tspre-works/output-rest/rest-package-AlertNotification/v_2102d---r_1/neo_configuration_api.xsd"/>
 :         <file uri="C:/tspre-works/output-rest/rest-package-authtrustmgmnt/v_2102d---r_1/TrustConfigurationAPI.xsd"/>
 :       </greenResources>
 :    </constraintComp>
 :    <constraintComp name="LinksLinkResolution" countRed="1" countGreen="0">
 :        <redResources>
 :            <file uri="C:/tspre-works/output-rest/rest-package-AlertNotification/v_2102d---r_1/cf_configuration_api.xsd">
 :                <msg>(under construction: default msg for LinksLinkResolution result)</msg>
 :            </file>
 :        </redResources>
 :    </constraintComp>
 : </constraintComps>    
 :
 :)
declare function f:writeValidationReport_constraintCompStat(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $options := map{}
    let $whiteTree := f:writeValidationReport_white($gfox, $domain, $context, $results, 'red', 'xml', $options)

    let $fn_listResources := function($results, $withMsgs) {
        for $r in $results
        let $uriAtt := $r/../(@file, @folder)[1]
        group by $uri := string($uriAtt)
        let $elemName := ($uriAtt[1]/local-name(.), 'resource')[1]
        let $msgs := if (not($withMsgs)) then () else (
            for $result in $r
            return $r/(@msg/string(), msg:defaultMsg(.))[1]        
            ) => distinct-values() => sort()
        order by if ($elemName eq 'folder') then 2 else 1, $uri 
        return 
            element {$elemName}{
                attribute uri {$uri},
                $msgs ! <msg>{.}</msg>
            }         
    }    
    let $constraintComps :=
        for $ccomp in $whiteTree//@constraintComp
        group by $ccname := $ccomp/string()
        let $results := $ccomp/..
        let $green := $results/self::gx:green
        let $red := $results/self::gx:red
        order by $ccname
        return
            <constraintComp name="{$ccname}" countRed="{count($red)}" countGreen="{count($green)}">{
                if (not($red)) then () else
                    <redResources>{$fn_listResources($red, true())}</redResources>,
                if (not($green)) then () else                    
                    <greenResources>{$fn_listResources($green, false())}</greenResources>
            }</constraintComp>
    let $report :=
        <constraintComps count="{count($constraintComps)}">{
            $whiteTree/@domain,
            $whiteTree/@greenfoxDocumentURI,
            $whiteTree/@greenfoxURI,
            $whiteTree/@countRed,
            $whiteTree/@countGreen,
            $whiteTree/@countRedResources,
            $whiteTree/@countGreenResources,
            $constraintComps
        }</constraintComps>
    return $report
};

(:~
 : Writes a report, report type 'white'.
 :)
declare function f:writeValidationReport_white(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $ccfilter := $options?ccfilter 
    let $fnfilter := $options?fnfilter
    let $gfoxSourceURI := $gfox[1]/@xml:base
    let $greenfoxURI := $gfox[1]/@greenfoxURI
    let $resourceDescriptors :=        
        for $result in $results  
        let $resourceIdentifier := $result/(@filePath, @folderPath)[1]
        let $resourceIdentifierType := $resourceIdentifier/local-name(.)    
        
        (: Group results by resource :)
        group by $resourceIdentifier
        
        (: Write a @file or @folder attribute :)
        let $resourceIdentifierAtt :=
            if (not($resourceIdentifier)) then () else
                let $attName := 
                    if (i:fox-resource-is-file($resourceIdentifier)) then 'file' 
                    else 'folder'
                return attribute {$attName} {$resourceIdentifier}
                
        (: Write a resource element named after the 'worst' result :)
        let $red := $result/self::gx:red
        let $yellow := $result/self::gx:yellow
        let $green := $result/self::gx:green
        let $whiteRed := $result/self::gx:whiteRed
        let $whiteYellow := $result/self::gx:whiteYellow
        let $whiteGreen := $result/self::gx:whiteGreen
        let $other := ($result except 
            ($red, $yellow, $green, $whiteRed, $whiteYellow, $whiteGreen))/.
        let $orderedResults := ($red, $yellow, $green, $whiteRed, $whiteYellow, $whiteGreen, $other)            
        let $removeAtts :=('filePath', 'folderPath')
        let $orderedResultsPruned := $orderedResults ! f:removeAtts(., $removeAtts)
        let $resourceElemName :=
            if ($red) then 'gx:redResource'
            else if ($yellow) then 'gx:yellowResource'
            else if ($green) then 'gx:greenResource'
            else if ($whiteRed) then 'gx:whiteRedResource'
            else if ($whiteYellow) then 'gx:whiteYellowResource'
            else if ($whiteGreen) then 'gx:whiteGreenResource'
            else error(QName((), 'SYSTEM_ERROR'), concat('Unexpected result colour: ', $result/name()))
        return
            element {$resourceElemName} {
                    $resourceIdentifierAtt,
                    $orderedResultsPruned}

    (: Collect resource elements by category (red, green, ... :)        
    let $redResources := $resourceDescriptors/self::gx:redResource
    let $yellowResources := $resourceDescriptors/self::gx:yellowResource    
    let $greenResources := $resourceDescriptors/self::gx:greenResource
    
    (: Write report :)    
    let $report :=
        <gx:validationReport domain="{f:getDomainDescriptor($domain) ! i:uriOrPathToNormPath(.)}"
                             countRed="{count($results/self::gx:red)}"
                             countYellow="{count($results/self::gx:yellow)}"
                             countGreen="{count($results/self::gx:green)}"
                             countRedResources="{count($redResources)}"
                             countYellowResources="{count($yellowResources)}"                             
                             countGreenResources="{count($greenResources)}"
                             validationTime="{current-dateTime()}"
                             greenfoxDocumentURI="{$gfoxSourceURI ! i:uriOrPathToNormPath(.)}" 
                             greenfoxURI="{$greenfoxURI}"
                             reportType="{$reportType}"
                             reportMediatype="application/xml">{
            $ccfilter/@text/attribute constraintCompFilter {.},    
            $fnfilter/@text/attribute fileNameFilter {.},
            <gx:redResources>{
                attribute count {count($redResources)},
                f:displayResultResults($redResources)
            }</gx:redResources>,
            <gx:yellowResources>{
                attribute count {count($yellowResources)},
                f:displayResultResults($yellowResources)
            }</gx:yellowResources>,
            <gx:greenResources>{
                attribute count {count($greenResources)},
                f:displayResultResults($greenResources)
            }</gx:greenResources>
        }</gx:validationReport>
    return
        $report/f:finalizeReport(.)
};

