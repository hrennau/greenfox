(:
 : -------------------------------------------------------------------------
 :
 : validationReportMerger.xqm - functions merging validation reports
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="merge" type="element()" func="mergeOp">     
         <param name="gfox" type="docFOX" fct_minDocCount="1" sep="WS"/>
         <param name="reportType" type="xs:string?" fct_values="white, red, wresults, rresults, std" default="red"/>
      </operation>
    </operations>  
:)  
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm",
    "resourceAccess.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Implements the operation 'validate'.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:mergeOp($request as element())
        as element() {
        
    (: Preliminary checks :)        
    let $gfox := tt:getParams($request, 'gfox')/*    
    let $reportType := tt:getParams($request, 'reportType')
    return
        f:merge($gfox, $reportType)    
};

declare function f:merge($gfox as element()+, $reportType as xs:string)
        as element() {

    let $prefixMap :=
        map:merge(
            for $nsdesc in $gfox/@greenfoxURI => distinct-values() => sort() => f:_getPrefixTnsPairs()
            let $prefix := substring-before($nsdesc, ':')
            let $uri := substring-after($nsdesc, ':')
            return map:entry($uri, $prefix)
        )
    let $results :=        
        for $gfox in $gfox
        let $uri := $gfox/@greenfoxURI
        let $prefix := $uri ! $prefixMap(.)
        let $results := $gfox//(gx:red, gx:yellow, gx:green)
        for $result in $results
        let $filePath := $result/../(@folder, @file)
        return
            element {node-name($result)} {
                $filePath,
                for $att in $result/@*
                return
                    typeswitch($att)
                    case attribute(constraintID) return
                        attribute constraintIRI {$prefix || ':' || $att}
                    case attribute(resourceID) return
                        attribute resourceIRI {$prefix || ':' || $att}
                    case attribute(valueShapeID) return
                        attribute valueShapeIRI {$prefix || ':' || $att}
                    default return $att,
                $result/node()                
            }
    let $resources :=
        for $result in $results
        group by $filePath := $result/(@file, @folder)
        let $result1 := $result[1]
        let $filePathAtt := $result1/(@file, @folder)/attribute {local-name(.)} {.}
        let $colour := $result1/local-name(.)
        order by (if ($colour eq 'red') then 1 
                 else if ($colour eq 'yellow') then 2 
                 else 3), 
                 $filePath            
        return
            element {'gx:'||$colour||'Resource'} {
                $filePathAtt,
                for $r in $result
                let $colour := $r/local-name(.)
                order by if ($colour eq 'red') then 1 else if ($colour eq 'yellow') then 2 else 3
                return
                    element {node-name($r)} {
                        $r/(@* except @file, @folder),
                        $r/node()
                    }
            }
    let $red := $results/self::gx:red
    let $countRed := count($red)
    let $redResources := $resources/self::gx:red
    let $countRedResources := count($redResources)   
    
    let $countYellowResources := $gfox/@countYellowResources => sum()
    let $countGreenResources := $gfox/@countGreenResources => sum()
    return 
        <gx:validationReport xmlns:gx="http://www.greenfox.org/ns/schema"
                             xmlns:xs="http://www.w3.org/2001/XMLSchema"
                             countRed="{$countRed}" 
                             countRedResources="{$countRedResources}"
                             countYellowResources="{$countYellowResources}"
                             countGreenResources="{$countGreenResources}">{
            <gx:greenfoxSchemas>{
                $gfox/<xs:greenfoxSchema documentURI="{@greenfoxDocumentURI}" 
                                         greenfoxURI="{@greenfoxURI}"
                                         greenfoxPrefix="{@greenfoxURI ! $prefixMap(.)}"
                                         countRed="{@countRed}"/>
            }</gx:greenfoxSchemas>,
            $resources
        }</gx:validationReport>
};  

(:~
 : Returns for a sequence of namespace URIs the
 : normalized prefixes. For each namespace a 
 : colon-separated concatenation of prefix and 
 : namespace URI is returned. Normalized prefixes
 : are the lower case letters corresponding to the
 : position of the namespace URI within the list
 : of namespace URIs. If the position is gt 25, 
 : the letters are reused and a suffix
 : is appended which indicates the number of
 : the current letter cycle (2, 3, ...). 
 : The prefixses therefore are:
 : 'a', 'b', 'c', ..., 'x', 'y', 'a2', 'b2', .....
 :
 : @tnss the target namespaces
 : @return the prefix/tns pairs
 :)
declare function f:_getPrefixTnsPairs($tnss as xs:string*) 
      as xs:string* {
   for $tns at $pos in $tnss
   let $seriesNr := ($pos - 1) idiv 25
   let $postfix := if (not($seriesNr)) then () else $seriesNr + 1
   let $p := 1 + ($pos - 1) mod 25
   let $char := substring('abcdefghijklmnopqrstuvwxy', $p, 1)
   let $prefix := concat($char, $postfix)
   where not($tns eq 'http://www.w3.org/XML/1998/namespace')
   return concat($prefix, ':', $tns)
};
