(:
 : -------------------------------------------------------------------------
 :
 : linkConstraint.xqm - validates against a link constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm",
    "log.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/link-resolver" at
    "linkResolver.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n s    v a l i d a t i n g    l i n k s
 :
 : ============================================================================ :)

(:~
 : Validates constraints referring to links.
 :
 : @param shape the value shape declaring the constraints
 : @param contextItem the initial context item to be used in expressions
 : @param contextFilePath the file path of the file containing the initial context item
 : @param contextDoc the XML document containing the initial context item
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateLinks($contextFilePath as xs:string,
                                 $constraintElem as element(), 
                                 $contextItem as item()?,                                 
                                 $contextDoc as document-node()?,
                                 $context as map(xs:string, item()*))
        as element()* {
    (: The focus path identifies the location of the initial context item;
       empty sequence if the initial context item is the root of the 
       context document :)
    let $focusPath :=
        if ($contextItem instance of node() and not($contextItem is $contextDoc)) then
            $contextItem/f:datapath(.)
        else ()
        
    (: The "context info" gives access to the context file path and the focus path :)        
    let $contextInfo := map:merge((
        $contextFilePath ! map:entry('filePath', .),
        $focusPath ! map:entry('nodePath', .)
    ))

    return
        (: Error: document could not be parsed :)        
        if (empty($contextItem)) then 
            f:validationResult_links('red', $constraintElem, (), (), 
                                     attribute reason {'Context document could not be parsed'}, 
                                     (), $contextInfo, ())
        else
            f:resolveAndValidateLinks($contextItem, $contextFilePath, $constraintElem, $context, $contextInfo)
};

(:~
 : Resolves and validates links.
 :
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param valueShape the value shape containing the constraint
 : @param context the processing context
 : @param contextInfo information about the resource context 
 : @return validation results, red and/or green
 :)
declare function f:resolveAndValidateLinks(
                             $contextNode as node(),
                             $filepath as xs:string,
                             $constraintElem as element(),
                             $context as map(xs:string, item()*),
                             $contextInfo as map(xs:string, item()*))
        as item()* {
    (: Link definition object :)
    let $ldo := $constraintElem/@rel/i:linkDefinitionObject(., $context)
    
    (: Link resolution objects :)
    let $lros := f:resolveLinksForValidation($contextNode, $filepath, $constraintElem, $context, $contextInfo)
    
    (: Write results :)
    return (
        i:validateLinkResolvable($lros, $ldo, $constraintElem, $contextInfo)
        (:i:validationResult_links($colour, $ldo, $valueShape, $failures, $successes, $contextInfo, ()):)
        ,
        (: Evaluate count constraints :)
        let $targetURIs := $lros?targetURI                            
        return f:validateLinkCount($targetURIs, $constraintElem, $contextInfo)    
    )
};

(:~
 : Resolves links defined by or referenced by a link constraint element.
 :
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param valueShape the value shape containing the constraint
 : @param context the processing context
 : @param contextInfo information about the resource context 
 : @return validation results, red and/or green
 :)
declare function f:resolveLinksForValidation(
                             $contextNode as node(),
                             $filepath as xs:string,
                             $constraintElem as element(),
                             $context as map(xs:string, item()*),
                             $contextInfo as map(xs:string, item()*))
        as map(*)* {
    (: Link definition object :)
    let $ldo := $constraintElem/@rel/i:linkDefinitionObject(., $context)
    
    (: Link resolution objects :)
    let $lros :=        
        let $rel := $constraintElem/@rel
        return
            if ($rel) then i:resolveRelationship($rel, 'lro', $filepath, $context)
            else        
                let $expr := $constraintElem/(@linkXP, @xpath)[1]    
                let $recursive := $constraintElem/@recursive/xs:boolean(.)
                let $mediatype := ($constraintElem/@mediatype, 'xml'[$recursive])[1]  
                return 
                    link:resolveLinks($filepath, $contextNode, (), $expr, (), $mediatype, $recursive, $context)
    return $lros                    
};

(:~
 : Validates a link count related constraint (LinkCountMinCount, LinkCountMaxCount, LinkCountCount).
 : It is not checked if the links can be resolved - only their number is considered.
 :
 : @param exprValue expression value producing the links
 : @param cmp link count related constraint
 : @param valueShape the value shape containing the constraint
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateLinkCount($exprValue as item()*,
                                     $valueShape as element(),
                                     $contextInfo as map(xs:string, item()*))
        as element()? {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $valueCount := count($exprValue)
    for $cmp in $valueShape/(@count, @minCount, @maxCount)
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown count comparison operator: ', $cmp))
    return        
        if ($cmpTrue($valueCount, $cmp)) then  
            f:validationResult_linkCount('green', $valueShape, $cmp, $valueCount, 
                                         $resultAdditionalAtts, (), $contextInfo, $resultOptions)
        else 
            let $values := $exprValue ! xs:string(.) ! <xs:value>{.}</xs:value>
            return
                f:validationResult_linkCount('red', $valueShape, $cmp, $exprValue, 
                                             $resultAdditionalAtts, $values, $contextInfo, $resultOptions)
};

(: ============================================================================
 :
 :     f u n c t i o n s    c r e a t i n g    v a l i d a t i o n    r e s u l t s
 :
 : ============================================================================ :)

(:~
 : Creates a validation result for a LinkResolvable constraint.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param exprValue expression value producing the links
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_links($colour as xs:string,
                                          $valueShape as element(),
                                          $errors as map(*)*,
                                          $linkMaps as map(*)*,
                                          $additionalAtts as attribute()*,
                                          $additionalElems as element()*,
                                          $contextInfo as map(xs:string, item()*),
                                          $options as map(*)?)
        as element() {
    let $recursive := $valueShape/@recursive/xs:boolean(.)
    let $values :=  
        if (empty($errors)) then () 
        else if ($recursive) then 
            $errors ! <gx:value where="{?filepath}">{?linkValue}</gx:value>
        else 
            $errors ! <gx:value>{?linkValue}</gx:value>
        
    let $exprAtt := $valueShape/@xpath        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^link', '') ! lower-case(.)    
    let $constraintConfig := 
        map{'constraintComp': 'LinkResolvableConstraint', 'atts': ('mediatype')}
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valueShape/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($linkMaps)} 
    
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-linkResolvable')
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, 'link', ())
        else i:getErrorMsg($valueShape, 'link', ())
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
            $values,
            $additionalElems
        }       
};

(:~
 : Creates a validation result for a LinkCount related constraint (LinkMinCount,
 : LinkMaxCount, LinkCount.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param valueShape the shape declaring the constraint
 : @param exprValue expression value producing the links
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_linkCount($colour as xs:string,
                                              $valueShape as element(),
                                              $constraint as node()*,
                                              $exprValue as item()*,
                                              $additionalAtts as attribute()*,
                                              $additionalElems as element()*,
                                              $contextInfo as map(xs:string, item()*),
                                              $options as map(*)?)
        as element() {
    let $exprAtt := $valueShape/@xpath        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^link', '') ! lower-case(.)    
    let $constraint1 := $constraint[1]
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(count) return map{'constraintComp': 'LinkCount', 'atts': ('count')}
        case attribute(minCount) return map{'constraintComp': 'LinkMinCount', 'atts': ('minCount')}
        case attribute(maxCount) return map{'constraintComp': 'LinkMaxCount', 'atts': ('maxCount')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valueShape/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-', $constraint1/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePathe {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, $constraint/local-name(.), ())
        else i:getErrorMsg($valueShape, $constraint/local-name(.), ())
    let $elemName := 'gx:' || $colour
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
