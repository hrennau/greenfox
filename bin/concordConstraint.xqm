(:
 : -------------------------------------------------------------------------
 :
 : concordConstraint.xqm - validates against a Content Correspondence constraint
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
    "linkResolver.xqm",
    "log.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/link-resolver" at
    "linkResolver2.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n s    v a l i d a t i n g    c o n t e n t    c o r r e s p o n d e n c e
 :
 : ============================================================================ :)

(:~
 : Validates a Content Correspondence constraint.
 :
 : @param contextFilePath the file path of the file containing the initial context item 
 : @param shape the value shape declaring the constraints
 : @param contextItem the initial context item to be used in expressions
 : @param contextDoc the XML document containing the initial context item
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateConcord($contextFilePath as xs:string,
                                   $shape as element(), 
                                   $contextItem as item()?,                                 
                                   $contextDoc as document-node()?,
                                   $context as map(xs:string, item()*))
        as element()* {
        
    let $contextInfo := 
        let $focusPath :=
            if ($contextItem instance of node() and not($contextItem is $contextDoc)) then
                $contextItem/i:datapath(.)
            else ()
        return  
            map:merge((
                $contextFilePath ! map:entry('filePath', .),
                $focusPath ! map:entry('nodePath', .)
            ))
        
    let $rel := $shape/@rel
    
    (: Resolve relationship to a sequence of relObjects :)
    let $relObjects := trace(i:resolveRelationship($rel, 'relobject', $contextFilePath, $context) , '_REL_OBJECTS: ')
    
    let $evaluationContext := $context?_evaluationContext    
    let $results := 
        (: Loop over constraints ... :)
        for $constraint in $shape/gx:content
        let $corr := $constraint/@corr
        let $quantifier := ($constraint/@quant, 'all')[1]
        let $sourceExpr := $constraint/@sourceXP
        let $targetExpr := $constraint/@targetXP      
        
        (: Repeat for each instance of the relationship (mapping of a source node to a target resource) :)
        for $relObject in $relObjects
        let $sourceNode := $relObject?sourceNode
        let $targetNodes := $relObject?targetNodes        
        let $result :=
            f:validateExpressionValue_cmpExpr($sourceExpr, $sourceNode,
                                              $targetExpr, $targetNodes,
                                              $corr, $quantifier,
                                              $contextFilePath, $contextDoc,                   
                                              $context,  
                                              $constraint, 
                                              $contextInfo)
        let $_DEBUG := trace($sourceNode,  '___SOURCE_NODE: ')                                              
        let $_DEBUG := trace($targetNodes, '___TARGET_NODES: ')
        let $_DEBUG := trace($result, '___RESULT: ')
        return $result                                              
    return $results
};

declare function f:validateExpressionValue_cmpExpr($sourceExpr as xs:string,
                                                   $sourceContextNode as node(),
                                                   $targetExpr as xs:string,
                                                   $targetContextNodes as node()*,
                                                   $corr as xs:string,
                                                   $quantifier as xs:string,
                                                   $contextFilePath as xs:string,
                                                   $contextDoc as document-node()?,                                                   
                                                   $context as map(*),
                                                   $constraintElem as element(),
                                                   $contextInfo as map(xs:string, item()*))
        as element()* {
    let $sourceExprLang := 'xpath'
    let $targetExprLang := 'xpath'
    let $flags := string($constraintElem/@flags)
    let $useDatatype := $constraintElem/@useDatatype/resolve-QName(., ..)
        
    let $evaluationContext := $context?_evaluationContext   
    let $sourceItemsRaw := i:evaluateXPath($sourceExpr, $sourceContextNode, $evaluationContext, true(), true())
    
    (: Expr value augmented (if useDatatype specified :)
    let $sourceItems := 
        if (empty($useDatatype)) then $sourceItemsRaw else 
            $sourceItemsRaw ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
        
    (: Target value generator function :)
    let $getTargetItems := function($ctxtItem) {
        let $items := 
            if ($targetExprLang eq 'foxpath') then 
                i:evaluateFoxpath($targetExpr, $ctxtItem, $evaluationContext, true())
            else 
                i:evaluateXPath($targetExpr, $ctxtItem, $evaluationContext, true(), true())
        return
            if (empty($useDatatype)) then $items 
            else $items ! i:castAs(., $useDatatype, ()) 
    }
    
    (: Comparison function :)
    let $cmpTrue :=
        switch($corr)
        case 'eq' return function($op1, $op2) {$op1 = $op2}        
        case 'ne' return function($op1, $op2) {$op1 != $op2}        
        case 'lt' return function($op1, $op2) {$op1 < $op2}
        case 'le' return function($op1, $op2) {$op1 <= $op2}
        case 'gt' return function($op1, $op2) {$op1 > $op2}
        case 'ge' return function($op1, $op2) {$op1 >= $op2}
        case 'in' return function($op1, $op2) {$op1 = $op2}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $corr))
    
    let $results :=
        for $targetContextNode in $targetContextNodes
        let $targetItems := $getTargetItems($targetContextNode)
        let $violations :=
            if ($quantifier eq 'all') then
                for $sourceItem at $pos in $sourceItems
                where exists($targetItems[not($cmpTrue(., $sourceItem)) or $sourceItem instance of element(gx:red)])
                return $sourceItemsRaw[$pos]
            else if ($quantifier eq 'some') then                
                for $sourceItem at $pos in $sourceItems
                where every $v in $targetItems satisfies (not($cmpTrue($v, $sourceItem)) or $sourceItem instance of element(gx:red))
                return $sourceItemsRaw[$pos]
            else error()    
        let $colour := if (exists($violations)) then 'red' else 'green'                
        return
            f:validationResult_expression($colour, $sourceExpr, $sourceExprLang, $targetExpr, $targetExprLang,
                                          $violations, $corr, $useDatatype, $flags,
                                          $constraintElem, $contextInfo, ())
    return $results            
};    

declare function f:validationResult_expression($colour as xs:string,
                                               $sourceExpr,
                                               $sourceExprLang,
                                               $targetExpr, 
                                               $targetExprLang,
                                               $violations as item()*,
                                               $corr as xs:string,
                                               $useDatatype as xs:QName?,
                                               $flags as xs:string?,
                                               $constraintElem as element(),
                                               $contextInfo as map(xs:string, item()*),
                                               $options as map(*)?)
        as element() {
    let $constraintId := $constraintElem/@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $corrAtt := $corr ! attribute correspondence {.}
    let $useDatatypeAtt := $useDatatype ! attribute useDatatype {.}
    let $flagsAtt := $flags[string()] ! attribute flags {.}
    let $constraintComp := 'ContentCorrespondence-' || $corr
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $corr, ())
        else i:getErrorMsg($constraintElem, $corr, ())
    let $elemName := concat('gx:', $colour)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            $filePathAtt,
            $focusNodeAtt,
            attribute expr {$sourceExpr},
            attribute exprLang {$sourceExprLang},            
            attribute targetExpr {$targetExpr},
            attribute targetExprLang {$targetExprLang},
            $corrAtt,
            $useDatatypeAtt,
            $flagsAtt,
            $violations ! <gx:value>{.}</gx:value>
        }
       
};


