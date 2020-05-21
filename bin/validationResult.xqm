(:
 : -------------------------------------------------------------------------
 :
 : validationReportEditor.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 

module namespace f="http://www.greenfox.org/ns/xquery-functions/validation-result";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxEditUtil.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Maps a value causing a constraint violation to a sequence of
 : 'value' or 'valueNodePath' elements.
 :
 : @param value the offending value
 : @param valueShape a shape or constraint element which may control the value representation
 : @return elements representing the offending value
 :) 
declare function f:validationResultValues($value as item()*, 
                                          $controller as element())
        as element()* {
    let $reporterXPath := $controller/@reporterXPath        
    return
        if ($reporterXPath) then
            for $item in $value
            let $rep := i:evaluateSimpleXPath($reporterXPath, $item)    
            return
                <gx:value>{$rep}</gx:value>
        else
            for $item in $value
            return
                typeswitch($item)
                case xs:anyAtomicType | attribute() return string($item) ! <gx:value>{.}</gx:value>
                case element() return
                    if ($item/not((@*, *))) then string ($item) ! <gx:value>{.}</gx:value>
                    else <gx:valueNodePath>{i:datapath($item)}</gx:valueNodePath>
                default return ()                
};     

(:~
 : Creates a validation result for a LinksResolvable constraint.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param ldo link definition element
 : @param constraintElem constraint element, defining constraints which may override
 :   any constraints specified by the link definition element
 : @param failures link resolution elements indicating a failed link resolution
 : @param successes link resolution elements indicating a successful link resolution
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_linksResolvable($ldo as map(*)?,
                                                    $constraintElem as element(),
                                                    $contextNode as node(),
                                                    $lros as map(*)*,
                                                    $contextInfo as map(xs:string, item()*),
                                                    $options as map(*)?)
        as element() {
        
    (: Successful and failing link resolutions :)
    let $failures := $lros[?errorCode]
    let $successes := $lros[not(?errorCode)]    
    let $colour := if (exists($failures)) then 'green' else 'red'
    
    (: Recursive flag :)
    let $recursiveAtt := ($constraintElem/@recursive, $ldo?recursive ! attribute recursive {.})[1]
    
    (: Values - link values of failing links :)
    let $values :=  
        if (empty($failures)) then () 
        else if ($recursiveAtt eq 'true') then 
            $failures ! <gx:value where="{?contextURI}">{?linkValue}</gx:value>
        else 
            $failures ! <gx:value>{?linkValue}</gx:value>
    
    (: Link name :)
    let $relAtt := $ldo?relName ! attribute rel {.}
    
    (: Link expression attributes :)
    let $exprAtts := ( 
        ($constraintElem/@linkXP, $ldo?linkXP ! attribute linkXP {.})[1],        
        ($constraintElem/@linkContextXP, $ldo?linkContextXP ! attribute linkContextXP {.})[1],
        ($constraintElem/@linkTargetXP, $ldo?linkTargetXP ! attribute linkTargetXP {.})[1]
    )
    
    (: Counts of successful and failing link resolutions :)
    let $failures := $lros[?errorCode]
    let $successes := $lros[not(?errorCode)]    
    let $countResolved := attribute countResolved {count($successes)} 
    let $countUnresolved := attribute countUnresolved {count($failures)}
    
    (: Component identification :)
    let $constraintComp := 'LinkResolvable'
    let $valueShapeId := $constraintElem/@valueShapeID
    let $constraintId := concat($valueShapeId, '-linkResolvable')
    
    (: Data location :)
    let $filePath := $contextInfo?filePath ! attribute contextURI {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    let $contextNodeDataPath := $contextNode/i:datapath(.)

    (: Message :)
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, 'linksResolvable', ())
        else i:getErrorMsg($constraintElem, 'linksResolvable', ())
        
    return
        element {'gx:' || $colour} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            attribute valueShapeID {$valueShapeId},  
            $filePath,
            $focusNode,
            $contextNodeDataPath ! attribute contextNodeDataPath {.},
            $countUnresolved,
            $countResolved,   
            $relAtt,
            $exprAtts,
            $recursiveAtt,
            $values
        }       
};

