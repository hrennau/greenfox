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

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkDefinition.xqm",
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
 : @param contextURI the file path of the file containing the initial context item 
 : @param contextDoc the XML document containing the initial context item
 : @param contextItem the initial context item to be used in expressions
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateLinks($contextURI as xs:string,
                                 $contextDoc as document-node()?,
                                 $contextItem as item()?,
                                 $constraintElem as element(),
                                 $context as map(xs:string, item()*))
        as element()* {
        
    (: context info - a container for current file path, current document and datapath of the focus node :)        
    let $contextInfo := 
        let $focusPath := $contextItem[. instance of node()][not(. is $contextDoc)]/f:datapath(.)
        return
            map:merge((
                $contextURI ! map:entry('filePath', .),
                $contextDoc ! map:entry('doc', .),                
                $focusPath ! map:entry('nodePath', .)
        ))
    return
        f:resolveAndValidateLinks($constraintElem, $contextItem, $contextInfo, $context)
};

(:~
 : Resolves and validates links.
 :
 : @param constraintElem the element declaring the constraint 
 : @param contextItem the initial context item to be used in expressions 
 : @param contextInfo information about the resource context
 : @param context the processing context 
 : @return validation results, red and/or green
 :)
declare function f:resolveAndValidateLinks(
                             $constraintElem as element(),
                             $contextItem as item(),                             
                             $contextInfo as map(xs:string, item()*),
                             $context as map(xs:string, item()*))
        as item()* {
        
    (: Link Definition object :)
    let $ldo := link:getLinkDefObject($constraintElem, $context)
    let $_DEBUG := trace($ldo, '___LDO: ')
    
    (: Link Resolution objects :)
    let $lros := link:resolveLinkDef($ldo, 'lro', $contextInfo?filePath, $contextItem[. instance of node()], $context, ())
    let $_DEBUG := trace(i:DEBUG_LROS($lros), '_LROS: ')
    
    (: Write validation results :)
    return (
        link:validateLinkResolvable($lros, $ldo, $constraintElem, $context),
        link:validateLinkCounts($lros, $ldo, $constraintElem, $context)                                      
    )
};
