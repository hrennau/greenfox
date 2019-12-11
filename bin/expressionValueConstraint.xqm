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
                                           $contextFilePath as xs:string,
                                           $contextDoc as document-node()?,
                                           $context as map(*))
        as element()* {
    let $msg := $constraint/@msg
    let $exprLang := local-name($constraint)
    let $expr := $constraint/@expr
    let $exprValue :=    
        if ($constraint/self::gx:xpath) then i:evaluateXPath($expr, $contextItem, $context, true(), true())
        else f:evaluateFoxpath($expr, $contextItem, $context, true())
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
    let $eqFoxpath := $constraint/@eqFoxpath
    let $containsXPath := $constraint/@containsXPath
    let $eqXPath := $constraint/@eqXPath
    let $matches := $constraint/@matches
    let $notMatches := $constraint/@notMatches
    let $like := $constraint/@like
    let $notLike := $constraint/@notLike
    let $flags := string($constraint/@flags)
    let $quantifier := 'all'
    
    let $eqFoxpathValue := 
        if (not($eqFoxpath)) then () else
            let $contextItem := $contextFilePath
            return              
                f:evaluateFoxpath($eqFoxpath, $contextItem, $context, true())

    let $containsXPathValue := 
        if (not($containsXPath)) then () else
            let $contextItem := ($contextDoc, $contextItem)[1]
            return  
                f:evaluateXPath($containsXPath, $contextItem, $context, true(), true())            

    let $eqXPathValue := 
        if (not($eqXPath)) then () else
            let $contextItem := ($contextDoc, $contextItem)[1]
            return
                f:evaluateXPath($eqXPath, $contextItem, $context, true(), true())            

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
        (: eqFoxpath
           ========= :)
        if (not($eqFoxpath)) then () else
        
        let $ok :=
            if ($quantifier eq 'all') then
                every $item in $exprValue satisfies $item = $eqFoxpathValue
            else
                some $item in $exprValue satisfies $item = $eqFoxpathValue
        return
           if ($ok) then () else
                let $eqFoxpathValueRep := $eqFoxpathValue => distinct-values() => string-join(', ')
                return
                    f:constructError_valueComparison($constraint, $quantifier, $eqFoxpath, $exprValue, 
                                                     attribute valueList {$eqFoxpathValueRep})          
        ,                                             
        (: containsXpath
           ============= :)
        if (not($containsXPath)) then () else
        
        let $ok :=
            if ($quantifier eq 'all') then
                every $item in $containsXPathValue satisfies $item = $exprValue
            else
                some $item in $containsXPathValue satisfies $item = $exprValue
        return
           if ($ok) then () else
                let $containsXPathValueRep := $containsXPathValue => distinct-values() => string-join(', ')
                return
                    f:constructError_valueComparison($constraint, $quantifier, $containsXPath, $exprValue, 
                                                     attribute valueList {$containsXPathValueRep})                
        ,
        (: eqXPath
           ======= :)
        if (not($eqXPath)) then () else
        
        let $ok :=
            if ($quantifier eq 'all') then
                every $item in $exprValue satisfies $item = $eqXPathValue
            else
                some $item in $exprValue satisfies $item = $eqXPathValue
        return
           if ($ok) then () else
                let $eqXPathValueRep := $eqXPathValue => distinct-values() => string-join(', ')
                return
                    f:constructError_valueComparison($constraint, $quantifier, $eqXPath, $exprValue, 
                                                     attribute valueList {$eqXPathValueRep})                
        
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
        if (not($eq)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item = $eq)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $eq, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue = $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $eq, $exprValue, ())
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
    let $allErrors := ($errors, $errorsIn)
    return
        if ($allErrors) then $allErrors
        else f:constructGreen_valueShape($constraint)
};

declare function f:constructError_valueComparison($constraint as element(),
                                                  $quantifier as xs:string, 
                                                  $comparison as node(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*) 
        as element(gx:error) {
    <gx:error>{
        $constraint/@msg,
        $constraint/@resourceShapeID,
        $constraint/@valueShapeID,
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
        $constraint/@resourceShapeID,
        $constraint/@valueShapeID,
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

declare function f:constructGreen_valueShape($constraint as element()) 
        as element(gx:green) {
    <gx:green>{
        $constraint/@resourceShapeID,
        $constraint/@valueShapeID,
        attribute constraintComp {$constraint/local-name(.)},
        $constraint/@id/attribute constraintID {.},
        $constraint/@label/attribute constraintLabel {.},
        $constraint/@expr/attribute expr {normalize-space(.)}
    }</gx:green>                                                  
};








