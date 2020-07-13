(:
 : -------------------------------------------------------------------------
 :
 : linkConnector.xqm - implements the link connector
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/greenlink";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkUtil.xqm";

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm",
    "log.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Applies the connector of a link to a link context item. Returns nodes, atoms or a map 
 : with an error code.
 :
 : @param ldo Link Definition Object
 : @param contextURI URI of the link context resource
 : @param contextPoint the link context point, which may be a node or the context resource URI
 : @param context processing context
 : @return items, which may be target URIs and/or target nodes
 :)
declare function f:applyLinkConnector($ldo as map(*),
                                      $contextURI as xs:string,
                                      $contextPoint as item(),                             
                                      $context as map(xs:string, item()*))
        as item()* {
    (:
    if ($ldo?linkXP) then
        f:resolveLinkExpression($ldo?linkXP, $contextItem, $context) ! string(.)
     :)
     
    (: Connector: uri expression 
       ========================= :) 
    if ($ldo?uriXP) then
        f:resolveLinkExpression($ldo?uriXP, $contextPoint, $context) ! string(.)
        
    (: Connector: href expression 
       ========================== :)
    else if ($ldo?hrefXP) then
        let $items := f:resolveLinkExpression($ldo?hrefXP, $contextPoint, $context)
        return
            if (not(every $item in $items satisfies $item instance of node())) then
                map{'type': 'connectorError', 
                    'errorCode': 'href_selection_not_nodes'}
            else $items ! string(.)
            
    (: Connector: foxpath expression 
       ============================= :)
    else if ($ldo?foxpath) then
        let $_DEBUG := trace($ldo, '_LDO: ')
        let $evaluationContext := $context?_evaluationContext
        return
            (: _TO_DO_ CLARIFY - should the Foxpath context be the contextItem or the contextURI?
               Temptative decision: the contextURI, as the context is typically not useful
               for a Foxpath expression; note that the contextItem is accessible via
               variable $linkContext :)
            i:evaluateFoxpath($ldo?foxpath, $contextURI, $evaluationContext, true())
            (: i:evaluateFoxpath($ldo?foxpath, $contextPoint, $evaluationContext, true()) :)
    else ()
};
