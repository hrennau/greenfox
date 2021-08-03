(:
 : -------------------------------------------------------------------------
 :
 : linkConstraint.xqm - validates the results of link resolution against constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "log.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm",
   "linkResolution.xqm",
   "linkValidation.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n s    v a l i d a t i n g    l i n k s
 :
 : ============================================================================ :)

(:~
 : Validates LinkResolvable constraints and supplementary constraints referring to
 : link-related cardinalities. The link definition is either referenced (@linkName)
 : or provided by attributes on the element declaring the constraints (<links>). 
 : Possible constraints (attribute names):
 : - resolvable 
 : - countContextNodes, minCountContextNodes, maxCountContextNodes 
 : - countTargetResources, minCountTargetResources, maxCountTargetResources
 : - countTargetDocs, minCountTargetDocs, maxCountTargetDocs
 : - countTargetNodes, minCountTargetNodes, maxCountTargetNodes
 :
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateLinks($constraintElem as element(),
                                 $context as map(xs:string, item()*))
        as element()* {
    f:resolveAndValidateLinks($constraintElem, $context)
};

(:~
 : Resolves and validates links.
 :
 : @param constraintElem the element declaring the constraint 
 : @param context the processing context 
 : @return validation results, red and/or green
 :)
declare function f:resolveAndValidateLinks(
                             $constraintElem as element(),
                             $context as map(xs:string, item()*))
        as item()* {
    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    let $useContextNode := ($contextNode, $contextDoc)[1]
    return
        
    (: Link Definition object :)
    let $ldo := link:getLinkDefObject($constraintElem, $context)
    (: let $_DEBUG := trace($ldo, '___LDO: ') :)
    
    (: Link Resolution objects :)
    let $lros := link:resolveLinkDef($ldo, 'lro', $contextURI, $useContextNode, $context, ())
    (: let $_DEBUG := trace(i:DEBUG_LROS($lros), '_LROS: ') :)
    
    (: Write validation results :)
    return (
        link:validateLinkResolvable($lros, $ldo, $constraintElem, $context),
        link:validateLinkCounts($lros, $ldo, $constraintElem, $context)                                      
    )
};
