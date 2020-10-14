(:
 : -------------------------------------------------------------------------
 :
 : valuePairConstraint.xqm - validates a resource against a ValuePair-like constraint
 :
 : Implements validation against the following constraints:
 : - valuePair
 : - valueCompared
 : - foxvaluePair
 : - foxvalueCompared
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/value-pair";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "log.xqm",
   "resourceAccess.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm",
   "linkResolution.xqm",
   "linkValidation.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a resource against ValuePair-like constraints: ValuePair, ValueCompared,
 : FoxvaluePair, FoxvalueCompared.
 :
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateValuePairConstraint($constraintElem as element(),
                                               $context as map(xs:string, item()*))
        as element()* {
       
    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    return
        
    (: Exception - no context document :)
    if ($constraintElem/@expr1XP and not($targetInfo?doc)) then
        result:validationResult_valuePair_exception($constraintElem,
            'Context resource could not be parsed', (), $context)
    else if ($constraintElem/(@expr1LP, @filter1LP, @map1LP) and not($targetInfo?lines)) then
        result:validationResult_valuePair_exception($constraintElem,
            'Context resource without lines document', (), $context)
    else
        (: ValueCompared | FoxvalueCompared :)    
        if ($constraintElem/
            (self::gx:valuesCompared, self::gx:valueCompared, 
             self::gx:foxvaluesCompared, self::gx:foxvalueCompared))
        then 
            let $ldo := link:getLinkDefObject($constraintElem, $context)
            (: let $_DEBUG := trace($ldo, '_LDO: ') :)
            let $lros := 
                let $requiresXml := exists($constraintElem/*/@expr2XP)
                let $options := if (not($requiresXml)) then () else map{'mediatype': 'xml'}
                return
                    link:resolveLinkDef($ldo, 'lro', $contextURI, $contextNode, $context, $options)
            let $results_link := link:validateLinkConstraints($lros, $ldo, $constraintElem, $context)
            let $results_pairs := f:validateValuesCompared($constraintElem, $lros, $context)                
            return ($results_link, $results_pairs)
            
        (: ValuePair, FoxvaluePair :)
        else f:validateValuePairs($constraintElem, $context)
};

(:~
 : ===============================================================================
 :
 :     P e r f o r m    v a l i d a t i o n s
 :
 : ===============================================================================
 :)

(:~
 : Validates a resource by comparing a resource value with resource values obtained
 : for a set of link target resources.
 :
 : @param constraintElem constraint defining element
 : @param lros Linke Result objects
 : @param context the processing context
 :)
declare function f:validateValuesCompared($constraintElem as element(),
                                          $lros as map(*)*,
                                          $context as map(xs:string, item()*))
        as element()* {
        
    (: Handle link errors :) 
    $lros[?errorCode]
    ! result:validationResult_valueCompared_exception($constraintElem, ., (), (), $context),
        
    (: Repeat validation for each combination of link context node and link target resource or target nodes 
       (represented by a Link Result Object) 
     :)
    for $lro in $lros[not(?errorCode)]    
    (: let $_DEBUG := trace(i:DEBUG_LROS($lros), '_LROS: ') :)
    let $targetURI := $lro?targetURI
    for $pair in $constraintElem/(gx:valueCompared, gx:foxvalueCompared)
    let $requiresContextNode := exists($pair/@expr1XP)
    let $requiresTargetNode := exists($pair/@expr2XP)
            
    let $contextNode :=
        let $contextItem := $lro?contextItem
        return
            if ($contextItem instance of node()) then $contextItem
            else $context?_targetInfo?doc
            
    let $targetItems :=
        if ($requiresTargetNode) then
            if (map:contains($lro, 'targetNodes')) then $lro?targetNodes
            else if (map:contains($lro, 'targetDoc')) then $lro?targetDoc
            else $lro?targetURI[i:fox-doc-available(.)] ! i:fox-doc(.)
        else $lro?targetURI
        
    return
        if ($requiresContextNode and empty($contextNode)) then
            result:validationResult_valuePair_exception($constraintElem,
                'No context node available', (), $context)
        else if (empty($targetItems)) then
            result:validationResult_valuePair_exception($constraintElem,
                'No target resource or node available', (), $context)
        else
            $pair/f:validateValuePair(., $contextNode, $targetItems, $lro, $context)            
};

(:~
 : Validates a resource by comparing two resource values.
 :
 : @param constraintElem constraint defining element
 : @param lros Linke Result objects
 : @param context the processing context
 :)
declare function f:validateValuePairs($constraintElem as element(),
                                      $context as map(xs:string, item()*))
        as element()* {
    let $targetInfo := $context?_targetInfo
    let $contextNode := ($targetInfo?focusNode, $targetInfo?doc)[1]
    for $pair in $constraintElem/(., *)/(self::gx:valuePair, self::gx:foxvaluePair) 
    return
        $pair/f:validateValuePair(., $contextNode, (), (), $context)
};

(:~
 : Validates the ValuePair constraints expressed by a single "pair element" - `valuePair`,
 : `foxvaluePair`, `valueCompared` or `foxvalueCompared` element.
 :
 : @param constraintElem element declaring the constraints
 : @param contextNode context node to be used by XPath expressions, except
 :   for expression 2 in case of $targetItems
 : @param targetItems target items produced by the link definition used by a 
 :   `valueCompared` or `foxvalueCompared` constraint; one of the following:
 :   targetNodes; targetDoc; doc(targetURI); targetURI
 : @param targetURI target URI produced by the link link definition used by a 
 :   `valueCompared` or `foxvalueCompared` constraint; MUST be set if 
 :   $targetItems is not empty
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateValuePair($constraintElem as element(),
                                     $contextNode as node()?,
                                     $targetItems as item()*,
                                     $lro as map(xs:string, item()*)?,                                     
                                     $context as map(*))
        as element()* {
    let $targetInfo := $context?_targetInfo        
    let $contextURI := $targetInfo?contextURI
    let $evaluationContext := $context?_evaluationContext

    let $targetURI := $lro?targetURI

    (: Definition of an expression pair constraint :)
    let $expr1XP := $constraintElem/@expr1XP
    let $expr2XP := $constraintElem/@expr2XP      
    let $expr1FOX := $constraintElem/@expr1FOX
    let $expr2FOX := $constraintElem/@expr2FOX    
    let $expr1LP := $constraintElem/@expr1LP
    let $expr2LP := $constraintElem/@expr2LP    
    
    let $filterMap1LP :=
        if (not($constraintElem/(@filter1LP, @map1LP))) then () else
            map:merge((
                map:entry('exprKind', 'filterMapLP'),
                $constraintElem/@filter1LP/map:entry('filterLP', string(.)),
                $constraintElem/@map1LP/map:entry('mapLP', string(.))))
    let $filterMap2LP :=
        if (not($constraintElem/(@filter2LP, @map2LP))) then () else
            map:merge((
                map:entry('exprKind', 'filterMapLP'),
                $constraintElem/@filter2LP/map:entry('filterLP', string(.)),
                $constraintElem/@map2LP/map:entry('mapLP', string(.))))
    
    let $constraintNode := $constraintElem/(@cmp, .)[1]
    let $quantifier := ($constraintElem/@quant, 'all')[1]
    let $flags := string($constraintElem/@flags)
    let $useDatatype := $constraintElem/@useDatatype/i:resolveUseDatatype(.)    
    let $useString := $constraintElem/@useString/tokenize(.)
    
    (: Context kind :)
    let $expr2Context := $constraintElem/@expr2Context
    
    let $expr1Spec := ($expr1XP/string(), $expr1FOX/string(), $expr1LP/string(), $filterMap1LP)[1]
    let $expr1Lang := if ($expr1XP) then 'xpath' 
                     else if ($expr1FOX) then 'foxpath' 
                     else if ($expr1LP) then 'linepath'
                     else if (exists($filterMap1LP)) then 'filtermap'
                     else error()
    let $expr2Spec := ($expr2XP/string(), $expr2FOX/string(), $expr2LP/string(), $filterMap2LP)[1]
    let $expr2Lang := if ($expr2XP) then 'xpath' 
                     else if ($expr2FOX) then 'foxpath' 
                     else if ($expr2LP) then 'linepath'
                     else if (exists($filterMap2LP)) then 'filtermap'
                     else error()
    
    let $expr1 :=
        if ($expr1XP) then $expr1XP/string()
        else if ($expr1FOX) then $expr1FOX/string()
        else if ($expr1LP) then $expr1LP/string()
        else if (exists($filterMap1LP)) then i:constructFilterMapExpr($filterMap1LP)
        else error()
    let $expr2 :=
        if ($expr2XP) then $expr2XP/string()
        else if ($expr2FOX) then $expr2FOX/string()
        else if ($expr2LP) then $expr2LP/string()
        else if (exists($filterMap2LP)) then i:constructFilterMapExpr($filterMap2LP)
        else error()
    
    (: Value 1 :)
    let $items1Raw :=
        switch($expr1Lang)
        case 'xpath' return i:evaluateXPath($expr1, $contextNode, $evaluationContext, true(), true())
        case 'foxpath' return i:evaluateFoxpath($expr1, $contextURI, $evaluationContext, true())        
        case 'linepath' return 
            let $contextLinesNode := $context?_reqDocs?lines
            return i:evaluateXPath($expr1, $contextLinesNode, $evaluationContext, true(), true())
        case 'filtermap' return 
            let $contextLinesNode := $context?_reqDocs?lines
            return i:evaluateXPath($expr1, $contextLinesNode, $evaluationContext, true(), true())
        default return error()
    let $items1TYRaw := i:applyUseDatatype($items1Raw, $useDatatype, $useString)

    (: results: value counts 1 :)
    let $results_expr1Count :=
        f:validateValuePair_counts(
            $constraintElem, $items1TYRaw, 'expr1', $expr1, $expr1Spec, $expr1Lang, (), $context)

    (: indexes: conversion errors 1 :)
    let $indexes_conversionError1 := 
        if (empty($useDatatype)) then () else
            for $i in 1 to count($items1Raw)
            where $items1TYRaw[$i] instance of map(*)
            return $i

    (: results: conversion errors 1 :)
    let $results_expr1Conversion :=
        if (empty($useDatatype)) then () else
            $items1TYRaw[position() = $indexes_conversionError1] 
            ! result:validationResult_valuePair(
                'red', $constraintElem, $constraintNode, 
                $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang, 
                ., (), $context)

    (: purify $items1, $items1TY :)
    let $items1 :=
        if (empty($useDatatype)) then $items1Raw
        else $items1Raw[not(position() = $indexes_conversionError1)]
    let $items1TY :=
        if (empty($useDatatype)) then $items1TYRaw
        else $items1TYRaw[not(position() = $indexes_conversionError1)]   

    (: Function items
       ============== :)       
    (: (1) Expression 2 value generator function
           If $varName is set, $varValue is bound to variable $varName.
           If $varName and $varName2 is set, $varValue2 is bound to variable $varName2 :)
    let $getItems2 := function($contextItem, $item, $targetDoc, $targetNode) {
        let $linkContextItem := $lro?contextItem
        let $newEvaluationContext := i:newEvaluationContext_expr2($items1TY, $item, $linkContextItem, $targetDoc, $targetNode, $context)
        return
            switch($expr2Lang)
            case 'xpath' return i:evaluateXPath($expr2, $contextItem, 
                $newEvaluationContext, true(), true())
            case 'foxpath' return i:evaluateFoxpath($expr2, $contextItem, 
                $newEvaluationContext, true())        
            case 'linepath' return i:evaluateXPath($expr2, $contextItem, 
                $newEvaluationContext, true(), true())
            case 'filtermap' return i:evaluateXPath($expr2, $contextItem, 
                $newEvaluationContext, true(), true())
            default return error()
    }
    
    (: (2) Comparison functions :)
    
    (: (2.1) Function processing a single item second operand :)
    let $cmpTrue :=
        if ($constraintNode/self::element()) then ()
        else if ($constraintNode = ('in', 'notin', 'includes', 'sameTerms', 'deepEqual')) then () else
        switch($constraintNode)
        case 'eq' return function($op1, $op2) {$op1 = $op2}        
        case 'ne' return function($op1, $op2) {$op1 != $op2}        
        case 'lt' return function($op1, $op2) {$op1 < $op2}
        case 'le' return function($op1, $op2) {$op1 <= $op2}
        case 'gt' return function($op1, $op2) {$op1 > $op2}
        case 'ge' return function($op1, $op2) {$op1 >= $op2}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $constraintNode))

    (: (2.2) Function processing multiple items second operand :)
    let $findViolations :=
        if (not($constraintNode = ('in', 'notin', 'includes', 'sameTerms', 'deepEqual'))) then () else
        switch($constraintNode)
 
        case 'in' return function($items1, $items1TY, $items2, $items2TY) {
            for $item1TY at $pos in $items1TY
            where not($item1TY = $items2TY)
            return $items1[$pos]}

        case 'notin' return function($items1, $items1TY, $items2, $items2TY) {
            for $item1TY at $pos in $items1TY
            where $item1TY = $items2TY
            return $items1[$pos]}

        case 'includes' return function($items1, $items1TY, $items2, $items2TY) {
            for $item2TY at $pos in $items2TY
            where not($item2TY = $items1TY)
            return $items2[$pos]}

        case 'sameTerms' return function($items1, $items1TY, $items2, $items2TY) {
            for $item1TY at $pos in $items1TY
            where not($item1TY = $items2TY)
            return $items1[$pos],
            for $item2TY at $pos in $items2TY
            where not($item2TY = $items1TY)
            return $items2[$pos]
            }
            
        case 'deepEqual' return function($items1, $items1TY, $items2, $items2TY) {
            (: In case of conversion errors - do not check :)
            if (count($items1) ne count($items1TY) or 
                count($items2) ne count($items2TY)) then ()
            else
                if (deep-equal($items1TY, $items2TY)) then () else
                
                (: Deliver first deviating pair 
                   or single item without corresponding item :)
                let $maxIndex := max((count($items1TY), count($items2TY)))
                let $minIndexDeviation :=
                    min(
                        for $pos in 1 to $maxIndex
                        where not($items1TY[$pos] eq $items2TY[$pos])
                        return $pos)
                return ($items1TY[$minIndexDeviation], $items2TY[$minIndexDeviation])
        }        
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $constraintNode))

    (: Produce results
       =============== :)       
    let $results_pair :=
            
        (: expression 2 context = item from expression 1        
           --------------------------------------------- :)
        if ($expr2Context eq 'item') then
            f:validateValuePair_context2_iterating(
                 $constraintElem, $constraintNode,            
                 $contextURI, $contextNode,
                 $targetURI, $targetItems[1][. instance of node()],
                 
                 $expr2Context, $quantifier, $useDatatype, $useString,
                 $expr1Spec, $expr1Lang,
                 $expr2, $expr2Spec, $expr2Lang,
                 $items1, $items1TY,
                 $getItems2, $cmpTrue,
                 $context)

        (: expression 2 context: independent of expression 1 items; not a pair constraint 
           ------------------------------------------------------------------------------ :)
        else if (empty($targetItems)) then
            (: Context item is context URI if Foxpath; context node or context URI, if XPath :)
            let $useContextItem := 
                if ($constraintElem/@expr2FOX) then $contextURI else $contextNode
                return
            
                    f:validateValuePair_context2_fixed(
                        $constraintElem, $constraintNode, 
                        $contextURI, $contextNode,
                        (), (),    (: $targetURI, $targetNode :)
                        
                        $quantifier, $useDatatype, $useString, 
                        $expr1Spec, $expr1Lang, $expr2, $expr2Spec, $expr2Lang,
                        $items1, $items1TY, $results_expr1Conversion,
                        $getItems2, $cmpTrue, $findViolations,
                        $context) 
        
        (: a pair constraint - loop over target items 
           ------------------------------------------ :)
        else
            (: Target items can be target nodes, the target doc, or the target URI :)
            for $targetItem in $targetItems 
            return
                f:validateValuePair_context2_fixed(
                    $constraintElem, $constraintNode,
                    $contextURI, $contextNode,
                    $targetURI, $targetItem[. instance of node()],
                    
                    $quantifier, $useDatatype, $useString, 
                    $expr1Spec, $expr1Lang, $expr2, $expr2Spec, $expr2Lang,
                    $items1, $items1TY, $results_expr1Conversion,
                    $getItems2, $cmpTrue, $findViolations,
                    $context) 
            
    return (
        $results_expr1Count, 
        $results_expr1Conversion,
        $results_pair)
        
};    

(:~
 : Validations of ValuePair constraints, the case where the
 : second expression is evaluated for each item from value 1.
 :)
declare function f:validateValuePair_context2_iterating(
    $constraintElem as element(), 
    $constraintNode as node(),
    
    $contextURI as xs:string, 
    $contextNode as node()?,
    $targetURI as xs:string?,
    $targetNode as node()?,
    
    $expr2Context as xs:string, $quantifier as xs:string, $useDatatype as xs:QName?, $useString as xs:string*,
    $expr1Spec as item(), $expr1Lang as xs:string,
    $expr2 as xs:string, $expr2Spec as item(), $expr2Lang as xs:string,
    $items1 as item()*, $items1TY as item()*, 
    $getItems2 as function(*), $cmpTrue as function(*)?,
    $context as map(xs:string, item()*))
        as element()* {
        
    (: targetDoc and targetNode are passed to $getItems2 
       in order to be written into th evaluation context :)
    let $targetDoc := 
        if ($targetNode instance of document-node()) then $targetNode 
        else $targetNode/root()
    let $targetNode := $targetNode[not(. instance of document-node())]
    return
    
    (: quantifier 'all' :)            
    if ($quantifier eq 'all') then
        for $item1 at $pos in $items1
        let $item1TY := $items1TY[$pos]
        
        let $items2 := 
            let $contextItem :=
                if ($expr2Lang eq 'foxpath') then ($targetURI, $contextURI)[1] 
                else $item1        
            return $getItems2($contextItem, $item1, $targetDoc, $targetNode)
        
        let $items2TYRaw := i:applyUseDatatype($items2, $useDatatype, $useString)
        let $items2TY := 
            if (empty($useDatatype)) then $items2TYRaw
            else $items2TYRaw[not(. instance of map(*))]
        let $items2ConversionError := 
            if (empty($useDatatype)) then () else $items2TYRaw[. instance of map(*)]
        return (
            (: Value 2: count checks :)
            f:validateValuePair_counts(
                $constraintElem, $items2, 'expr2', $expr2, $expr2Spec, $expr2Lang, $item1, $context),
            
            (: Value 2: count comparison check :)
            f:validateValuePair_cmpCount($constraintElem, $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang, 
                $items1, $items2, $item1, $context),
            
            (: Value 2: conversion errors :)
            $items2ConversionError ! result:validationResult_valuePair(
                    'red', $constraintElem, $constraintNode,
                    $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang,
                    ., (), $context),
                    
            (: Value comparison check :)
            if (empty($items2TY)) then () 
            else if (empty($cmpTrue)) then ()
            else
                let $violation := $item1[not($cmpTrue($item1TY, $items2TY))]
                let $colour := if (exists($violation)) then 'red' else 'green'                        
                return
                    result:validationResult_valuePair(
                        $colour, $constraintElem, $constraintNode, 
                        $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang,
                        $violation, (), $context)
        )       
    (: quantifier: 'some' or 'someForEach' :)           
    else            
        let $itemReports :=            
            for $item1 at $pos in $items1
            let $item1TY := $items1TY[$pos]
            
            let $items2 := 
                let $contextItem :=
                    if ($expr2Lang eq 'foxpath') then ($targetURI, $contextURI)[1] 
                    else $item1        
                return $getItems2($contextItem, $item1, $targetDoc, $targetNode)
            
            let $items2TYRaw := 
                if (empty($useDatatype)) then $items2 else i:applyUseDatatype($items2, $useDatatype, $useString)
            let $items2TY := 
                if (empty($useDatatype)) then $items2TYRaw
                else $items2TYRaw[not(. instance of map(*))]
                
            let $items2ConversionErrorResults :=
                if (empty($useDatatype)) then () else 
                    $items2TYRaw[. instance of map(*)] 
                    ! result:validationResult_valuePair(
                        'red', $constraintElem, $constraintNode,
                        $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang,
                        ., (), $context)
            let $countResults :=
                f:validateValuePair_counts(
                    $constraintElem, $items2, 'expr2', $expr2, $expr2Spec, $expr2Lang, $item1, $context)   
               
            let $countCmpResults :=
                f:validateValuePair_cmpCount($constraintElem, $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang, 
                    $items1, $items2, $items1, $context)            
            
            return
                (: Write for each item from value 1 a map with keys:
                       item1, conversionErrors2, countResults, match 
                 :)
                map:merge((                
                    (: item1 :)
                    map:entry('item1', $item1),                    
                    (: countResults :)
                    map:entry('countResults', $countResults),                
                    (: countCmpResults :)
                    map:entry('countCmpResults', $countCmpResults),                
                    (: conversion errors value 2 :)
                    map:entry('conversionErrors2', $items2ConversionErrorResults),                    
                    (: match :)
                    map:entry('match', $cmpTrue($item1TY, $items2TY))
                ))
        return (
            (: Count and conversion results :)
            $itemReports?countResults,
            $itemReports?countCmpResults,
            $itemReports?conversionErrors2,

            (: Quantifier: some :)
            if ($quantifier eq 'some') then
                let $match := exists($itemReports[?match])
                let $colour := if ($match) then 'green' else 'red'
                return
                    result:validationResult_valuePair(
                        $colour, $constraintElem, $constraintNode, 
                        $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang,
                        (), (), $context)
                        
            (: Quantifier: someForEach :)                        
            else if ($quantifier eq 'someForEach') then        
                let $violations := 
                    for $itemReport at $pos in $itemReports
                    return if ($itemReport?match) then () else $items1[$pos]
                let $colour := if (empty($violations)) then 'green' else 'red'
                return (
                    result:validationResult_valuePair(
                        $colour, $constraintElem, $constraintNode, 
                        $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang,
                        $violations, (), $context)
                )
            else error(QName((), 'SCHEMA_ERROR'), concat('Unknown quantifier @quant: ', $quantifier))                        
        )        
};

(:~
 : Validations of ValuePair constraints, the case where the
 : second expression is evaluated only once not for each item 
 : from value 1.
 :)
declare function f:validateValuePair_context2_fixed(
    $constraintElem as element(),
    $constraintNode as node(),
    
    $contextURI as xs:string,
    $contextNode as node()?,
    $targetURI as xs:string?,
    $targetNode as node()?,
    
    (:
    $contextItem as item(),   (: may be targetURI, targetDoc, or targetNode :)
    $targetURI as xs:string?,    (: only set if constraint is a Compared constraint :)
     :)
     
    $quantifier as xs:string,
    $useDatatype as xs:QName?,
    $useString as xs:string*,
    $expr1Spec as item(),
    $expr1Lang as xs:string,
    $expr2 as xs:string,
    $expr2Spec as item(),
    $expr2Lang as xs:string,

    $items1 as item()*,
    $items1TY as item()*,
    $results_expr1Conversion as element()*,

    $getItems2 as function(*),
    $cmpTrue as function(*)?,
    $findViolations as function(*)?,
    $context as map(xs:string, item()*)) 
        as element()* {
        
    (: Get value of expression 2 :)
    let $items2 :=
        let $targetDoc := 
            if ($targetNode instance of document-node()) then $targetNode 
            else $targetNode/root()
        let $targetNode := $targetNode[not(. instance of document-node())]
        return
        
        (: Foxpath :) 
        if ($expr2Lang eq 'foxpath') then
            let $contextItemURI := ($targetURI, $contextURI)[1]
            return
                $getItems2($contextItemURI, (), $targetDoc, $targetNode)
        else
            let $contextItem := ($targetNode, $targetDoc, $contextNode)[1]
            return
                $getItems2($contextItem, (), $targetDoc, $targetNode)
            
    let $items2TYRaw := i:applyUseDatatype($items2, $useDatatype, $useString)
    let $items2TY := 
        if (empty($useDatatype)) then $items2TYRaw
        else $items2TYRaw[not(. instance of map(*))]
    let $items2ConversionError := 
        if (empty($useDatatype)) then () else $items2TYRaw[. instance of map(*)]
                
    (: *** Check results: conversion error value 2 :)
    let $results_expr2Conversion :=
        $items2ConversionError ! result:validationResult_valuePair(
            'red', $constraintElem, $constraintNode, 
            $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang,
            ., (), $context)

    (: *** Check results: counts :)
    let $results_expr2Count :=
        f:validateValuePair_counts(
            $constraintElem, $items2, 'expr2', $expr2, $expr2Spec, $expr2Lang, (), $context)
    
    (: *** Check count comparison :)
    let $results_cmpCount :=    
        f:validateValuePair_cmpCount($constraintElem, $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang, 
            $items1, $items2, (), $context)

    (: *** Check results: pair :)    
    let $results_pair :=
        if ($constraintNode/self::element()) then () else
        
        (:
         : Identify items for which the correspondence check fails;
           in case of includes, these are value 2 items;
           in case of sameTerms and deepEqual, these are value 1 and/or value 2 items
           otherwise these are value 1 items
         :) 
        let $violations :=
    
            (: aggregate comparison :)
            if (exists($findViolations)) then
                $findViolations($items1, $items1TY, $items2, $items2TY)
                
            (: quantifier 'all' :)
                    
            else if ($quantifier eq 'all') then
                for $item1TY at $pos in $items1TY
                return
                    if (exists($useDatatype) and i:isCastError($item1TY)) then $item1TY
                    else if (exists($items2TY[not($cmpTrue($item1TY, .))])) then $items1[$pos]
                    else ()
                    
            (: quantifier 'some' :)
               
            else if ($quantifier eq 'some') then    
                let $match := $items1TY[some $v in $items2TY satisfies $cmpTrue(., $v)]
                return
                    if (exists($match)) then () else $items1
                        
            (: quantifier 'someForEach' :)
                
            else if ($quantifier eq 'someForEach') then                    
                for $item1TY at $pos in $items1TY
                where every $v in $items2TY satisfies not($cmpTrue($item1TY, $v))
                return $items1[$pos]
                
            else error(QName((), 'SCHEMA_ERROR'), concat('Unexpected quantifier: ', $quantifier))
            
        let $colour := if (exists($violations)) then 'red' else 'green'
        return
            result:validationResult_valuePair(
                $colour, $constraintElem, $constraintNode, 
                $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang,
                $violations, (), $context)

    (: *** All results :)
    return (
        $results_expr2Conversion,    
        $results_expr2Count,
        $results_cmpCount,
        $results_pair)
};

(:~
 : Validates ValuePair*Count (or FoxvaluePair*Count) constraints. 
 :
 : @param items the items returned by an expression
 : @param exprRole the role of the expression - 'expr1' or 'expr2'
 : @constraintElem the element declaring the constraints
 : @item1 the item from expression 1 used as context item when evaluating expession 2
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateValuePair_counts($constraintElem as element(),
                                            $items as item()*,
                                            $exprRole as xs:string, (: source | target :) 
                                            $expr as xs:string, 
                                            $exprSpec as item(),
                                            $exprLang as xs:string,
                                            $contextItem1 as item()?,
                                            $context as map(xs:string, item()*))
        as element()* {
        
    let $constraintNodes := $constraintElem/(
        if ($exprRole eq 'expr1') then (@count1, @minCount1, @maxCount1)
        else if ($exprRole eq 'expr2') then (@count2, @minCount2, @maxCount2)
        else error())
    let $results :=
        if (empty($constraintNodes)) then () else
        
        (: evaluate constraints :)
        let $valueCount := count($items)        
        for $constraintNode in $constraintNodes
        let $constraintValue := $constraintNode/xs:integer(.)
        let $green :=
            typeswitch($constraintNode)
            case attribute(count1)    | attribute(count2)    return $valueCount eq $constraintValue
            case attribute(minCount1) | attribute(minCount2) return $valueCount ge $constraintValue
            case attribute(maxCount1) | attribute(maxCount2) return $valueCount le $constraintValue
            default return error()
        let $colour := if ($green) then 'green' else 'red'        
        return  
            result:validationResult_valuePair_counts(
                $colour, $constraintElem, $constraintNode, $exprRole, $exprSpec, $exprLang, 
                $valueCount, $contextItem1, (), $context)
    return $results        
};

(:~
 : Validates ValuePairCmpCount (or FoxvaluePairCmpCount) constraints. 
 :
 : @param constraintElem the constraint element
 : @param items1 value of expression 1
 : @param items2 value of expression 2
 : @param context the evaluation context
 : @return validation results
 :)
declare function f:validateValuePair_cmpCount($constraintElem as element(),
                                              $expr1Spec as item(),
                                              $expr2Spec as item(), 
                                              $expr1Lang as xs:string,
                                              $expr2Lang as xs:string,
                                              $items1 as item()*,
                                              $items2 as item()*,
                                              $contextItem1 as item()?,                                              
                                              $context as map(xs:string, item()*))
        as element()* {
        
    let $constraintNode := $constraintElem/@cmpCount
    return if (not($constraintNode)) then () else
        
    let $valueCount1 := count($items1)
    let $valueCount2 := count($items2)
    let $green :=
        switch($constraintNode)
            case 'eq' return $valueCount1 eq $valueCount2
            case 'ne' return $valueCount1 ne $valueCount2
            case 'lt' return $valueCount1 lt $valueCount2
            case 'le' return $valueCount1 le $valueCount2
            case 'gt' return $valueCount1 gt $valueCount2
            case 'ge' return $valueCount1 ge $valueCount2
            default return error()

    let $colour := if ($green) then 'green' else 'red'        
    return  
        result:validationResult_valuePair_cmpCount(
            $colour, $constraintElem, $constraintNode, 
            $expr1Spec, $expr2Spec, $expr1Lang, $expr2Lang,
            $valueCount1, $valueCount2, $contextItem1, $context)       
};


