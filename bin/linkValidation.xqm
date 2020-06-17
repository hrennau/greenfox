(:
 : -------------------------------------------------------------------------
 :
 : linkValidation.xqm - functions checking the results of link resolution
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/greenlink";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "foxpathUtil.xqm",
    "greenfoxUtil.xqm";

import module namespace vr="http://www.greenfox.org/ns/xquery-functions/validation-result" at
    "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : ===============================================================================
 :
 :     P e r f o r n    v a l i d a t i o n
 :
 : ===============================================================================
 :)

(:~
 : Validates the result of resolving a link definition. The constraints may be declared
 : in the link defining element or in an element which references the link definition. 
 : A constraint declared in a link referencing element overrides a constraint of the
 : same kind declared in the link definition.
 :
 : @param lros link resolution objects
 : @param ldo link definition object
 : @param constraintElem constraint element, defining constraints which may override
 :   any constraints specified by the link definition element
  : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateLinkConstraints($lros as map(*)*,
                                           $ldo as map(*)?,                                      
                                           $constraintElem as element()?,
                                           $contextInfo as map(xs:string, item()*))
        as element()* {
    f:validateLinkResolvable($lros, $ldo, $constraintElem, $contextInfo),
    f:validateLinkCounts($lros, $ldo, $constraintElem, $contextInfo)
};

(:~
 : Validates the constraint that links must be resolvable. A resolvable link is a link
 : involving a URI which can be resolved to a resource.
 :
 : @param lros link resolution objects
 : @param ldo link definition object
 : @param constraintElem constraint element, defining constraints which may override
 :   any constraints specified by the link definition element
  : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateLinkResolvable($lros as map(*)*,
                                          $ldo as map(*)?,                                      
                                          $constraintElem as element()?,
                                          $contextInfo as map(xs:string, item()*))
        as element()* {
    if (empty(($ldo, $constraintElem))) then () else
    
    let $linkConstraints := $ldo?constraints
    return    
        if (not((($constraintElem, $linkConstraints)/(@resolvable))[1] eq 'true')) then ()   
        else
    
    (: Link Resolution Objects are grouped by context node :)
    for $lro in $lros
    group by $sourceNode := $lro?contextNode/generate-id(.)
    let $lro1 := $lro[1]
    let $contextItem := $lro1?contextItem  
    return
        vr:validationResult_linksResolvable($ldo, $constraintElem, $contextItem, $lro1, $contextInfo, ())
};        

(:~
 : Validates link count related constraints. These are:
 :
 : @countContextNodes -       LinkContextNodesCount
 : @minCountContextNodes -    LinkContextNodesMinCount
 : @maxCountContextNodes -    LinkContextNodesMaxCount
 :
 : @countTargetResources -    LinkTargetResourcesCount
 : @minCountTargetResources - LinkTargetResourcesMinCount
 : @maxCountTargetResources - LinkTargetResourcesMaxCount
 :
 : @countTargetDocs -         LinkTargetDocsCount
 : @minCountTargetDocs -      LinkTargetDocsMinCount
 : @maxCountTargetDocs -      LinkTargetDocsMaxCount
 :
 : @countTargetNodes -        LinkTargetNodesCount
 : @minCountTargetNodes -     LinkTargetNodesMinCount
 : @maxCountTargetNodes -     LinkTargetNodesMaxCount
 :
 : It is not checked if the links can be resolved - only their number is considered.
 :
 : @param lros link resolution objects
 : @param ldo link definition object
 : @param constraintElem constraint element, defining constraints which may override
 :   any constraints specified by the link definition element
  : @param contextInfo information about the resource context
 : @return validation results, red or green
 :)
declare function f:validateLinkCounts($lros as map(*)*,
                                      $ldo as map(*)?,                                      
                                      $constraintElem as element()?,
                                      $contextInfo as map(xs:string, item()*))
        as element()* {
    if (empty(($ldo, $constraintElem))) then () else
    
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $linkConstraints := $ldo?constraints    
    
    (: Cardinality: contextNodes 
       ------------------------- :)
    let $countConstraintsContextNodes := (
        ($constraintElem/@countContextNodes, $linkConstraints/@countContextNodes)[1],
        ($constraintElem/@minCountContextNodes, $linkConstraints/@minCountContextNodes)[1],
        ($constraintElem/@maxCountContextNodes, $linkConstraints/@maxCountContextNodes)[1]
    )
    let $resultsContextNodes :=
        if (not($countConstraintsContextNodes)) then () else
        
        (: let $_DEBUG := trace($lros, '___LROS: ') :)
        (: determine count :)
        let $valueCount := 
            let $contextNodes := ($lros?contextNode)/.
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
            vr:validationResult_linkCount($ldo, $constraintElem, $countConstraint, $lros, 
                $colour, $valueCount, (), $contextInfo, $resultOptions)
            
    (: Cardinality: target resources per context node 
       ---------------------------------------------- :)            
    let $resultsTargetResources :=
        let $countConstraintsTargetResources := $constraintElem/(        
            @countTargetResources, @minCountTargetResources, @maxCountTargetResources
        )
        let $countConstraintsTargetResources := (
            ($constraintElem/@countTargetResources,    $linkConstraints/@countTargetResources)[1],
            ($constraintElem/@minCountTargetResources, $linkConstraints/@minCountTargetResources)[1],
            ($constraintElem/@maxCountTargetResources, $linkConstraints/@maxCountTargetResources)[1]
        )
        for $lro allowing empty in $lros
        group by $sourceNode := $lro?contextNode/generate-id(.)
        let $targetResources := ($lro[?targetExists]?targetURI) => distinct-values()
        let $lro1 := $lro[1]
        
        (: determine count :)
        let $valueCount := count($targetResources)

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
            vr:validationResult_linkCount($ldo, $constraintElem, $countConstraint, $lros, 
                $colour, $valueCount, $lro1?contextNode, $contextInfo, $resultOptions)
        
    (: Cardinality: target docs per context node 
       ----------------------------------------- :)            
    let $resultsTargetDocs :=
        let $countConstraintsTargetDocs := $constraintElem/(        
            @countTargetDocs, @minCountTargetDocs, @maxCountTargetDocs
        )
        let $countConstraintsTargetDocs := (
            ($constraintElem/@countTargetDocs,    $linkConstraints/@countTargetDocs)[1],
            ($constraintElem/@minCountTargetDocs, $linkConstraints/@minCountTargetDocs)[1],
            ($constraintElem/@maxCountTargetDocs, $linkConstraints/@maxCountTargetDocs)[1]
        )
        for $lro allowing empty in $lros
        group by $sourceNode := $lro?contextNode/generate-id(.)
        let $targetDocs := ($lro?targetDoc)/.
        let $lro1 := $lro[1]
        
        (: determine count :)
        let $valueCount := count($targetDocs)

        (: evaluate constraints :)
        for $countConstraint in $countConstraintsTargetDocs
        let $cmp := $countConstraint/xs:integer(.)
        let $green :=
            typeswitch($countConstraint)
            case attribute(countTargetDocs) return $valueCount eq $cmp
            case attribute(minCountTargetDocs) return $valueCount ge $cmp
            case attribute(maxCountTargetDocs) return $valueCount le $cmp
            default return error()
        let $colour := if ($green) then 'green' else 'red'    
        return  
            vr:validationResult_linkCount($ldo, $constraintElem, $countConstraint, $lros, 
                $colour, $valueCount, $lro1?contextNode, $contextInfo, $resultOptions)
        
    (: Cardinality: target nodes per context node 
       ------------------------------------------ :)            
    let $resultsTargetNodes :=
                
        let $countConstraintsTargetNodes := $constraintElem/(        
            @countTargetNodes, @minCountTargetNodes, @maxCountTargetNodes
        )
        let $countConstraintsTargetNodes := (
            ($constraintElem/@countTargetNodes,    $linkConstraints/@countTargetNodes)[1],
            ($constraintElem/@minCountTargetNodes, $linkConstraints/@minCountTargetNodes)[1],
            ($constraintElem/@maxCountTargetNodes, $linkConstraints/@maxCountTargetNodes)[1]
        )
        for $lro allowing empty in $lros
        group by $sourceNode := $lro?contextNode/generate-id(.)
        let $targetNodes := ($lro?targetNodes)/.
        let $lro1 := $lro[1]
        where $lro1?errorCode or $lro1 ! map:contains(., 'targetNodes')
        return
            (: determine count :)
            let $valueCount := count($targetNodes)

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
                vr:validationResult_linkCount($ldo, $constraintElem, $countConstraint, $lros, 
                    $colour, $valueCount, $lro1?contextNode, $contextInfo, $resultOptions)
        
    return (
        $resultsContextNodes,
        $resultsTargetResources,
        $resultsTargetDocs,
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

(:
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
        case attribute(countTargetDocs)         return map{'constraintComp': 'LinkTargetDocsCount',         'atts': ('countTargetDocs')}
        case attribute(minCountTargetDocs)      return map{'constraintComp': 'LinkTargetDocsMinCount',      'atts': ('minCountTargetDocs')}
        case attribute(maxCountTargetDocs)      return map{'constraintComp': 'LinkTargetDocsMaxCount',      'atts': ('maxCountTargetDocs')}
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
            $contextNodeDataPath ! attribute contextNodeDataPath {.},
            $standardAtts,
            $valueCountAtt            
        }       
};
:)
