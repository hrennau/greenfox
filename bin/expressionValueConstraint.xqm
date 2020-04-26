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

declare function f:validateExpressionValue($contextFilePath as xs:string,
                                           $constraint as element(), 
                                           $contextItem as item()?,                                           
                                           $contextDoc as document-node()?,
                                           $context as map(xs:string, item()*))
        as element()* {
    (:   
    let $_DEBUG := trace(typeswitch($contextItem) 
                         case document-node() return 'DNODE' 
                         case element() return 'ELEM' 
                         default return 'OTHER', '_TYPE_CONTEXT_ITEM_0: ')
     :)
     let $focusPath :=
        if ($contextItem instance of node() and not($contextItem is $contextDoc)) then
            $contextItem/f:datapath(.)
        else ()
    let $contextInfo := map:merge((
        $contextFilePath ! map:entry('filePath', .),
        $focusPath ! map:entry('nodePath', .)
    ))
    let $msg := $constraint/@msg
    let $exprLang := local-name($constraint)
    let $expr := $constraint/@expr
    let $evaluationContext := $context?_evaluationContext
    let $exprValue :=    
        if ($constraint/self::gx:xpath) then 
            i:evaluateXPath($expr, $contextItem, $evaluationContext, true(), true())
        else if ($constraint/self::gx:foxpath) then  
            f:evaluateFoxpath($expr, $contextFilePath, $evaluationContext, true())
        else error(QName((), 'SCHEMA_ERROR'), concat('Unknown expression kind: ', $constraint/name(.)))
        
    let $constraintId := $constraint/@id
    let $constraintLabel := $constraint/@label
    
    let $empty := $constraint/@empty
    let $exists := $constraint/@exists
    let $minCount := $constraint/@minCount
    let $maxCount := $constraint/@maxCount
    let $count := $constraint/@count
    let $datatype := $constraint/@datatype
    let $itemsUnique := $constraint/@itemsUnique
    
    let $eq := $constraint/@eq   
    let $ne := $constraint/@ne    
    let $gt := $constraint/@gt
    let $ge := $constraint/@ge
    let $lt := $constraint/@lt
    let $le := $constraint/@le    
    let $in := $constraint/gx:in
    let $notin := $constraint/gx:notin
    let $contains := $constraint/gx:contains
    let $matches := $constraint/@matches
    let $notMatches := $constraint/@notMatches
    let $like := $constraint/@like
    let $notLike := $constraint/@notLike
    
    let $length := $constraint/@length
    let $minLength := $constraint/@minLength
    let $maxLength := $constraint/@maxLength    
    
    let $eqFoxpath := $constraint/@eqFoxpath
    let $neFoxpath := $constraint/@neFoxpath
    let $ltFoxpath := $constraint/@ltFoxpath
    let $leFoxpath := $constraint/@leFoxpath
    let $gtFoxpath := $constraint/@gtFoxpath
    let $geFoxpath := $constraint/@geFoxpath
    let $inFoxpath := $constraint/@inFoxpath
    let $containsFoxpath := $constraint/@containsFoxpath    
    
    let $eqXPath := $constraint/@eqXPath
    let $neXPath := $constraint/@neXPath
    let $ltXPath := $constraint/@ltXPath
    let $leXPath := $constraint/@leXPath    
    let $gtXPath := $constraint/@gtXPath
    let $geXPath := $constraint/@geXPath    
    let $inXPath := $constraint/@inXPath
    let $containsXPath := $constraint/@containsXPath    
    
    let $flags := string($constraint/@flags)
    let $quantifier := ($constraint/@quant, 'all')[1]
    
    let $contextRel := $constraint/@contextRel
    
    let $eqFoxpathValue := 
        if (not($eqFoxpath)) then () else
            let $contextItem := $contextFilePath
            return f:evaluateFoxpath($eqFoxpath, $contextItem, $evaluationContext, true())

    let $containsXPathValue := 
        if (not($containsXPath)) then () else
            let $contextItem := ($contextDoc, $contextItem)[1]
            return  
                f:evaluateXPath($containsXPath, $contextItem, $evaluationContext, true(), true())            

    let $eqXPathValue := 
        if (not($eqXPath)) then () else
            let $contextItem := ($contextDoc, $contextItem)[1]
            return
                f:evaluateXPath($eqXPath, $contextItem, $evaluationContext, true(), true())            

    let $results := 
        let $contextInfos :=
            if (not($contextRel)) then $contextInfo
            else
                let $relTargets := f:relationshipTargets($contextRel, $contextFilePath, $context)
                for $relTarget in $relTargets
                return
                    map:put($contextInfo, 'relTarget', $relTarget)
        for $contextInfo in $contextInfos 
        return
    (
        if (not($eq)) then () else f:validateExpressionValue_cmp($exprValue, $eq, $quantifier, $constraint, $contextInfo),    
        if (not($ne)) then () else f:validateExpressionValue_cmp($exprValue, $ne, $quantifier, $constraint, $contextInfo),
        if (not($in)) then () else f:validateExpressionValue_in($exprValue, $quantifier, $constraint, $contextInfo),
        if (not($notin)) then () else f:validateExpressionValue_notin($exprValue, $quantifier, $constraint, $contextInfo),
        if (not($contains)) then () else f:validateExpressionValue_contains($exprValue, $quantifier, $constraint, $contextInfo),
        if (not($lt)) then () else f:validateExpressionValue_cmp($exprValue, $lt, $quantifier, $constraint, $contextInfo),
        if (not($le)) then () else f:validateExpressionValue_cmp($exprValue, $le, $quantifier, $constraint, $contextInfo),
        if (not($gt)) then () else f:validateExpressionValue_cmp($exprValue, $gt, $quantifier, $constraint, $contextInfo),
        if (not($ge)) then () else f:validateExpressionValue_cmp($exprValue, $ge, $quantifier, $constraint, $contextInfo),
        if (not($matches)) then () else f:validateExpressionValue_cmp($exprValue, $matches, $quantifier, $constraint, $contextInfo),
        if (not($notMatches)) then () else f:validateExpressionValue_cmp($exprValue, $notMatches, $quantifier, $constraint, $contextInfo),
        if (not($like)) then () else f:validateExpressionValue_cmp($exprValue, $like, $quantifier, $constraint, $contextInfo),
        if (not($notLike)) then () else f:validateExpressionValue_cmp($exprValue, $notLike, $quantifier, $constraint, $contextInfo),
        if (not($length)) then () else f:validateExpressionValue_cmp($exprValue, $length, $quantifier, $constraint, $contextInfo),
        if (not($minLength)) then () else f:validateExpressionValue_cmp($exprValue, $minLength, $quantifier, $constraint, $contextInfo),
        if (not($maxLength)) then () else f:validateExpressionValue_cmp($exprValue, $maxLength, $quantifier, $constraint, $contextInfo),        
        if (not($empty)) then () else f:validateExpressionValueCount($exprValue, $empty, $constraint, $contextInfo),
        if (not($exists)) then () else f:validateExpressionValueCount($exprValue, $exists, $constraint, $contextInfo),
        if (not($count)) then () else f:validateExpressionValueCount($exprValue, $count, $constraint, $contextInfo),     
        if (not($minCount)) then () else f:validateExpressionValueCount($exprValue, $minCount, $constraint, $contextInfo),
        if (not($maxCount)) then () else f:validateExpressionValueCount($exprValue, $maxCount, $constraint, $contextInfo),
        if (not($datatype)) then () else f:validateExpressionValue_cmp($exprValue, $datatype, $quantifier, $constraint, $contextInfo),

        if (not($eqXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $eqXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($neXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $neXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($leXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $leXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($ltXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $ltXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($geXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $geXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($gtXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $gtXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($inXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $inXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($containsXPath)) then () else f:validateExpressionValue_containsExpressionValue(
                                                                          $exprValue, $containsXPath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $constraint, $contextInfo),

        if (not($eqFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $eqFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($neFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $neFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($ltFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $ltFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($leFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $leFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($gtFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $gtFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($geFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $geFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($inFoxpath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $inFoxpath, $contextItem, $contextFilePath, 
                                                                            $contextDoc, $context, $quantifier, $constraint, $contextInfo),
        if (not($containsFoxpath)) then () else f:validateExpressionValue_containsExpressionValue(
                                                                          $exprValue, $containsFoxpath, $contextItem, $contextFilePath, 
                                                                          $contextDoc, $context, $constraint, $contextInfo),
        if (not($itemsUnique/boolean(.))) then () else f:validateExpressionValue_itemsUnique($exprValue, $itemsUnique, $constraint, $contextInfo),   
        
        ()                                                                          

       
    )
    let $furtherResults :=
        for $xpath in $constraint/gx:xpath
        for $exprValueItem in $exprValue
        return
            i:validateExpressionValue($xpath, $exprValueItem, $contextFilePath, $contextDoc, $context)
    return (
        $results,
        $furtherResults
    )
};

declare function f:validateExpressionValue_contains($exprValue as item()*,
                                                    $quantifier as xs:string,
                                                    $valueShape as element(),
                                                    $contextInfo as map(xs:string, item()*))
        as element() {
    let $contains := $valueShape/gx:contains        
    let $values := $contains/string()
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $violations :=
        if ($quantifier eq 'all') then $values[not(. = $exprValue)] 
        else if ($values = $exprValue) then ()
        else $values
    return
        if (exists($violations)) then 
            let $useViolations := if ($quantifier eq 'some') then () else $violations
            return
                f:validationResult_expression('red', $valueShape, $contains, $exprValue,
                                              $resultAdditionalAtts, ($useViolations ! <gx:value>{.}</gx:value>), 
                                              $contextInfo, $resultOptions)
        else 
            f:validationResult_expression('green', $valueShape, $contains, $exprValue,
                                          $resultAdditionalAtts, (), 
                                          $contextInfo, $resultOptions)
};        

declare function f:validateExpressionValue_itemsUnique($exprValue as item()*,
                                                       $itemsUnique as attribute(),
                                                       $valueShape as element(),
                                                       $contextInfo as map(xs:string, item()*))
        as element() {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
        
    let $violations :=
        if (count($exprValue) eq count(distinct-values($exprValue))) then ()
        else
            for $item in $exprValue
            group by $value := $item
            where count($item) gt 1
            return $item[1]
    return
        if (exists($violations)) then 
            f:validationResult_expression('red', $valueShape, $itemsUnique, $exprValue,
                                          $resultAdditionalAtts, ($violations ! <gx:value>{.}</gx:value>), 
                                          $contextInfo, $resultOptions)
        else 
            f:validationResult_expression('green', $valueShape, $itemsUnique, $exprValue,
                                          $resultAdditionalAtts, (), 
                                          $contextInfo, $resultOptions)
};        


declare function f:validateExpressionValueCount($exprValue as item()*,
                                                $cmp as attribute(),
                                                $valueShape as element(),
                                                $contextInfo as map(xs:string, item()*))
        as element()? {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $count := count($exprValue)
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        case attribute(empty) return function($count, $cmp) {if ($cmp eq 'true') then $count = 0 else $count gt 0}        
        case attribute(exists) return function($count, $cmp) {if ($cmp eq 'true') then $count gt 0 else $count eq 0}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown count comparison operator: ', $cmp))
    return        
        if ($cmpTrue($count, $cmp)) then  
            f:validationResult_expressionCount('green', $valueShape, $cmp, $count, $exprValue, 
                                               $resultAdditionalAtts, (), $contextInfo, $resultOptions)
        else 
            let $values := 
                if ($cmp/self::attribute(empty) eq 'true' or 
                    $cmp/self::attribute(exists) eq 'false')
                then f:extractValues($exprValue, $valueShape)
                else ()
            return
                f:validationResult_expressionCount('red', $valueShape, $cmp, $count, $exprValue, 
                                                   $resultAdditionalAtts, $values, $contextInfo, $resultOptions)
};        

declare function f:validateExpressionValue_cmp($exprValue as item()*,
                                               $cmp as attribute(),
                                               $quantifier as xs:string,                                               
                                               $valueShape as element(),
                                               $contextInfo as map(xs:string, item()*))
        as element() {
    (: let $_DEBUG := trace($cmp, 'CMP: ') :)   
    
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
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
        case attribute(length) return function($op1, $op2) {string-length($op1) = $op2}
        case attribute(minLength) return function($op1, $op2) {string-length($op1) >= $op2}        
        case attribute(maxLength) return function($op1, $op2) {string-length($op1) <= $op2}        
        case attribute(datatype) return function($op1, $op2) {i:castableAs($op1, QName($i:URI_XSD, $op2))}       
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $cmp))
        
    
    let $useDatatype := $valueShape/@useDatatype/resolve-QName(., ..)
    let $useCmp :=
        if ($cmp/self::attribute(like)) then $cmp/f:glob2regex(.)
        else if ($cmp/self::attribute(notLike)) then $cmp/f:glob2regex(.)
        else if ($cmp/self::attribute(datatype)) then $cmp        
        else if (empty($useDatatype)) then $cmp 
        else i:castAs($cmp, $useDatatype, ())
    let $useItems := if (empty($useDatatype)) then $exprValue else 
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $useItems ! (
                if (. instance of element(gx:red)) then .
                else if (not($cmpTrue(., $useCmp))) then .
                else ())
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $cmp, $exprValue,
                                                   $resultAdditionalAtts, i:validationResultValues($violations, $valueShape),                                           
                                                   $contextInfo, $resultOptions)
        else if ($quantifier eq 'some') then 
            if (exists($useItems[$cmpTrue(., $useCmp)]))  then () 
            else f:validationResult_expression('red', $valueShape, $cmp, $exprValue,
                                                $resultAdditionalAtts, i:validationResultValues($exprValue, $valueShape), 
                                                $contextInfo, $resultOptions)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, $exprValue,
                                           $resultAdditionalAtts, (), 
                                           $contextInfo, $resultOptions)
};        

declare function f:validateExpressionValue_cmpExpr($exprValue as item()*,
                                                   $cmp as attribute(),
                                                   $contextItem as item()?,
                                                   $contextFilePath as xs:string,
                                                   $contextDoc as document-node()?,
                                                   $context as map(*),
                                                   $quantifier as xs:string,                                               
                                                   $valueShape as element(),
                                                   $contextInfo as map(xs:string, item()*))
        as element() {
    (: let $_DEBUG := trace($cmp, 'CMP_EXPR: ') :)
    let $evaluationContext := $context?_evaluationContext    
    let $exprKind := $valueShape/local-name(.)
    let $cmpExprKind := if (ends-with($cmp/local-name(.), 'Foxpath')) then 'foxpath' else 'xpath'
    let $flags := string($valueShape/@flags)
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $useDatatype := $valueShape/@useDatatype/resolve-QName(., ..)
        
    (: Retrieve relationship target to be used as context for comparison expression :)
    let $cmpRelTarget := $contextInfo?relTarget
    
    (: Context kind :)
    let $cmpContext :=
        if (exists($cmpRelTarget)) then () else
        let $attName := local-name($cmp) || 'Context'
        return $valueShape/@*[local-name(.) eq $attName]

    (: the check items :)
    let $checkItems := if (empty($useDatatype)) then $exprValue else 
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
        
    (: construction of comparison value - argument is the context item :)
    let $getCmpItems := function($ctxtItem) {
        let $cmpValue := 
            if ($cmpExprKind eq 'foxpath') then 
                i:evaluateFoxpath($cmp, $ctxtItem, $evaluationContext, true())
            else i:evaluateXPath($cmp, $ctxtItem, $evaluationContext, true(), true())
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
        case attribute(inXPath) return function($op1, $op2) {$op1 = $op2}
        
        case attribute(eqFoxpath) return function($op1, $op2) {$op1 = $op2}
        case attribute(neFoxpath) return function($op1, $op2) {$op1 = $op2}        
        case attribute(ltFoxpath) return function($op1, $op2) {$op1 < $op2}
        case attribute(leFoxpath) return function($op1, $op2) {$op1 <= $op2}
        case attribute(gtFoxpath) return function($op1, $op2) {$op1 > $op2}        
        case attribute(geFoxpath) return function($op1, $op2) {$op1 >= $op2}
        case attribute(inFoxpath) return function($op1, $op2) {$op1 = $op2}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $cmp))
    
    let $errors :=
            (: re-evaluate cmp expression for each check item, using it as context item :)
            if ($cmpContext eq '#item') then
                if ($quantifier eq 'all') then
                    let $violations :=
                        for $checkItem at $pos in $checkItems
                        let $item := $exprValue[$pos]
                        return $item[
                            $checkItem instance of element(gx:red) or not($cmpTrue($checkItem, $getCmpItems($item)))]
                    return
                        if (empty($violations)) then () else
                            f:validationResult_expression('red', $valueShape, $cmp, $exprValue, 
                                $resultAdditionalAtts,
                                ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, 
                                $contextInfo, $resultOptions)
                        
                else if ($quantifier eq 'some') then
                    let $matches :=
                        for $checkItem at $pos in $checkItems[not(self::gx:red)]
                        let $item := $exprValue[$pos]
                        return $item[$cmpTrue($checkItem, $getCmpItems($item))]
                    return
                        if (exists($matches)) then ()
                        else
                            f:validationResult_expression('red', $valueShape, $cmp, $exprValue, 
                                $resultAdditionalAtts,
                                ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, 
                                $contextInfo, $resultOptions)
                    
                else error()                            
            else
                let $useContextItem := 
                    if ($cmpRelTarget) then
                        if ($cmpExprKind eq 'xpath') then 
                            if ($cmpRelTarget instance of node()) then $cmpRelTarget
                            else doc($cmpRelTarget)
                        else $cmpRelTarget
                    else if ($exprKind eq 'foxpath' and $cmpExprKind eq 'xpath') then $contextDoc
                    else if ($exprKind eq 'xpath' and $cmpExprKind eq 'foxpath') then $contextFilePath
                    else $contextItem
                let $cmpItems := $getCmpItems($useContextItem)
                return
                    if ($quantifier eq 'all') then
                        let $violations := $checkItems[. instance of element(gx:red) or not($cmpTrue(., $cmpItems))]
                        return
                            if (empty($violations)) then () 
                            else f:validationResult_expression('red', $valueShape, $cmp, $exprValue, 
                                                               $resultAdditionalAtts, 
                                                               ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, 
                                                               $contextInfo, $resultOptions)
                    else if ($quantifier eq 'some') then
                        if ($checkItems[not(. instance of element(gx:red)) and $cmpTrue(., $cmpItems)]) then ()
                        else f:validationResult_expression('red', $valueShape, $cmp, $exprValue, 
                                                           $resultAdditionalAtts, 
                                                           ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, 
                                                           $contextInfo, $resultOptions)
                    else error()                            
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, $exprValue, 
                                           $resultAdditionalAtts, (), 
                                           $contextInfo, $resultOptions)
};    

declare function f:validateExpressionValue_containsExpressionValue(
                                                         $exprValue as item()*,
                                                         $cmp as attribute(),
                                                         $contextItem as item()?,
                                                         $contextFilePath as xs:string,
                                                         $contextDoc as document-node()?,
                                                         $context as map(*),
                                                         $valueShape as element(),
                                                         $contextInfo as map(xs:string, item()*))
        as element() {
    (: let $_DEBUG := trace($cmp, 'CMP: ') :)   
    let $evaluationContext := $context?_evaluationContext
    let $flags := string($valueShape/@flags)
    let $exprKind := $valueShape/local-name(.)
    let $cmpExprKind := if (ends-with($cmp/local-name(.), 'Foxpath')) then 'foxpath' else 'xpath'
    
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $useDatatype := $valueShape/@useDatatype/resolve-QName(., ..)
        
    (: the check items :)
    let $checkItems := if (empty($useDatatype)) then $exprValue else 
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
        
    (: construction of comparison value - argument is the context item :)
    let $useContextItem := 
        let $_DEBUG := concat($exprKind, '/', $cmpExprKind) return
        if ($exprKind eq 'foxpath' and $cmpExprKind eq 'xpath') then $contextDoc
        else if ($exprKind eq 'xpath' and $cmpExprKind eq 'foxpath') then $contextFilePath
        else $contextItem
    let $cmpValue := 
        if ($cmpExprKind eq 'foxpath') then 
            i:evaluateFoxpath($cmp, $useContextItem, $evaluationContext, true())
        else i:evaluateXPath($cmp, $useContextItem, $evaluationContext, true(), true())
    let $cmpItems :=
            if (empty($useDatatype)) then $cmpValue 
            else $cmpValue ! i:castAs(., $useDatatype, ())
    (: identify errors :)
    
    let $errors :=
        let $violations := $cmpItems[. instance of element(gx:red) or not(. = $checkItems)]
        return
            if (empty($violations)) then () 
            else f:validationResult_expression('red', $valueShape, $cmp, $exprValue,
                 $resultAdditionalAtts, 
                 ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, 
                 $contextInfo, $resultOptions)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, $exprValue, 
                 $resultAdditionalAtts, (), 
                 $contextInfo, $resultOptions)
};        


declare function f:validateExpressionValue_in($exprValue as item()*,
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


declare function f:validationResult_expression($colour as xs:string,
                                               $valueShape as element(),
                                               $constraint as node()*,
                                               $exprValue as item()*,
                                               $additionalAtts as attribute()*,
                                               $additionalElems as element()*,
                                               $contextInfo as map(xs:string, item()*),
                                               $options as map(*)?)
        as element() {
    let $exprLang := $valueShape/local-name(.)
    let $expr := $valueShape/@expr/normalize-space(.)    
    let $constraint1 := $constraint[1]    
    let $constraintConfig :=
        typeswitch($constraint1)
        case attribute(eq) return map{'constraintComp': 'ExprValueEq', 'atts': ('eq', 'useDatatype', 'quant')}
        case attribute(ne) return map{'constraintComp': 'ExprValueNe', 'atts': ('ne', 'useDatatype', 'quant')}
        case element(gx:in) return map{'constraintComp': 'ExprValueIn', 'atts': ('useDatatype')}
        case element(gx:notin) return map{'constraintComp': 'ExprValueNotin', 'atts': ('useDatatype')}
        case element(gx:contains) return map{'constraintComp': 'ExprValueContains', 'atts': ('useDatatype')}
        case attribute(lt) return map{'constraintComp': 'ExprValueLt', 'atts': ('lt', 'useDatatype', 'quant')}        
        case attribute(le) return map{'constraintComp': 'ExprValueLe', 'atts': ('le', 'useDatatype', 'quant')}        
        case attribute(gt) return map{'constraintComp': 'ExprValueGt', 'atts': ('gt', 'useDatatype', 'quant')}        
        case attribute(ge) return map{'constraintComp': 'ExprValueGe', 'atts': ('ge', 'useDatatype', 'quant')}
        case attribute(datatype) return map{'constraintComp': 'ExprValueDatatype', 'atts': ('datatype', 'useDatatype', 'quant')}
        case attribute(matches) return map{'constraintComp': 'ExprValueMatches', 'atts': ('matches', 'useDatatype', 'quant')}
        case attribute(notMatches) return map{'constraintComp': 'ExprValueNotMatches', 'atts': ('notMatches', 'useDatatype', 'quant')}
        case attribute(like) return map{'constraintComp': 'ExprValueLike', 'atts': ('like', 'useDatatype', 'quant')}        
        case attribute(notLike) return map{'constraintComp': 'ExprValueNotLike', 'atts': ('notLike', 'useDatatype', 'quant')}
        case attribute(length) return map{'constraintComp': 'ExprValueLength', 'atts': ('length', 'quant')}
        case attribute(minLength) return map{'constraintComp': 'ExprValueMinLength', 'atts': ('minLength', 'quant')}        
        case attribute(maxLength) return map{'constraintComp': 'ExprValueMinLength', 'atts': ('maxLength', 'quant')}        
        case attribute(eqXPath) return map{'constraintComp': 'ExprValueEqXPath', 'atts': ('eqXPath', 'useDatatype', 'quant')}
        case attribute(neXPath) return map{'constraintComp': 'ExprValueNeXPath', 'atts': ('neXPath', 'useDatatype', 'quant')}
        case attribute(leXPath) return map{'constraintComp': 'ExprValueLeXPath', 'atts': ('leXPath', 'useDatatype', 'quant')}
        case attribute(ltXPath) return map{'constraintComp': 'ExprValueLtXPath', 'atts': ('ltXPath', 'useDatatype', 'quant')}
        case attribute(geXPath) return map{'constraintComp': 'ExprValueGeXPath', 'atts': ('geXPath', 'useDatatype', 'quant')}
        case attribute(gtXPath) return map{'constraintComp': 'ExprValueGtXPath', 'atts': ('gtXPath', 'useDatatype', 'quant')}
        case attribute(inXPath) return map{'constraintComp': 'ExprValueInXPath', 'atts': ('inXPath', 'useDatatype', 'quant')}        
        case attribute(containsXPath) return map{'constraintComp': 'ExprValueContainsXPath', 'atts': ('containsXPath', 'useDatatype')}
        case attribute(containsFoxpath) return map{'constraintComp': 'ExprValueContainsFoxpath', 'atts': ('containsFoxpath', 'useDatatype')}
        case attribute(eqFoxpath) return map{'constraintComp': 'ExprValueEqFoxpath', 'atts': ('eqFoxpath', 'useDatatype', 'quant')}
        case attribute(neFoxpath) return map{'constraintComp': 'ExprValueNeFoxpath', 'atts': ('neFoxpath', 'useDatatype', 'quant')}
        case attribute(ltFoxpath) return map{'constraintComp': 'ExprValueLtFoxpath', 'atts': ('ltFoxpath', 'useDatatype', 'quant')}
        case attribute(leFoxpath) return map{'constraintComp': 'ExprValueLeFoxpath', 'atts': ('leFoxpath', 'useDatatype', 'quant')}
        case attribute(gtFoxpath) return map{'constraintComp': 'ExprValueGtFoxpath', 'atts': ('gtFoxpath', 'useDatatype', 'quant')}
        case attribute(geFoxpath) return map{'constraintComp': 'ExprValueGeFoxpath', 'atts': ('geFoxpath', 'useDatatype', 'quant')}
        case attribute(inFoxpath) return map{'constraintComp': 'ExprValueInFoxpath', 'atts': ('inFoxpath', 'useDatatype', 'quant')}        
        case attribute(itemsUnique) return map{'constraintComp': 'ExprValueItemsUnique', 'atts': ('itemsUnique')}
        default return error()
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-', $constraint1/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valueShape/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, $constraint1/local-name(.), ())
        else i:getErrorMsg($valueShape, $constraint1/local-name(.), ())
    let $elemName := 
        switch($colour)
        case 'red' return 'gx:red'
        default return concat('gx:', $colour)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute valueShapeID {$valueShapeId},            
            $valueShape/@label/attribute constraintLabel {.},
            $filePath,
            $focusNode,
            $standardAtts,
            $additionalAtts,
            $valueCountAtt,            
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            $additionalElems
        }
       
};

declare function f:validationResult_expressionCount($colour as xs:string,
                                                    $valueShape as element(),
                                                    $constraint as node()*,
                                                    $count as xs:integer,
                                                    $exprValue as item()*,
                                                    $additionalAtts as attribute()*,
                                                    $additionalElems as element()*,
                                                    $contextInfo as map(xs:string, item()*),
                                                    $options as map(*)?)
        as element() {
    let $exprLang := $valueShape/local-name(.)
    let $expr := $valueShape/@expr/normalize-space(.)   
    let $constraint1 := $constraint[1]
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(count) return map{'constraintComp': 'ExprValueCount', 'atts': ('count')}
        case attribute(minCount) return map{'constraintComp': 'ExprValueCount', 'atts': ('minCount')}
        case attribute(maxCount) return map{'constraintComp': 'ExprValueCount', 'atts': ('maxCount')}
        case attribute(empty) return map{'constraintComp': 'ExprValueEmpty', 'atts': ('empty')}
        case attribute(exists) return map{'constraintComp': 'ExprValueExists', 'atts': ('exists')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valueShape/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $valueShapeId := $valueShape/@valueShapeID
    (: let $constraintSuffix := $constraintComponent ! replace(., '^ExprValue', '') ! f:firstCharToLowerCase(.) :)
    (: let $constraintId := concat($valueShapeId, '-', $constraintSuffix) :)    
    let $constraintId := concat($valueShapeId, '-', $constraint1/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, $constraint/local-name(.), ())
        else i:getErrorMsg($valueShape, $constraint/local-name(.), ())
    let $elemName := 
        switch($colour)
        case 'red' return 'gx:red'
        default return concat('gx:', $colour)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute valueShapeID {$valueShapeId},  
            $filePath,
            $focusNode,
            $standardAtts,
            $useAdditionalAtts,
            $valueCountAtt,            
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            $additionalElems
        }       
};

declare function f:extractValues($exprValue as item()*, $valueShape as element())
        as element()* {
    let $reporterXPath := $valueShape/@reporterXPath        
    return
        if ($reporterXPath) then
            for $item in $exprValue
            let $rep := i:evaluateSimpleXPath($reporterXPath, $item)    
            return
                <gx:value>{$rep}</gx:value>
        else
            for $item in $exprValue
            return
                typeswitch($item)
                case xs:anyAtomicType | attribute() return string($item) ! <gx:value>{.}</gx:value>
                case element() return
                    if ($item/not((@*, *))) then string ($item) ! <gx:value>{.}</gx:value>
                    else <gx:valueNodePath>{i:datapath($item)}</gx:valueNodePath>
                default return ()                
};        
