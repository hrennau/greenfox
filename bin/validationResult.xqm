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
