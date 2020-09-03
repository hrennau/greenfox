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
 : @param contextURI the file path of the file containing the initial context item 
 : @param contextDoc the XML document containing the initial context item
 : @param contextItem the initial context item to be used in expressions
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateValueConstraint($contextURI as xs:string,
                                           $contextDoc as document-node()?,
                                           $contextNode as node()?,
                                           $constraintElem as element(),
                                           $context as map(xs:string, item()*))
        as element()* {
    
    (: Exception - no context document :)
    if ($constraintElem/gx:value/@exprXP and not($context?_targetInfo?doc)) then
        result:validationResult_value_exception($constraintElem,
            'Context resource could not be parsed', (), $context)
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
        
    $constraintElem/(gx:value, gx:foxvalue)/f:validateValue(., $contextNode, $context)
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
    let $evaluationContext := $context?_evaluationContext
    
    (: Read expression :)
    let $exprXP := $constraintElem/@exprXP
    let $exprFOX := $constraintElem/@exprFOX
    let $expr := ($exprXP, $exprFOX)[1]
    let $exprLang := if ($exprXP) then 'xpath' 
                     else if ($exprFOX) then 'foxpath' 
                     else error()
    
    (: Evaluate expression :)
    let $exprValue :=    
        if ($exprXP) then 
            i:evaluateXPath($exprXP, $contextNode, $evaluationContext, true(), true())
        else if ($exprFOX) then  
            i:evaluateFoxpath($exprFOX, $contextURI, $evaluationContext, true())
        else error(QName((), 'SCHEMA_ERROR'), 'Missing expression')
    
    let $results := 
    (
        f:validateValue_counts($exprValue, $constraintElem, $context),
        f:validateValue_cmp($exprValue, $expr, $exprLang, $constraintElem, $context),    
        f:validateValue_in($exprValue, $expr, $exprLang, $constraintElem, $context),
        f:validateValue_contains($exprValue, $expr, $exprLang, $constraintElem, $context),
        f:validateValue_eqeq($exprValue, $expr, $exprLang, $constraintElem, $context),
        f:validateValue_itemsUnique($exprValue, $expr, $exprLang, $constraintElem, $context),
        ()
    )
    return
        $results
};    

declare function f:validateValue_cmp($exprValue as item()*,
                                     $expr as xs:string,
                                     $exprLang as xs:string,
                                     $constraintElem as element(),
                                     $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo        
    let $resultAdditionalAtts := ()
    let $resultOptions := ()    
    let $flags := string($constraintElem/@flags)
    let $quantifier := ($constraintElem/@quant, 'all')[1]
    let $useDatatype := $constraintElem/@useDatatype/(
        if (not(contains(., ':'))) then QName($i:URI_XSD, .)
        else resolve-QName(., ..))
    let $typedItems := 
        if (empty($useDatatype)) then $exprValue else 
            $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
    
    for $cmp in $constraintElem/(
        @eq, @ne, @lt, @le, @gt, @ge, 
        @matches, @notMatches, @like, @notLike, 
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
        if ($cmp/self::attribute(like)) then trace( $cmp/i:glob2regex(.) , '_USECMP: ')
        else if ($cmp/self::attribute(notLike)) then $cmp/i:glob2regex(.)
        else if ($cmp/self::attribute(datatype)) then $cmp        
        else if (empty($useDatatype)) then $cmp 
        else i:castAs($cmp, $useDatatype, ())
    let $results :=
        if ($quantifier eq 'all') then 
            let $violations := 
                for $ti at $pos in $typedItems
                return
                    if ($ti instance of element(gx:red)) then $ti
                    else if (not($cmpTrue($ti, $useCmp))) then 
                        if (empty($useDatatype)) then $ti else $exprValue[$pos]
                    else ()
            let $colour := if (empty($violations)) then 'green' else 'red'
            return 
                result:validationResult_value($colour, $constraintElem, $cmp, $exprValue, $violations, $expr, $exprLang,
                                              $resultAdditionalAtts, (), $resultOptions, $context)
        else if ($quantifier eq 'some') then 
            let $match := exists($typedItems[$cmpTrue(., $useCmp)]) 
            let $colour := if ($match) then 'green' else 'red'
            return
                result:validationResult_value($colour, $constraintElem, $cmp, $exprValue, (), $expr, $exprLang,
                                              $resultAdditionalAtts, (), $resultOptions, $context)
    return
        $results
};      

(:~
 : Validates ValueIn and ValueNotin constraints.
 :)
declare function f:validateValue_in($exprValue as item()*,
                                    $expr as xs:string,
                                    $exprLang as xs:string,                                                  
                                    $constraintElem as element(),
                                    $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo        
    let $constraints := $constraintElem/(gx:in, gx:notin)
    return if (not($constraints)) then () else
    
    let $resultAdditionalAtts := ()
    let $resultOptions := ()    
    let $fn_matches := function($item, $constraint) {
        some $alternative in $constraint/* satisfies
        typeswitch($alternative)
        case element(gx:eq) return $item = $alternative
        case element(gx:ne) return $item != $alternative
        case element(gx:like) return i:matchesLike($item, $alternative, $alternative/@flags)
        case element(gx:notLike) return not(i:matchesLike($item, $alternative, $alternative/@flags))                        
        case element(gx:matches) return matches($item, $alternative, string($alternative/@flags))
        case element(gx:notMatches) return not(matches($item, $alternative, string($alternative/@flags)))                        
        default return error()    
    }
    let $flags := string($constraintElem/@flags)    
    let $quantifier := ($constraintElem/@quant, 'all')[1]
    for $cmp in $constraints
    return
        typeswitch($cmp)
        case element(gx:in) return
            if ($quantifier eq 'all') then            
                let $violations := $exprValue[not($fn_matches(., $cmp))]
                let $colour := if (exists($violations)) then 'red' else 'green'
                return
                    result:validationResult_value(
                        $colour, $constraintElem, $cmp, $exprValue, $violations, $expr, $exprLang,
                        $resultAdditionalAtts, (), $resultOptions, $context)
            else if ($quantifier eq 'some') then
                let $conforms := some $item in $exprValue satisfies $fn_matches($item, $cmp)
                let $colour := if ($conforms) then 'green' else 'red'                
                return
                    result:validationResult_value(
                        $colour, $constraintElem, $cmp, $exprValue, $exprValue[not($conforms)], $expr, $exprLang,
                        $resultAdditionalAtts, (), $resultOptions, $context)
            else error()                        
        case element(gx:notin) return
            if ($quantifier eq 'all') then
                let $violations := $exprValue[$fn_matches(., $cmp)]
                let $colour := if (exists($violations)) then 'red' else 'green'
                return
                    result:validationResult_value(
                        $colour, $constraintElem, $cmp, $exprValue, $violations, $expr, $exprLang,
                        $resultAdditionalAtts, (), $resultOptions, $context)
            else if ($quantifier eq 'some') then
                let $conforms := some $item in $exprValue satisfies not($fn_matches($item, $cmp))
                let $colour := if ($conforms) then 'green' else 'red'                
                return
                    result:validationResult_value(
                        $colour, $constraintElem, $cmp, $exprValue, $exprValue[not($conforms)], $expr, $exprLang,
                        $resultAdditionalAtts, (), $resultOptions, $context)
                
        default return error()
};        

(:~
 : Validates ValueContains constraints.
 :)
declare function f:validateValue_contains($exprValue as item()*,
                                          $expr as xs:string,
                                          $exprLang as xs:string,                                              
                                          $constraintElem as element(),
                                          $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo  
    let $constraintNode := $constraintElem/gx:contains
    let $expectedItems := $constraintElem/gx:contains/gx:term
    return if (not($expectedItems)) then () else

    let $quantifier := ($constraintElem/@quant, 'all')[1] return
    
    if ($quantifier eq 'all') then
        let $notContained := $expectedItems[not(. = $exprValue)]
        let $colour := if (exists($notContained)) then 'red' else 'green'
        let $additionalElems :=
            if ($colour eq 'green') then () else
                $notContained/string() ! <gx:missingValue>{.}</gx:missingValue>
        return
            result:validationResult_value(
                $colour, $constraintElem, $constraintNode, $exprValue, (), $expr, $exprLang,
                (), $additionalElems, (), $context)
    else if ($quantifier eq 'some') then
        let $contained := $expectedItems[. = $exprValue]
        let $colour := if (exists($contained)) then 'green' else 'red'
        return
            result:validationResult_value(
                $colour, $constraintElem, $constraintNode, $exprValue, (), $expr, $exprLang,
                (), (), (), $context)
    else error()        
};        

(:~
 : Validates ValueEqEq constraints.
 :)
declare function f:validateValue_eqeq($exprValue as item()*,
                                      $expr as xs:string,
                                      $exprLang as xs:string,                                              
                                      $constraintElem as element(),
                                      $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo  
    let $constraintNode := $constraintElem/gx:eqeq
    let $expectedItems := $constraintElem/gx:eqeq/gx:term
    return if (not($expectedItems)) then () else

    let $violations1 := $exprValue[not(. = $expectedItems)]
    let $violations2 := $expectedItems[not(. = $exprValue)]
    let $colour := if (exists(($violations1, $violations2))) then 'red' else 'green' 
    let $violations := $violations1
    let $additionalElems := $violations2/string() ! <gx:missingValue>{.}</gx:missingValue>
    return
        result:validationResult_value(
            $colour, $constraintElem, $constraintNode, $exprValue, $violations, $expr, $exprLang,
            (), $additionalElems, (), $context)
};        

(:~
 : Validates ValueItemsUnique constraints.
 :)
declare function f:validateValue_itemsUnique($exprValue as item()*,
                                          $expr as xs:string,
                                          $exprLang as xs:string,                                              
                                          $constraintElem as element(),
                                          $context as map(xs:string, item()*))
        as element()* {
    let $itemsUnique := $constraintElem/@itemsUnique
    return if (empty($itemsUnique)) then () else
    
    let $useDatatype := $constraintElem/@useDatatype/(
        if (not(contains(., ':'))) then QName($i:URI_XSD, .)
        else resolve-QName(., ..))
    let $typedItems := 
        if (empty($useDatatype)) then $exprValue else 
            $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
    
    let $itemsUniqueExp := $itemsUnique/xs:boolean(.)
    let $itemsUniqueAct := count($typedItems) eq $typedItems => distinct-values() => count()
    let $colour :=
        if ($itemsUniqueExp and $itemsUniqueAct or
            not($itemsUniqueExp) and not($itemsUniqueAct)) then 'green'
            else 'red'
            
    let $violations :=
        let $values :=
            if (not($itemsUniqueExp)) then () else
                for $item in $exprValue
                group by $v := $item ! (if (empty($useDatatype)) then . else i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red')))
                where count($item) gt 1
                return $v
        return $exprValue[. = $values]                
    return            
        result:validationResult_value(
            $colour, $constraintElem, $itemsUnique, $exprValue, $violations, $expr, $exprLang,
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
                $colour, $constraintElem, $constraintNode, $items, (), $context)
                
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
                $colour, $constraintElem, $constraintNode, $items, (), $context)
    return ($results1, $results2)        
};



