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
            f:evaluateFoxpath($expr, $contextItem, $evaluationContext, true())
        else error(QName((), 'SCHEMA_ERROR'), concat('Unknown expression kind: ', $constraint/name(.)))
        
    let $constraintId := $constraint/@id
    let $constraintLabel := $constraint/@label
    
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
    
    let $eqFoxpath := $constraint/@eqFoxpath
    let $ltFoxpath := $constraint/@ltFoxpath
    let $leFoxpath := $constraint/@leFoxpath
    let $gtFoxpath := $constraint/@gtFoxpath
    let $geFoxpath := $constraint/@geFoxpath
    let $inFoxpath := $constraint/@inFoxpath
    let $containsFoxpath := $constraint/@containsFoxpath    
    
    let $eqXPath := $constraint/@eqXPath
    let $ltXPath := $constraint/@ltXPath
    let $leXPath := $constraint/@leXPath    
    let $gtXPath := $constraint/@gtXPath
    let $geXPath := $constraint/@geXPath    
    let $inXPath := $constraint/@inXPath
    let $containsXPath := $constraint/@containsXPath    
    
    let $flags := string($constraint/@flags)
    let $quantifier := ($constraint/@quant, 'all')[1]
    
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

    let $results := (
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
        if (not($count)) then () else f:validateExpressionValueCount($exprValue, $count, $constraint, $contextInfo),     
        if (not($minCount)) then () else f:validateExpressionValueCount($exprValue, $minCount, $constraint, $contextInfo),
        if (not($maxCount)) then () else f:validateExpressionValueCount($exprValue, $maxCount, $constraint, $contextInfo),
        if (not($datatype)) then () else f:validateExpressionValue_cmp($exprValue, $datatype, $quantifier, $constraint, $contextInfo),

        if (not($eqXPath)) then () else f:validateExpressionValue_cmpExpr($exprValue, $eqXPath, $contextItem, $contextFilePath, 
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
    let $violations :=
        if ($quantifier eq 'all') then $values[not(. = $exprValue)] 
        else if ($values = $exprValue) then ()
        else $values
    return
        if (exists($violations)) then 
            let $useViolations := if ($quantifier eq 'some') then () else $violations
            return
                f:validationResult_expression('red', $valueShape, $contains, (), ($useViolations ! <gx:value>{.}</gx:value>), $contextInfo)
        else 
            f:validationResult_expression('green', $valueShape, $contains, (), (), $contextInfo)
};        

declare function f:validateExpressionValue_itemsUnique($exprValue as item()*,
                                                       $itemsUnique as attribute(),
                                                       $valueShape as element(),
                                                       $contextInfo as map(xs:string, item()*))
        as element() {
    let $violations :=
        if (count($exprValue) eq count(distinct-values($exprValue))) then ()
        else
            for $item in $exprValue
            group by $value := $item
            where count($item) gt 1
            return $item[1]
    return
        if (exists($violations)) then 
            f:validationResult_expression('red', $valueShape, $itemsUnique, (), ($violations ! <gx:value>{.}</gx:value>), $contextInfo)
        else 
            f:validationResult_expression('green', $valueShape, $itemsUnique, (), (), $contextInfo)
};        


declare function f:validateExpressionValueCount($exprValue as item()*,
                                                $cmp as attribute(),
                                                $valueShape as element(),
                                                $contextInfo as map(xs:string, item()*))
        as element() {
    let $count := count($exprValue)
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown count comparison operator: ', $cmp))
    return        
        if ($cmpTrue($count, $cmp)) then  
            f:validationResult_expressionCount('green', $valueShape, $cmp, $count, (), (), $contextInfo)
        else 
            f:validationResult_expressionCount('red', $valueShape, $cmp, $count, (), (), $contextInfo)
};        

declare function f:validateExpressionValue_cmp($exprValue as item()*,
                                               $cmp as attribute(),
                                               $quantifier as xs:string,                                               
                                               $valueShape as element(),
                                               $contextInfo as map(xs:string, item()*))
        as element() {
    (: let $_DEBUG := trace($cmp, 'CMP: ') :)     
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
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:error'))
    let $errors :=
        if ($quantifier eq 'all') then 
            let $violations := $useItems ! (
                if (. instance of element(gx:error)) then .
                else if (not($cmpTrue(., $useCmp))) then .
                else ())
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $cmp, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
        else if ($quantifier eq 'some') then 
            if (exists($useItems[$cmpTrue(., $useCmp)]))  then () 
            else f:validationResult_expression('red', $valueShape, $cmp, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, (), (), $contextInfo)
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
                            $checkItem instance of element(gx:error) or not($cmpTrue($checkItem, $getCmpItems($item)))]
                    return
                        if (empty($violations)) then () else
                            f:validationResult_expression('red', $valueShape, $cmp, (), 
                                ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
                        
                else if ($quantifier eq 'some') then
                    let $matches :=
                        for $checkItem at $pos in $checkItems[not(self::gx:error)]
                        let $item := $exprValue[$pos]
                        return $item[$cmpTrue($checkItem, $getCmpItems($item))]
                    return
                        if (exists($matches)) then ()
                        else
                            f:validationResult_expression('red', $valueShape, $cmp, (), 
                                ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
                    
                else error()                            
            else
                let $useContextItem := 
                    if ($exprKind eq 'foxpath' and $cmpExprKind eq 'xpath') then $contextDoc
                    else if ($exprKind eq 'xpath' and $cmpExprKind eq 'foxpath') then $contextFilePath
                    else $contextItem
                let $cmpItems := $getCmpItems($useContextItem)
                return
                    if ($quantifier eq 'all') then
                        let $violations := $checkItems[. instance of element(gx:error) or not($cmpTrue(., $cmpItems))]
                        return
                            if (empty($violations)) then () 
                            else f:validationResult_expression('red', $valueShape, $cmp, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
                    else if ($quantifier eq 'some') then
                        if ($checkItems[not(. instance of element(gx:error)) and $cmpTrue(., $cmpItems)]) then ()
                        else f:validationResult_expression('red', $valueShape, $cmp, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
                    else error()                            
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, (), (), $contextInfo)
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
    
    let $useDatatype := $valueShape/@useDatatype/resolve-QName(., ..)
        
    (: the check items :)
    let $checkItems := if (empty($useDatatype)) then $exprValue else 
        $exprValue ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:error'))
        
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
        let $violations := $cmpItems[. instance of element(gx:error) or not(. = $checkItems)]
        return
            if (empty($violations)) then () 
            else f:validationResult_expression('red', $valueShape, $cmp, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
    return
        if ($errors) then $errors
        else f:validationResult_expression('green', $valueShape, $cmp, (), (), $contextInfo)
};        


declare function f:validateExpressionValue_in($exprValue as item()*,
                                              $quantifier as xs:string,
                                              $valueShape as element(),
                                              $contextInfo as map(xs:string, item()*))
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
                        default return error(QName((), 'ILLFORMED_GREENFOX_SCHEMA'), concat("Unexpected child of 'in': ", name($alternative)))                
            )]                    
            return
                if (empty($violations)) then () 
                else f:validationResult_expression('red', $valueShape, $in, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
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
                else f:validationResult_expression('red', $valueShape, $in, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
    return
        if ($errors) then $errors else f:validationResult_expression('green', $valueShape, $in, (), (), $contextInfo)
};        

declare function f:validateExpressionValue_notin($exprValue as item()*,
                                                 $quantifier as xs:string,
                                                 $valueShape as element(),
                                                 $contextInfo as map(xs:string, item()*))
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
                else f:validationResult_expression('red', $valueShape, $notin, (), ($violations => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
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
                else f:validationResult_expression('red', $valueShape, $notin, (), ($exprValue => distinct-values()) ! <gx:value>{.}</gx:value>, $contextInfo)
    return
        if ($errors) then $errors else f:validationResult_expression('green', $valueShape, $notin, (), (), $contextInfo)
};        


declare function f:validationResult_expression($colour as xs:string,
                                               $valueShape as element(),
                                               $constraint as node()*,
                                               $additionalAtts as attribute()*,
                                               $additionalElems as element()*,
                                               $contextInfo as map(xs:string, item()*))
        as element() {
    let $exprLang := $valueShape/local-name(.)
    let $expr := $valueShape/@expr/normalize-space(.)    
    let $constraint1 := $constraint[1]    
    let $constraintConfig :=
        typeswitch($constraint1)
        case attribute(eq) return map{'constraintComp': 'ExprValueEq', 'atts': ('eq', 'useDatatype')}
        case attribute(ne) return map{'constraintComp': 'ExprValueNe', 'atts': ('ne', 'useDatatype')}
        case element(gx:in) return map{'constraintComp': 'ExprValueIn', 'atts': ('useDatatype')}
        case element(gx:notin) return map{'constraintComp': 'ExprValueNotin', 'atts': ('useDatatype')}
        case element(gx:contains) return map{'constraintComp': 'ExprValueContains', 'atts': ('useDatatype')}
        case attribute(lt) return map{'constraintComp': 'ExprValueLt', 'atts': ('lt', 'useDatatype')}        
        case attribute(le) return map{'constraintComp': 'ExprValueLe', 'atts': ('le', 'useDatatype')}        
        case attribute(gt) return map{'constraintComp': 'ExprValueGt', 'atts': ('gt', 'useDatatype')}        
        case attribute(ge) return map{'constraintComp': 'ExprValueGe', 'atts': ('ge', 'useDatatype')}
        case attribute(datatype) return map{'constraintComp': 'ExprValueDatatype', 'atts': ('datatype', 'useDatatype')}
        case attribute(matches) return map{'constraintComp': 'ExprValueMatches', 'atts': ('matches', 'useDatatype')}
        case attribute(notMatches) return map{'constraintComp': 'ExprValueNotMatches', 'atts': ('notMatches', 'useDatatype')}
        case attribute(like) return map{'constraintComp': 'ExprValueLike', 'atts': ('like', 'useDatatype')}        
        case attribute(notLike) return map{'constraintComp': 'ExprValueNotLike', 'atts': ('notLike', 'useDatatype')}
        case attribute(eqXPath) return map{'constraintComp': 'ExprValueEqXPath', 'atts': ('eqXPath', 'useDatatype')}
        case attribute(leXPath) return map{'constraintComp': 'ExprValueLeXPath', 'atts': ('leXPath', 'useDatatype')}
        case attribute(ltXPath) return map{'constraintComp': 'ExprValueLtXPath', 'atts': ('ltXPath', 'useDatatype')}
        case attribute(geXPath) return map{'constraintComp': 'ExprValueGeXPath', 'atts': ('geXPath', 'useDatatype')}
        case attribute(gtXPath) return map{'constraintComp': 'ExprValueGtXPath', 'atts': ('gtXPath', 'useDatatype')}
        case attribute(inXPath) return map{'constraintComp': 'ExprValueInXPath', 'atts': ('inXPath', 'useDatatype')}        
        case attribute(containsXPath) return map{'constraintComp': 'ExprValueContainsXPath', 'atts': ('containsXPath', 'useDatatype')}
        case attribute(containsFoxpath) return map{'constraintComp': 'ExprValueContainsFoxpath', 'atts': ('containsFoxpath', 'useDatatype')}
        case attribute(eqFoxpath) return map{'constraintComp': 'ExprValueEqFoxpath', 'atts': ('eqFoxpath', 'useDatatype')}
        case attribute(ltFoxpath) return map{'constraintComp': 'ExprValueLtFoxpath', 'atts': ('ltFoxpath', 'useDatatype')}
        case attribute(leFoxpath) return map{'constraintComp': 'ExprValueLeFoxpath', 'atts': ('leFoxpath', 'useDatatype')}
        case attribute(gtFoxpath) return map{'constraintComp': 'ExprValueGtFoxpath', 'atts': ('gtFoxpath', 'useDatatype')}
        case attribute(geFoxpath) return map{'constraintComp': 'ExprValueGeFoxpath', 'atts': ('geFoxpath', 'useDatatype')}
        case attribute(inFoxpath) return map{'constraintComp': 'ExprValueInFoxpath', 'atts': ('inFoxpath', 'useDatatype')}        
        case attribute(itemsUnique) return map{'constraintComp': 'ExprValueItemsUnique', 'atts': ('itemsUnique')}
        default return error()
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-', $constraint1/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
        
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, $constraint1/local-name(.), ())
        else i:getErrorMsg($valueShape, $constraint1/local-name(.), ())
    let $elemName := 
        switch($colour)
        case 'red' return 'gx:error'
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
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            $valueShape/@*[local-name(.) = $constraintConfig?atts],
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
                                                    $additionalElems as element()*,
                                                    $contextInfo as map(xs:string, item()*))
        as element() {
    let $exprLang := $valueShape/local-name(.)
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
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePathe {.}
    
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
            attribute constraintComp {$constraintComponent},
            attribute constraintID {$constraintId},
            attribute valueShapeID {$valueShapeId},  
            $filePath,
            $focusNode,
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            attribute valueCount {$count},
            $constraint[self::attribute()],
            $additionalAtts,
            (: $valueShape/*, :)   (: may depend on 'verbosity' :)
            $constraint[self::element()],
            $additionalElems
        }       
};

(:
declare function f:constructError_valueComparison($constraint as element(),
                                                  $quantifier as xs:string, 
                                                  $comparison as node(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*,
                                                  $contextInfo as map(xs:string, item()*))
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
:)
(:
declare function f:constructError_countComparison($constraint as element(),
                                                  $comparison as node(), 
                                                  $exprValue as item()*,
                                                  $additionalAtts as attribute()*,
                                                  $contextInfo as map(xs:string, item()*)) 
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
:)
(:
declare function f:constructGreen_valueShape($constraint as element(),
                                             $contextInfo as map(xs:string, item()*)) 
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
:)







