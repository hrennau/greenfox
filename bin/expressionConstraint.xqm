(:
 : -------------------------------------------------------------------------
 :
 : expressionConstraint.xqm - validates a resource against an Expression constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/expression";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm",
    "resourceAccess.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at
    "linkDefinition.xqm",
    "linkResolution.xqm",
    "linkValidation.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at
    "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates an Expression Pair constraint.
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
declare function f:validateExpressionConstraint($contextURI as xs:string,
                                                $contextDoc as document-node()?,
                                                $contextNode as node()?,
                                                $constraintElem as element(),
                                                $context as map(xs:string, item()*))
        as element()* {
    
    (: context info - a container for current file path, current document and datapath of the focus node :)    
    let $contextInfo := 
        let $focusPath := $contextNode[not(. is $contextDoc)] ! i:datapath(.)
        return  
            map:merge((
                $contextURI ! map:entry('filePath', .),
                $contextDoc ! map:entry('doc', .),
                $focusPath ! map:entry('nodePath', .)))
    return
        (: Exception - no context document :)
        if (not($contextInfo?doc)) then
            result:validationResult_expression_exception($constraintElem,
                'Context resource could not be parsed', (), $contextInfo)
        else
        
    (: Check expression pairs :)    
    let $results := f:validateExpressions($constraintElem, $contextNode, $contextInfo, $context)
    
    return $results
};

(:~
 : ===============================================================================
 :
 :     P e r f o r m    v a l i d a t i o n s
 :
 : ===============================================================================
 :)

declare function f:validateExpressions($constraintElem as element(),
                                       $contextNode as node()?,
                                       $contextInfo as map(*),
                                       $context as map(xs:string, item()*))
        as element()* {
        
    $constraintElem/gx:expression/f:validateExpression(., $contextNode, $contextInfo, $context)
};

(:~
 : Validates the constraints expressed by an `expressionPair` element contained
 : by an ExpressionPair constraint. These constraints are ...
 : - a correspondence constraint, defined by @cmp, @expr1XP, @expr2XP, @expr1FOX, @expr2FOX
 :   and further attributes (@quant, @useDatatype, @flags)
 : - count constraints, referring to the number of items returned by expression 1 and 2
 :
 : @param expressionPair element declaring an ExpressionPair constraint
 : @param contextNode a context node to be used instead of the document root element
 : @param contextInfo informs about the focus document and focus node 
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateExpression($constraintElem as element(gx:expression),
                                      $contextNode as node()?,
                                      $contextInfo as map(xs:string, item()*),
                                      $context as map(*))
        as element()* {
    let $contextURI := $contextInfo?filePath
    let $contextNode := ($contextNode, $contextInfo?doc)[1]
    let $evaluationContext := $context?_evaluationContext
    
    (: Read expression :)
    let $exprXP := $constraintElem/@exprXP
    let $exprFOX := $constraintElem/@exprFOX
    let $expr := ($exprXP, $exprFOX)[1]
    let $exprLang := if ($exprXP) then 'xpath' else if ($exprFOX) then 'foxpath' else error()
    
    (: Read constraints :)    
    let $minCount := $constraintElem/@minCount
    let $maxCount := $constraintElem/@maxCount
    let $count := $constraintElem/@count

    let $empty := $constraintElem/@empty
    let $exists := $constraintElem/@exists
    let $datatype := $constraintElem/@datatype
    let $itemsUnique := $constraintElem/@itemsUnique
    
    let $eq := $constraintElem/@eq   
    let $ne := $constraintElem/@ne    
    let $gt := $constraintElem/@gt
    let $ge := $constraintElem/@ge
    let $lt := $constraintElem/@lt
    let $le := $constraintElem/@le
    
    let $in := $constraintElem/gx:in
    let $notin := $constraintElem/gx:notin
    let $contains := $constraintElem/gx:contains
    
    let $matches := $constraintElem/@matches
    let $notMatches := $constraintElem/@notMatches
    let $like := $constraintElem/@like
    let $notLike := $constraintElem/@notLike
    
    let $length := $constraintElem/@length
    let $minLength := $constraintElem/@minLength
    let $maxLength := $constraintElem/@maxLength    
    
    (: Read evaluation options :)
    let $flags := string($constraintElem/@flags)
    let $quantifier := ($constraintElem/@quant, 'all')[1]
    let $useDatatype := $constraintElem/@useDatatype/resolve-QName(., ..)    

    (: Evaluate expression :)
    let $exprValue :=    
        if ($exprXP) then 
            i:evaluateXPath($exprXP, $contextNode, $evaluationContext, true(), true())
        else if ($exprFOX) then  
            i:evaluateFoxpath($exprFOX, $contextURI, $evaluationContext, true())
        else error(QName((), 'SCHEMA_ERROR'), 'Missing expression')
    
    let $results := 
    (
        f:validateExpressionCounts($exprValue, $constraintElem, $contextInfo),
        f:validateExpression_cmp($exprValue, $expr, $exprLang, $quantifier, $constraintElem, $contextInfo),    
        f:validateExpression_in($exprValue, $expr, $exprLang, $quantifier, $constraintElem, $contextInfo),
        ()
    )
    return
        $results
};    

declare function f:validateExpression_cmp($exprValue as item()*,
                                          $expr as xs:string,
                                          $exprLang as xs:string,
                                          $quantifier as xs:string,                                               
                                          $constraintElem as element(),
                                          $contextInfo as map(xs:string, item()*))
        as element()* {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()    
    let $flags := string($constraintElem/@flags)
    let $useDatatype := $constraintElem/@useDatatype/resolve-QName(., ..)
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
        if ($cmp/self::attribute(like)) then $cmp/i:glob2regex(.)
        else if ($cmp/self::attribute(notLike)) then $cmp/i:glob2regex(.)
        else if ($cmp/self::attribute(datatype)) then $cmp        
        else if (empty($useDatatype)) then $cmp 
        else i:castAs($cmp, $useDatatype, ())
    let $results :=
        if ($quantifier eq 'all') then 
            let $violations := $typedItems ! (
                if (. instance of element(gx:red)) then .
                else if (not($cmpTrue(., $useCmp))) then .
                else ())
            let $colour := if (empty($violations)) then 'green' else 'red'
            return 
                result:validationResult_expression($constraintElem, $colour, $exprValue, $violations, $expr, $exprLang, $cmp,
                                              $resultAdditionalAtts, (),                                            
                                              $contextInfo, $resultOptions)
        else if ($quantifier eq 'some') then 
            let $match := exists($typedItems[$cmpTrue(., $useCmp)]) 
            let $colour := if ($match) then 'green' else 'red'
            return
                result:validationResult_expression($constraintElem, $colour, $exprValue, (), $expr, $exprLang, $cmp,
                                              $resultAdditionalAtts, (), 
                                              $contextInfo, $resultOptions)
    return
        $results
};      

(:~
 : Validates ExpressionIn and ExpressionNotin constraints.
 :)
declare function f:validateExpression_in($exprValue as item()*,
                                          $expr as xs:string,
                                          $exprLang as xs:string,
                                          $quantifier as xs:string,                                               
                                          $constraintElem as element(),
                                          $contextInfo as map(xs:string, item()*))
        as element() {
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
        default return error()    
    }
    let $flags := string($constraintElem/@flags)        
    for $cmp in $constraints
    return
        typeswitch($cmp)
        case element(gx:in) return
            if ($quantifier eq 'all') then            
                let $violations := $exprValue[not($fn_matches(., $cmp))]
                let $colour := if (exists($violations)) then 'red' else 'green'
                return
                    result:validationResult_expression(
                        $constraintElem, $colour, $exprValue, $violations, $expr, $exprLang, $cmp,
                        $resultAdditionalAtts, (), $contextInfo, $resultOptions)
            else if ($quantifier eq 'some') then
                let $conforms := some $item in $exprValue satisfies $fn_matches($item, $cmp)
                let $colour := if ($conforms) then 'green' else 'red'                
                return
                    result:validationResult_expression(
                        $constraintElem, $colour, $exprValue, $exprValue[not($conforms)], $expr, $exprLang, $cmp,
                        $resultAdditionalAtts, (), $contextInfo, $resultOptions)
            else error()                        
        case element(gx:notin) return
            if ($quantifier eq 'all') then
                let $violations := $exprValue[$fn_matches(., $cmp)]
                let $colour := if (exists($violations)) then 'red' else 'green'
                return
                    result:validationResult_expression(
                        $constraintElem, $colour, $exprValue, $violations, $expr, $exprLang, $cmp,
                        $resultAdditionalAtts, (), $contextInfo, $resultOptions)
            else if ($quantifier eq 'some') then
                let $conforms := some $item in $exprValue satisfies not($fn_matches($item, $cmp))
                let $colour := if ($conforms) then 'green' else 'red'                
                return
                    result:validationResult_expression(
                        $constraintElem, $colour, $exprValue, $exprValue[not($conforms)], $expr, $exprLang, $cmp,
                        $resultAdditionalAtts, (), $contextInfo, $resultOptions)
                
        default return error()
};        

(:
declare function f:validateExpression_in($exprValue as item()*,
                                         $quantifier as xs:string,
                                         $valueShape as element(),
                                         $contextInfo as map(xs:string, item()*))
        as element() {
    let $in := $valueShape/gx:in
    return
    
    if (not($in)) then () else
    
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $exprValue[not(
                some $alternative in $in/* satisfies
                    typeswitch($alternative)
                        case element(gx:eq) return . = $alternative
                        case element(gx:ne) return . != $alternative
                        case element(gx:like) return i:matchesLike(., $alternative, $alternative/@flags)
                        case element(gx:notLike) return not(i:matchesLike(., $alternative, $alternative/@flags))                        
                        default return error(QName((), 'ILLFORMED_GREENFOX_SCHEMA'), concat("Unexpected child of 'in': ", name($alternative)))                
            )]                    
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $in, $exprValue, 
                                                   $resultAdditionalAtts,
                                                   ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, 
                                                   $contextInfo, $resultOptions)
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
                else f:validationResult_expression('red', $valueShape, $in, $exprValue, 
                                                   $resultAdditionalAtts, 
                                                   ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, 
                                                   $contextInfo, $resultOptions)
    return
        if ($errors) then $errors else f:validationResult_expression('green', $valueShape, $in, $exprValue, 
                                                                     $resultAdditionalAtts, (), 
                                                                     $contextInfo, $resultOptions)
};        

declare function f:validateExpressionValue_notin($exprValue as item()*,
                                                 $quantifier as xs:string,
                                                 $valueShape as element(),
                                                 $contextInfo as map(xs:string, item()*))
        as element() {
    let $notin := $valueShape/gx:notin
    return
    
    if (not($notin)) then () else
    
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
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
                else f:validationResult_expression('red', $valueShape, $notin, $exprValue, 
                                                   $resultAdditionalAtts, 
                                                   ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, 
                                                   $contextInfo, $resultOptions)
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
                else f:validationResult_expression('red', $valueShape, $notin, $exprValue, 
                                                   $resultAdditionalAtts, 
                                                   ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, 
                                                   $contextInfo, $resultOptions)
    return
        if ($errors) then $errors else f:validationResult_expression('green', $valueShape, $notin, $exprValue, 
                                                                     $resultAdditionalAtts, (), 
                                                                     $contextInfo, $resultOptions)
};        
:)

(:~
 : Validates the count constraints expressed by an `expression` element:
 : @count, @minCount, @maxCount. 
 :
 : @param items the items returned by an expression
 : @param constraintElem an `expression` element representing an Expression constraint
 : @param contextInfo informs about the focus document and focus node
 : @return validation results
 :)
declare function f:validateExpressionCounts($items as item()*,
                                            $constraintElem as element(),
                                            $contextInfo as map(xs:string, item()*))
        as element()* {
        
    let $countConstraints := $constraintElem/(@count, @minCount, @maxCount)
    let $results :=
        if (empty($countConstraints)) then () else
        
        (: evaluate constraints :)
        let $valueCount := count($items)        
        for $countConstraint in $countConstraints
        let $cmpWith := $countConstraint/xs:integer(.)
        let $green :=
            typeswitch($countConstraint)
            case attribute(count)    return $valueCount eq $cmpWith
            case attribute(minCount) return $valueCount ge $cmpWith
            case attribute(maxCount) return $valueCount le $cmpWith
            default return error()
        let $colour := if ($green) then 'green' else 'red'        
        return  
            result:validationResult_expression_counts(
                $colour, $constraintElem, $countConstraint, $valueCount, $contextInfo, ())
    return $results        
};



