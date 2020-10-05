(:
 : -------------------------------------------------------------------------
 :
 : validationReportWriter.xqm - functions producing validation reports
 :
 : -------------------------------------------------------------------------
 :)
 

module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "compile.xqm",
   "log.xqm",
   "greenfoxEditUtil.xqm",
   "greenfoxUtil.xqm",
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
                                         $results as element()*, 
                                         $reportType as xs:string, 
                                         $format as xs:string,
                                         $options as map(*),
                                         $context as map(xs:string, item()*))
        as item()* {
    let $ccfilter := $options?ccfilter
    let $fnfilter := $options?fnfilter
    let $results := $results[not($ccfilter) or tt:matchesNameFilter(@constraintComp, $ccfilter)]
                            [not($fnfilter) or tt:matchesNameFilter((@filePath, @folderPath)[1] ! replace(., '.*/', ''), $fnfilter)]
    return
    
    switch($reportType)
    case "wresults" return f:writeValidationReport_wresults($reportType, $gfox, $domain, $context, $results, $format, $options)
    case "rresults" return f:writeValidationReport_wresults($reportType, $gfox, $domain, $context, $results, $format, $options)
    case "white" return f:writeValidationReport_white($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "red" return f:writeValidationReport_red($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "sum1" return f:writeValidationReport_sum($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "sum2" return f:writeValidationReport_sum($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "sum3" return f:writeValidationReport_sum($gfox, $domain, $context, $results, $reportType, $format, $options)    
    case "std" return f:writeValidationReport_wresults($gfox, $domain, $context, $results, $reportType, $format, $options)    
    default return error(QName((), 'INVALID_ARG'), concat('Unexpected validation report type: ', "'", $reportType, "'",
        '; value must be one of: sum1, sum2, sum3, red, white, rresults, wresults.'))
};

declare function f:writeValidationReport_wresults(
                                        $reportType as xs:string,
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $format as xs:string,
                                        $options as map(*))
        as item()* {
    let $ccfilter := $options?ccfilter        
    let $fnfilter := $options?fnfilter
    let $gfoxSourceURI := $gfox[1]/@xml:base
    let $greenfoxURI := $gfox[1]/@greenfoxURI
    let $useResults := 
        if ($reportType eq 'wresults') then $results 
        else if ($reportType eq 'rresults') then $results[self::gx:red, self::gx:yellow]
        else error()
    let $report :=    
        <gx:validationReport domain="{f:getDomainDescriptor($domain)}"
                             countErrors="{count($results/(self::gx:red, self::gx:red))}" 
                             validationTime="{current-dateTime()}"
                             greenfoxDocumentURI="{$gfoxSourceURI}" 
                             greenfoxURI="{$greenfoxURI}"
                             reportType="{$reportType}"
                             reportMediatype="application/xml">{
            $ccfilter/@text/attribute constraintCompFilter {.},                             
            $fnfilter/@text/attribute fileNameFilter {.},
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
        (: let $_DEBUG := trace($result, '___RESULT: ') :)
        let $resourceIdentifier := $result/(@filePath, @folderPath)[1]
        let $resourceIdentifierType := $resourceIdentifier/local-name(.)        
        group by $resourceIdentifier
        let $resourceIdentifierAtt :=
            if (not($resourceIdentifier)) then () else
                let $attName := if (i:fox-resource-is-file($resourceIdentifier)) then 'file' else 'folder'
                return
                    attribute {$attName} {$resourceIdentifier}
        let $red := $result/self::gx:red
        let $yellow := $result/self::gx:yellow
        let $green := $result/self::gx:green
        let $whiteRed := $result/self::gx:whiteRed
        let $whiteYellow := $result/self::gx:whiteYellow
        let $whiteGreen := $result/self::gx:whiteGreen
        let $other := ($result except ($red, $yellow, $green, $whiteRed, $whiteYellow, $whiteGreen))/.
        let $removeAtts :=('filePath', 'folderPath')
        return
            if ($red) then 
                <gx:redResource>{
                    $resourceIdentifierAtt, 
                    $result/self::gx:red/f:removeAtts(., $removeAtts),
                    $result/self::gx:yellow/f:removeAtts(., $removeAtts),
                    $result/self::gx:green/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteRed/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteYellow/f:removeAtts(., $removeAtts),                    
                    $result/self::gx:whiteGreen/f:removeAtts(., $removeAtts)
                }</gx:redResource>
            else if ($yellow) then 
                <gx:yellowResource>{
                    $resourceIdentifierAtt,
                    $result/self::gx:yellow/f:removeAtts(., $removeAtts), 
                    $result/self::gx:green/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteRed/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteYellow/f:removeAtts(., $removeAtts),                    
                    $result/self::gx:whiteGreen/f:removeAtts(., $removeAtts)                    
                }</gx:yellowResource> 
            else if ($green) then 
                <gx:greenResource>{
                    $resourceIdentifierAtt, 
                    $result/self::gx:green/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteRed/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteYellow/f:removeAtts(., $removeAtts),                    
                    $result/self::gx:whiteGreen/f:removeAtts(., $removeAtts)                    
                }</gx:greenResource>
            else if ($whiteRed) then 
                <gx:whiteRedResource>{
                    $resourceIdentifierAtt, 
                    $result/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteRed/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteYellow/f:removeAtts(., $removeAtts),                    
                    $result/self::gx:whiteGreen/f:removeAtts(., $removeAtts)                    
                }</gx:whiteRedResource>
            else if ($whiteYellow) then 
                <gx:whiteYellowResource>{
                    $resourceIdentifierAtt, 
                    $result/f:removeAtts(., $removeAtts),
                    $result/self::gx:whiteYellow/f:removeAtts(., $removeAtts),                    
                    $result/self::gx:whiteGreen/f:removeAtts(., $removeAtts)                    
                }</gx:whiteYellowResource>
            else if ($whiteGreen) then 
                <gx:whiteGreenResource>{
                    $resourceIdentifierAtt, 
                    $result/self::gx:whiteGreen/f:removeAtts(., $removeAtts)                    
                }</gx:whiteGreenResource>
            else error()
    let $redResources := $resourceDescriptors/self::gx:redResource
    let $yellowResources := $resourceDescriptors/self::gx:yellowResource    
    let $greenResources := $resourceDescriptors/self::gx:greenResource
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

(:~
 : Writes a 'red' report.
 :
 :)
declare function f:writeValidationReport_red(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $white := f:writeValidationReport_white($gfox, $domain, $context, $results, 'red', 'xml', $options)        
    let $red := f:whiteToRed($white, $options)
    return $red
};

(:~
 : Writes a 'constraintCompStat' report.
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

    let $fn_listResources := function($resources) {
        for $r in $resources
        let $pathAtt := $r/../(@file, @folder)[1]
        let $elemName := ($pathAtt/local-name(.), 'resource')[1]
        order by if ($elemName eq 'folder') then 2 else 1, $pathAtt 
        return element {$elemName}{$pathAtt/string()}
    }    
    let $entries :=
        for $ccomp in $whiteTree//@constraintComp
        group by $ccname := $ccomp/string()
        let $results := $ccomp/..
        let $green := $results/self::gx:green
        let $red := $results/self::gx:red
        order by $ccname
        return
            <constraintComp name="{$ccname}" countRed="{count($red)}" countGreen="{count($green)}">{
                if (not($red)) then () else
                    <redResources>{$fn_listResources($red)}</redResources>,
                if (not($green)) then () else                    
                    <greenResources>{$fn_listResources($green)}</greenResources>
            }</constraintComp>
    let $report :=
        <constraintComps count="{$entries}">{
            $whiteTree/@domain,
            $whiteTree/@greenfoxDocumentURI,
            $whiteTree/@greenfoxURI,
            $whiteTree/@countRed,
            $whiteTree/@countGreen,
            $whiteTree/@countRedResources,
            $whiteTree/@countGreenResources,
            $entries
        }</constraintComps>
    return $report
};

(:~
 : Writes a 'sum*' report.
 :
 :)
declare function f:writeValidationReport_sum(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as item() {
    let $ccfilter := $options?ccfilter
    let $fnfilter := $options?fnfilter
    let $ccstat := f:writeValidationReport_constraintCompStat($gfox, $domain, $context, $results, 'red', 'xml', $options)
    let $ccomps := $ccstat/*
    
    let $countRed := $ccstat/@countRed/xs:integer(.)
    let $countGreen := $ccstat/@countGreen/xs:integer(.)
    let $countRedResources := $ccstat/@countRedResources/xs:integer(.)
    let $countGreenResources := $ccstat/@countGreenResources/xs:integer(.)
    
    let $redResources := 
        for $r in $ccstat//redResources/(folder, file)
        group by $rname := string($r)
        let $kind := if ($r[1]/self::folder) then 'D' else 'F'
        let $ccomps := $r/../../@name => distinct-values() => sort()
        order by $kind, $rname
        return <resource name="{$rname}" kind="{$kind}" ccomps="{$ccomps}"/>
    let $greenResources :=
        for $r in $ccstat//greenResources/(folder, file)
        group by $rname := string($r)
        let $kind := if ($r[1]/self::folder) then 'D' else 'F'
        let $ccomps := $r/../../@name => distinct-values() => sort()
        order by $kind, $rname
        return <resource name="{$rname}" kind="{$kind}" ccomps="{$ccomps}"/>
            
    let $ccompNameWidth := (('constraint comp', $ccomps/@name) !string-length(.)) => max()
    let $countRedWidth := (('#red', $ccomps/@countRed/string()) ! string-length(.)) => max()
    let $countGreenWidth := (('#green', $ccomps/@countGreen/string()) ! string-length(.)) => max()
    let $hsepChar1 := '-'
    let $hsepChar2 := '-'
    let $hsep1 := tt:repeatChar($hsepChar1, $ccompNameWidth + $countRedWidth + $countGreenWidth + 10)
    let $hsep2 :=
        concat('|', $hsepChar1,
               tt:repeatChar($hsepChar2, $ccompNameWidth), $hsepChar2, '|',
               tt:repeatChar($hsepChar2, $countRedWidth), $hsepChar2, $hsepChar2, '|',
               tt:repeatChar($hsepChar2, $countGreenWidth), $hsepChar2, $hsepChar2)
    let $lines := (
        f:displayMsg($gfox),
        '',
        'G r e e n f o x    r e p o r t    s u m m a r y',
        '',
        'greenfox: ' || $ccstat/@greenfoxDocumentURI/i:uriOrPathToNormPath(.),
        'domain:   ' || $ccstat/@domain,
        ' ',
        $ccfilter/@text/concat('>>>>>>&#xA;', 'Constraint comp filter: ', ., '&#xA;>>>>>>&#xA;'),
        $fnfilter/@text/concat('>>>>>>&#xA;', 'Resource name filter:   ', ., '&#xA;>>>>>>&#xA;'),        
        '#red:     ' || $countRed || (if (not($countRed)) then () else concat('   (', $countRedResources, ' resources)')),
        '#green:   ' || $ccstat/@countGreen || (if (not($countGreen)) then () else concat('   (', $countGreenResources, ' resources)')),
        ' ',
        $hsep1,
        '| ' || 
        tt:rpad('Constraint Comp', $ccompNameWidth, ' ') || ' | ' || 
        tt:rpad('#red', $countRedWidth, ' ') || ' | ' || 
        tt:rpad('#green', $countGreenWidth, ' ') || ' |',
        $hsep2,
        for $ccomp in $ccstat/constraintComp
        let $name := $ccomp/@name
        let $countRed := $ccomp/@countRed
        let $countGreen := $ccomp/@countGreen
        return
            concat('| ',
                   tt:rpad($name, $ccompNameWidth, '.'), ' | ', 
                   tt:lpad($countRed, $countRedWidth, ' '), ' | ',
                   tt:lpad($countGreen, $countGreenWidth, ' '),
                   ' |'),
        $hsep1,
        if ($reportType eq 'sum1') then () else (        
            ' ',
            if (empty($redResources)) then () else (
                'Red resources: ',
                $redResources/concat('  ', @kind, ' ', @name, '   (', @ccomps, ')'),
                ' ')
            ,        
            if ($reportType eq 'sum2') then () else (
                    if (empty($greenResources)) then () else (
                    'Green resources: ',
                    $greenResources/concat('  ', @kind, ' ', @name, '   (', @ccomps, ')'),
                    ' ')
                )
        ),
        '',
        ''
    )
    let $report := string-join($lines, '&#xA;')
    return $report
};    

(:~
 : Transforms a 'white' report into a 'red' report.
 :
 : @param whiteTree a 'white' report
 : @param options options controlling the report
 : @return the 'red' report
 :) 
declare function f:whiteToRed($white as element(gx:validationReport), 
                              $options as map(*))
        as element(gx:validationReport) {
    f:whiteToRedRC($white, $options)        
};

(:~
 : Recursive helper function of 'f:whiteToRed'.
 :
 : @param n as node from the 'whiteTree' report
 : @param options options controlling the report
 : @return the representation of the node in the 'red' report
 :)
declare function f:whiteToRedRC($n as node(), $options as map(*))
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n ! f:whiteToRedRC(., $options)}
    case element(gx:green) return ()        
    case element(gx:whiteGreen) return ()
    case element(gx:whiteYellow) return ()
    case element(gx:whiteRed) return ()
    
    case element(gx:greenResources) return ()
    case element(gx:whiteGreenResources) return ()
    case element(gx:whiteYellowResources) return ()
    case element(gx:whiteRedResources) return ()

    case element(gx:yellowResources) | element(gx:redResources) return 
        if (not($n//(gx:yellow, gx:red))) then ()
        else
            element {node-name($n)} {
                $n/@* ! f:whiteToRedRC(., $options),
                $n/node() ! f:whiteToRedRC(., $options)            
            }

    case element() return
        element {node-name($n)} {
            $n/@* ! f:whiteToRedRC(., $options),
            $n/node() ! f:whiteToRedRC(., $options)            
        }
    case attribute(reportType) return attribute reportType {'red'}        
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

declare function f:displayResultResults($resources as element()*)
        as node()* {
    for $r in $resources
    let $file := $r/(@file, @folder)[1]
    return (
        comment {concat('&#xA;&#xA;*** ', $file, '&#xA;&#xA;    ')},
        $r
    )
        
};      

declare function f:displayMsg($gfox as element(gx:greenfox))
        as xs:string? {
    if (not(contains($gfox/base-uri(.), 'declarative-amsterdam-2020/schema/air01.gfox.xml'))) then () else
    (
    '=============================================================================',
    '=                                                                           =',
    '=                   W  E  L  C  O  M  E        A  T                         =',
    '=                                                                           =',
    '=     D  E  C  L  A  R  A  T  I  V  E        A  M  S  T  E  R  D  A  M      =',
    '=                                                                           =',  
    '=                                 2  0  2  0                                =',
    '=                                                                           =',
    '=============================================================================',
    ''
    ) => string-join('&#xA;')
};        
