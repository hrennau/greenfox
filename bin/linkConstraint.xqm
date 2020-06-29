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
 : Validates constraints referring to links. The link is either referenced (@linkName)
 : or defined by attributes on the constraints element ('links'). Possible
 : constraints:
 : - resolvable 
 : - countContextNodes, minCountContextNodes, maxCountContextNodes 
 : - countTargetResources, minCountTargetResources, maxCountTargetResources
 : - countTargetDocs, minCountTargetDocs, maxCountTargetDocs
 : - countTargetNodes, minCountTargetNodes, maxCountTargetNodes
 :
 : @param contextFilePath the file path of the file containing the initial context item 
 : @param constraintElem element defining the constraints
 : @param contextItem the initial context item to be used in expressions
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
        
    (: The "context info" gives access to the context file path and the focus path :)        
    let $contextInfo := 
        let $focusPath := $contextItem[. instance of node()][not(. is $contextDoc)]/f:datapath(.)
        return
            map:merge((
                $contextFilePath ! map:entry('filePath', .),
                $contextDoc ! map:entry('doc', .),                
                $focusPath ! map:entry('nodePath', .)
        ))
    return
        f:resolveAndValidateLinks($contextItem, $constraintElem, $contextInfo, $context)
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
                             $contextItem as item(),
                             $constraintElem as element(),
                             $contextInfo as map(xs:string, item()*),
                             $context as map(xs:string, item()*))
        as item()* {
        
    (: Link definition object :)
    let $ldo := link:getLinkDefObject($constraintElem, $context)
    
    (: Link resolution objects :)
    let $lros := link:resolveLinkDef($ldo, 'lro', $contextInfo?filePath, $contextItem[. instance of node()], $context, ())
    
    (: Write validation results :)
    return (
        link:validateLinkResolvable($lros, $ldo, $constraintElem, $contextInfo),
        link:validateLinkCounts($lros, $ldo, $constraintElem, $contextInfo)                                      
    )
};
