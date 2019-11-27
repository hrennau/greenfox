(:
 : -------------------------------------------------------------------------
 :
 : foxpathValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFoxpath($foxpath as xs:string, $contextItem as item(), $context)
        as element()* {
    let $expr := $foxpath/@expr
  
    
    let $exprValue := f:evaluateFoxpath($expr, $contextItem)
    
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


