(:
 : -------------------------------------------------------------------------
 :
 : concordConstraint.xqm - validates a resource against a Content Correspondence constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/concord";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm",
    "resourceAccess.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkDefinition.xqm",
    "linkResolution.xqm",
    "linkValidation.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" at
    "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a Content Correspondence constraint.
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
declare function f:validateConcord($contextURI as xs:string,
                                   $contextDoc as document-node()?,
                                   $contextItem as item()?,
                                   $constraintElem as element(),
                                   $context as map(xs:string, item()*))
        as element()* {
    
    (: context info - a container for current file path, current document and datapath of the focus node :)    
    let $contextInfo := 
        let $focusPath := 
            $contextItem[. instance of node()][not(. is $contextDoc)] ! i:datapath(.)
        return  
            map:merge((
                $contextURI ! map:entry('filePath', .),
                $contextDoc ! map:entry('doc', .),
                $focusPath ! map:entry('nodePath', .)))
    return
        (: Exception - no context document :)
        if (not($contextInfo?doc)) then
            result:validationResult_concord_exception($constraintElem, (),
                'Context resource could not be parsed', (), $contextInfo)
        else
        
    (: Link resolution :)
    let $ldo := link:getLinkDefObject($constraintElem, $context)
    let $lros := link:resolveLinkDef($ldo, 'lro', $contextURI, 
        $contextItem[. instance of node()], $context, map{'mediatype': 'xml'})
    
    (: Check link constraints :)
    let $results_link := link:validateLinkConstraints($lros, $ldo, $constraintElem, $contextInfo) 
    
    (: Check correspondences :)    
    let $results_correspondence := f:validateConcordPairs($constraintElem, $lros, $contextInfo, $context)
    return ($results_link, $results_correspondence)
};

(:~
 : ===============================================================================
 :
 :     P e r f o r m    v a l i d a t i o n s
 :
 : ===============================================================================
 :)

declare function f:validateConcordPairs($constraintElem as element(),
                                        $lros as map(*)*,
                                        $contextInfo as map(*),
                                        $context as map(xs:string, item()*))
        as element()* {
        
    (: Repeat for each combination of link context node and link target document :)
    for $lro in $lros
        
    (: Check for link error :)
    return
        if ($lro?errorCode) then
            result:validationResult_concord_exception($constraintElem, $lro, (), (), $contextInfo)
        else
           
        (: Fetch target nodes :)
        let $targetNodes := 
            if (map:contains($lro, 'targetNodes')) then $lro?targetNodes
            else if (map:contains($lro, 'targetDoc')) then $lro?targetDoc
            else $lro?targetURI[i:fox-doc-available(.)] ! i:fox-doc(.) 
        return
            if (not($targetNodes)) then            
                let $msg :=
                    if ($lro?targetURI ! i:fox-resource-exists(.)) then 
                        'Correspondence target resource cannot be parsed'
                    else 'Correspondence target resource not found'
                return
                    result:validationResult_concord_exception(
                        $constraintElem, $lro, $msg, (), $contextInfo)                        
            else

        (: Fetch context item :)
        let $contextItem := $lro?contextItem
        
        (: Repeat for each constraint defining child of the constraint element :)
        return
            $constraintElem/gx:valueCord
                /f:validateConcordPair(., $contextItem, $targetNodes, $contextInfo, $context)
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
declare function f:validateConcordPair($valueCord as element(gx:valueCord),
                                       $linkContextItem as item(), 
                                       $linkTargetNodes as node()*,                                         
                                       $contextInfo as map(xs:string, item()*),
                                       $context as map(*))
        as element()* {
    let $contextNode := ($linkContextItem[. instance of node()], $contextInfo?doc)[1]
    let $evaluationContext := $context?_evaluationContext
    
    (: Definition of the correspondence :)
    let $cmp := $valueCord/@cmp
    let $quantifier := ($valueCord/@quant, 'all')[1]
    let $sourceExpr := $valueCord/@sourceXP
    let $targetExpr := $valueCord/@targetXP      
    let $flags := string($valueCord/@flags)
    let $useDatatype := $valueCord/@useDatatype/resolve-QName(., ..)        
    let $sourceExprLang := 'xpath'
    let $targetExprLang := 'xpath'    
    
    (: Count constraints, referring the values of source and target expression :)
    let $countSource := $valueCord/@countSource/xs:integer(.)
    let $minCountSource := $valueCord/@minCountSource/xs:integer(.)
    let $maxCountSource := $valueCord/@maxCountSource/xs:integer(.)    
    let $countTarget := $valueCord/@countTarget/xs:integer(.)
    let $minCountTarget := $valueCord/@minCountTarget/xs:integer(.)
    let $maxCountTarget := $valueCord/@maxCountTarget/xs:integer(.)
    
    (: Source expr value :)
    let $sourceItemsRaw :=
        i:evaluateXPath($sourceExpr, $contextNode, $evaluationContext, true(), true())    
    
    let $sourceItems :=
        if (empty($useDatatype)) then $sourceItemsRaw else 
        $sourceItemsRaw ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
    
    (: Check the number of items of the source expression value :)
    let $results_sourceCount :=
        f:validateConcordCounts($sourceItems, 'source', $valueCord, $contextInfo)
    
    (: Function items
       ============== :)       
    (: (1) Target value generator function :)
    let $getTargetItems := function($contextItem) {
        let $items := 
            if ($targetExprLang eq 'foxpath') then 
                i:evaluateFoxpath($targetExpr, $contextItem, $evaluationContext, true())
            else
                i:evaluateXPath($targetExpr, $contextItem, $evaluationContext, true(), true())
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
        case 'in' return function($op1, $op2) {$op1 = $op2}
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
        (: Loop over all link target nodes :)
        for $linkTargetNode in $linkTargetNodes
        
        (: Get target items :)
        let $targetItems := $getTargetItems($linkTargetNode)
        
        (: Check the number of items of the source expression value :)
        let $results_targetCount :=
            f:validateConcordCounts($targetItems, 'target', $valueCord, $contextInfo)
        
        (:
         : Identify source expression items for which the correspondence 
         : check fails.
         :)
        let $violations :=
            if ($cmp = ('in', 'notin')) then
                for $sourceItem at $pos in $sourceItems
                where $sourceItem instance of element(gx:red) or 
                      not($cmpTrueAgg($sourceItem, $targetItems))
                return $sourceItemsRaw[$pos]
            else if ($quantifier eq 'all') then
                for $sourceItem at $pos in $sourceItems
                where $sourceItem instance of element(gx:red) or 
                      exists($targetItems[not($cmpTrue($sourceItem, .))])
                return $sourceItemsRaw[$pos]
            else if ($quantifier eq 'some') then                
                for $sourceItem at $pos in $sourceItems
                where $sourceItem instance of element(gx:red) or
                      (every $v in $targetItems satisfies not($cmpTrue($sourceItem, $v)))
                return $sourceItemsRaw[$pos]
            else error()    
        let $colour := if (exists($violations)) then 'red' else 'green'                
        return (
            $results_targetCount,
            result:validationResult_concord($colour, $violations, $cmp, $valueCord, $contextInfo)
        )                                             
    return ($results_sourceCount, $results)            
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
declare function f:validateConcordCounts($items as item()*,
                                         $exprRole as xs:string, (: source | target :)
                                         $valueCord as element(),
                                         $contextInfo as map(xs:string, item()*))
        as element()* {
        
    let $countConstraints := $valueCord/(
        if ($exprRole eq 'source') then (@countSource, @minCountSource, @maxCountSource)
        else if ($exprRole eq 'target') then (@countTarget, @minCountTarget, @maxCountTarget)
        else error())
    let $results :=
        if (empty($countConstraints)) then () else
        
        (: evaluate constraints :)
        let $valueCount := count($items)        
        for $countConstraint in $countConstraints
        let $cmpWith := $countConstraint/xs:integer(.)
        let $green :=
            typeswitch($countConstraint)
            case attribute(countSource)    | attribute(countTarget)    return $valueCount eq $cmpWith
            case attribute(minCountSource) | attribute(minCountTarget) return $valueCount ge $cmpWith
            case attribute(maxCountSource) | attribute(maxCountTarget) return $valueCount le $cmpWith
            default return error()
        let $colour := if ($green) then 'green' else 'red'        
        return  
            result:validationResult_concord_counts($colour, $valueCord, $countConstraint, $valueCount, $contextInfo)
    return $results        
};

