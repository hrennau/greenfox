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
    "log.xqm",
    "resourceAccess.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkDefinition.xqm",
    "linkResolution.xqm",
    "linkValidation.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a Content Correspondence constraint.
 :
 : The $contextItem is either the current resource, or a focus node.
 :
 : @param contextFilePath the file path of the file containing the initial context item 
 : @param constraintElem the element declaring the constraint
 : @param contextItem the initial context item to be used in expressions
 : @param contextDoc the XML document containing the initial context item
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateConcord($filePath as xs:string,
                                   $constraintElem as element(), 
                                   $contextItem as item()?,                                 
                                   $contextDoc as document-node()?,
                                   $context as map(xs:string, item()*))
        as element()* {
    
    let $contextNode := $contextItem[. instance of node()]
    
    (: context info - a container for current file path and datapath of the focus node :)    
    let $contextInfo := 
        let $focusPath :=
            if ($contextItem instance of node() and not($contextItem is $contextDoc)) then
                $contextItem/i:datapath(.)
            else ()
        return  
            map:merge((
                $filePath ! map:entry('filePath', .),
                $focusPath ! map:entry('nodePath', .)
            ))

    return
        (: Exception - no context document :)
        if (not($contextDoc)) then
            f:validationResult_concord_exception($constraintElem, (),
                'Context resource could not be parsed', (), $contextInfo)
        else
        
    (: Link definition object, link resolution objects :)
    let $ldo := link:getLinkDefObject($constraintElem, $context)
    
    (: Resolve link definition (use 'xml' as default mediatype) :)
    let $lros := link:resolveLinkDef(
        $ldo, 'lro', $filePath, $contextItem[. instance of node()], $context, map{'mediatype': 'xml'})
    
    (: Check link constraints :)
    let $results_link := link:validateLinkConstraints($lros, $ldo, $constraintElem, $contextInfo) 
    
    (: Check correspondences :)    
    let $results_correspondence := 
    
        (: Repeat for each combination of link context node and link target document :)
        for $lro in $lros
        
        (: Check for link error :)
        return
            if ($lro?errorCode) then
                f:validationResult_concord_exception($constraintElem, $lro, (), (), $contextInfo)
            else
           
        (: Fetch target nodes :)
        let $targetNodes := 
            if (map:contains($lro, 'targetNodes')) then $lro?targetNodes
            else if (map:contains($lro, 'targetDoc')) then $lro?targetDoc
            else 
                let $msg :=
                    if ($lro?targetURI ! i:fox-resource-exists(.)) then 
                        'Correspondence target resource cannot be parsed'
                    else 'Correspondence target resource not found'
                return
                    f:validationResult_concord_exception($constraintElem, $lro, 
                        'Correspondence target resource not found', (), $contextInfo)                        
        return if ($targetNodes/self::gx:red) then $targetNodes else

        (: Fetch context item :)
        let $contextItem := $lro?contextItem
        
        (: Repeat for each constraint defining child of the constraint element :)
        for $valuePair in $constraintElem/gx:constraint
        return
            (: Check correspondence :)
            f:validateConcordValues($valuePair,
                                    $contextItem, 
                                    $targetNodes,
                                    $filePath, 
                                    $contextDoc,                   
                                    $context,                                    
                                    $contextInfo)
    return ($results_link, 
            $results_correspondence)
};

(:~
 : ===============================================================================
 :
 :     P e r f o r n    v a l i d a t i o n s
 :
 : ===============================================================================
 :)

(:~
 : Validates the constraints expressed by a `valuePair` element contained
 : by a Content Correspondence Constraint. These constraints are ...
 : - a correspondence constraint, defined by @corr, @sourceXP, @targetXP and further attributes
 : - count constraints, referring to the number of items returned by the source and
 :   target expression
 :
 : The validation is repeated for each link target node - thus effectively
 : every combination of link context node and link target node is checked.
 :
 : @param valuePair an element declaring a Correspondence Constraint on a 
 :   pair of content values
 : @param linkContextNode the link context node
 : @param linkTargetNodes the link target nodes
 : @param contextFilePath the file path of the context resource
 : @param contextDoc the document representation of the context resource
 : @param context the processing context
 : @param contextInfo informs about the focus document and focus node
 : @return validation results
 :)
declare function f:validateConcordValues($valuePair as element(),
                                         $linkContextItem as item(), 
                                         $linkTargetNodes as node()*,                                         
                                         $contextFilePath as xs:string, 
                                         $contextDoc as document-node()?,                                                   
                                         $context as map(*),                                         
                                         $contextInfo as map(xs:string, item()*))
        as element()* {
    let $contextNode := ($linkContextItem[. instance of node()], $contextDoc)[1]
    let $evaluationContext := $context?_evaluationContext
    
    (: Definition of the correspondence :)
    let $cmp := $valuePair/@corr
    let $quantifier := ($valuePair/@quant, 'all')[1]
    let $sourceExpr := $valuePair/@sourceXP
    let $targetExpr := $valuePair/@targetXP      
    let $flags := string($valuePair/@flags)
    let $useDatatype := $valuePair/@useDatatype/resolve-QName(., ..)        
    let $sourceExprLang := 'xpath'
    let $targetExprLang := 'xpath'    
    
    (: Count constraints, referring the values of source and target expression :)
    let $countSource := $valuePair/@countSource/xs:integer(.)
    let $minCountSource := $valuePair/@minCountSource/xs:integer(.)
    let $maxCountSource := $valuePair/@maxCountSource/xs:integer(.)    
    let $countTarget := $valuePair/@countTarget/xs:integer(.)
    let $minCountTarget := $valuePair/@minCountTarget/xs:integer(.)
    let $maxCountTarget := $valuePair/@maxCountTarget/xs:integer(.)
    
    (: Source expr value :)
    let $sourceItemsRaw :=
        i:evaluateXPath($sourceExpr, $contextNode, $evaluationContext, true(), true())    
    
    let $sourceItems :=
        if (empty($useDatatype)) then $sourceItemsRaw else 
        $sourceItemsRaw ! i:castAs(., $useDatatype, QName($i:URI_GX, 'gx:red'))
    
    (: Check the number of items of the source expression value :)
    let $results_sourceCount :=
        f:validateConcordContentCount($sourceItems, 'source', $valuePair, $contextInfo)
    
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
            f:validateConcordContentCount($targetItems, 'target', $valuePair, $contextInfo)
        
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
            f:validationResult_concord($colour, $violations, $cmp, $valuePair, $contextInfo)
        )                                             
    return ($results_sourceCount, $results)            
};    

(:~
 : Validates the count constraints expressed by a `valuePair` element contained
 : by a Content Correspondence Constraint. These constraints are ...
 : - source count constraints, referring to the number of items returned by the 
 :   source expresssion, defined by @countSource, @minCountSource, @maxCountSource
 : - target value count constraints, referring to the number of items returned
 :   by the target expression, defined by @countTarget, @minCountTarget, @maxCountTarget 
 :
 : @param items the items returned by an expression
 : @param exprRole the role of the expression - source or target expression
 : @valuePair the element declaring the count constraint
 : @param contextInfo informs about the focus document and focus node
 : @return validation results
 :)
declare function f:validateConcordContentCount($items as item()*,
                                               $exprRole as xs:string, (: source | target :)
                                               $valuePair as element(),
                                               $contextInfo as map(xs:string, item()*))
        as element()* {
        
    let $countConstraints := $valuePair/(
        if ($exprRole eq 'source') then (@countSource, @minCountSource, @maxCountSource)
        else if ($exprRole eq 'target') then (@countTarget, @minCountTarget, @maxCountTarget)
        else error()
        )
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
            f:validationResult_concord_counts($colour, $valuePair, $countConstraint, $valueCount, $contextInfo)

    return $results        
};

(:~
 : ===============================================================================
 :
 :     V a l i d a t i o n    r e s u l t s :   
 :         C o n t e n t    C o r r e s p o n d e n c e    c o n s t r a i n t
 :
 : ===============================================================================
 :)
 
(:~
 : Constructs a validation result obtained from the validation of a Content Correspondence
 : constraint.
 :
 : @param colour describes the success status - success, failure, warning
 : @param violations items violating the constraint
 : @param cmp operator of comparison
 : @param valuePair an element declaring a Correspondence Constraint on a 
 :   pair of content values
 : @contextInfo informs about the focus document and focus node
 :)
declare function f:validationResult_concord($colour as xs:string,
                                            $violations as item()*,
                                            $cmp as xs:string,
                                            $valuePair as element(),
                                            $contextInfo as map(xs:string, item()*))
        as element() {
    let $constraintId := $valuePair/@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $cmpAtt := $cmp ! attribute correspondence {.}
    let $useDatatypeAtt := $valuePair/@useDatatype ! attribute useDatatype {.}
    let $flagsAtt := $valuePair/@flags[string()] ! attribute flags {.}
    let $constraintComp := 'ContentCorrespondence-' || $cmp
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valuePair, $cmp, ())
        else i:getErrorMsg($valuePair, $cmp, ())
    let $elemName := concat('gx:', $colour)
    let $sourceExprLang := 'xpath'
    let $targetExprLang := 'xpath'    
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            $filePathAtt,
            $focusNodeAtt,
            $valuePair/@sourceXP ! attribute expr {.},
            attribute exprLang {$sourceExprLang},            
            $valuePair/@targetXP ! attribute targetExpr {.},
            attribute targetExprLang {$targetExprLang},
            $cmpAtt,
            $useDatatypeAtt,
            $flagsAtt,
            $violations ! <gx:value>{.}</gx:value>
        }
       
};

(:~
 : Creates a validation result for a ContentCorrespondenceCount related 
 : constraint (ContentCorrespondenceSourceCount, ...SourceMinCount, ...SourceMaxCount, 
 : ContentCorrespondenceTargetCount, ...TargetMinCount, ...TargetMaxCount).
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param valuePair an element declaring a Correspondence Constraint on a 
 :   pair of content values
 : @param constraint a constraint expressing attribute (e.g. @sourceMinCount)
 : @param valueCount the actual number of values 
 : @param contextInfo informs about the focus document and focus node
 : @return a validation result, red or green
 :)
declare function f:validationResult_concord_counts($colour as xs:string,
                                                   $valuePair as element(),
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
    let $standardAtts := $valuePair/@*[local-name(.) = $standardAttNames]
    let $valueCountAtt := attribute valueCount {$valueCount} 
    
    let $resourceShapeId := $valuePair/@resourceShapeID
    let $constraintElemId := $valuePair/@id
    let $constraintId := concat($constraintElemId, '-', $constraint/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valuePair, $constraint/local-name(.), ())
        else i:getErrorMsg($valuePair, $constraint/local-name(.), ())
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

(:~
 : Creates a validation result expressing an exceptional condition 
 : which prevents normal evaluation of a Content Correspondence 
 : constraint. Such an exceptional condition is, for example, a 
 : failure to resolve a link definition used to identify the target 
 : resource taking part in the correspondence checking.
 :
 : @param valuePair an element declaring a Correspondence Constraint on a 
 :   pair of content values
 : @param lro Link Resolution Object describing the attempt to resolve 
 :   a link description
 : @param exception an optional message string
 : @param addAtts additional attributes 
 : @param contextInfo informs about the focus document and focus node
 : @return a red validation result
 :)
declare function f:validationResult_concord_exception(
                                            $valuePair as element(),
                                            $lro as map(*)?,        
                                            $exception as xs:string?,                                                  
                                            $addAtts as attribute()*,
                                            $contextInfo as map(xs:string, item()*))
        as element() {
    let $constraintComp := 'ContentCorrespondence'        
    let $constraintId := $valuePair/@id
    let $filePathAtt := $contextInfo?filePath ! attribute filePath {.}
    let $focusNodeAtt := $contextInfo?nodePath ! attribute nodePath {.}
    let $contextItemInfo :=
        if (empty($lro)) then ()
        else
            let $contextItem := $lro?contextItem
            return
                if (not($contextItem instance of node())) then ()
                else attribute contextItem {i:datapath($contextItem)}
    let $targetInfo := $lro?targetURI ! attribute targetURI {.}    
    let $msg :=
        if ($exception) then $exception
        else if (exists($lro)) then
            let $errorCode := $lro?errorCode
            return
                if ($errorCode) then
                    switch($errorCode)
                    case 'no_resource' return 'Correspondence target resource not found'
                    case 'no_text' return 'Correspondence target resource not a text file'
                    case 'not_json' return 'Correspondence target resource not a valid JSON document'
                    case 'not_xml' return 'Correspondence target resource not a valid XML document'
                    case 'href_selection_not_nodes' return
                        'Link error - href expression does not select nodes'
                    case 'uri' return
                        'Target URI not a valid URI'
                    default return concat('Unexpected error code: ', $errorCode)
                else if ($lro?targetURI ! i:fox-resource-exists(.)) then 
                    'Correspondence target resource cannot be parsed'
                else 
                    'Correspondence target resource not found'
        
    return
        element {'gx:red'} {
            attribute exception {$msg},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            $contextItemInfo,
            $targetInfo,
            $addAtts,
            $filePathAtt,
            $focusNodeAtt
        }
       
};









