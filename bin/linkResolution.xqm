(:
 : -------------------------------------------------------------------------
 :
 : linkResolver.xqm - functions resolving links
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/greenlink";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkConnector.xqm",
   "linkDefinition.xqm",
   "linkUtil.xqm";

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "log.xqm",
   "uriUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Resolves a Link Definition Object to a sequence of Link Resolution Objects.
 : These LROs are the objects obtained by applying the LDO to a single context
 : resource or context node.
 : 
 : @param linkDef link definition represented by Link Definition name, Link 
 :   Definition Object or an element containing a Link Definition
 : @param resultFormat determines the result format; lro: Link Resolution Objects;
 :       uri: URI references; doc: target documents
 : @param contextURI the URI of the context resource
 : @param contextNode an optional context node
 : @param context processing context
 : @param options processing options; option 'mediatype' specifies
 :   a mediatype, to be added to the Link Definition
 : @return a sequence of Link Resolution Objects, or selected data retrieved
 :   from these
 :)
declare function f:resolveLinkDef($linkDef as item(),
                                  $resultFormat as xs:string?, (: lro | uri | doc :)
                                  $contextURI as xs:string,
                                  $contextNode as node()?,                              
                                  $context as map(xs:string, item()*),
                                  $options as map(*)?)
        as item()* {
    let $ldo := link:getLinkDefObject($linkDef, $context)     
    
    (: Determine context node, if not provided, yet required :)
    let $contextNode :=
        if ($contextNode) then $contextNode
        else if (not($ldo?requiresContextNode)) then ()
        else
            let $doc := $context?_reqDocs?doc
            return
                if (not($doc)) then  
                    error((), concat('Invalid call - Link Definition "', $ldo?name, '" requires context node.'))
                else $doc
    
    (: Result format 'doc' implies a structured target mediatype, which defaults to 'xml'. :)
    let $ldoAugmented :=
        if ($ldo?mediatype) then $ldo
        else
            let $mediatype := 
                if ($options?mediatype) then $options?mediatype
                else if ($resultFormat eq 'doc') then 'xml'                
                (: else if ($ldo?targetXP) then 'xml' :) (: obsolete - see f:parseLinkDefinition() :)
                else ()
            return
                if (not($mediatype)) then $ldo
                else
                    map:put($ldo, 'mediatype', $mediatype)
        
    (: Determine Link Resolution Objects :)
    let $lros := f:resolveLinkDefRC($ldoAugmented, $contextURI, $contextNode, $context, (), ())
    
    (: Determine result to be delivered :)
    return 
        switch($resultFormat)
        case 'lro' return $lros
        case 'uri' return $lros?targetURI
        case 'doc' return $lros?targetDoc
        default return error()
};

(:~
 : Recursive helper function of `resolveLinkDef`.
 :)
declare function f:resolveLinkDefRC(
                              $ldo as map(*),
                              $contextURI as xs:string,
                              $contextNode as node()?,                              
                              $context as map(xs:string, item()*),
                              $urisSofar as xs:string*,
                              $nodesSofar as xs:string*)
                             
        as map(xs:string, item()*)* {
        
    let $contextExpr := $ldo?contextXP
    let $mediatype := $ldo?mediatype
    
    (: Link Context items
       ================== 
       A Link Context expression is optional; the default link context is 
       the context node or context URI, dependent on whether the link 
       definition requires a context node :)
    
    let $linkContextItems :=     
        if (not($contextExpr)) then 
            if ($ldo?requiresContextNode) then ($contextNode, $contextURI)[1]
            else $contextURI
        else if (not($contextNode)) then error((), 
            concat('Link context expression requires a context node; expression: ', 
                   $contextExpr))                       
        else link:resolveLinkExpression($contextExpr, $contextNode, $context)

    (: Apply connector to each Link Context item
       ========================================= :)
    for $linkContextItem in $linkContextItems
    let $connectorValue := link:applyLinkConnector($ldo, $contextURI, $linkContextItem, $context)
    return
        (: Result: Connector error 
           ======================= :)
        if ($connectorValue[. instance of map(*)]?type eq 'connectorError') then
            map{'type': 'linkResolutionObject',
                'contextURI': $contextURI,
                'contextItem': $linkContextItem,
                'targetExists': false(),
                'errorCode': $connectorValue?errorCode}        
        else
        
    let $hrefs := $connectorValue[. instance of xs:anyAtomicType]
    let $connectorNodes := $connectorValue[. instance of node()]
    
    (: Link Resolution Objects for connector output: atomic link items 
       =============================================================== :)
    let $lrosAtomicItems :=   
        for $href in $hrefs
        let $baseURI := $contextURI
        let $targetURI := i:resolveUri($href, $baseURI)
        
        (: Ignore URIs already obtained 
           ---------------------------- :)
        where not($targetURI = ($urisSofar))
        
        return
            (: Result: not a valid URI
               ======================= :)
            if (not($targetURI)) then
                map{'type': 'linkResolutionObject',
                    'contextURI': $contextURI,
                    'contextItem': $linkContextItem,
                    'href': string($href),                
                    'targetExists': false(),
                    'errorCode': 'no_uri'}            
        
            (: Mediatype: json :)
            else if ($mediatype = 'json') then            
                if (not(i:fox-unparsed-text-available($targetURI, ()))) then
                
                    (: Result: resource not found
                       ========================== :)                
                    if (not(i:fox-resource-exists($targetURI))) then
                        map{'type': 'linkResolutionObject',
                            'contextURI': $contextURI,
                            'contextItem': $linkContextItem,                     
                            'href': string($href), 
                            'targetURI': $targetURI, 
                            'targetExists': false(),
                            'errorCode': 'no_resource'}
                            
                    (: Result: not a text resource
                       =========================== :)               
                    else
                        map{'type': 'linkResolutionObject',
                            'contextURI': $contextURI,
                            'contextItem': $linkContextItem,                     
                            'href': string($href), 
                            'targetURI': $targetURI, 
                            'targetExists': true(),
                            'errorCode': 'no_text'}
                else
                    let $text := i:fox-unparsed-text($targetURI, ())
                    let $targetDoc := try {json:parse($text)} catch * {()}
                    let $targetNodes := $targetDoc ! f:getLinkTargetNodes(., $ldo?targetXP, $linkContextItem, $context)
                    return 
                        if (not($targetDoc)) then
                        
                            (: Result: not a JSON document
                               =========================== :)                        
                            map{'type': 'linkResolutionObject',
                                'contextURI': $contextURI,
                                'contextItem': $linkContextItem,                            
                                'href': string($href), 
                                'targetURI': $targetURI,
                                'targetExists': true(),
                                'errorCode': 'not_json'}
                        else 
                            (: Result: JSON document, optionally also selected target nodes
                               ============================================================ :)                        
                            map:merge((
                                map{'type': 'linkResolutionObject',
                                    'contextURI': $contextURI,
                                    'contextItem': $linkContextItem,                            
                                    'href': string($href), 
                                    'targetURI': $targetURI,
                                    'targetExists': true(),
                                    'targetDoc': $targetDoc},
                                    $ldo?targetXP ! map{
                                    'targetNodes': $targetNodes}))

            (: Mediatype: csv :)
            else if ($mediatype = 'csv') then   
                if (not(i:fox-unparsed-text-available($targetURI, ()))) then
                
                    (: Result: resource not found
                       ========================== :)                
                    if (not(i:fox-resource-exists($targetURI))) then
                        map{'type': 'linkResolutionObject',
                            'contextURI': $contextURI,
                            'contextItem': $linkContextItem,                     
                            'href': string($href), 
                            'targetURI': $targetURI, 
                            'targetExists': false(),
                            'errorCode': 'no_resource'}
                            
                    (: Result: not a text resource
                       =========================== :)               
                    else
                        map{'type': 'linkResolutionObject',
                            'contextURI': $contextURI,
                            'contextItem': $linkContextItem,                     
                            'href': string($href), 
                            'targetURI': $targetURI, 
                            'targetExists': true(),
                            'errorCode': 'no_text'}
                else
                    let $text := i:fox-unparsed-text($targetURI, ())
                    (: _TO_DO_ We need a function csvDoc consuming the document text, rather than the URI :)
                    let $targetDoc := try {i:csvDoc($targetURI, (), $ldo)} 
                                      catch * {trace((), concat('+++ CSV PARSE EXCEPTION; ERR_CODE: ', $err:code, ' ; ERR_DESCRIPTION: ', $err:description))}
                    let $targetNodes := $targetDoc ! f:getLinkTargetNodes(., $ldo?targetXP, $linkContextItem, $context)
                    return 
                        if (not($targetDoc)) then
                        
                            (: Result: not a JSON document
                               =========================== :)                        
                            map{'type': 'linkResolutionObject',
                                'contextURI': $contextURI,
                                'contextItem': $linkContextItem,                            
                                'href': string($href), 
                                'targetURI': $targetURI,
                                'targetExists': true(),
                                'errorCode': 'not_json'}
                        else 
                            (: Result: JSON document, optionally also selected target nodes
                               ============================================================ :)                        
                            map:merge((
                                map{'type': 'linkResolutionObject',
                                    'contextURI': $contextURI,
                                    'contextItem': $linkContextItem,                            
                                    'href': string($href), 
                                    'targetURI': $targetURI,
                                    'targetExists': true(),
                                    'targetDoc': $targetDoc},
                                    $ldo?targetXP ! map{
                                    'targetNodes': $targetNodes}))
            

            (: Mediatype: xml :)            
            else if ($mediatype = 'xml') then
                if (not(i:fox-doc-available($targetURI))) then 
                    if (not(i:fox-resource-exists($targetURI))) then
                    
                        (: Result: resource not found
                           ========================== :)                    
                        map{'type': 'linkResolutionObject',
                            'contextURI': $contextURI,
                            'contextItem': $linkContextItem,                    
                            'href': string($href),
                            'targetURI': $targetURI,
                            'targetExists': false(),
                            'errorCode': 'no_resource'}
                    else
                        if (not(i:fox-unparsed-text-available($targetURI, ()))) then
                        
                            (: Result: not a text resource
                               =========================== :)                        
                            map{'type': 'linkResolutionObject',
                                'contextURI': $contextURI,
                                'contextItem': $linkContextItem,                    
                                'href': string($href),
                                'targetURI': $targetURI,
                                'targetExists': true(),
                                'errorCode': 'no_text'}
                        else
                            (: Result: not an XML document
                               =========================== :)                        
                            map{'type': 'linkResolutionObject',
                                'contextURI': $contextURI,
                                'contextItem': $linkContextItem,                    
                                'href': string($href),
                                'targetURI': $targetURI,
                                'targetExists': true(),
                                'errorCode': 'not_xml'}
                else 
                    let $targetDoc := i:fox-doc($targetURI)
                    let $targetNodes := $targetDoc ! f:getLinkTargetNodes(., $ldo?targetXP, $linkContextItem, $context)  
                    return
                       (: Result: XML document, optionally also selected target nodes
                          =========================================================== :)
                        map:merge((
                            map{'type': 'linkResolutionObject',
                                'contextURI': $contextURI,
                                'contextItem': $linkContextItem,                            
                                'href': string($href), 
                                'targetURI': $targetURI,
                                'targetExists': true(),
                                'targetDoc': $targetDoc},
                                $ldo?targetXP ! map{
                                'targetNodes': $targetNodes}))
            else
                if (not(i:fox-resource-exists($targetURI))) then
                
                    (: Result: resource not found
                       ========================== :)                
                    map{'type': 'linkResolutionObject',
                        'contextURI': $contextURI,
                        'contextItem': $linkContextItem,                    
                        'href': string($href),
                        'targetURI': $targetURI,
                        'targetExists': false(),
                        'errorCode': 'no_resource'}
                else
                   (: Result: resource URI
                      ==================== :)
                    map{'type': 'linkResolutionObject',
                        'contextURI': $contextURI,
                        'contextItem': $linkContextItem,                    
                        'href': string($href),
                        'targetURI': $targetURI,
                        'targetExists': true()}
    
    (: Link Resolution Objects for connector output: node items, grouped by containing doc 
       =================================================================================== :)
    let $lrosNodeItems :=
        for $connectorNode in $connectorNodes
        let $root := $connectorNode/root()
        group by $rootID := $root/generate-id(.)  
        let $targetURI := $root/base-uri(.)
        let $nonRootNodes := $connectorNode except $root[1]
        let $includedRootNode := $root[. intersect $connectorNode]
        
        (: target nodes: 
               if expr targetXP is specified: 
                   union of the expression values obtained for each context node;
                   context nodes: 
                       all non-root nodes, if there are any,
                       the root node otherwise
               otherwise: all non-root nodes obtained from the foxpath
         :)
        let $targetXP := $ldo?targetXP
        let $targetNodes :=
            if (not($targetXP)) then $nonRootNodes
            (: else if (count($connectorNode) eq 1) then $connectorNode :) (: Removed this clause - unclear what was intended :)
            else
                f:getLinkTargetNodes($connectorNode, $ldo?targetXP, $linkContextItem, $context)                    
        return
        
            (: Result for subset of nodes belonging to a single resource
               ========================================================= :)
            map:merge((
                map{
                    'type': 'linkResolutionObject',
                    'contextURI': $contextURI,
                    'contextItem': $linkContextItem,
                    'targetExists': true(),
                    'targetURI': $targetURI,
                    'targetDoc': $root},

                (: Target nodes: only if targetXP specified, or if foxpath produces non-root nodes :)
                if (not($ldo?targetXP) and not($nonRootNodes)) then () 
                else
                    map{'targetNodes': $targetNodes}
            ))
    let $lros := ($lrosAtomicItems, $lrosNodeItems)
    let $newUrisSofar := ($urisSofar, $lros?targetURI) => distinct-values()
    let $newNodesSofar := ($nodesSofar, $connectorNodes)/.
    return (
        $lros,
        
        (: Continue navigation if 'recursive', excluding LRO with error :) 
        if (not($ldo?recursive)) then () else
            $lros[not(?errorCode)] 
            !f:resolveLinkDefRC($ldo, ?targetURI, ?targetDoc, $context, $newUrisSofar, $newNodesSofar)            
    )
};

(:~
 : Returns the link target nodes of a link. If no link target expression is
 : specified, no nodes are returned. Otherwise the link target expression is
 : evaluated once for each connector node, using it as context node. The
 : connector nodes are the nodes returned by the connector, if it returns
 : nodes. If the connector returns a URI, rather than nodes, the connector
 : node is the root node obtained by parsing the URI. When evaluating the 
 : link target expression, the link context node is bound to the context 
 : variable 'linkContext'.
 :
 : @param connectorNodes the connector nodes
 : @param targetExpr an expression mapping the connector nodes to
 :   the link target nodes
 : @param linkContextItem the link context item of the link
 : @param context the processing context
 : @return the link target nodes of the link
 :) 
declare function f:getLinkTargetNodes($connectorNodes as node()+, 
                                      $targetExpr as xs:string?, 
                                      $linkContextItem as item(), 
                                      $context as map(xs:string, item()*))
        as node()* {
    if (not($targetExpr)) then () else
 
    let $nodes :=
        let $evaluationContextNext := 
            i:newEvaluationContext_linkContextItem($linkContextItem, $context) 
        for $connectorNode in $connectorNodes return
            i:evaluateXPath($targetExpr, $connectorNode, $evaluationContextNext, true(), true())
    return $nodes/.            
};        
