(:
 : -------------------------------------------------------------------------
 :
 : valueConstraint.xqm - validates a resource against Value constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/value";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "resourceAccess.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm",
   "linkResolution.xqm",
   "linkValidation.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates Value constraints.
 :
 : The $contextItem is either the current resource, or a focus node.
 :
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateValueConstraint($constraintElem as element(),
                                           $context as map(xs:string, item()*))
        as element()* {
    
    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    return
    
    (: Exception - no context document :)
    if ($constraintElem/(self::gx:value, gx:value)/@exprXP and not($context?_targetInfo?doc)) then
        result:validationResult_value_exception($constraintElem, (),
            'Context resource could not be parsed', (), (), $context)
    else
        
    (: Check values :)    
    let $results := f:validateValues($constraintElem, $contextNode, $context)
    
    return $results
};

(:~
 : ===============================================================================
 :
 :     P e r f o r m    v a l i d a t i o n s
 :
 : ===============================================================================
 :)

declare function f:validateValues($constraintElem as element(),
                                  $contextNode as node()?,
                                  $context as map(xs:string, item()*))
        as element()* {
        
    $constraintElem/(self::gx:value, self::gx:foxvalue, gx:value, gx:foxvalue)
        /f:validateValue(., $contextNode, $context)
};

(:~
 : Validates the constraints expressed by a `Value` element. These constraints are ...
 : _TO_DO_ continue description
 : - ...
 : - count constraints, referring to the number of items of the expression value
 :
 : @param constraintElem element declaring Value constraints
 : @param contextNode a context node to be used instead of the document root element
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateValue($constraintElem as element(),
                                 $contextNode as node()?,
                                 $context as map(*))
        as element()* {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $contextNode := ($targetInfo?focusNode, $targetInfo?doc)[1]
    let $contextLinesNode := $context?_reqDocs?lines
    let $evaluationContext := $context?_evaluationContext
    
    (: Read expression :)
    let $exprXP := $constraintElem/@exprXP
    let $exprFOX := $constraintElem/@exprFOX
    let $exprLP := $constraintElem/@exprLP
    let $filterMapLP :=
        if (not($constraintElem/(@filterLP, @mapLP))) then () else
            map:merge((
                map:entry('exprKind', 'filterMapLP'),
                $constraintElem/@filterLP/map:entry('filterLP', string(.)),
                $constraintElem/@mapLP/map:entry('mapLP', string(.))))
    let $exprSpec := ($exprXP, $exprFOX, $exprLP, $filterMapLP)[1]
    let $exprLang := if ($exprXP) then 'xpath' 
                     else if ($exprFOX) then 'foxpath' 
                     else if ($exprLP) then 'linepath'
                     else if (exists($filterMapLP)) then 'filtermap'
                     else error()
    
    let $expr :=
        if ($exprXP) then $exprXP
        else if ($exprFOX) then $exprFOX
        else if ($exprLP) then $exprLP
        else if (exists($filterMapLP)) then i:constructFilterMapExpr($filterMapLP)
        else error()
        
    (: Evaluate expression :)
    let $exprValue :=    
        if ($exprXP) then 
            i:evaluateXPath($exprXP, $contextNode, $evaluationContext, true(), true())
        else if ($exprFOX) then  
            i:evaluateFoxpath($exprFOX, $contextURI, $evaluationContext, true())
        else if ($exprLP) then
            i:evaluateXPath($exprLP, $contextLinesNode, $evaluationContext, true(), true())    
        else if (exists($filterMapLP)) then
            i:evaluateXPath($expr, $contextLinesNode, $evaluationContext, true(), true())    
                          
        else error(QName((), 'SCHEMA_ERROR'), 'Missing expression')
    
    let $results := 
    (
        f:validateValue_counts($exprValue, $expr, $exprSpec, $exprLang, $constraintElem, $context),
        f:validateValue_cmp($exprValue, $expr, $exprSpec, $exprLang, $constraintElem, $context),    
        f:validateValue_in($exprValue, $expr, $exprSpec, $exprLang, $constraintElem, $context),
        f:validateValue_contains($exprValue, $expr, $exprSpec, $exprLang, $constraintElem, $context),
        f:validateValue_sameTerms($exprValue, $expr, $exprSpec, $exprLang, $constraintElem, $context),
        f:validateValue_deepEqual($exprValue, $expr, $exprSpec, $exprLang, $constraintElem, $context),
        f:validateValue_itemsDistinct($exprValue, $expr, $exprSpec, $exprLang, $constraintElem, $context),
        ()
    )
    return
        $results
};    

declare function f:validateValue_cmp($exprValue as item()*,
                                     $expr as xs:string,
                                     $exprSpec as item(),
                                     $exprLang as xs:string,
                                     $constraintElem as element(),
                                     $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo        
    let $resultAdditionalAtts := ()
    let $resultOptions := ()    
    let $flags := string($constraintElem/@flags)
    let $quantifier := ($constraintElem/@quant, 'all')[1]
    let $useDatatype := $constraintElem/@useDatatype/i:resolveUseDatatype(.)
    let $useString := $constraintElem/@useString/tokenize(.)
    let $exprValueTY := i:applyUseDatatype($exprValue, $useDatatype, $useString) 
    
    for $cmp in $constraintElem/(
        @eq, @ne, @lt, @le, @gt, @ge, 
        @matches, @notMatches, @like, @notLike, 
        @min, @max,
        @length, @minLength, @maxLength, 
        @datatype)    
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
        case attribute(length) return function($op1, $op2) {string-length($op1) = $op2}
        case attribute(minLength) return function($op1, $op2) {string-length($op1) >= $op2}        
        case attribute(maxLength) return function($op1, $op2) {string-length($op1) <= $op2}        
        case attribute(datatype) return function($op1, $op2) {i:castableAs($op1, QName($i:URI_XSD, $op2))}       
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $cmp))        
    let $useCmp :=
        if ($cmp/self::attribute(like)) then $cmp/i:glob2regex(.)
        else if ($cmp/self::attribute(notLike)) then $cmp/i:glob2regex(.)
        else if ($cmp/self::attribute(datatype)) then $cmp        
        else if (empty($useDatatype)) then $cmp 
        else i:castAs($cmp, $useDatatype, ())
    let $results :=
        if ($quantifier eq 'all') then 
            let $violations := 
                for $ti at $pos in $exprValueTY
                return
                    if ($ti instance of element(gx:red)) then $ti
                    else if (not($cmpTrue($ti, $useCmp))) then 
                        if (empty($useDatatype)) then $ti else $exprValue[$pos]
                    else ()
            let $colour := if (empty($violations)) then 'green' else 'red'
            return 
                result:validationResult_value($colour, $constraintElem, $cmp, $exprValue, $violations, $exprSpec, $exprLang,
                                              $resultAdditionalAtts, (), $resultOptions, $context)
        else if ($quantifier eq 'some') then 
            let $match := exists($exprValueTY[$cmpTrue(., $useCmp)]) 
            let $colour := if ($match) then 'green' else 'red'
            return
                result:validationResult_value($colour, $constraintElem, $cmp, $exprValue, (), $exprSpec, $exprLang,
                                              $resultAdditionalAtts, (), $resultOptions, $context)
        else error()                                              
    return
        $results
};      

(:~
 : Validates ValueIn and ValueNotin constraints.
 :)
declare function f:validateValue_in($exprValue as item()*,
                                    $expr as xs:string,
                                    $exprSpec as item(),
                                    $exprLang as xs:string,                                                  
                                    $constraintElem as element(),
                                    $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo        
    let $constraintNodes := $constraintElem/(gx:in, gx:notin)
    return if (not($constraintNodes)) then () else
    
    let $resultAdditionalAtts := ()
    let $resultOptions := ()  
    
    let $useDatatype := $constraintElem/@useDatatype/i:resolveUseDatatype(.)
    let $useString := $constraintElem/@useString/tokenize(.)    
    let $exprValueConverted := i:applyUseDatatypeAndFilterErrors($exprValue, $useDatatype, $useString)
    let $exprValueTY := $exprValueConverted?values
    let $conversionErrors1 := $exprValueConverted?errors?item
    let $results_conversionError1 := (
        if (empty($conversionErrors1)) then () else
            let $msg :=
                concat("DATA CONVERSION ERROR - ",
                       "some value items could not be converted to '", $useDatatype, "'.")
            let $addAtts := attribute useDatatype {$useDatatype}
            let $addElems := $conversionErrors1 ! <gx:value>{string(.)}</gx:value>                           
            return result:validationResult_value_exception($constraintElem, $constraintNodes[1], $msg, $addAtts, $addElems, $context),
            ()
    )
    
    let $fn_matches := function($item, $itemTY, $alternatives) {
        some $alternative in $alternatives satisfies
        typeswitch($alternative)
        case element(gx:eq) return 
            if (exists($useDatatype)) then 
                $itemTY eq $alternative/@valueTY 
                else $item eq $alternative
        case element(gx:ne) return 
            if (exists($useDatatype)) then
                $itemTY != $alternative/@valueTY
                else $item ne $alternative
        case element(gx:like) return i:matchesLike($item, $alternative, $alternative/@flags)
        case element(gx:notLike) return not(i:matchesLike($item, $alternative, $alternative/@flags))                        
        case element(gx:matches) return matches($item, $alternative, string($alternative/@flags))
        case element(gx:notMatches) return not(matches($item, $alternative, string($alternative/@flags)))                        
        default return error()    
    }
    let $flags := string($constraintElem/@flags)    
    let $quantifier := ($constraintElem/@quant, 'all')[1]
    return (

    (: Results #1: conversion errors 
       ============================= :)
    $results_conversionError1,
    
    (: Results #2: constraint results, also reference value conversion errors 
       ====================================================================== :)
    (: Loop over constraints :)
    for $constraintNode in $constraintNodes
    
    (: Alternatives are enhanced by typed values (if appropriate) :)
    let $alternativesRaw :=
        if (empty($useDatatype)) then $constraintNode/*
        else
            for $alternative in $constraintNode/*
            return
                typeswitch($alternative)
                case element(gx:eq) | element(gx:ne) return
                    let $converted := $alternative/i:applyUseDatatype(., $useDatatype, $useString)
                    return
                        if ($converted instance of map(*)) then $converted else
                        element {node-name($alternative)} {
                            $alternative/@*, attribute valueTY {$converted},
                            $alternative/node()
                        }
                default return $alternative
    let $alternatives := $alternativesRaw[. instance of element()]                
    let $conversionErrors2 := $alternativesRaw[. instance of map(*)]
    
    let $results_conversionError2 := (
        if (empty($conversionErrors2)) then () else
            let $msg :=
                concat("DATA CONVERSION ERROR - ",
                       "some value items could not be converted to '", $useDatatype, "'.")
            let $addAtts := attribute useDatatype {$useDatatype}
            let $addElems := $conversionErrors2 ! <gx:value>{string(.)}</gx:value>                           
            return result:validationResult_value_exception($constraintElem, $constraintNode, $msg, $addAtts, $addElems, $context),
            ()
    )    
    let $results_constraint :=
        typeswitch($constraintNode)
        case element(gx:in) return
            if ($quantifier eq 'all') then            
                let $violations := 
                    if (empty($useDatatype)) then $exprValue[not($fn_matches(., ., $alternatives))]
                    else
                        for $item at $pos in $exprValue
                        let $itemTY := $exprValue[$pos]
                        where not($fn_matches($item, $itemTY, $alternatives))
                        return $item
                let $colour := if (exists($violations)) then 'red' else 'green'
                return
                    result:validationResult_value(
                        $colour, $constraintElem, $constraintNode, $exprValue, $violations, $exprSpec, $exprLang,
                        $resultAdditionalAtts, (), $resultOptions, $context)
            else if ($quantifier eq 'some') then
                let $conforms :=
                    if (empty($useDatatype)) then 
                        some $item in $exprValue satisfies $fn_matches($item, $item, $alternatives)
                    else
                        some $pos in 1 to count($exprValue)
                        satisfies $fn_matches($exprValue[$pos], $exprValueTY[$pos], $alternatives)
                let $colour := if ($conforms) then 'green' else 'red'                
                return
                    result:validationResult_value(
                        $colour, $constraintElem, $constraintNode, $exprValue, $exprValue[not($conforms)], $exprSpec, $exprLang,
                        $resultAdditionalAtts, (), $resultOptions, $context)
            else error()                        
        case element(gx:notin) return
            if ($quantifier eq 'all') then
                let $violations := 
                    if (empty($useDatatype)) then $exprValue[$fn_matches(., ., $alternatives)]
                    else
                        for $item at $pos in $exprValue
                        let $itemTY := $exprValue[$pos]
                        where $fn_matches($item, $itemTY, $alternatives)
                        return $item                    
                let $colour := if (exists($violations)) then 'red' else 'green'
                return
                    result:validationResult_value(
                        $colour, $constraintElem, $constraintNode, $exprValue, $violations, $exprSpec, $exprLang,
                        $resultAdditionalAtts, (), $resultOptions, $context)
            else if ($quantifier eq 'some') then
                let $conforms := 
                    if (empty($useDatatype)) then
                        some $item in $exprValue satisfies not($fn_matches($item, $constraintNode))
                    else                        
                        some $pos in 1 to count($exprValue)
                        satisfies not($fn_matches($exprValue[$pos], $exprValueTY[$pos], $alternatives))
                let $colour := if ($conforms) then 'green' else 'red'                
                return
                    result:validationResult_value(
                        $colour, $constraintElem, $constraintNode, $exprValue, $exprValue[not($conforms)], $exprSpec, $exprLang,
                        $resultAdditionalAtts, (), $resultOptions, $context)
            else ()    
        default return error()
    return (
        $results_conversionError2,
        $results_constraint
    )
    )
};        

(:~
 : Validates ValueContains constraints.
 :)
declare function f:validateValue_contains($exprValue as item()*,
                                          $expr as xs:string,
                                          $exprSpec as item(),
                                          $exprLang as xs:string,                                              
                                          $constraintElem as element(),
                                          $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo  
    let $constraintNode := $constraintElem/gx:contains
    let $expectedItems := $constraintElem/gx:contains/gx:term
    return if (not($expectedItems)) then () else
    
    let $useDatatype := $constraintElem/@useDatatype/i:resolveUseDatatype(.)
    let $useString := $constraintElem/@useString/tokenize(.)    
    let $exprValueConverted := i:applyUseDatatypeAndFilterErrors($exprValue, $useDatatype, $useString)
    let $expectedItemsConverted := i:applyUseDatatypeAndFilterErrors($expectedItems, $useDatatype, $useString)
    let $exprValueTY := $exprValueConverted?values
    let $expectedItemsTY := $expectedItemsConverted?values
    let $conversionErrors1 := $exprValueConverted?errors?item
    let $conversionErrors2 := $expectedItemsConverted?errors?item
    let $results_conversionError := (
        if (empty($conversionErrors1)) then () else
            let $msg :=
                concat("DATA CONVERSION ERROR - ",
                       "some value items could not be converted to '", $useDatatype, "'.")
            let $addAtts := attribute useDatatype {$useDatatype}
            let $addElems := $conversionErrors1 ! <gx:value>{string(.)}</gx:value>                           
            return result:validationResult_value_exception($constraintElem, $constraintNode, $msg, $addAtts, $addElems, $context),
        if (empty($conversionErrors2)) then () else
            let $msg :=
                concat("INVALID SCHEMA - some 'term' values from element '", $constraintNode/local-name(.), "' ",
                       "cannot be converted to '", $useDatatype, "'.")
            let $addAtts := attribute useDatatype {$useDatatype}                           
            let $addElems := $conversionErrors2 ! <gx:value>{string(.)}</gx:value>
            return result:validationResult_value_exception($constraintElem, $constraintNode, $msg, $addAtts, $addElems, $context)
    )
    let $results_constraint :=    
        let $notContainedTY := $expectedItemsTY[not(. = $exprValueTY)]
        let $colour := if (exists($notContainedTY)) then 'red' else 'green'
        let $additionalElems :=
            if ($colour eq 'green') then () else
                $notContainedTY ! string() ! <gx:missingValue>{.}</gx:missingValue>
        return
            result:validationResult_value(
                $colour, $constraintElem, $constraintNode, $exprValue, (), $exprSpec, $exprLang,
                (), $additionalElems, (), $context)
    return ($results_conversionError, $results_constraint)                
};        

(:~
 : Validates ValueSameTerms constraints.
 :)
declare function f:validateValue_sameTerms($exprValue as item()*,
                                           $expr as xs:string,
                                           $exprSpec as item(),
                                           $exprLang as xs:string,                                              
                                           $constraintElem as element(),
                                           $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo  
    let $constraintNode := $constraintElem/gx:sameTerms
    let $expectedItems := $constraintElem/gx:sameTerms/gx:term
    return if (not($expectedItems)) then () else
    
    let $useDatatype := $constraintElem/@useDatatype/i:resolveUseDatatype(.)
    let $useString := $constraintElem/@useString/tokenize(.)    
    let $exprValueConverted := i:applyUseDatatypeAndFilterErrors($exprValue, $useDatatype, $useString)
    let $expectedItemsConverted := i:applyUseDatatypeAndFilterErrors($expectedItems, $useDatatype, $useString)
    let $exprValueTY := $exprValueConverted?values
    let $expectedItemsTY := $expectedItemsConverted?values
    let $conversionErrors1 := $exprValueConverted?errors?item
    let $conversionErrors2 := $expectedItemsConverted?errors?item
    let $results_conversionError := (
        if (empty($conversionErrors1)) then () else
            let $msg :=
                concat("DATA CONVERSION ERROR - ",
                       "some value items could not be converted to '", $useDatatype, "'.")
            let $addAtts := attribute useDatatype {$useDatatype}
            let $addElems := $conversionErrors1 ! <gx:value>{string(.)}</gx:value>                           
            return result:validationResult_value_exception($constraintElem, $constraintNode, $msg, $addAtts, $addElems, $context),
        if (empty($conversionErrors2)) then () else
            let $msg :=
                concat("INVALID SCHEMA - some 'term' values from element 'sameTerms' ",
                       "cannot be converted to '", $useDatatype, "'.")
            let $addAtts := attribute useDatatype {$useDatatype}                           
            let $addElems := $conversionErrors2 ! <gx:value>{string(.)}</gx:value>
            return result:validationResult_value_exception($constraintElem, $constraintNode, $msg, $addAtts, $addElems, $context)
    )
    
    let $violations1 := 
        if (empty($useDatatype)) then $exprValue[not(. = $expectedItems)]
        else 
            for $pos in 1 to count($exprValue)
            where not($exprValueTY[$pos] = $expectedItemsTY)
            return $exprValue[$pos]
    let $violations2 := $expectedItemsTY[not(. = $exprValueTY)]
    let $colour := if (exists(($violations1, $violations2))) then 'red' else 'green' 
    let $violations := $violations1
    let $additionalElems := $violations2 ! string(.) ! <gx:missingValue>{.}</gx:missingValue>
    let $results_constraint :=
        result:validationResult_value(
            $colour, $constraintElem, $constraintNode, $exprValue, $violations, $exprSpec, $exprLang,
            (), $additionalElems, (), $context)
    return (
        $results_constraint,
        $results_conversionError
    )
};        

(:~
 : Validates ValueDeepEqual constraints.
 :)
declare function f:validateValue_deepEqual($exprValue as item()*,
                                           $expr as xs:string,
                                           $exprSpec as item(),
                                           $exprLang as xs:string,                                              
                                           $constraintElem as element(),
                                           $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo  
    let $constraintNode := $constraintElem/gx:deepEqual
    let $expectedItems := $constraintElem/gx:deepEqual/gx:term/string()
    return if (not($constraintNode)) then () else
    
    let $useDatatype := $constraintElem/@useDatatype/i:resolveUseDatatype(.)
    let $useString :=
        (: If neither useDatatype nor useString is used, the items must be converted to string :)
        if (exists($useDatatype)) then () 
        else
            let $explicit := $constraintElem/@useString
            return if (not($explicit)) then 'sv' else $explicit/tokenize(.)
    
    let $exprValueConverted := i:applyUseDatatypeAndFilterErrors($exprValue, $useDatatype, $useString)
    let $expectedItemsConverted := i:applyUseDatatypeAndFilterErrors($expectedItems, $useDatatype, $useString)
    let $exprValueTY := $exprValueConverted?values
    let $expectedItemsTY := $expectedItemsConverted?values
    let $conversionErrors1 := $exprValueConverted?errors?item
    let $conversionErrors2 := $expectedItemsConverted?errors?item
    let $results_conversionError := (
        if (empty($conversionErrors1)) then () else
            let $msg :=
                concat("DATA CONVERSION ERROR - ",
                       "some value items could not be converted to '", $useDatatype, "'.")
            let $addAtts := attribute useDatatype {$useDatatype}
            let $addElems := $conversionErrors1 ! <gx:value>{string(.)}</gx:value>                           
            return result:validationResult_value_exception($constraintElem, $constraintNode, $msg, $addAtts, $addElems, $context),
        if (empty($conversionErrors2)) then () else
            let $msg :=
                concat("INVALID SCHEMA - some 'term' values from element '", $constraintNode/local-name(.), "' ",
                       "cannot be converted to '", $useDatatype, "'.")
            let $addAtts := attribute useDatatype {$useDatatype}                           
            let $addElems := $conversionErrors2 ! <gx:value>{string(.)}</gx:value>
            return result:validationResult_value_exception($constraintElem, $constraintNode, $msg, $addAtts, $addElems, $context)
    )
    let $results_constraint :=
        if ($results_conversionError) then
            let $msg := "CHECK NOT POSSIBLE - deepEqual check not possible because of datatype conversion errors"
            return                
                result:validationResult_value_exception($constraintElem, $constraintNode, $msg, (), (), $context)        
        else
        
        (: Number of items not equal :)
        if (count($exprValueTY) ne count($expectedItemsTY)) then
            let $addAtts := (
                    attribute countItems {count($exprValueTY)},
                    attribute countDeepEqualTerms {count($expectedItemsTY)}
            )
            return
                let $addAtts := attribute addInfo {'Numbers of value items and control terms different'}
                return
                    result:validationResult_value(
                        'red', $constraintElem, $constraintNode, $exprValue, (), $exprSpec, $exprLang,
                        $addAtts, $addAtts, (), $context)
        
        (: Deep-equal ok :)
        else if (deep-equal($exprValueTY, $expectedItemsTY)) then 
                result:validationResult_value(
                    'green', $constraintElem, $constraintNode, $exprValue, (), $exprSpec, $exprLang,
                    (), (), (), $context)
        
        (: Deep-equal not ok :)
        else                
            (: Index of first deviation :)
            let $minIndexDeviation :=
                min(
                    for $pos in 1 to count($exprValueTY)
                    where not($exprValueTY[$pos] eq $expectedItemsTY[$pos])
                    return $pos)
            let $violations := $exprValue[$minIndexDeviation]
            let $addAtts := 
                attribute valueNotEqualTo {$expectedItems[$minIndexDeviation]}
            let $addElems := ()             
            return
                result:validationResult_value(
                    'red', $constraintElem, $constraintNode, $exprValue, $violations, $exprSpec, $exprLang,
                    $addAtts, $addElems, (), $context)
    return (
        $results_conversionError,
        $results_constraint
    )
};        

(:~
 : Validates ValueItemsDistinct constraints.
 :)
declare function f:validateValue_itemsDistinct(
                                          $exprValue as item()*,
                                          $expr as xs:string,
                                          $exprSpec as item(),
                                          $exprLang as xs:string,                                              
                                          $constraintElem as element(),
                                          $context as map(xs:string, item()*))
        as element()* {
    let $itemsUnique := $constraintElem/@distinct
    return if (empty($itemsUnique)) then () else
    
    let $useDatatype := $constraintElem/@useDatatype/i:resolveUseDatatype(.)
    let $useString := $constraintElem/@useString/tokenize(.)
    let $exprValueTY := i:applyUseDatatype($exprValue, $useDatatype, $useString)
    let $itemsUniqueExp := $itemsUnique/xs:boolean(.)
    let $itemsUniqueAct := count($exprValueTY) eq $exprValueTY => distinct-values() => count()
    let $colour :=
        if ($itemsUniqueExp and $itemsUniqueAct or
            not($itemsUniqueExp) and not($itemsUniqueAct)) then 'green'
            else 'red'
            
    let $violations :=
        let $values :=
            if (not($itemsUniqueExp)) then () else
                for $item in $exprValue
                group by $v := $item ! i:applyUseDatatype(., $useDatatype, $useString)
                where count($item) gt 1
                return $v
        return $exprValue[. = $values]                
    return            
        result:validationResult_value(
            $colour, $constraintElem, $itemsUnique, $exprValue, $violations, $exprSpec, $exprLang,
                (), (), (), $context)
};        


(:~
 : Validates the count constraints expressed by an `expression` element:
 : @count, @minCount, @maxCount. 
 :
 : @param items the items returned by an expression
 : @param constraintElem an `expression` element representing an Expression constraint
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateValue_counts($items as item()*,
                                        $expr as xs:string,
                                        $exprSpec as item(),
                                        $exprLang as xs:string,
                                        $constraintElem as element(),
                                        $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo
    let $valueCount := count($items)    
    let $constraintNodes1 := $constraintElem/(@count, @minCount, @maxCount)
    let $constraintNodes2 := $constraintElem/(@exists, @empty)
    let $results1 :=
        if (empty($constraintNodes1)) then () else
        
        (: evaluate constraints :)
        for $constraintNode in $constraintNodes1
        let $cmpWith := $constraintNode/xs:integer(.)
        let $ok :=
            typeswitch($constraintNode)
            case attribute(count)    return $valueCount eq $cmpWith
            case attribute(minCount) return $valueCount ge $cmpWith
            case attribute(maxCount) return $valueCount le $cmpWith
            default return error()
        let $colour := if ($ok) then 'green' else 'red'        
        return  
            result:validationResult_value_counts(
                $colour, $constraintElem, $constraintNode, $items, $exprSpec, $exprLang, (), $context)
                
    let $results2 :=
        if (empty($constraintNodes2)) then () else
        for $constraintNode in $constraintNodes2
        let $ok :=
            typeswitch($constraintNode)
            case attribute(exists) return 
                $constraintNode/xs:boolean(.) and $valueCount or 
                not($constraintNode/xs:boolean(.)) and not($valueCount)
            case attribute(empty) return
                $constraintNode/xs:boolean(.) and not($valueCount) or 
                not($constraintNode/xs:boolean(.)) and $valueCount
            default return error()
        let $colour := if ($ok) then 'green' else 'red'
        return
            result:validationResult_value_counts(
                $colour, $constraintElem, $constraintNode, $items, $exprSpec, $exprLang, (), $context)
    return ($results1, $results2)        
};



