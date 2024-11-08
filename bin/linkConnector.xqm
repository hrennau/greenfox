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
   "uriUtil0.xqm";

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
        
    (: Connector: uri expression 
       ========================= :) 
    if ($ldo?uriXP) then
        f:resolveLinkExpressionXP($ldo?uriXP, $contextPoint, $context) ! string(.)
        
    (: Connector: href expression 
       ========================== :)
    else if ($ldo?hrefXP) then
        let $items := f:resolveLinkExpressionXP($ldo?hrefXP, $contextPoint, $context)
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
            i:newEvaluationContext_linkContextItem($contextPoint, $context)
        return
            i:evaluateFoxpath($ldo?foxpath, $contextURI, $evaluationContextNext, true())
            
    (: Connector: URI 
       ============== :)
    else if ($ldo?uri) then    
        let $baseUri := $context?_targetInfo?contextURI || '/'
        let $items := i:existentResourceUri($ldo?uri, $baseUri, ())
        return $items
        
    (: Connector: URI template 
       ======================= :)
    else if ($ldo?uriTemplate) then
        let $items := f:resolveUriTemplate($ldo, $contextURI, $contextPoint, $context)
        return $items
        
    (: Connector: mirror 
       ================= :)
    else if (exists($ldo?mirror)) then
        let $items := f:resolveMirror($ldo, $contextURI, $context)
        return $items
    
    else ()
};

(:~
 : Applies a URI template connector to a link context item. 
 :  
 : @param ldo Link Definition Object
 : @param contextPoint link context node
 : @param context the processing context
 : @return a sequence of URIss
 :)
declare function f:resolveUriTemplate($ldo as map(*),
                                      $contextURI as xs:string,
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
                let $value := $templateVarElem/(
                    if (@valueXP) then 
                        @valueXP/f:resolveLinkExpressionXP(., $contextPoint, $context) ! string(.)
                    else if (@valueFOX) then
                        @valueFOX/f:resolveLinkExpressionFOX(., $contextURI, $context) ! string(.)
                    else @value/string())
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
        if (not($postfix)) then $left else
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
                                 $contextURI as item(),
                                 $context as map(xs:string, item()*))
        as xs:string* {
    let $uri := $context?_targetInfo?contextURI        
    
    let $reflector1 :=
        let $raw := $ldo?mirror?reflector1URI
        return if ($raw) then $raw else

        (: Reflector 1 is resolved in the context of the link context resource :)
        let $fox := $ldo?mirror?reflector1FOX 
        return
            if (not($fox)) then error(QName((), 'INVALID_SCHEMA'), 'Mirror link without reflector1URI or reflector1FOX')
            else f:resolveReflectorExpr($fox, $contextURI, $context)
                        
    let $reflector2 := 
        let $raw := $ldo?mirror?reflector2URI
        return if ($raw) then $raw else
        
        (: Reflector 2 is resolved in the context of reflector 1 :)
        let $fox := $ldo?mirror?reflector2FOX 
        return
            if (not($fox)) then error(QName((), 'INVALID_SCHEMA'), 'Mirror link without reflector2URI or reflector2FOX')
            else f:resolveReflectorExpr($fox, $reflector1, $context)
                        
    let $reflectedReplaceSubstring := $ldo?mirror?reflectedReplaceSubstring
    let $reflectedReplaceWith := $ldo?mirror?reflectedReplaceWith
    let $reflected := i:getImage($uri, $reflector1, $reflector2, $reflectedReplaceSubstring, $reflectedReplaceWith)
    return $reflected
};  

(:~
 : Resolves a Foxpath expression providing a reflector URI.
 :
 : @param expr the expression returning the reflector URI
 : @param contextURI the context URI, in the context of which the expression must be resolved
 : @param context the processing context
 : @return the reflector URI
 :)
declare function f:resolveReflectorExpr($expr as xs:string, 
                                        $contextURI as xs:string,
                                        $context as map(xs:string, item()*))
        as xs:string?    {
    let $evaluationContext := $context?_evaluationContext
    return
        i:evaluateFoxpath($expr, $contextURI, $evaluationContext, true())
};        

