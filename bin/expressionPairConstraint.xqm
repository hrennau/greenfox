(:
 : -------------------------------------------------------------------------
 :
 : expressionPairConstraint.xqm - validates a resource against an Expression Pair constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/expression-pair";
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
declare function f:validateExpressionPairConstraint($contextURI as xs:string,
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
            result:validationResult_expressionPair_exception($constraintElem,
                'Context resource could not be parsed', (), $contextInfo)
        else
        
    (: Check expression pairs :)    
    let $results := f:validateExpressionPairs($constraintElem, $contextNode, $contextInfo, $context)
    
    return $results
};

(:~
 : ===============================================================================
 :
 :     P e r f o r m    v a l i d a t i o n s
 :
 : ===============================================================================
 :)

declare function f:validateExpressionPairs($constraintElem as element(),
                                           $contextNode as node()?,
                                           $contextInfo as map(*),
                                           $context as map(xs:string, item()*))
        as element()* {
        
    $constraintElem/gx:expressionPair/f:validateExpressionPair(., $contextNode, $contextInfo, $context)
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
declare function f:validateExpressionPair($expressionPair as element(gx:expressionPair),
                                          $contextNode as node()?,
                                          $contextInfo as map(xs:string, item()*),
                                          $context as map(*))
        as element()* {
    let $contextNode := ($contextNode, $contextInfo?doc)[1]
    let $evaluationContext := $context?_evaluationContext
    
    (: Definition of an expression pair constraint :)
    let $expr1XP := $expressionPair/@expr1XP
    let $expr2XP := $expressionPair/@expr2XP      
    let $expr1FOX := $expressionPair/@expr1FOX
    let $expr2FOX := $expressionPair/@expr2FOX      
    let $cmp := $expressionPair/@cmp
    let $quantifier := ($expressionPair/@quant, 'all')[1]
    let $flags := string($expressionPair/@flags)
    let $useDatatype := $expressionPair/@useDatatype/resolve-QName(., ..)     
    
    (: Context kind :)
    let $expr2Context :=
        let $attName := local-name($cmp) || 'Context'
        return $expressionPair/@*[local-name(.) eq $attName]
    let $expr1 := ($expr1XP, $expr1FOX)[1]
    let $expr2 := ($expr2XP, $expr2FOX)[1]
   
    let $expr1Lang := if ($expr1 eq $expr1XP) then 'xpath' else 'foxpath'
    let $expr2Lang := if ($expr2 eq $expr2XP) then 'xpath' else 'foxpath'    
    
    (: Source expr value :)
    let $items1 := 
        if ($expr1Lang eq 'foxpath') then
            i:evaluateFoxpath($expr1, $contextInfo?filePath, $evaluationContext, true())
        else if ($expr1Lang eq 'xpath') then
            i:evaluateXPath($expr1, $contextNode, $evaluationContext, true(), true())
        else error()
        
    let $items1Typed :=
        if (empty($useDatatype)) then $items1 else 
        $items1 ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
    
    (: Check the number of items of the source expression value :)
    let $results_expr1Count :=
        f:validateExpressionPairCounts($items1, 'expr1', $expressionPair, (), $contextInfo)
    
    (: Function items
       ============== :)       
    (: (1) Expression 2 value generator function :)
    let $getItems2 := function($contextItem) {
        let $items := 
            if ($expr2Lang eq 'foxpath') then 
                i:evaluateFoxpath($expr2, $contextInfo?filePath, $evaluationContext, true())
            else
                i:evaluateXPath($expr2, $contextItem, $evaluationContext, true(), true())
        return
            if (empty($useDatatype)) then $items 
            else $items ! i:castAs(., $useDatatype, ()) 
    }
    
    (: (2) Comparison functions :)
    
    (: (2.1) Function processing a single item second operand :)
    let $cmpTrue :=
        if ($cmp = ('in', 'notin')) then () else
        switch($cmp)
        case 'eq' return function($op1, $op2) {$op1 = $op2}        
        case 'ne' return function($op1, $op2) {$op1 != $op2}        
        case 'lt' return function($op1, $op2) {$op1 < $op2}
        case 'le' return function($op1, $op2) {$op1 <= $op2}
        case 'gt' return function($op1, $op2) {$op1 > $op2}
        case 'ge' return function($op1, $op2) {$op1 >= $op2}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $cmp))

    (: (2.2) Function processing multiple items second operand :)
    let $cmpTrueAgg :=
        if (not($cmp = ('in', 'notin'))) then () else
        switch($cmp)
        case 'in' return function($op1, $op2) {$op1 = $op2}
        case 'notin' return function($op1, $op2) {not($op1 = $op2)}        
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $cmp))

    (: Produce results
       =============== :)       
    let $results :=
        (: expression 2 context = item from expression 1        
           --------------------------------------------- :)
        if ($expr2Context eq '#item') then
        
            (: quantifier 'all' :)
            
            if ($quantifier eq 'all') then
                for $item1 at $pos in $items1
                let $item1Typed := $items1Typed[$pos]
                return
                    if ($item1Typed instance of element(gx:red)) then
                        result:validationResult_expressionPair(
                            'red', $item1Typed, $cmp, $expressionPair, $contextInfo, ())
                    else (
                        let $items2 := $getItems2($item1)
                        let $violation := $item1[not($cmpTrue($item1Typed, $items2))] [exists($items2)]
                        let $colour := if (exists($violation)) then 'red' else 'green'                        
                        return (
                            result:validationResult_expressionPair(
                                $colour, $violation, $cmp, $expressionPair, $contextInfo, ()),
                            f:validateExpressionPairCounts($items2, 'expr2', $expressionPair, $item1, $contextInfo)
                        )
                    )                                
            else
            
                (: quantifier: 'some' or 'forEachItemSome' :)
                
                let $itemReports :=
                    for $item1 at $pos in $items1
                    let $item1Typed := $items1Typed[$pos]
                    return
                        map:merge((
                            map:entry('item1', $item1),
                            if ($item1Typed instance of element(gx:red)) then
                                map:entry('datatypeError', 
                                    result:validationResult_expressionPair(
                                        'red', $item1Typed, $cmp, $expressionPair, $contextInfo, ()))
                            else
                                let $items2 := $getItems2($item1)
                                let $countResults :=
                                    f:validateExpressionPairCounts(
                                        $items2, 'expr2', $expressionPair, $item1, $contextInfo)
                                let $match := $cmpTrue($item1Typed, $items2)
                                return (
                                    map:entry('countResults', $countResults),
                                    map:entry('match', $match)
                                )
                        ))
                return (
                    $itemReports?countResults,
                    $itemReports?datatypeError,

                    if ($quantifier eq 'some') then
                        let $match := exists($itemReports[?match])
                        let $colour := if ($match) then 'green' else 'red'
                        return
                            result:validationResult_expressionPair(
                                $colour, (), $cmp, $expressionPair, $contextInfo, ())
                    else if ($quantifier eq 'forEachItemSome') then        
                        let $violations := 
                            for $itemReport at $pos in $itemReports
                            return if ($itemReport?match) then () else $items1Typed[$pos]
                        let $colour := if (empty($violations)) then 'green' else 'red'
                        return (
                            result:validationResult_expressionPair(
                                $colour, $violations, $cmp, $expressionPair, $contextInfo, ())
                        )
                    else error(QName((), 'SCHEMA_ERROR'), concat('Unknown quantifier @quant: ', $quantifier))                        
                )
                
        (: expression 2 context: independent of expression 1 items 
           ------------------------------------------------------- :)
        else
            (: Get value of expression 2 :)
            let $items2 := $contextNode/$getItems2(.)

            (: Check the items count :)
            let $results_expr2Count := f:validateExpressionPairCounts($items2, 'expr2', $expressionPair, (), $contextInfo)
    
            (:
             : Identify expression 1 items for which the correspondence check fails.
             :) 
            let $violations :=
            
                (: aggregate comparison :)
                
                if ($cmp = ('in', 'notin')) then
                    for $item1Typed at $pos in $items1Typed
                    where $item1Typed instance of element(gx:red) or 
                          not($cmpTrueAgg($item1Typed, $items2))
                    return $items1[$pos]
                    
                (: quantifier 'all' :)
                
                else if ($quantifier eq 'all') then
                    for $item1Typed at $pos in $items1Typed
                    where $item1Typed instance of element(gx:red) or 
                          exists($items2[not($cmpTrue($item1Typed, .))])
                    return $items1[$pos]
                    
                (: quantifier 'some' :)
                
                else if ($quantifier eq 'some') then    
                    let $match := $items1Typed[
                        not(. instance of element(gx:red)) 
                        and (some $v in $items2 satisfies $cmpTrue(., $v))]
                    return
                        if (exists($match)) then ()
                        else $items1Typed
                        
                (: quantifier 'forEachItemSome' :)
                
                else if ($quantifier eq 'forEachItemSome') then                    
                    for $item1Typed at $pos in $items1Typed
                    where $item1Typed instance of element(gx:red) or
                          (every $v in $items2 satisfies not($cmpTrue($item1Typed, $v)))
                    return $items1[$pos]
                else error(QName((), 'SCHEMA_ERROR'), concat('Unexpected quantifier: ', $quantifier))
                
            let $colour := if (exists($violations)) then 'red' else 'green'                
            return (
                $results_expr2Count,
                result:validationResult_expressionPair($colour, $violations, $cmp, $expressionPair, $contextInfo, ())
            )
            
    return ($results_expr1Count, $results)            
};    

(:~
 : Validates the count constraints expressed by a `valueCord` element contained
 : by a Content Correspondence Constraint. These constraints are ...
 : - source count constraints, referring to the number of items returned by the 
 :   source expresssion, defined by @countSource, @minCountSource, @maxCountSource
 : - target value count constraints, referring to the number of items returned
 :   by the target expression, defined by @countTarget, @minCountTarget, @maxCountTarget 
 :
 : @param items the items returned by an expression
 : @param exprRole the role of the expression - source or target expression
 : @valueCord the element declaring the count constraint
 : @item1 the value from expression 1 serving as context item when evaluating expession 2
 : @param contextInfo informs about the focus document and focus node
 : @return validation results
 :)
declare function f:validateExpressionPairCounts($items as item()*,
                                                $exprRole as xs:string, (: source | target :)
                                                $expressionPair as element(),
                                                $contextItem1 as item()?,
                                                $contextInfo as map(xs:string, item()*))
        as element()* {
        
    let $countConstraints := $expressionPair/(
        if ($exprRole eq 'expr1') then (@count1, @minCount1, @maxCount1)
        else if ($exprRole eq 'expr2') then (@count2, @minCount2, @maxCount2)
        else error())
    let $results :=
        if (empty($countConstraints)) then () else
        
        (: evaluate constraints :)
        let $valueCount := count($items)        
        for $countConstraint in $countConstraints
        let $cmpWith := $countConstraint/xs:integer(.)
        let $green :=
            typeswitch($countConstraint)
            case attribute(count1)    | attribute(count2)    return $valueCount eq $cmpWith
            case attribute(minCount1) | attribute(minCount2) return $valueCount ge $cmpWith
            case attribute(maxCount1) | attribute(maxCount2) return $valueCount le $cmpWith
            default return error()
        let $colour := if ($green) then 'green' else 'red'        
        return  
            result:validationResult_expressionPair_counts(
                $colour, $expressionPair, $countConstraint, $valueCount, $contextItem1, $contextInfo, ())
    return $results        
};
