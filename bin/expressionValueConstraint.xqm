(:
 : -------------------------------------------------------------------------
 :
 : expressionValueValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "foxpathEvaluator.xqm",
    "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateExpressionValue($constraint as element(), 
                                           $contextItem as item()?,
                                           $context as map(*))
        as element()* {
    let $exprLang := 
        if ($constraint/self::gx:xpath) then 'xpath' 
        else if ($constraint/self::gx:foxpath) then 'foxpath'
        else error()
    let $expr := $constraint/@expr
    let $exprValue :=
    
        (: XPath - a single map contains context item and external variables :)
        if ($constraint/self::gx:xpath) then
            let $exprContext := map:put($context, '', $contextItem)
            return xquery:eval($expr, $exprContext)
            
        (: foxpath - context item is one parameter, map with external variables another parameter :)            
        else
            let $exprContext := $context
            let $requiredBindings := map:keys($context)
            let $exprAugmented := i:finalizeQuery($expr, $requiredBindings)
            return f:evaluateFoxpath($exprAugmented, $contextItem, $exprContext)

    let $constraintId := $constraint/@id
    let $constraintLabel := $constraint/@label
    
    let $minCount := $constraint/@minCount
    let $maxCount := $constraint/@maxCount
    let $count := $constraint/@count
    
    let $eq := $constraint/@eq   
    let $ne := $constraint/@ne
    let $gt := $constraint/@gt
    let $ge := $constraint/@ge
    let $lt := $constraint/@lt
    let $le := $constraint/@le
    let $matches := $constraint/@matches
    let $notMatches := $constraint/@notMatches
    let $like := $constraint/@like
    let $notLike := $constraint/@notLike
    let $flags := string($constraint/@flags)
    let $quantifier := 'all'
    
    let $errors := (
        (: count errors
           ============ :)
        if (empty($maxCount) or count($exprValue) le $maxCount/xs:integer(.)) then () else
            f:constructError_countComparison($exprLang, $constraintId, $constraintLabel, $expr, $maxCount, $exprValue, ())
        ,
        if (empty($minCount) or count($exprValue) ge $minCount/xs:integer(.)) then () else
            f:constructError_countComparison($exprLang, $constraintId, $constraintLabel, $expr, $minCount, $exprValue, ())
        ,
        if (empty($count) or count($exprValue) eq $count/xs:integer(.)) then () else
            f:constructError_countComparison($exprLang, $constraintId, $constraintLabel, $expr, $count, $exprValue, ())
        ,
        (: comparison errors
           ================= :)
        if (not($eq)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item = $eq)) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $eq, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue = $gt) then () 
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $eq, $exprValue, ())
        ,
        if (not($ne)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item != $ne)) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $ne, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue != $ne) then () 
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, 
                                                      $expr, $quantifier, $ne, $exprValue, ())
        ,
        if (not($gt)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item > $gt)) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $gt, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue > $gt) then () 
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $gt, $exprValue, ())
        ,
        if (not($lt)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item < $lt)) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $lt, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue < $gt) then () 
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $lt, $exprValue, ())
        ,
        if (not($ge)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item >= $gt)) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $ge, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue >= $gt) then () 
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $ge, $exprValue, ())
        ,
        if (not($le)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item <= $gt)) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $le, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue <= $gt) then () 
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $le, $exprValue, ())
        ,
        (: match errors
           ============ :)
        if (not($matches)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies matches($item, $matches, $flags))) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $matches, $exprValue, attribute flags {$flags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies matches($item, $matches, $flags)) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $matches, $exprValue, attribute flags {$flags})
        ,
        if (not($notMatches)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies not(matches($item, $notMatches, $flags)))) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $notMatches, $exprValue, attribute flags {$flags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies not(matches($item, $notMatches, $flags))) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $notMatches, $exprValue, attribute flags {$flags})
        ,
        (: like errors
           =========== :)
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
                if (count($exprValue) and (every $item in $exprValue satisfies matches($item, $regex, $useFlags))) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $like, $exprValue, attribute flags {$useFlags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies matches($item, $regex, $useFlags)) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $like, $exprValue, attribute flags {$useFlags})
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
                if (count($exprValue) and (every $item in $exprValue satisfies not(matches($item, $regex, $useFlags)))) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $notLike, $exprValue, attribute flags {$useFlags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies not(matches($item, $regex, $useFlags))) then ()
                else f:constructError_valueComparison($exprLang, $constraintId, $constraintLabel, $expr, 
                                                      $quantifier, $notLike, $exprValue, attribute flags {$useFlags})
        ,
        ()
    )
    return
        $errors        
};

declare function f:constructError_valueComparison($exprLang as xs:string,
                                                  $constraintId as attribute()?,
                                                  $constraintLabel as attribute()?,
                                                  $expr as xs:string, 
                                                  $quantifier as xs:string, 
                                                  $comparison as attribute(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:error) {
    <gx:error constraintComp="{$exprLang}">{
        $constraintId/attribute constraintID {.},
        $constraintLabel/attribute constraintLabel {.},
        attribute expr {$expr},
        attribute quantifier {$quantifier},
        $comparison,
        if (count($exprValue) gt 1) then () else attribute actualValue {$exprValue},
        $additionalAtts,        
        if (count($exprValue) le 1) then () else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>
    }</gx:error>                                                  
};

declare function f:constructError_countComparison($exprLang as xs:string,
                                                  $constraintId as attribute()?,
                                                  $constraintLabel as attribute()?,
                                                  $expr as xs:string, 
                                                  $constraintAtt as attribute(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:error) {
    <gx:error constraintComp="{$exprLang}">{
        $constraintId/attribute constraintID {.},
        $constraintLabel/attribute constraintLabel {.},
        attribute expr {$expr},
        $constraintAtt,
        attribute actualCount {count($exprValue)},
        if (count($exprValue) gt 1) then () else attribute actualValue {$exprValue},
        $additionalAtts,        
        if (count($exprValue) le 1) then () else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>
    }</gx:error>                                                  
};









