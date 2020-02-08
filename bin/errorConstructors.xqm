(:
 : -------------------------------------------------------------------------
 :
 : errorConstructors.xqm - Document me!
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
    "log.xqm" ;
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:constructError_valueComparison($class as xs:string,
                                                  $constraintId as attribute()?,
                                                  $constraintLabel as attribute()?,
                                                  $expr as xs:string, 
                                                  $quantifier as xs:string, 
                                                  $valueExpected as xs:string, 
                                                  $cmpExpected as xs:string, 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:red) {
    <gx:red class="{$class}">{
        $constraintId,
        $constraintLabel,
        attribute expr {$expr},
        attribute quantifier {$quantifier},
        attribute valueExpected {$valueExpected},
        attribute cmpExpected {$cmpExpected},

        if (count($exprValue) gt 1) then () else attribute actualValue {$exprValue},
        $additionalAtts,        
        if (count($exprValue) le 1) then () else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>
    }</gx:red>                                                  
};

declare function f:constructError_countComparison($class as xs:string,
                                                  $constraintId as attribute()?,
                                                  $constraintLabel as attribute()?,
                                                  $expr as xs:string, 
                                                  $constraintAtt as attribute(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:red) {
    <gx:red class="{$class}">{
        $constraintId,
        $constraintLabel,
        attribute expr {$expr},
        $constraintAtt,
        attribute actualCount {count($exprValue)},
        if (count($exprValue) gt 1) then () else attribute actualValue {$exprValue},
        $additionalAtts,        
        if (count($exprValue) le 1) then () else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>
    }</gx:red>                                                  
};
