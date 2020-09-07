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
  : @param context the processing context
 : @return a validation result, red or green
 :)
declare function f:validateLinkConstraints($lros as map(*)*,
                                           $ldo as map(*)?,                                      
                                           $constraintElem as element()?,
                                           $context as map(xs:string, item()*))
        as element()* {
    f:validateLinkResolvable($lros, $ldo, $constraintElem, $context),
    f:validateLinkCounts($lros, $ldo, $constraintElem, $context)
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
                                          $context as map(xs:string, item()*))
        as element()* {
    if (empty(($ldo, $constraintElem))) then () else
    
    let $linkConstraints := $ldo?constraints
    return    
        if (not((($constraintElem, $linkConstraints)/(@resolvable))[1] eq 'true')) then ()   
        else
    
    (: Link Resolution Objects are grouped by context item :)
    for $lro in $lros
    let $contextItem := $lro?contextItem
    let $contextPoint :=   typeswitch($contextItem) 
        case $n as node() return $n/generate-id(.) default return $contextItem
    group by $contextPoint
    let $contextItem := $lro[1]?contextItem  
    return
        vr:validationResult_linkResolvable($ldo, $lro, $constraintElem, $contextItem, $context, ())
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
 : @countAllTargetResources -    LinkAllTargetResourcesCount
 : @minCountAllTargetResources - LinkAllTargetResourcesMinCount
 : @maxCountAllTargetResources - LinkAllTargetResourcesMaxCount
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
 : @param lros link resolution objects, obtained by applying the link definition to a single context resource
 : @param ldo link definition object
 : @param constraintElem constraint element, defining constraints which may override
 :   any constraints specified by the link definition element
  : @param contextInfo information about the resource context
 : @return validation results, red or green
 :)
declare function f:validateLinkCounts($lros as map(*)*,
                                      $ldo as map(*)?,                                      
                                      $constraintElem as element()?,
                                      $context as map(xs:string, item()*))
        as element()* {
    if (empty(($ldo, $constraintElem))) then () else
    
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    (: let $_DEBUG := trace( $lros?contextItem ! (if (. instance of node()) then generate-id(.) else .) , '_CONTEXT_ITEMS: '):)
    let $linkConstraints := $ldo?constraints    
    let $constraintAtts := ($linkConstraints, $constraintElem)/@*
    let $constraintMap :=
        map:merge((
            let $constraints := $constraintAtts[matches(name(), '^(minCount|maxCount|count)ContextNodes$')]
            return
                if (empty($constraints)) then () else
                let $valueCount :=
                    let $contextItems := $lros?contextItem
                    let $nodes := $contextItems[. instance of node()]/.
                    let $atoms := $contextItems[not(. instance of node())]
                    return count($nodes) + count($atoms)
                return 
                    map{'contextNodes': map{'actCount': $valueCount, 'constraints': $constraints}},
            let $constraints := $constraintAtts[matches(name(), '^(minCount|maxCount|count)TargetResources$')]
            return
                if (empty($constraints)) then () else
                let $valueCount := $lros[?targetExists]?targetURI => distinct-values() => count()
                return 
                    map{'targetResources': map{'actCount': $valueCount, 'constraints': $constraints}},
            let $constraints := $constraintAtts[matches(name(), '^(minCount|maxCount|count)TargetDocs$')]
            return
                if (empty($constraints)) then () else
                let $valueCount := $lros?targetDoc/. => count()
                return 
                    map{'targetDocs': map{'actCount': $valueCount, 'constraints': $constraints}},
            let $constraints := $constraintAtts[matches(name(), '^(minCount|maxCount|count)TargetNodes$')]
            return
                if (empty($constraints)) then () else
                let $valueCount := $lros?targetNodes/. => count()
                return 
                    map{'targetNodes': map{'actCount': $valueCount, 'constraints': $constraints}},
            let $constraints := $constraintAtts[matches(name(), '^(minCount|maxCount|count)TargetResourcesPerContextPoint$')]
            return
                if (empty($constraints)) then () else
                let $valueCounts :=
                    for $lro allowing empty in $lros        
                    let $contextItem := $lro?contextItem
                    let $contextPoint:= ($contextItem[. instance of node()]/generate-id(.), $contextItem)[1]                    
                    group by $contextPoint
                    let $targetResources := ($lro[?targetExists]?targetURI) => distinct-values()
                    return count($targetResources)
                return
                    map{'targetResourcesPerContextPoint': map{'actCount': $valueCounts, 'constraints': $constraints}},
            let $constraints := $constraintAtts[matches(name(), '^(minCount|maxCount|count)TargetDocsPerContextPoint$')]
            return
                if (empty($constraints)) then () else
                let $valueCounts :=
                    for $lro allowing empty in $lros        
                    let $contextItem := $lro?contextItem
                    let $contextPoint:= ($contextItem[. instance of node()]/generate-id(.), $contextItem)[1] 
                    group by $contextPoint
                    let $targetDocs := $lro?targetDoc/.
                    return count($targetDocs)
                return
                    map{'targetDocsPerContextPoint': map{'actCount': $valueCounts, 'constraints': $constraints}},
            let $constraints := $constraintAtts[matches(name(), '^(minCount|maxCount|count)TargetNodesPerContextPoint$')]
            return
                if (empty($constraints)) then () else
                let $valueCounts :=
                    for $lro allowing empty in $lros        
                    let $contextItem := $lro?contextItem
                    let $contextPoint:= ($contextItem[. instance of node()]/generate-id(.), $contextItem)[1]                    
                    group by $contextPoint
                    let $targetNodes := $lro?targetNodes/.
                    return count($targetNodes)
                return
                    map{'targetNodesPerContextPoint': map{'actCount': $valueCounts, 'constraints': $constraints}}
        ))
        (:  let $_DEBUG := trace($constraintMap, '___CONSTRAINT_MAP: '):)
        let $fn_write_results := function($constraintObject) {
            if (empty($constraintObject)) then () else
            
            let $vcounts := $constraintObject?actCount
            for $countConstraint in $constraintObject?constraints
            let $cstValue := $countConstraint/xs:integer(.)
            let $cstName := $countConstraint/name()
            let $green :=
                if (starts-with($cstName, 'count')) then every $v in $vcounts satisfies $v eq $cstValue
                else if (starts-with($cstName, 'minCount')) then every $v in $vcounts satisfies $v ge $cstValue
                else if (starts-with($cstName, 'maxCount')) then every $v in $vcounts satisfies $v le $cstValue
                else error()
            let $colour := if ($green) then 'green' else 'red'        
            return  
                vr:validationResult_linkCount($colour, $ldo, $lros, $constraintElem, $countConstraint, 
                    $vcounts, (), $resultOptions, $context)            
        }
        
        let $results := (
            $constraintMap?contextNodes ! $fn_write_results(.),
            $constraintMap?targetResources ! $fn_write_results(.),
            $constraintMap?targetDocs ! $fn_write_results(.),
            $constraintMap?targetNodes ! $fn_write_results(.),
            $constraintMap?targetResourcesPerContextPoint ! $fn_write_results(.),
            $constraintMap?targetDocsPerContextPoint ! $fn_write_results(.),
            $constraintMap?targetNodesPerContextPoint ! $fn_write_results(.)
        ) 
        return $results
};

(:~
 : Returns all constraint attributes found in an element.
 :
 : @param constraintElem an element possibly declaring link constraints
 : @return all attributees on $constraintElem declaring link constraints
 :)
declare function f:getLinkConstraintAtts($constraintElem as element())
        as attribute()* {
    $constraintElem/@*[matches(name(), 
        '^(count|minCount|maxCount)' ||
        '(ContextNodes|TargetResources|TargetDocs|TargetDocs)' ||
        '(PerContextPoint)?$', 'x')]        
};
