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
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateExpressionValue($constraint as element(), 
                                           $contextItem as item()?,
                                           $contextFilePath as xs:string,
                                           $contextDoc as document-node()?,
                                           $context as map(*))
        as element()* {
(:        
    let $_DEBUG := trace(typeswitch($contextItem) 
                         case document-node() return 'DNODE' 
                         case element() return 'ELEM' 
                         default return 'OTHER', '_TYPE_CONTEXT_ITEM_0: ')
:)                         
    let $msg := $constraint/@msg
    let $exprLang := local-name($constraint)
    let $expr := $constraint/@expr
    let $exprValue :=    
        if ($constraint/self::gx:xpath) then i:evaluateXPath($expr, $contextItem, $context, true(), true())
        else if ($constraint/self::gx:foxpath) then  f:evaluateFoxpath($expr, $contextItem, $context, true())
        else error(QName((), 'SCHEMA_ERROR'), concat('Unknown expression kind: ', $constraint/name(.)))
        
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
    let $in := $constraint/gx:in
    let $notin := $constraint/gx:notin
    let $matches := $constraint/@matches
    let $notMatches := $constraint/@notMatches
    let $like := $constraint/@like
    let $notLike := $constraint/@notLike
    
    let $eqFoxpath := $constraint/@eqFoxpath
    let $ltFoxpath := $constraint/@ltFoxpath
    let $leFoxpath := $constraint/@leFoxpath
    let $gtFoxpath := $constraint/@gtFoxpath
    let $geFoxpath := $constraint/@geFoxpath    
    let $containsFoxpath := $constraint/@containsFoxpath    
    
    let $eqXPath := $constraint/@eqXPath
    let $leXPath := $constraint/@leXPath    
    let $ltXPath := $constraint/@ltXPath
    let $geXPath := $constraint/@geXPath
    let $gtXPath := $constraint/@gtXPath
    let $containsXPath := $constraint/@containsXPath    
    
    let $flags := string($constraint/@flags)
    let $quantifier := ($constraint/@quant, 'all')[1]
    
    let $eqFoxpathValue := 
        if (not($eqFoxpath)) then () else
            let $contextItem := $contextFilePath
            return f:evaluateFoxpath($eqFoxpath, $contextItem, $context, true())

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
(:    
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
:)        
(:
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
:)        
(:        ,                                             
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
:)                                                     
(:
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
:)        
    )
    
    let $errors := (
        if (not($eq)) then () else f:validateExpressionValue_cmp($exprValue, $eq, $quantifier, $constraint),    
        if (not($ne)) then () else f:validateExpressionValue_cmp($exprValue, $ne, $quantifier, $constraint),
        if (not($in)) then () else f:validateExpressionValue_in($exprValue, $quantifier, $constraint),
        if (not($notin)) then () else f:validateExpressionValue_notin($exprValue, $quantifier, $constraint),
        if (not($lt)) then () else f:validateExpressionValue_cmp($exprValue, $lt, $quantifier, $constraint),
        if (not($le)) then () else f:validateExpressionValue_cmp($exprValue, $le, $quantifier, $constraint),
        if (not($gt)) then () else f:validateExpressionValue_cmp($exprValue, $gt, $quantifier, $constraint),
        if (not($ge)) then () else f:validateExpressionValue_cmp($exprValue, $ge, $quantifier, $constraint),
        if (not($matches)) then () else f:validateExpressionValue_cmp($exprValue, $matches, $quantifier, $constraint),
        if (not($notMatches)) then () else f:validateExpressionValue_cmp($exprValue, $notMatches, $quantifier, $constraint),
        if (not($like)) then () else f:validateExpressionValue_cmp($exprValue, $like, $quantifier, $constraint),
        if (not($notLike)) then () else f:validateExpressionValue_cmp($exprValue, $notLike, $quantifier, $constraint),        
        if (not($count)) then () else f:validateExpressionValueCount($exprValue, $count, $constraint),     
        if (not($minCount)) then () else f:validateExpressionValueCount($exprValue, $minCount, $constraint),
        if (not($maxCount)) then () else f:validateExpressionValueCount($exprValue, $maxCount, $constraint),

        if (not($eqXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $eqXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint),
        if (not($leXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $leXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint),
        if (not($ltXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $ltXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint),
        if (not($geXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $geXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint),
        if (not($gtXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $gtXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint),
        if (not($containsXPath)) then () else f:validateExpressionValue_containsXPath(
                                                                          $exprValue, $containsXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $constraint),

        if (not($eqFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $eqFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint),
        if (not($ltFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $ltFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint),
        if (not($leFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $leFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint),
        if (not($gtFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $gtFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint),
        if (not($geFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $geFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint),

        (: count errors
           ============ :)
(:           
        if (empty($maxCount) or count($exprValue) le $maxCount/xs:integer(.)) then () else
            f:constructError_countComparison($constraint, $maxCount, $exprValue, ())
        ,
        if (empty($minCount) or count($exprValue) ge $minCount/xs:integer(.)) then () else
            f:constructError_countComparison($constraint, $minCount, $exprValue, ())
        ,
        if (empty($count) or count($exprValue) eq $count/xs:integer(.)) then () else
            f:constructError_countComparison($constraint, $count, $exprValue, ())
        ,
:)        
        (: comparison errors
           ================= :)
    (:           
    if (not($eq)) then () else f:validateExpressionValue_eq($exprValue, $quantifier, $constraint)
          
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
:)      
(:
        if (not($gt)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item > $gt)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $gt, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue > $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $gt, $exprValue, ())
        ,
:)        
(:        
        if (not($lt)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item < $lt)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $lt, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue < $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $lt, $exprValue, ())
        ,
:)     
(:
        if (not($ge)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item >= $gt)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $ge, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue >= $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $ge, $exprValue, ())
        ,
:)        
(:        
        if (not($le)) then () else
            if ($quantifier eq 'all') then 
                if (count($exprValue) and (every $item in $exprValue satisfies $item <= $gt)) then ()
                else f:constructError_valueComparison($constraint, $quantifier, $le, $exprValue, ())
            else if ($quantifier eq 'some') then 
                if ($exprValue <= $gt) then () 
                else f:constructError_valueComparison($constraint, $quantifier, $le, $exprValue, ())
        ,
:)        
        (: match errors
           ============ :)
(:           
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
:)        
        (: like errors
           =========== :)
(:           
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
:)        
        ()
       
    )
    return
        if ($errors) then $errors
        else f:constructGreen_valueShape($constraint)
};

(:
declare function f:validateExpressionValue_eq($exprValue as item()*,
                                              $quantifier as xs:string,
                                              $valueShape as element())
        as element() {
    let $eq := $valueShape/@eq
    return
    
    if (not($eq)) then () else
    
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $exprValue[not(. = $eq)]
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $eq, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
        else if ($quantifier eq 'some') then 
            if ($exprValue = $eq) then () 
            else f:validationResult_expression('red', $valueShape, $eq, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $eq, (), ())
};        

declare function f:validateExpressionValue_ne($exprValue as item()*,
                                              $quantifier as xs:string,
                                              $valueShape as element())
        as element() {
    let $ne := $valueShape/@ne
    return
    
    if (not($ne)) then () else
    
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $exprValue[. = $ne]
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $ne, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
        else if ($quantifier eq 'some') then 
            if ($exprValue != $ne) then () 
            else f:validationResult_expression('red', $valueShape, $ne, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $ne, (), ())
};        
:)
(:
declare function f:validateExpressionValue_lt($exprValue as item()*,
                                              $quantifier as xs:string,
                                              $valueShape as element())
        as element() {
    let $lt := $valueShape/@lt return    
    if (not($lt)) then () else
    
    let $useDatatype := $valueShape/@useDatatype/resolve-QName(., ..)
    let $useLt := if (empty($useDatatype)) then $lt else i:castAs($lt, $useDatatype, ())
    let $useItems := if (empty($useDatatype)) then $exprValue else 
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:error'))
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $useItems ! (
                if (. instance of element(gx:error)) then .
                else if (. >= $useLt) then .
                else ())
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $lt, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
        else if ($quantifier eq 'some') then 
            if ($useItems < $useLt) then () 
            else f:validationResult_expression('red', $valueShape, $lt, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $lt, (), ())
};        
:)

declare function f:validateExpressionValueCount($exprValue as item()*,
                                                $cmp as attribute(),
                                                $valueShape as element())
        as element() {
    let $_DEBUG := trace($cmp, 'COUNT_CMP: ')    
    let $count := count($exprValue)
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown count comparison operator: ', $cmp))
    return        
        if ($cmpTrue($count, $cmp)) then  
            f:validationResult_expressionCount('green', $valueShape, $cmp, $count, (), ())
        else 
            f:validationResult_expressionCount('red', $valueShape, $cmp, $count, (), ())
};        

declare function f:validateExpressionValue_cmp($exprValue as item()*,
                                               $cmp as attribute(),
                                               $quantifier as xs:string,                                               
                                               $valueShape as element())
        as element() {
    let $_DEBUG := trace($cmp, 'CMP: ')     
    let $flags := string($valueShape/@flags)
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(eq) return function($op1, $op2) {$op1 = $op2}        
        case attribute(ne) return function($op1, $op2) {$op1 != $op2}        
        case attribute(lt) return function($op1, $op2) {$op1 < $op2}
        case attribute(le) return function($op1, $op2) {$op1 <= $op2}
        case attribute(gt) return function($op1, $op2) {$op1 > $op2}
        case attribute(ge) return function($op1, $op2) {$op1 >= $op2}
        case attribute(matches) return function($op1, $op2) {matches($op1, $op2, $flags)}
        case attribute(notMatches) return function($op1, $op2) {not(matches($op1, $op2, $flags))}
        case attribute(like) return function($op1, $op2) {matches($op1, $op2, $flags)}
        case attribute(notLike) return function($op1, $op2) {not(matches($op1, $op2, $flags))}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $cmp))
    
    let $useDatatype := $valueShape/@useDatatype/resolve-QName(., ..)
    let $useCmp :=
        if ($cmp/self::attribute(like)) then $cmp/f:glob2regex(.)
        else if ($cmp/self::attribute(notLike)) then $cmp/f:glob2regex(.)
        else if (empty($useDatatype)) then $cmp 
        else i:castAs($cmp, $useDatatype, ())
    let $useItems := if (empty($useDatatype)) then $exprValue else 
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:error'))
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $useItems ! (
                if (. instance of element(gx:error)) then .
                else if (not($cmpTrue(., $useCmp))) then .
                else ())
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $cmp, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
        else if ($quantifier eq 'some') then 
            if ($cmpTrue, $useItems, $useCmp) then () 
            else f:validationResult_expression('red', $valueShape, $cmp, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, (), ())
};        

declare function f:validateExpressionValue_cmpExpr($exprValue as item()*,
                                                   $cmp as attribute(),
                                                   $contextItem as item()?,
                                                   $contextFilePath as xs:string,
                                                   $contextDoc as document-node()?,
                                                   $context as map(*),
                                                   $quantifier as xs:string,                                               
                                                   $valueShape as element())
        as element() {
    let $_DEBUG := trace($cmp, 'CMP_EXPR: ')    
    let $exprKind := $valueShape/local-name(.)
    let $cmpExprKind := if (ends-with($cmp/local-name(.), 'Foxpath')) then 'foxpath' else 'xpath'
    let $flags := string($valueShape/@flags)
    
    let $useDatatype := $valueShape/@useDatatype/resolve-QName(., ..)
        
    let $cmpContext :=
        let $attName := local-name($cmp) || 'Context'
        return $valueShape/@*[local-name(.) eq $attName]

    (: the check items :)
    let $checkItems := if (empty($useDatatype)) then $exprValue else 
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:error'))
        
    (: construction of comparison value - argument is the context item :)
    let $getCmpItems := function($ctxtItem) {
        let $cmpValue := 
            if ($cmpExprKind eq 'foxpath') then trace(i:evaluateFoxpath($cmp, $ctxtItem, $context, true()) , 'EVAL_FOXPATH: ')
            else i:evaluateXPath($cmp, $ctxtItem, $context, true(), true())
        return
            if (empty($useDatatype)) then $cmpValue 
            else $cmpValue ! i:castAs(., $useDatatype, ()) 
    }
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(eqXPath) return function($op1, $op2) {$op1 = $op2}        
        case attribute(neXPath) return function($op1, $op2) {$op1 != $op2}        
        case attribute(ltXPath) return function($op1, $op2) {$op1 < $op2}
        case attribute(leXPath) return function($op1, $op2) {$op1 <= $op2}
        case attribute(gtXPath) return function($op1, $op2) {$op1 > $op2}
        case attribute(geXPath) return function($op1, $op2) {$op1 >= $op2}
        
        case attribute(eqFoxpath) return function($op1, $op2) {$op1 = $op2}
        case attribute(ltFoxpath) return function($op1, $op2) {$op1 < $op2}
        case attribute(leFoxpath) return function($op1, $op2) {$op1 <= $op2}
        case attribute(gtFoxpath) return function($op1, $op2) {$op1 > $op2}        
        case attribute(geFoxpath) return function($op1, $op2) {$op1 >= $op2}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $cmp))
    
    let $errors :=
            (: re-evaluate cmp expression for each check item, using it as context item :)
            if ($cmpContext eq '#item') then
                if ($quantifier eq 'all') then
                    let $violations :=
                        for $checkItem at $pos in $checkItems
                        let $item := $exprValue[$pos]
                        return $item[
                            $checkItem instance of element(gx:error) or not($cmpTrue($checkItem, $getCmpItems($item)))]
                    return
                        if (empty($violations)) then () else
                            f:validationResult_expression('red', $valueShape, $cmp, (), 
                                ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
                        
                else if ($quantifier eq 'some') then
                    let $matches :=
                        for $checkItem at $pos in $checkItems[not(self::gx:error)]
                        let $item := $exprValue[$pos]
                        return $item[$cmpTrue($checkItem, $getCmpItems($item))]
                    return
                        if (exists($matches)) then ()
                        else
                            f:validationResult_expression('red', $valueShape, $cmp, (), 
                                ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>)
                    
                else error()                            
            else
                let $useContextItem := 
                    let $_DEBUG := trace(concat($exprKind, '/', $cmpExprKind), 'EXPR_KIND / CMP_EXPR_KIND: ')
                    return
                    
                    if ($exprKind eq 'foxpath' and $cmpExprKind eq 'xpath') then $contextDoc
                    else if ($exprKind eq 'xpath' and $cmpExprKind eq 'foxpath') then $contextFilePath
                    else $contextItem
                let $cmpItems := $getCmpItems($useContextItem)
                return
                    if ($quantifier eq 'all') then
                        let $violations := $checkItems[. instance of element(gx:error) or not($cmpTrue(., $cmpItems))]
                        return
                            if (empty($violations)) then () 
                            else f:validationResult_expression('red', $valueShape, $cmp, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
                    else if ($quantifier eq 'some') then
                        if ($checkItems[not(. instance of element(gx:error)) and $cmpTrue(., $cmpItems)]) then ()
                        else f:validationResult_expression('red', $valueShape, $cmp, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>)
                    else error()                            
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, (), ())
};        

declare function f:validateExpressionValue_in($exprValue as item()*,
                                              $quantifier as xs:string,
                                              $valueShape as element())
        as element() {
    let $in := $valueShape/gx:in
    return
    
    if (not($in)) then () else
    
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $exprValue[not(
                some $alternative in $in/* satisfies
                    typeswitch($alternative)
                        case element(gx:eq) return . = $alternative
                        case element(gx:ne) return . != $alternative
                        case element(gx:like) return i:matchesLike(., $alternative, $alternative/@flags)
                        case element(gx:notLike) return not(i:matchesLike(., $alternative, $alternative/@flags))                        
                        default return error()                
            )]                    
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $in, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
        else if ($quantifier eq 'some') then
            let $conforms :=
                some $item in $exprValue, $alternative in $in/* satisfies
                typeswitch($alternative)
                    case element(gx:eq) return $item = $alternative
                    case element(gx:ne) return $item != $alternative
                    case element(gx:like) return i:matchesLike($item, $alternative, $alternative/@flags)
                    case element(gx:notLike) return not(i:matchesLike($item, $alternative, $alternative/@flags))                        
                    default return error()                
            return
                if ($conforms) then ()
                else f:validationResult_expression('red', $valueShape, $in, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>)
    return
        if ($errors) then $errors else f:validationResult_expression('green', $valueShape, $in, (), ())
};        

declare function f:validateExpressionValue_notin($exprValue as item()*,
                                                 $quantifier as xs:string,
                                                 $valueShape as element())
        as element() {
    let $notin := $valueShape/gx:notin
    return
    
    if (not($notin)) then () else
    
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $exprValue[
                some $alternative in $notin/* satisfies
                    typeswitch($alternative)
                        case element(gx:eq) return . = $alternative
                        case element(gx:ne) return . != $alternative
                        case element(gx:like) return i:matchesLike(., $alternative, $alternative/@flags)
                        case element(gx:notLike) return not(i:matchesLike(., $alternative, $alternative/@flags))                        
                        default return error()                
            ]                    
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $notin, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
        else if ($quantifier eq 'some') then
            let $conforms :=
                some $item in $exprValue, $alternative in $notin/* satisfies not(
                typeswitch($alternative)
                    case element(gx:eq) return $item = $alternative
                    case element(gx:ne) return $item != $alternative
                    case element(gx:like) return i:matchesLike($item, $alternative, $alternative/@flags)
                    case element(gx:notLike) return not(i:matchesLike($item, $alternative, $alternative/@flags))                        
                    default return error()
                )
            return
                if ($conforms) then ()
                else f:validationResult_expression('red', $valueShape, $notin, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>)
    return
        if ($errors) then $errors else f:validationResult_expression('green', $valueShape, $notin, (), ())
};        

declare function f:validateExpressionValue_containsXPath($exprValue as item()*,
                                                         $cmp as attribute(),
                                                         $contextItem as item()?,
                                                         $contextFilePath as xs:string,
                                                         $contextDoc as document-node()?,
                                                         $context as map(*),
                                                         $valueShape as element())
        as element() {
    let $_DEBUG := trace($cmp, 'CMP: ')     
    let $flags := string($valueShape/@flags)
    
    let $useDatatype := $valueShape/@useDatatype/resolve-QName(., ..)
        
    (: the check items :)
    let $checkItems := if (empty($useDatatype)) then $exprValue else 
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:error'))
        
    (: construction of comparison value - argument is the context item :)
    let $cmpValue := i:evaluateXPath($cmp, $contextItem, $context, true(), true())    
    let $cmpItems :=
        if (empty($useDatatype)) then $cmpValue 
        else $cmpValue ! i:castAs(., $useDatatype, ())
        
    (: identify errors :)
    let $errors :=
        let $violations := $cmpItems[. instance of element(gx:error) or not(. = $checkItems)]
        return
            if (empty($violations)) then () 
            else f:validationResult_expression('red', $valueShape, $cmp, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, (), ())
};        

declare function f:validationResult_expression($colour as xs:string,
                                               $valueShape as element(),
                                               $constraint as node()*,
                                               $additionalAtts as attribute()*,
                                               $additionalElems as element()*)
        as element() {
    let $valueShapeKind := $valueShape/local-name(.)
    let $expr := $valueShape/@expr/normalize-space(.)        
    let $constraintComponent :=
        typeswitch($constraint[1])
        case attribute(eq) return 'ExprValueEq'
        case attribute(ne) return 'ExprValueNe'
        case element(gx:in) return 'ExprValueIn'
        case element(gx:notin) return 'ExprValueNotin'
        case attribute(lt) return 'ExprValueLt'        
        case attribute(le) return 'ExprValueLe'        
        case attribute(gt) return 'ExprValueGt'        
        case attribute(ge) return 'ExprValueGe'
        case attribute(matches) return 'ExprValueMatches'
        case attribute(notMatches) return 'ExprValueNotMatches'
        case attribute(like) return 'ExprValueLike'        
        case attribute(notLike) return 'ExprValueNotLike'
        case attribute(eqXPath) return 'ExprValueEqXPath'
        case attribute(leXPath) return 'ExprValueLeXPath'
        case attribute(ltXPath) return 'ExprValueLtXPath'
        case attribute(geXPath) return 'ExprValueGeXPath'
        case attribute(gtXPath) return 'ExprValueGtXPath'
        case attribute(containsXPath) return 'ExprValueContainsXPath'
        case attribute(eqFoxpath) return 'ExprValueEqFoxpath'
        case attribute(ltFoxpath) return 'ExprValueLtFoxpath'
        case attribute(leFoxpath) return 'ExprValueLeFoxpath'
        case attribute(gtFoxpath) return 'ExprValueGtFoxpath'
        case attribute(geFoxpath) return 'ExprValueGeFoxpath'
        default return error()
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-', $constraint/local-name(.))
        
    let $msg :=
        if ($colour eq 'green') then 
            let $msgName := concat($constraint/local-name(.), 'MsgOK')
            return $valueShape/@*[local-name(.) eq $msgName]/attribute msg {.}
        else
            let $msgName := concat($constraint/local-name(.), 'Msg')
            return $valueShape/(@*[local-name(.) eq $msgName]/attribute msg {.}, @msg)[1]
    let $elemName := 
        switch($colour)
        case 'red' return 'gx:error'
        default return concat('gx:', $colour)
    return
        element {$elemName} {
            $msg,
            attribute valueShapeKind {$valueShapeKind},
            attribute constraintComp {$constraintComponent},
            attribute valueShapeID {$valueShapeId},
            attribute constraintID {$constraintId},
            $valueShape/@label/attribute constraintLabel {.},
            attribute expr {$expr},
            $valueShape/(@* except (@resourceShapeID, @valueShapeID, @constraintID, @label, @expr, @id, @msg))[not(matches(local-name(.), 'Msg(OK)?$'))],
            $additionalAtts,
            (: $valueShape/*, :)   (: may depend on 'verbosity' :)
            $additionalElems
        }
       
};

declare function f:validationResult_expressionCount($colour as xs:string,
                                                    $valueShape as element(),
                                                    $constraint as node()*,
                                                    $count as xs:integer,
                                                    $additionalAtts as attribute()*,
                                                    $additionalElems as element()*)
        as element() {
    let $valueShapeKind := $valueShape/local-name(.)
    let $expr := $valueShape/@expr/normalize-space(.)        
    let $constraintComponent :=
        typeswitch($constraint[1])
        case attribute(count) return 'ExprValueCount'
        case attribute(minCount) return 'ExprValueMinCount'        
        case attribute(maxCount) return 'ExprValueMaxCount'
        default return error()
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintSuffix := $constraintComponent ! replace(., '^ExprValue', '') ! f:firstCharToLowerCase(.)
    let $constraintId := concat($valueShapeId, '-', $constraintSuffix)
    
    let $msg :=
        if ($colour eq 'green') then 
            let $msgName := concat($constraint/local-name(.), 'MsgOK')
            return $valueShape/@*[local-name(.) eq $msgName]/attribute msg {.}
        else
            let $msgName := concat($constraint/local-name(.), 'Msg')
            return $valueShape/(@*[local-name(.) eq $msgName]/attribute msg {.}, @msg)[1]
    let $elemName := 
        switch($colour)
        case 'red' return 'gx:error'
        default return concat('gx:', $colour)
    return
        element {$elemName} {
            $msg,
            attribute valueShapeKind {$valueShapeKind},
            attribute constraintComp {$constraintComponent},
            attribute valueShapeID {$valueShapeId},
            attribute constraintID {$constraintId},
            attribute expr {$expr},
            attribute actualCount {$count},
            $constraint[self::attribute()],
            $additionalAtts,
            (: $valueShape/*, :)   (: may depend on 'verbosity' :)
            $constraint[self::element()],
            $additionalElems
        }       
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







