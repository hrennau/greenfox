(:
 : -------------------------------------------------------------------------
 :
 : linkResolver.xqm - functions resolving links
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/link-resolver";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm",
    "log.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n s    r e s o l v i n g    l i n k s
 :
 : ============================================================================ :)

(:~
 : Resolves links specified in terms of a URI expression, an optional Link Context Expression
 : and an optional Link Target Expression. Returns for each link a link resolution object.
 : _TO_EDIT_
 : ... which is a map
 : providing the link value (as obtained from the expression), the link URI (obtained
 : by resolving against the base URI), the filepath of the link defining document
 : (often called the "context"), the parsed target document (if mediatype is XML or 
 : JSON and if the link could be resolved) and an optional error code. Absence/presence 
 : of an errorCode means successful/failed link resolution. If $recursive is true, 
 : links are resolved recursively. Recursive resolving means that the expression 
 : producing the link values is applied to the documents obtained by resolving the 
 : link.
 :
 : @param contextURI the file path of the resource currently investigated
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param linkContextExpr expression mapping the context node to link context nodes
 : @param linkExpr expression mapping a link context node to the link value items
 : @param mediatype the mediatype of link targets
 : @param recursive flag indicating if links are resolved recursively
 : @param context the processing context
 : @return link resolution objects, either containing the resolved target or information about 
 :   failure to resolve the link
 :)
declare function f:resolveLinks(
                             $contextURI as xs:string,
                             $contextNode as node()?,
                             $linkContextExpr as xs:string?,
                             $linkExpr as xs:string,
                             $linkTargetExpr as xs:string?,
                             $mediatype as xs:string?,
                             $recursive as xs:boolean?,
                             $context as map(xs:string, item()*))
        as map(xs:string, item()*)* {
    let $lros := f:resolveLinksRC($contextURI, $contextNode, 
                                  $linkContextExpr, $linkExpr, $linkTargetExpr, 
                                  $mediatype, $recursive, 
                                  $context, (), ())
    
    (: There may be duplicates to be removed, as recursive descents happen in parallel :)
(:    
    let $lrosDedup :=
        for $lrObject in $lrObjects
        group by $targetURI := $lrObject?targetURI
        return
            if (not($targetURI)) then $lrObject
            else $lrObject[1]
    return
        $lrObjectsDedup
 :)
    return $lros 
};

(:~
 : Recursive helper function of `resolveLinks`.
 :
 : @param contextURI the file path of the resource currently investigated
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param linkContextExpr expression mapping the context node to link context nodes
 : @param linkExpr expression mapping a link context node to the link value items
 : @param mediatype the mediatype of link targets
 : @param recursive flag indicating if links are resolved recursively
 : @param context the processing context
 : @return link resolution objects, either containing the resolved target or information about 
 :   failure to resolve the link
 :)
declare function f:resolveLinksRC(
                             $contextURI as xs:string,
                             $contextNode as node()?,
                             $linkContextExpr as xs:string?,
                             $linkExpr as xs:string,
                             $linkTargetExpr as xs:string?,
                             $mediatype as xs:string?,
                             $recursive as xs:boolean?,
                             $context as map(xs:string, item()*),
                             $pathsSofar as xs:string*,
                             $errorsSofar as xs:string*)
                             
        as map(xs:string, item()*)* {
        
    (: The mapping of the context node to Link Context Nodes is optional:
       the default link context is the context node itself. :)        
    let $linkContextNodes :=
        if (not($linkContextExpr)) then $contextNode
        else f:resolveLinkExpression($linkContextExpr, $contextNode, $context)
        
    for $linkContextNode in $linkContextNodes
    let $linkValues := f:resolveLinkExpression($linkExpr, $linkContextNode, $context)
    let $lros :=   
        for $linkValue in $linkValues
        let $baseUri := $contextURI
        let $targetURI := i:fox-resolve-uri($linkValue, $baseUri)
        where not($targetURI = ($pathsSofar, $errorsSofar))
        return
            let $_DEBUG := i:DEBUG($targetURI, 'links', 2, '_URI_TO_RESOLVE: ') return
            
            (: Error - link value cannot be resolved :)
            if (not($targetURI)) then
                map{'type': 'linkResolutionObject',
                    'contextURI': $contextURI,
                    'contextNode': $linkContextNode,
                    'linkValue': string($linkValue),                
                    'targetURI': '',
                    'targetExists': false(),
                    'errorCode': 'no_uri'}            
        
            (: Mediatype: json :)
            else if ($mediatype = 'json') then            
                if (not(i:fox-unparsed-text-available($targetURI, ()))) then
                    let $targetExists := i:fox-resource-exists($targetURI)
                    let $errorCode := if ($targetExists) then 'no_text' else 'no_resource'
                    return
                        map{'type': 'linkResolutionObject',
                            'contextURI': $contextURI,
                            'contextNode': $linkContextNode,                     
                            'linkValue': string($linkValue), 
                            'targetURI': $targetURI, 
                            'targetExists': $targetExists,
                            'errorCode': $errorCode}
                else
                    let $text := i:fox-unparsed-text($targetURI, ())
                    let $jdoc := try {json:parse($text)} catch * {()}
                    let $linkTargetNodes := f:getLinkTargetNodes($jdoc, $linkTargetExpr, $linkContextNode, $context)
                    return 
                        if (not($jdoc)) then 
                            map{'type': 'linkResolutionObject',
                                'contextURI': $contextURI,
                                'contextNode': $linkContextNode,                            
                                'linkValue': string($linkValue), 
                                'targetURI': $targetURI,
                                'targetExists': true(),
                                'errorCode': 'not_json'}
                        else 
                            map:merge((
                                map:entry('type', 'linkResolutionObject'),                                
                                map:entry('contextURI', $contextURI),
                                map:entry('contextNode', $linkContextNode),
                                map:entry('linkValue', string($linkValue)),
                                map:entry('targetURI', $targetURI),
                                map:entry('targetExists', true()),
                                map:entry('targetDoc', $jdoc),
                                $linkTargetExpr ! map:entry('targetNodes', $linkTargetNodes)))
            
            (: Mediatype: xml :)            
            else if ($mediatype = 'xml') then
                if (not(i:fox-doc-available($targetURI))) then 
                    let $_DEBUG := i:DEBUG($targetURI, 'links', 1, '_LINK_RESOLVING_XML#FAILURE: ') 
                    let $targetExists := i:fox-resource-exists($targetURI)
                    let $errorCode := if ($targetExists) then 'not_xml' else 'no_resource'                    
                    return
                        map{'type': 'linkResolutionObject',
                            'contextURI': $contextURI,
                            'contextNode': $linkContextNode,                    
                            'linkValue': string($linkValue),
                            'targetURI': $targetURI,
                            'targetExists': $targetExists,
                            'errorCode': $errorCode}
                else 
                    let $_DEBUG := i:DEBUG($targetURI, 'links', 1, '_LINK_RESOLVING_XML#SUCCESS: ') 
                    let $targetDoc := i:fox-doc($targetURI)
                    let $linkTargetNodes := f:getLinkTargetNodes($targetDoc, $linkTargetExpr, $linkContextNode, $context)  
                    return
                        map:merge((
                            map:entry('type', 'linkResolutionObject'),
                            map:entry('contextURI', $contextURI),
                            map:entry('contextNode', $linkContextNode),                    
                            map:entry('linkValue', string($linkValue)),
                            map:entry('targetURI', $targetURI), 
                            map:entry('targetExists', true()),
                            map:entry('targetDoc', $targetDoc),
                            $linkTargetExpr ! map:entry('targetNodes', $linkTargetNodes)
                        ))
            else
                if (i:fox-resource-exists($targetURI)) then
                    map{'type': 'linkResolutionObject',
                        'contextURI': $contextURI,
                        'contextNode': $linkContextNode,                    
                        'linkValue': string($linkValue),
                        'targetURI': $targetURI,
                        'targetExists': true()}
                else
                    map{'type': 'linkResolutionObject',
                        'contextURI': $contextURI,
                        'contextNode': $linkContextNode,                    
                        'linkValue': string($linkValue),
                        'targetURI': $targetURI,
                        'targetExists': false(),
                        'errorCode': 'no_resource'}
    
    let $lrosError := $lros[?errorCode][not(?targetURI = $errorsSofar)]
    let $lrosSuccess := $lros[not(?errorCode)][not(?targetURI = $pathsSofar)]    
    let $newErrors := $lrosError?targetURI    
    let $newPaths := $lrosSuccess?targetURI
    let $newPathsSofar := ($pathsSofar, $newPaths)
    let $newErrorsSofar := ($errorsSofar, $newErrors)
    return (
        $lrosError,   (: these are errors not yet observed :)
        $lrosSuccess,   (: these are targets not yet observed :)
        if (not($recursive)) then () else
            $lrosSuccess 
            ! f:resolveLinksRC(?targetURI, ?targetDoc, 
                               $linkContextExpr, $linkExpr, $linkTargetExpr, 
                               $mediatype, $recursive, 
                               $context, 
                               $newPathsSofar, $newErrorsSofar)            
    )
};

declare function f:getLinkTargetNodes($targetResource as node(), 
                                      $linkTargetExpr as xs:string?, 
                                      $linkContextItem as node(), 
                                      $context as map(xs:string, item()*))
        as node()* {
    if (not($linkTargetExpr)) then ()
    else 
        let $evaluationContextNext := map:put($context?_evaluationContext, QName('', 'linkContext'), $linkContextItem)
        return
            i:evaluateXPath($linkTargetExpr, $targetResource, $evaluationContextNext, true(), true())        
};        

(:~
 : Resolves the link expression in the context of an XDM node to a value.
 :
 : The expression is retrieved from the shape element, and the evaluation context
 : is retrieved from the processing context.
 :
 : @param doc document in the context of which the expression must be resolved
 : @param valueShape the value shape specifying the link constraints
 : @param context context for evaluations
 : @return the expression value
 :)
declare function f:resolveLinkExpression($expr as xs:string,
                                         $contextNode as node(),
                                         $context as map(xs:string, item()*))
        as item()* {
    let $exprLang := 'xpath'
    let $evaluationContext := $context?_evaluationContext    
    let $exprValue :=
        switch($exprLang)
        case 'xpath' return i:evaluateXPath($expr, $contextNode, $evaluationContext, true(), true())
        default return error(QName((), 'SCHEMA_ERROR'), "'Missing attribute - <links> element must have an 'xpath' attribute")
    return $exprValue        
};        
