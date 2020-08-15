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
 : Validates the constraints expressed by a `valueCord` element contained
 : by a Content Correspondence Constraint. These constraints are ...
 : - a correspondence constraint, defined by @cmp, @sourceXP, @targetXP and further attributes
 : - count constraints, referring to the number of items returned by the source and
 :   target expression
 :
 : The validation is repeated for each link target node - thus effectively
 : every combination of link context node and link target node is checked.
 :
 : @param valueCord an element declaring a Correspondence Constraint on a 
 :   pair of content values
 : @param linkContextNode the link context node
 : @param linkTargetNodes the link target nodes
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
    let $cmp := $expressionPair/@cmp
    let $quantifier := ($expressionPair/@quant, 'all')[1]
    let $expr1 := $expressionPair/@expr1XP
    let $expr2 := $expressionPair/@expr2XP      
    let $flags := string($expressionPair/@flags)
    let $useDatatype := $expressionPair/@useDatatype/resolve-QName(., ..)        
    let $expr1Lang := 'xpath'
    let $expr2Lang := 'xpath'    
    
    (: Source expr value :)
    let $expr1ItemsRaw := i:evaluateXPath($expr1, $contextNode, $evaluationContext, true(), true())    
    
    let $expr1Items :=
        if (empty($useDatatype)) then $expr1ItemsRaw else 
        $expr1ItemsRaw ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
    
    (: Check the number of items of the source expression value :)
    let $results_expr1Count :=
        f:validateExpressionPairCounts($expr1Items, 'expr1', $expressionPair, $contextInfo)
    
    (: Function items
       ============== :)       
    (: (1) Target value generator function :)
    let $getExpr2Items := function($contextItem) {
        let $items := 
            if ($expr2Lang eq 'foxpath') then 
                i:evaluateFoxpath($expr2, $contextInfo?filePath, $evaluationContext, true())
            else
                i:evaluateXPath($expr2, $contextNode, $evaluationContext, true(), true())
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
        (: Get expr#2 value items :)
        let $expr2Items := $contextNode/$getExpr2Items(.)
        
        (: Check the number of items of the source expression value :)
        let $results_expr2Count :=
            f:validateExpressionPairCounts($expr2Items, 'expr2', $expressionPair, $contextInfo)
        
        (:
         : Identify source expression items for which the correspondence 
         : check fails.
         :)
        let $violations :=
            if ($cmp = ('in', 'notin')) then
                for $expr1Item at $pos in $expr1Items
                where $expr1Item instance of element(gx:red) or 
                      not($cmpTrueAgg($expr1Item, $expr2Items))
                return $expr1ItemsRaw[$pos]
            else if ($quantifier eq 'all') then
                for $expr1Item at $pos in $expr1Items
                where $expr1Item instance of element(gx:red) or 
                      exists($expr2Items[not($cmpTrue($expr1Item, .))])
                return $expr1ItemsRaw[$pos]
            else if ($quantifier eq 'some') then                
                for $expr1Item at $pos in $expr1Items
                where $expr1Item instance of element(gx:red) or
                      (every $v in $expr2Items satisfies not($cmpTrue($expr1Item, $v)))
                return $expr1ItemsRaw[$pos]
            else error()    
        let $colour := if (exists($violations)) then 'red' else 'green'                
        return (
            $results_expr2Count,
            result:validationResult_expressionPair($colour, $violations, $cmp, $expressionPair, $contextInfo)
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
 : @param contextInfo informs about the focus document and focus node
 : @return validation results
 :)
declare function f:validateExpressionPairCounts($items as item()*,
                                                $exprRole as xs:string, (: source | target :)
                                                $expressionPair as element(),
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
            result:validationResult_expressionPair_counts($colour, $expressionPair, $countConstraint, $valueCount, $contextInfo)
    return $results        
};

