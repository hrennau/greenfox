(:
 : -------------------------------------------------------------------------
 :
 : linkConnector.xqm - implements the link connector
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/greenlink";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkUtil.xqm";

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "log.xqm",
   "uriUtil.xqm";

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
        let $evaluationContext := $context?_evaluationContext
        
        (: Extend evaluation context: $linkContext :)
        let $evaluationContextNext := 
        
            if (not($contextPoint instance of node())) then $evaluationContext else
                map:put($context?_evaluationContext, QName('', 'linkContext'), $contextPoint)

        return
            i:evaluateFoxpath($ldo?foxpath, $contextURI, $evaluationContextNext, true())
            
    else if ($ldo?uriTemplate) then
        let $items := f:resolveUriTemplate($ldo, $contextPoint, $context)
        return $items
        
    else if (exists($ldo?mirror)) then
        let $items := f:resolveMirror($ldo, $contextPoint, $context)
        return $items
    
    else ()
};

(:~
 : Applies a URI template connector to a link context item. 
 :  
 : @param ldo Link Definition object
 : @param contextPoint link context node
 : @param context the processing context
 : @return a sequence of URIss
 :)
declare function f:resolveUriTemplate($ldo as map(*),
                                      $contextPoint as item(),
                                      $context as map(xs:string, item()*))
        as xs:string* {
    (: let $_DEBUG :=  ($contextPoint, '_CONTEXT_POINT: '):)
    
    let $uriTemplate := $ldo?uriTemplate        
    let $templateVarMap :=
        let $templateVars := $ldo?templateVars
        return
            map:merge(
                for $name in $templateVars ! map:keys(.)
                let $templateVarElem := $templateVars($name) 
                let $value := $templateVarElem/@exprXP/f:resolveLinkExpression(., $contextPoint, $context) ! string(.)
                return map:entry($name, $value)
            )
    let $templateResolution := f:resolveUriTemplateRC($uriTemplate, $templateVarMap)
    return $templateResolution
};

(:~
 : Recursive helper function of 'resolveUriTemplate'.
 :
 : @param uriTemplate a URI template
 : @param templateVarMap a map associating template variable names with values
 : @return the resolve URI template, a sequence of one or more strings
 :)
declare function f:resolveUriTemplateRC($uriTemplate as xs:string, 
                                        $templateVarMap as map(*))
        as xs:string* {
    let $sep := codepoints-to-string(30000)        
    let $partsConcat := replace($uriTemplate, '^(.*?)?\{(.*?)\}(.*)', '$1'||$sep||'$2'||$sep||'$3')
    return
        if ($partsConcat eq $uriTemplate) then $uriTemplate else
        
    
    let $parts := tokenize($partsConcat, $sep)
    let $prefix := $parts[1]
    let $varName := $parts[2]
    let $postfix := $parts[3]
            
    let $varValue := $templateVarMap($varName)
    let $left :=
        if (empty($varValue)) then $prefix else
            $varValue ! concat($prefix, .)
    let $right := 
        if (not($postfix)) then ()
        else f:resolveUriTemplateRC($postfix, $templateVarMap)
    return
        if (empty($postfix)) then $left else
            for $item1 in $left, $item2 in $right
            return concat($item1, $item2)
};

(:~
 : Applies a Mirror link to a context URI. 
 :  
 : @param ldo Link Definition object
 : @param context the processing context
 : @return a sequence of URIss
 :)
declare function f:resolveMirror($ldo as map(*),
                                 $contextPoint as item(),
                                 $context as map(xs:string, item()*))
        as xs:string* {
    let $uri := $context?_targetInfo?contextURI        
    let $reflector1 := $ldo?mirror?reflector1        
    let $reflector2 := $ldo?mirror?reflector2
    let $reflectedReplaceSubstring := $ldo?mirror?reflectedReplaceSubstring
    let $reflectedReplaceWith := $ldo?mirror?reflectedReplaceWith
    let $reflected := i:getImage($uri, $reflector1, $reflector2, $reflectedReplaceSubstring, $reflectedReplaceWith)
    return $reflected
};        
