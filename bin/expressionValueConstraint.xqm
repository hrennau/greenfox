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
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateExpressionValue($constraint as element(), 
                                           $contextItem as item()?,
                                           $context as map(*))
        as element()* {
    let $msg := $constraint/@msg
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
            
        else trace(
            f:evaluateFoxpath($expr, $contextItem, $context, true())
, '### EXPR_VALUE: ')
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
    let $inFoxpath := $constraint/@inFoxpath
    let $matches := $constraint/@matches
    let $notMatches := $constraint/@notMatches
    let $like := $constraint/@like
    let $notLike := $constraint/@notLike
    let $flags := string($constraint/@flags)
    let $quantifier := 'all'
    
    let $inFoxpathValue := 
        if (not($inFoxpath)) then () else
            let $contextItem :=
                if ($contextItem instance of xs:anyAtomicType) then $contextItem
                else $contextItem/root()/base-uri(.)
            return                
                f:evaluateFoxpath($inFoxpath, $contextItem, $context, true())
    
    let $errorsIn := (
        if (not($constraint/gx:in)) then () else

        let $ok :=
            if ($quantifier eq 'all') then
                every $item in $exprValue satisfies 
                    some $alternative in $constraint/gx:in/* satisfies
                        typeswitch($alternative)
                        case element(gx:eq) return $item = $alternative
                        case element(gx:ne) return $item != $alternative
                        case element(gx:like) return i:matchesLike($item, $alternative, $alternative/@flags)
                        case element(gx:notLike) return not(i:matchesLike($item, $alternative, $alternative/@flags))                        
                        default return error()                
            else error()
        return
            if ($ok) then () else
                f:constructError_valueComparison($constraint, $quantifier, $constraint/gx:in, $exprValue, ())
        ,
        if (not($inFoxpath)) then () else
        
        let $ok :=
            if ($quantifier eq 'all') then
                every $item in $exprValue satisfies $item = $inFoxpathValue
            else
                some $item in $exprValue satisfies $item = $inFoxpathValue
        return
           if ($ok) then () else
                f:constructError_valueComparison($constraint, $quantifier, $inFoxpath, $exprValue, ())                
    )            
    let $errors := (
        (: count errors
           ============ :)
        if (empty($maxCount) or count($exprValue) le $maxCount/xs:integer(.)) then () else
            f:constructError_countComparison($constraint, $maxCount, $exprValue, ())
        ,
        if (empty($minCount) or count($exprValue) ge $minCount/xs:integer(.)) then () else
            f:constructError_countComparison($constraint, $minCount, $exprValue, ())
        ,
        if (empty($count) or count($exprValue) eq $count/xs:integer(.)) then () else
            f:constructError_countComparison($constraint, $count, $exprValue, ())
        ,
        (: comparison errors
           ================= :)
        if (not($eq)) then () else trace(
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies trace( $item = $eq, '### COMPARISON: '))) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $eq, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue = $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $eq, $exprValue, ())   , '### CHECK EQ: ')
        ,
        if (not($ne)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item != $ne)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $ne, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue != $ne) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $ne, $exprValue, ())
        ,
        if (not($gt)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item > $gt)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $gt, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue > $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $gt, $exprValue, ())
        ,
        if (not($lt)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item < $lt)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $lt, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue < $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $lt, $exprValue, ())
        ,
        if (not($ge)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item >= $gt)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $ge, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue >= $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $ge, $exprValue, ())
        ,
        if (not($le)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item <= $gt)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $le, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue <= $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $le, $exprValue, ())
        ,
        (: match errors
           ============ :)
        if (not($matches)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies matches($item, $matches, $flags))) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $matches, $exprValue, attribute flags {$flags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies matches($item, $matches, $flags)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $matches, $exprValue, attribute flags {$flags})
        ,
        if (not($notMatches)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies not(matches($item, $notMatches, $flags)))) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $notMatches, $exprValue, attribute flags {$flags})
            else if ($quantifier eq 'some') then 
                if (some $item in $exprValue satisfies not(matches($item, $notMatches, $flags))) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $notMatches, $exprValue, attribute flags {$flags})
        ,
        (: like errors
           =========== :)
        if (not($like)) then () else           
            let $useFlags := ($flags, 'i')[1] 
            return
                if ($quantifier eq 'all') then 
                    if (count($exprValue) and (every $item in $exprValue satisfies i:matchesLike($item, $like, $useFlags))) then ()
                    else f:constructError_valueComparison($constraint, $quantifier, $like, $exprValue, attribute flags {$useFlags})
                else if ($quantifier eq 'some') then 
                    if (some $item in $exprValue satisfies i:matchesLike($item, $like, $useFlags)) then ()
                    else f:constructError_valueComparison($constraint, $quantifier, $like, $exprValue, attribute flags {$useFlags})
        ,
        if (not($notLike)) then () else
            let $useFlags := ($flags, 'i')[1]        
            return                
                if ($quantifier eq 'all') then 
                    if (count($exprValue) and (every $item in $exprValue satisfies not(f:matchesLike($item, $notLike, $useFlags)))) then ()
                    else f:constructError_valueComparison($constraint, $quantifier, $notLike, $exprValue, attribute flags {$useFlags})
                else if ($quantifier eq 'some') then 
                    if (some $item in $exprValue satisfies not(f:matchesLike    ($item, $notLike, $useFlags))) then ()
                    else f:constructError_valueComparison($constraint, $quantifier, $notLike, $exprValue, attribute flags {$useFlags})
        ,
        ()
    )
    return
        ($errors, $errorsIn)        
};

declare function f:constructError_valueComparison($constraint as element(),
                                                  $quantifier as xs:string, 
                                                  $comparison as node(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:error) {
    <gx:error>{
        $constraint/@msg,
        attribute constraintComp {$constraint/local-name(.)},
        $constraint/@id/attribute constraintID {.},
        $constraint/@label/attribute constraintLabel {.},
        $constraint/@expr/attribute expr {normalize-space(.)},
        attribute quantifier {$quantifier},
        $comparison[$comparison/self::attribute()],
        if (count($exprValue) gt 1) then () else attribute actualValue {$exprValue},
        $additionalAtts,        
        if (count($exprValue) le 1) then () else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>,
        $comparison[$comparison/self::element()]
    }</gx:error>                                                  
};

declare function f:constructError_countComparison($constraint as element(),
                                                  $comparison as node(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:error) {
    <gx:error>{
        $constraint/@msg,
        attribute constraintComp {$constraint/local-name(.)},
        $constraint/@id/attribute constraintID {.},
        $constraint/@label/attribute constraintLabel {.},
        $constraint/@expr/attribute expr {normalize-space(.)},
        $comparison[$comparison/self::attribute()],
        if (count($exprValue) gt 1) then () else attribute actualValue {$exprValue},
        $additionalAtts,        
        if (count($exprValue) le 1) then () else $exprValue ! <gx:actualValue>{string(.)}</gx:actualValue>,
        $comparison[$comparison/self::element()]
    }</gx:error>                                                  
};









