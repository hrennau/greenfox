(:
 : -------------------------------------------------------------------------
 :
 : xpathValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_foxpath.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateXPath($doc as element(), $xpath as element(gx:xpath), $context)
        as element()* {
    let $eq := $xpath/@eq   
    let $ne := $xpath/@ne
    let $gt := $xpath/@gt
    let $ge := $xpath/@ge
    let $lt := $xpath/@lt
    let $le := $xpath/@le
    let $matches := $xpath/@matches
    let $flags := string($xpath/@flags)
    let $quantifier := 'all'
    
    let $expr := $xpath/@expr
    let $exprContext := map{
        '': $doc
    }
    let $exprValue := xquery:eval($expr, $exprContext)
    let $errors := (
        if (not($eq)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item eq $eq) then ()
                else f:constructError_valueComparison($expr, $quantifier, $eq, 'eq', $exprValue)
            else if ($quantifier eq 'some') then 
                if ($exprValue = $gt) then () 
                else f:constructError_valueComparison($expr, $quantifier, $eq, 'eq', $exprValue)
        ,
        if (not($ne)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item ne $ne) then ()
                else f:constructError_valueComparison($expr, $quantifier, $ne, 'ne', $exprValue)
            else if ($quantifier eq 'some') then 
                if ($exprValue != $ne) then () 
                else f:constructError_valueComparison($expr, $quantifier, $ne, 'ne', $exprValue)
        ,
        if (not($gt)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item gt $gt) then ()
                else f:constructError_valueComparison($expr, $quantifier, $gt, 'gt', $exprValue)
            else if ($quantifier eq 'some') then 
                if ($exprValue > $gt) then () 
                else f:constructError_valueComparison($expr, $quantifier, $gt, 'gt', $exprValue)
        ,
        if (not($lt)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item lt $lt) then ()
                else f:constructError_valueComparison($expr, $quantifier, $lt, 'lt', $exprValue)
            else if ($quantifier eq 'some') then 
                if ($exprValue < $gt) then () 
                else f:constructError_valueComparison($expr, $quantifier, $lt, 'lt', $exprValue)
        ,
        if (not($ge)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item ge $gt) then ()
                else f:constructError_valueComparison($expr, $quantifier, $ge, 'ge', $exprValue)
            else if ($quantifier eq 'some') then 
                if ($exprValue >= $gt) then () 
                else f:constructError_valueComparison($expr, $quantifier, $ge, 'ge', $exprValue)
        ,
        if (not($le)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item le $gt) then ()
                else f:constructError_valueComparison($expr, $quantifier, $le, 'le', $exprValue)
            else if ($quantifier eq 'some') then 
                if ($exprValue <= $gt) then () 
                else f:constructError_valueComparison($expr, $quantifier, $le, 'le', $exprValue)
        ,
        if (not($matches)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies matches($item, $matches, $flags)) then ()
                else f:constructError_valueComparison($expr, $quantifier, $matches, 'matches', $exprValue)
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies matches($item, $matches, $flags)) then ()
                else f:constructError_valueComparison($expr, $quantifier, $matches, 'matches', $exprValue)
        ,
        ()
    )
    return
        <gx:xpathErrors count="{count($errors)}">{$errors}</gx:xpathErrors>
        [$errors]
        
};

declare function f:constructError_valueComparison($expr as xs:string, 
                                                  $quantifier as xs:string, 
                                                  $valueExpected as xs:string, 
                                                  $cmpExpected as xs:string, 
                                                  $exprValue as item()*) 
        as element(gx:error) {
    <gx:error expr="{$expr}" quantifier="{$quantifier}" valueExpected="{$valueExpected}" cmpExpected="{$cmpExpected}">{
        if (count($exprValue) eq 1) then attribute actualValue {$exprValue}
        else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>
    }</gx:error>                                                  
};



