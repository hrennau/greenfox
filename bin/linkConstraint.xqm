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
 : Validates constraints referring to links. The link is either referenced (@rel)
 : or defined by attributes on the constraints element ('links'). Possible
 : constraints:
 : - linksResolvable 
 : - countContextNodes 
 : - countTargetResources
 : - countTargetDocs
 : - countTargetNodes
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
                             $contextItem as item(),
                             $filepath as xs:string,
                             $constraintElem as element(),
                             $context as map(xs:string, item()*),
                             $contextInfo as map(xs:string, item()*))
        as item()* {
        
    (: Link definition object :)
    let $ldo := $constraintElem/@rel/i:linkDefinitionObject(., $context)
    
    (: Link resolution objects :)
    let $lros := f:resolveLinksForValidation($contextItem, $filepath, $constraintElem, $context, $contextInfo)
    
    (: Write results :)
    return (
        i:validateLinkResolvable($lros, $ldo, $constraintElem, $contextInfo),
        i:validateLinkCounts($lros, $ldo, $constraintElem, $contextInfo)                                      
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
                             $contextItem as item(),
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
            if ($rel) then i:resolveRelationship($rel, 'lro', $constraintElem, $filepath, $context)
            else        
                let $linkContextExpr := $constraintElem/@contextXP
                let $linkExpr := $constraintElem/(@linkXP, @xpath)[1]                
                let $linkTargetExpr := $constraintElem/@targetXP
                let $recursive := $constraintElem/@recursive/xs:boolean(.)
                let $mediatype := ($constraintElem/@mediatype, 'xml'[$recursive])[1]  
                return 
                    link:resolveUriLinks($filepath, $contextItem, $linkContextExpr, $linkExpr, $linkTargetExpr, $mediatype, $recursive, $context)
    return $lros                    
};
