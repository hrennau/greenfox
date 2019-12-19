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
    let $in := $constraint/gx:in
    let $notin := $constraint/gx:notin
    
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
    let $quantifier := ($constraint/@quant, 'all')[1]
    
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
(:        
        if (not($eq)) then () else f:validateExpressionValue_eq($exprValue, $quantifier, $constraint),    
        if (not($ne)) then () else f:validateExpressionValue_ne($exprValue, $quantifier, $constraint),
:)        
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
    let $allErrors := ($errors, $errorsIn)
    return
        if ($allErrors) then $allErrors
        else f:constructGreen_valueShape($constraint)
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
                else if (not($cmpTrue(., $useCmp))) then trace(., concat('§§§§ NOT_CMPTRUE; USE_ITEM: ', ., ' ; USECMP: ', $useCmp, ': '))
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
        default return error()
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-', $constraint/local-name(.))
        
    let $msg := trace(
        if ($colour eq 'green') then 
            let $msgName := concat($constraint/local-name(.), 'MsgOK')
            return $valueShape/@*[local-name(.) eq $msgName]/attribute msg {.}
        else
            let $msgName := concat($constraint/local-name(.), 'Msg')
            return $valueShape/(@*[local-name(.) eq $msgName]/attribute msg {.}, @msg)[1]
    , '### MSG: ')
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








