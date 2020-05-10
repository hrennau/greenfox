(:
 : -------------------------------------------------------------------------
 :
 : resourceRelationshipConstraints.xqm - functions checking resource relationship constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "foxpathUtil.xqm",
    "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : ===============================================================================
 :
 :     P e r f o r n    v a l i d a t i o n
 :
 : ===============================================================================
 :)

(:~
 : Validates link count related constraints (LinkCountMinCount, LinkCountMaxCount, LinkCountCount).
 : It is not checked if the links can be resolved - only their number is considered.
 :
 : @param exprValue expression value producing the links
 : @param cmp link count related constraint
 : @param valueShape the value shape containing the constraint
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateLinkCounts($ldo as map(*),
                                      $lros as map(*)*,
                                      $constraintElem as element(),
                                      $contextInfo as map(xs:string, item()*))
        as element()* {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $linkConstraints := $ldo?constraints    
    
    (: Cardinality: contextNodes :)
    let $countConstraintsContextNodes := (
        ($constraintElem/@countContextNodes, $linkConstraints/@countContextNodes)[1],
        ($constraintElem/@minCountContextNodes, $linkConstraints/@minCountContextNodes)[1],
        ($constraintElem/@maxCountContextNodes, $linkConstraints/@maxCountContextNodes)[1]
    )
    let $resultsContextNodes :=
        if (not($countConstraintsContextNodes)) then () else
        
        (: determine count :)
        let $valueCount := 
            let $contextNodes := ($lros?contextNode)/.
            (:
            let $_DEBUG := trace(count($contextNodes), '___COUNT_CONTEXT_NODES: ')
            let $_DEBUG := trace($countConstraintsContextNodes, '___CONSTRAINTS: ')
            :)
            return count($contextNodes)
            
        (: evaluate constraints :)
        for $countConstraint in $countConstraintsContextNodes
        let $cmp := $countConstraint/xs:integer(.)
        let $green :=
            typeswitch($countConstraint)
            case attribute(countContextNodes) return $valueCount eq $cmp
            case attribute(minCountContextNodes) return $valueCount ge $cmp
            case attribute(maxCountContextNodes) return $valueCount le $cmp
            default return error()
        let $colour := if ($green) then 'green' else 'red'        
        return  
            f:validationResult_linkCount($colour, $constraintElem, $countConstraint, $valueCount, (), $contextInfo, $resultOptions)
            
    (: Cardinality: target resources per context node :)            
    let $resultsTargetResources :=
        let $countConstraintsTargetResources := $constraintElem/(        
            @countTargetResources, @minCountTargetResources, @maxCountTargetResources
        )
        let $countConstraintsTargetResources := (
            ($constraintElem/@countTargetResources,    $linkConstraints/@countTargetResources)[1],
            ($constraintElem/@minCountTargetResources, $linkConstraints/@minCountTargetResources)[1],
            ($constraintElem/@maxCountTargetResources, $linkConstraints/@maxCountTargetResources)[1]
        )
        for $lro in $lros
        group by $sourceNode := $lro?contextNode/generate-id(.)
        let $targetResources := $lro?targetDoc
        
        (: determine count :)
        let $valueCount := (
            if (every $tr in $targetResources satisfies $tr instance of node()) then $targetResources/.
            else distinct-values(
                for $tr in $targetResources return if ($tr instance of xs:anyAtomicType) then $tr else $tr/base-uri(.)
            )
            ) => count()

        (: evaluate constraints :)
        for $countConstraint in $countConstraintsTargetResources
        let $cmp := $countConstraint/xs:integer(.)
        let $green :=
            typeswitch($countConstraint)
            case attribute(countTargetResources) return $valueCount eq $cmp
            case attribute(minCountTargetResources) return $valueCount ge $cmp
            case attribute(maxCountTargetResources) return $valueCount le $cmp
            default return error()
        let $colour := if ($green) then 'green' else 'red'        
        return  
            f:validationResult_linkCount($colour, $constraintElem, $countConstraint, $valueCount, $lro?contextNode, $contextInfo, $resultOptions)
        
    (: Cardinality: target nodes per context node :)            
    let $resultsTargetNodes :=
        let $countConstraintsTargetNodes := $constraintElem/(        
            @countTargetNodes, @minCountTargetNodes, @maxCountTargetNodes
        )
        let $countConstraintsTargetNodes := (
            ($constraintElem/@countTargetNodes,    $linkConstraints/@countTargetNodes)[1],
            ($constraintElem/@minCountTargetNodes, $linkConstraints/@minCountTargetNodes)[1],
            ($constraintElem/@maxCountTargetNodes, $linkConstraints/@maxCountTargetNodes)[1]
        )
        for $lro in $lros
        group by $sourceNode := $lro?contextNode/generate-id(.)
        
        (: determine count :)
        let $valueCount :=
            let $targetNodes := $lro?targetNodes/.       
            return count($targetNodes)

        (: evaluate constraints :)
        for $countConstraint in $countConstraintsTargetNodes
        let $cmp := $countConstraint/xs:integer(.)
        let $green :=
            typeswitch($countConstraint)
            case attribute(countTargetNodes) return $valueCount eq $cmp
            case attribute(minCountTargetNodes) return $valueCount ge $cmp
            case attribute(maxCountTargetNodes) return $valueCount le $cmp
            default return error()
        let $colour := if ($green) then 'green' else 'red'        
        return  
            f:validationResult_linkCount($colour, $constraintElem, $countConstraint, $valueCount, $lro?contextNode, $contextInfo, $resultOptions)
        
    return (
        $resultsContextNodes,
        $resultsTargetResources,
        $resultsTargetNodes
    )
        
};

(:~
 : ===============================================================================
 :
 :     W r i t e    v a l i d a t i o n    r e s u l t s
 :
 : ===============================================================================
 :)

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
                                              $constraintElem as element(),
                                              $constraint as attribute(),
                                              $valueCount as item()*,
                                              $contextNode as node()?,
                                              $contextInfo as map(xs:string, item()*),
                                              $options as map(*)?)
        as element() {
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(countContextNodes)       return map{'constraintComp': 'LinkContextNodesCount',    'atts': ('countContextNodes')}
        case attribute(minCountContextNodes)    return map{'constraintComp': 'LinkContextNodesMinCount', 'atts': ('minCountContextNodes')}
        case attribute(maxCountContextNodes)    return map{'constraintComp': 'LinkContextNodesMaxCount', 'atts': ('maxCountContextNodes')}
        case attribute(countTargetResources)    return map{'constraintComp': 'LinkTargetResourcesCount',    'atts': ('countTargetResources')}
        case attribute(minCountTargetResources) return map{'constraintComp': 'LinkTargetResourcesMinCount', 'atts': ('minCountTargetResources')}
        case attribute(maxCountTargetResources) return map{'constraintComp': 'LinkTargetResourcesMaxCount', 'atts': ('maxCountTargetResources')}
        case attribute(countTargetNodes)        return map{'constraintComp': 'LinkTargetNodesCount',        'atts': ('countTargetNodes')}
        case attribute(minCountTargetNodes)     return map{'constraintComp': 'LinkTargetNodesMinCount',     'atts': ('minCountTargetNodes')}
        case attribute(maxCountTargetNodes)     return map{'constraintComp': 'LinkTargetNodesMaxCount',     'atts': ('maxCountTargetNodes')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := 
        let $explicit := $constraintElem/@*[local-name(.) = $standardAttNames]
        return
            (: make sure the constraint attribute is included, even if it is a default constraint :)
            ($explicit, $constraint[not(. intersect $explicit)])
    let $valueCountAtt := attribute valueCount {$valueCount} 
    let $rel := $constraintElem/@rel
    
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintElemId := $constraintElem/@id
    let $constraintId := concat($constraintElemId, '-', $constraint/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}
    let $contextNodeDataPath := $contextNode/i:datapath(.)

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraint/local-name(.), ())
    let $elemName := 'gx:' || $colour
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            $filePath,
            $focusNode,
            $rel ! attribute rel {.},
            $contextNodeDataPath ! attribute contextNode {.},
            $standardAtts,
            $valueCountAtt            
        }       
};

