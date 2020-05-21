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
    "resourceRelationships.xqm",
    "resourceRelationshipConstraints.xqm",
    "log.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/link-resolver" at
    "linkResolver.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n s    v a l i d a t i n g    c o n t e n t    c o r r e s p o n d e n c e
 :
 : ============================================================================ :)

(:~
 : Validates a Content Correspondence constraint.
 :
 : The $contextItem is either the current resource, or a focus node.
 :
 : @param contextFilePath the file path of the file containing the initial context item 
 : @param shape the value shape declaring the constraints
 : @param contextItem the initial context item to be used in expressions
 : @param contextDoc the XML document containing the initial context item
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateConcord($contextFilePath as xs:string,
                                   $constraintElem as element(), 
                                   $contextItem as item()?,                                 
                                   $contextDoc as document-node()?,
                                   $context as map(xs:string, item()*))
        as element()* {
    
    (: context info - a container for current file path and datapath of the focus node :)    
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
        
    let $rel := $constraintElem/@rel
    
    (: Resolve: relationship name -> Link Resolution Objects :)
    let $ldo := i:linkDefinitionObject($rel, $context)
    let $lros := i:resolveRelationship($rel, 'lro', $constraintElem, $contextFilePath, $context)
    let $results_count := i:validateLinkCounts($lros, $ldo, $constraintElem, $contextInfo)
    
    let $evaluationContext := $context?_evaluationContext    
    let $results := 
        (: Loop over content elements - each one provides constraints ... :)
        for $content in $constraintElem/gx:content
        let $cmp := $content/@corr
        let $quantifier := ($content/@quant, 'all')[1]
        let $sourceExpr := $content/@sourceXP
        let $targetExpr := $content/@targetXP      
        
        (: Repeat for each instance of the relationship (mapping of a source node to a target resource);
           note that an instance may contain multiple target nodes
         :)
        for $lro in $lros
        let $contextNode := $lro?contextNode
        let $targetNodes := $lro?targetNodes        
        let $result :=
            f:validateConcordValues($contextNode, $targetNodes,
                                    $sourceExpr, $targetExpr,
                                    $cmp, $quantifier,
                                    $contextFilePath, $contextDoc,                   
                                    $context,  
                                    $content, 
                                    $contextInfo)
        return $result                                              
    return ($results, $results_count)
};

(:~
 : ===============================================================================
 :
 :     P e r f o r n    v a l i d a t i o n s
 :
 : ===============================================================================
 :)

(:~
 : Validates the constraints expressed by a `content` element contained
 : by a Content Correspondence Constraint.
 :
 : @param linkContextNode the link context node
 : @param linkTargetNodes the link target nodes
 : @param sourceExpr expression evaluated in the context of the link context node
 : @param targetExpr expression evaluated in the context of each link target node
 : @param cmp specifies a comparison condition
 : @return
 :)
declare function f:validateConcordValues($linkContextNode as node(), $linkTargetNodes as node()*,                                         
                                         $sourceExpr as xs:string, $targetExpr as xs:string,
                                         $cmp as xs:string, $quantifier as xs:string,
                                         $contextFilePath as xs:string, $contextDoc as document-node()?,                                                   
                                         $context as map(*),
                                         $contentElem as element(),
                                         $contextInfo as map(xs:string, item()*))
        as element()* {
    let $sourceExprLang := 'xpath'
    let $targetExprLang := 'xpath'
    let $flags := string($contentElem/@flags)
    let $useDatatype := $contentElem/@useDatatype/resolve-QName(., ..)
    
    let $countSource := $contentElem/@countSource/xs:integer(.)
    let $minCountSource := $contentElem/@minCountSource/xs:integer(.)
    let $maxCountSource := $contentElem/@maxCountSource/xs:integer(.)
    
    let $countTarget := $contentElem/@countTarget/xs:integer(.)
    let $minCountTarget := $contentElem/@minCountTarget/xs:integer(.)
    let $maxCountTarget := $contentElem/@maxCountTarget/xs:integer(.)
    
    let $evaluationContext := $context?_evaluationContext   
    
    (: Source expr value :)
    let $sourceItemsRaw := 
        i:evaluateXPath($sourceExpr, $linkContextNode, $evaluationContext, true(), true())    
    
    let $sourceItems :=
        if (empty($useDatatype)) then $sourceItemsRaw else 
        $sourceItemsRaw ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
    
    (: Evaluation source item count constraint :)
    let $results_sourceCount := 
        f:validateConcordContentCount($sourceItems, 'source', $contentElem, $contextInfo)
    
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
        switch($cmp)
        case 'eq' return function($op1, $op2) {$op1 = $op2}        
        case 'ne' return function($op1, $op2) {$op1 != $op2}        
        case 'lt' return function($op1, $op2) {$op1 < $op2}
        case 'le' return function($op1, $op2) {$op1 <= $op2}
        case 'gt' return function($op1, $op2) {$op1 > $op2}
        case 'ge' return function($op1, $op2) {$op1 >= $op2}
        case 'in' return function($op1, $op2) {$op1 = $op2}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown comparison operator: ', $cmp))
    
    let $results :=
        for $linkTargetNode in $linkTargetNodes
        let $targetItems := $getTargetItems($linkTargetNode)
        
        (: Evaluation target item count constraint :)
        let $results_targetCount :=
            f:validateConcordContentCount($targetItems, 'target', $contentElem, $contextInfo)
        
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
        return (
            $results_targetCount,
            f:validationResult_concordValues($colour, $sourceExpr, $sourceExprLang, $targetExpr, $targetExprLang,
                                             $violations, $cmp, $useDatatype, $flags,
                                             $contentElem, $contextInfo, ())
        )                                             
    return ($results, $results_sourceCount)            
};    

declare function f:validateConcordContentCount($items as item()*,
                                               $itemKind as xs:string, (: source | target :)
                                               $contentElem as element(),
                                               $contextInfo as map(xs:string, item()*))
        as element()* {
        
    let $countConstraints := $contentElem/(
        if ($itemKind eq 'source') then (@countSource, @minCountSource, @maxCountSource)
        else if ($itemKind eq 'target') then (@countTarget, @minCountTarget, @maxCountTarget)
        else error()
        )
    let $results :=
        if (empty($countConstraints)) then () else
        
        let $valueCount := count($items)
            
        (: evaluate constraints :)
        for $countConstraint in $countConstraints
        let $cmp := $countConstraint/xs:integer(.)
        let $green :=
            typeswitch($countConstraint)
            case attribute(countSource)    | attribute(countTarget)    return $valueCount eq $cmp
            case attribute(minCountSource) | attribute(minCountTarget) return $valueCount ge $cmp
            case attribute(maxCountSource) | attribute(maxCountTarget) return $valueCount le $cmp
            default return error()
        let $colour := if ($green) then 'green' else 'red'        
        return  
            f:validationResult_concordContentCount($colour, $contentElem, $countConstraint, $valueCount, $contextInfo)

    return $results        
};

(:~
 : ===============================================================================
 :
 :     W r i t e    v a l i d a t i o n    r e s u l t s
 :
 : ===============================================================================
 :)

declare function f:validationResult_concordValues($colour as xs:string,
                                                  $sourceExpr,
                                                  $sourceExprLang,
                                                  $targetExpr, 
                                                  $targetExprLang,
                                                  $violations as item()*,
                                                  $cmp as xs:string,
                                                  $useDatatype as xs:QName?,
                                                  $flags as xs:string?,
                                                  $constraintElem as element(),
                                                  $contextInfo as map(xs:string, item()*),
                                                  $options as map(*)?)
        as element() {
    let $constraintId := $constraintElem/@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $cmpAtt := $cmp ! attribute correspondence {.}
    let $useDatatypeAtt := $useDatatype ! attribute useDatatype {.}
    let $flagsAtt := $flags[string()] ! attribute flags {.}
    let $constraintComp := 'ContentCorrespondence-' || $cmp
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $cmp, ())
        else i:getErrorMsg($constraintElem, $cmp, ())
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
            $cmpAtt,
            $useDatatypeAtt,
            $flagsAtt,
            $violations ! <gx:value>{.}</gx:value>
        }
       
};

(:~
 : Creates a validation result for a ContentCorrespondenceCount related constraint (ContentCorrespondenceSourceCount,
 : ...SourceMinCount, ...SourceMaxCount, ContentCorrespondenceTargetCount, ...TargetMinCount, ...TargetMaxCount).
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param contentElemt a content element, part of a ContentCorrespondence constraint
 : @param constraint a constraint expressing attribute (e.g. @sourceMinCount)
 : @param valueCount the actual number of values 
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validationResult_concordContentCount($colour as xs:string,
                                                        $contentElem as element(),
                                                        $constraint as attribute(),
                                                        $valueCount as item()*,
                                                        $contextInfo as map(xs:string, item()*))
        as element() {
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(countSource)    return map{'constraintComp': 'ContentCorrespondenceSourceValueCount',    'atts': ('countSource')}
        case attribute(minCountSource) return map{'constraintComp': 'ContentCorrespondenceSourceValueMinCount', 'atts': ('minCountSource')}        
        case attribute(maxCountSource) return map{'constraintComp': 'ContentCorrespondenceSourceValueMaxCount', 'atts': ('maxCountSource')}        
        case attribute(countTarget)    return map{'constraintComp': 'ContentCorrespondenceTargetValueCount',    'atts': ('countTarget')}
        case attribute(minCountTarget) return map{'constraintComp': 'ContentCorrespondenceTargetValueMinCount', 'atts': ('minCountTarget')}        
        case attribute(maxCountTarget) return map{'constraintComp': 'ContentCorrespondenceTargetValueMaxCount', 'atts': ('maxCountTarget')}        
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $contentElem/@*[local-name(.) = $standardAttNames]
    let $valueCountAtt := attribute valueCount {$valueCount} 
    
    let $resourceShapeId := $contentElem/@resourceShapeID
    let $constraintElemId := $contentElem/@id
    let $constraintId := concat($constraintElemId, '-', $constraint/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($contentElem, $constraint/local-name(.), ())
        else i:getErrorMsg($contentElem, $constraint/local-name(.), ())
    let $elemName := 'gx:' || $colour
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            $filePath,
            $focusNode,
            $standardAtts,
            $valueCountAtt            
        }       
};








