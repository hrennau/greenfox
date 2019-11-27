(:
 : -------------------------------------------------------------------------
 :
 : xpathValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateXPath($doc as element(), $xpath as element(gx:xpath), $context)
        as element()* {
    let $constraintId := $xpath/@id
    let $constraintLabel := $xpath/@label
    
    let $minCount := $xpath/@minCount
    let $maxCount := $xpath/@maxCount
    let $count := $xpath/@count
    
    let $eq := $xpath/@eq   
    let $ne := $xpath/@ne
    let $gt := $xpath/@gt
    let $ge := $xpath/@ge
    let $lt := $xpath/@lt
    let $le := $xpath/@le
    let $matches := $xpath/@matches
    let $notMatches := $xpath/@notMatches
    let $like := $xpath/@like
    let $notLike := $xpath/@notLike
    let $flags := string($xpath/@flags)
    let $quantifier := 'all'
    
    let $expr := $xpath/@expr
    let $exprContext := map{
        '': $doc
    }
    let $exprValue := xquery:eval($expr, $exprContext)
    
    let $errors := (
        (: count errors
           ============ :)
        if (empty($maxCount) or count($exprValue) le $maxCount/xs:integer(.)) then () else
            f:constructError_countComparison($constraintId, $constraintLabel, $expr, $maxCount, $exprValue, ())
        ,
        if (not($eq)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item eq $eq) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $eq, 'eq', $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue = $gt) then () 
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $eq, 'eq', $exprValue, ())
        ,
        if (not($ne)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item ne $ne) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $ne, 'ne', $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue != $ne) then () 
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $ne, 'ne', $exprValue, ())
        ,
        if (not($gt)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item gt $gt) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $gt, 'gt', $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue > $gt) then () 
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $gt, 'gt', $exprValue, ())
        ,
        if (not($lt)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item lt $lt) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $lt, 'lt', $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue < $gt) then () 
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $lt, 'lt', $exprValue, ())
        ,
        if (not($ge)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item ge $gt) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $ge, 'ge', $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue >= $gt) then () 
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $ge, 'ge', $exprValue, ())
        ,
        if (not($le)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies $item le $gt) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $le, 'le', $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue <= $gt) then () 
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $le, 'le', $exprValue, ())
        ,
        if (not($matches)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies matches($item, $matches, $flags)) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $matches, 'matches', $exprValue, attribute flags {$flags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies matches($item, $matches, $flags)) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $matches, 'matches', $exprValue, attribute flags {$flags})
        ,
        if (not($notMatches)) then () else
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies not(matches($item, $notMatches, $flags))) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $notMatches, 'notMatches', $exprValue, attribute flags {$flags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies not(matches($item, $notMatches, $flags))) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $notMatches, 'notMatches', $exprValue, attribute flags {$flags})
        ,
        if (not($like)) then () else
            let $useFlags :=
                if ($flags[string()]) then $flags else 'i'
            let $regex :=
                $like !
                replace(., '\*', '.*') !
                replace(., '\?', '.') !
                concat('^', ., '$')
            return                
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies matches($item, $regex, $useFlags)) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $like, 'like', $exprValue, attribute flags {$useFlags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies matches($item, $regex, $useFlags)) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $like, 'like', $exprValue, attribute flags {$useFlags})
        ,
        if (not($notLike)) then () else
            let $useFlags :=
                if ($flags[string()]) then $flags else 'i'
            let $regex :=
                $notLike !
                replace(., '\*', '.*') !
                replace(., '\?', '.') !
                concat('^', ., '$')
            return                
            if ($quantifier eq 'all') then 
                if (every $item in $exprValue satisfies not(matches($item, $regex, $useFlags))) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $notLike, 'notLike', $exprValue, attribute flags {$useFlags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies not(matches($item, $regex, $useFlags))) then ()
                else f:constructError_valueComparison($constraintId, $constraintLabel, $expr, $quantifier, $notLike, 'notLike', $exprValue, attribute flags {$useFlags})
        ,
        ()
    )
    return
        <gx:xpathErrors count="{count($errors)}">{$errors}</gx:xpathErrors>
        [$errors]
        
};

declare function f:constructError_valueComparison($constraintId as attribute()?,
                                                  $constraintLabel as attribute()?,
                                                  $expr as xs:string, 
                                                  $quantifier as xs:string, 
                                                  $valueExpected as xs:string, 
                                                  $cmpExpected as xs:string, 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:error) {
    <gx:error class="xpath">{
        $constraintId,
        $constraintLabel,
        attribute expr {$expr},
        attribute quantifier {$quantifier},
        attribute valueExpected {$valueExpected},
        attribute cmpExpected {$cmpExpected},

        if (count($exprValue) gt 1) then () else attribute actualValue {$exprValue},
        $additionalAtts,        
        if (count($exprValue) le 1) then () else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>
    }</gx:error>                                                  
};

declare function f:constructError_countComparison($constraintId as attribute()?,
                                                  $constraintLabel as attribute()?,
                                                  $expr as xs:string, 
                                                  $constraintAtt as attribute(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:error) {
    <gx:error class="xpath">{
        $constraintId,
        $constraintLabel,
        attribute expr {$expr},
        $constraintAtt,
        attribute actualCount {count($exprValue)},
        if (count($exprValue) gt 1) then () else attribute actualValue {$exprValue},
        $additionalAtts,        
        if (count($exprValue) le 1) then () else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>
    }</gx:error>                                                  
};






