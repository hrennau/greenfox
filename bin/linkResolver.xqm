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

(:~
 : Resolves a Link Definition Object to a sequence of Link Resolution Objects.
 : 
 : @param ldo a Link Definition Object
 : @param resultFormat determines the result format; lro: Link Resolution Objects;
 :       uri: URI references; target documents
 : @param contextURI the URI of the context resource
 : @param contextNode the context node
 : @param context processing context
 : @return a sequence of Link Resolution Objects, or selected data retrieved
 :   from these
 :)
declare function f:resolveLdo($ldo as map(*),
                              $resultFormat as xs:string?, (: lro | uri | doc :)
                              $contextURI as xs:string,
                              $contextNode as node()?,                              
                              $context as map(xs:string, item()*))
        as map(xs:string, item()*)* {

    let $contextNode :=
        if ($contextNode) then $contextNode
        else if ($ldo?requiresContextNode) then
            let $doc := $context?_reqDocs?doc
            return
                if (not($doc)) then  
                    error((), concat('Invalid call - Link Definition "', $ldo?name, '" requires context node.'))
                else $doc        
    let $mediatype :=
        if ($ldo?mediatype) then $ldo?mediatype 
        else if ($resultFormat eq 'doc') then 'xml'
        else ()
    let $ldoAugmented := map:put($ldo, 'mediatype', $mediatype)
    let $lros := f:resolveLdoRC($ldoAugmented, $contextURI, $contextNode, $context, (), ()) 
    return $lros 
};

declare function f:resolveLdoRC(
                              $ldo as map(*),
                              $contextURI as xs:string,
                              $contextNode as node()?,                              
                              $context as map(xs:string, item()*),
                              $urisSofar as xs:string*,
                              $nodesSofar as xs:string*)
                             
        as map(xs:string, item()*)* {
        
    let $linkContextExpr := $ldo?linkContextXP
    let $mediatype := $ldo?mediatype
    
    (: The mapping of the context node to Link Context Nodes is optional:
       the default link context is the context resource, represented
       by the context resource URI and, optionally, a context node :)        
    let $linkContextItems :=
        if (not($linkContextExpr)) then ($contextNode, $contextURI)[1]
        else if (not($contextNode)) then error((), 
            concat('Link context expression requires a context node; expression: ', 
                   $linkContextExpr))                       
        else f:resolveLinkExpression($linkContextExpr, $contextNode, $context)

    (: Apply link definition to each link context item :)
    for $linkContextItem in $linkContextItems
    let $connectorValue := f:applyLinkConnector($ldo, $contextURI, $linkContextItem, $context)
    let $hrefs := $connectorValue[. instance of xs:anyAtomicType]
    let $connectorNodes := $connectorValue[. instance of node()]
    
    (: Link Resolution Objects for atomic link items :)
    let $lrosAtomicItems :=   
        for $href in $hrefs
        let $baseURI := $contextURI
        let $targetURI := i:fox-resolve-uri($href, $baseURI)
        where not($targetURI = ($urisSofar))
        return
            (: Error - link value cannot be resolved :)
            if (not($targetURI)) then
                map{'type': 'linkResolutionObject',
                    'contextURI': $contextURI,
                    'contextItem': $linkContextItem,
                    'href': string($href),                
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
                            'contextItem': $linkContextItem,                     
                            'href': string($href), 
                            'targetURI': $targetURI, 
                            'targetExists': $targetExists,
                            'errorCode': $errorCode}
                else
                    let $text := i:fox-unparsed-text($targetURI, ())
                    let $jdoc := try {json:parse($text)} catch * {()}
                    let $linkTargetNodes := f:getLinkTargetNodes($jdoc, $ldo?linkTargetXP, $linkContextItem, $context)
                    return 
                        if (not($jdoc)) then 
                            map{'type': 'linkResolutionObject',
                                'contextURI': $contextURI,
                                'contextItem': $linkContextItem,                            
                                'href': string($href), 
                                'targetURI': $targetURI,
                                'targetExists': true(),
                                'errorCode': 'not_json'}
                        else 
                            map:merge((
                                map:entry('type', 'linkResolutionObject'),                                
                                map:entry('contextURI', $contextURI),
                                map:entry('contextItem', $linkContextItem),
                                map:entry('href', string($href)),
                                map:entry('targetURI', $targetURI),
                                map:entry('targetExists', true()),
                                map:entry('targetDoc', $jdoc),
                                $ldo?linkTargetXP ! map:entry('targetNodes', $linkTargetNodes)))
            
            (: Mediatype: xml :)            
            else if ($mediatype = 'xml') then
                if (not(i:fox-doc-available($targetURI))) then 
                    let $targetExists := i:fox-resource-exists($targetURI)
                    let $errorCode := if ($targetExists) then 'not_xml' else 'no_resource'                    
                    return
                        map{'type': 'linkResolutionObject',
                            'contextURI': $contextURI,
                            'contextItem': $linkContextItem,                    
                            'href': string($href),
                            'targetURI': $targetURI,
                            'targetExists': $targetExists,
                            'errorCode': $errorCode}
                else 
                    let $targetDoc := i:fox-doc($targetURI)
                    let $linkTargetNodes := f:getLinkTargetNodes($targetDoc, $ldo?linkTargetXP, $linkContextItem, $context)  
                    return
                        map:merge((
                            map:entry('type', 'linkResolutionObject'),
                            map:entry('contextURI', $contextURI),
                            map:entry('contextItem', $linkContextItem),                    
                            map:entry('href', string($href)),
                            map:entry('targetURI', $targetURI), 
                            map:entry('targetExists', true()),
                            map:entry('targetDoc', $targetDoc),
                            $ldo?linkTargetXP ! map:entry('targetNodes', $linkTargetNodes)
                        ))
            else
                if (i:fox-resource-exists($targetURI)) then
                    map{'type': 'linkResolutionObject',
                        'contextURI': $contextURI,
                        'contextItem': $linkContextItem,                    
                        'href': string($href),
                        'targetURI': $targetURI,
                        'targetExists': true()}
                else
                    map{'type': 'linkResolutionObject',
                        'contextURI': $contextURI,
                        'contextItem': $linkContextItem,                    
                        'href': string($href),
                        'targetURI': $targetURI,
                        'targetExists': false(),
                        'errorCode': 'no_resource'}
    
    
    (: Link Resolution Objects for node items: grouped by containing root node :)                    
    let $lrosNodeItems :=
        for $connectorNode in $connectorNodes
        let $root := $connectorNode/root()
        group by $rootID := $root/generate-id(.)        
        let $nonRootNodes := $connectorNode except $root[1]
        let $includedRootNode := $root[. intersect $connectorNode]
        
        (: target nodes: 
               if expr linkTargetXP is specified: 
                   union of the expression values obtained for each context node;
                   context nodes: 
                       all non-root nodes, if there are any,
                       the root node otherwise
               otherwise: all non-root nodes obtained from the foxpath
         :)
        let $linkTargetXP := $ldo?linkTargetXP
        let $linkTargetNodes :=
            if (not($linkTargetXP)) then $nonRootNodes
            else if (count($connectorNode) eq 1) then $connectorNode
            else
                let $myConnectorNodes := ($nonRootNodes, $includedRootNode)
                return
                    f:getLinkTargetNodes($myConnectorNodes, $ldo?linkTargetXP, $linkContextItem, $context)                    
        return
            map:merge((
                map:entry('type', 'linkResolutionObject'),
                map:entry('contextURI', $contextURI),
                map:entry('contextItem', $linkContextItem),
                map:entry('targetExists', true()),
                map:entry('targetDoc', $root),
                (: Target nodes: only if linkTargetXP specified, or if foxpath produces non-root nodes :)
                if (not($ldo?linkTargetXP) and not($nonRootNodes)) then () 
                else
                    map:entry('targetNodes', $linkTargetNodes)
            ))
    let $lros := ($lrosAtomicItems, $lrosNodeItems)
    let $newUrisSofar := ($urisSofar, $lros?targetURI) => distinct-values()
    let $newNodesSofar := ($nodesSofar, $connectorNodes)/.
    return (
        $lros,
        if (not($ldo?recursive)) then () else
            $lros[not(?errorCode)] 
            !f:resolveLdoRC($ldo, ?targetURI, ?targetDoc, $context, $newUrisSofar, $newNodesSofar)            
    )
};

(:~
 : Returns a string if application of a link definition requires a
 : context node. The string expresses the reason why a context node
 : is required.
 :
 : @param ldo Link Definition Object
 : @return a string giving a reason, or the empty sequence
 :)
declare function f:linkRequiresContextNode($ldo as map(xs:string, item()*))
        as xs:string? {
    if ($ldo?linkContextXP) then
        'Link context expression requires a context node.'
    else if ($ldo?linkXP) then 
        'Link expression requires a context node.'
    else if ($ldo?hrefXP) then 
        'href expression requires a context node.'
    else if ($ldo?uriXP) then 
        'URI expression requires a context node.'
    else if ($ldo?uriTemplate) then 
        'URI template requires a context node.'
    else ()
};

(:~
 : Applies the connector of a link.
 :
 : @param contextURI URI of the link context resource
 : @param contextItem the context item, which may be a node or the context resource URI
 : @param context processing context
 : @return items, which may be target URIs or target nodes
 :)
declare function f:applyLinkConnector($ldo as map(*),
                                      $contextURI as xs:string,
                                      $contextItem as item(),                             
                                      $context as map(xs:string, item()*))
        as item()* {
    if ($ldo?linkXP) then
        f:resolveLinkExpression($ldo?linkXP, $contextItem, $context) ! string(.)
    else if ($ldo?foxpath) then
        let $evaluationContext := $context?_evaluationContext
        return
            i:evaluateFoxpath($ldo?foxpath, $contextItem, $evaluationContext, true())    
    else ()
};

(:~
 : Resolves a Foxpath-based link definition.
 :
 : @param linkContextURI the URI of the link context resource
 : @param linkContextDoc the root node of the context resource, represented as node tree
 : @param linkContextXP expression mapping the link context doc to link context items
 : @param foxpath the Foxpath expression used by the link
 : @param linkTargetXP expression mapping the foxpath value items to target items
 : @param targetMediatype mediatype of the link targets
 : @param resultFormat the representation of the Link Resolution Objects
 : @param context the processing context
 :)
declare function f:resolveFoxLinks(
                        $linkContextURI as xs:string,
                        $linkContextDoc as node()?,
                        $linkContextXP as xs:string?,
                        $foxpath as xs:string,
                        $linkTargetXP as xs:string?,
                        $targetMediatype as xs:string?,
                        $resultFormat as xs:string,  (: uri | doc | lro :)
                        $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $unparsedTextEncoding := ()
    let $targetMediatype := 
        if (not($targetMediatype) and ($linkTargetXP or $resultFormat eq 'doc')) then 
            'xml'
        else 
            $targetMediatype
    
    (: Link context items:
       - unless $linkContextXP is provided: the context resource URI
       - otherwise: the value items of $linkContextXP :)
    let $linkContextItems :=
        if (not($linkContextXP)) then $linkContextURI
        else i:evaluateXPath($linkContextXP, $linkContextDoc, $evaluationContext, true(), true())

    (: For each Link Context Item ... :)
    for $linkContextItem in $linkContextItems
    
    (: Determine targets - may be URIs, may be documents, may be within-document nodes :)
    let $targets := i:evaluateFoxpath($foxpath, $linkContextItem, $evaluationContext, true())    
    let $targetsAtomic := $targets[. instance of xs:anyAtomicType]
    let $targetsNode := $targets[. instance of node()]

    (: Link Resolution Objects for atomic items (URIs) :)
    let $lrosAtomicItems :=
        for $target in $targetsAtomic 
        return        
            let $targetURI := $target
            let $targetExists := i:fox-resource-exists($targetURI)
                
            (: target document - will either be a node, or an error code :)
            let $targetDoc :=
                if (not($targetExists)) then () else
                    
                if ($targetMediatype eq 'json') then
                    if (not(i:fox-unparsed-text-available($targetURI, $unparsedTextEncoding))) then 
                        'nofind_text'
                    else
                        let $text := i:fox-unparsed-text($targetURI, $unparsedTextEncoding)
                        return
                            let $jdoc := try {json:parse($text)} catch * {()}
                            return
                                if ($jdoc) then $jdoc
                                else 'not_json'
                                
                else if ($targetMediatype eq 'xml') then
                    if (i:fox-doc-available($targetURI)) then doc($targetURI)
                    else if (i:fox-unparsed-text-available($targetURI, $unparsedTextEncoding)) then 'not_xml'
                    else 'nofind_text'
                    
                else ()
                    
            (: Flag indicating that link target nodes should be determined :)
            let $linkTargetNodesExpected := $linkTargetXP and $targetDoc instance of node()
                    
            (: Determine link target nodes :)
            let $linkTargetNodes :=
                if (not($linkTargetNodesExpected)) then ()
                else
                    (: Evaluation requires binding of variable 'linkContext' to the link context item :)
                    let $evaluationContextNext := map:put($evaluationContext, QName('', 'linkContext'), $linkContextItem)
                    return i:evaluateXPath($linkTargetXP, $targetDoc, $evaluationContextNext, true(), true())
            return
                map:merge((
                    map:entry('type', 'linkResolutionObject'),
                    map:entry('contextURI', $linkContextURI),
                    if ($linkContextItem instance of xs:anyAtomicType) then ()
                    else
                        map:entry('contextNode', $linkContextItem),
                    map:entry('targetURI', $targetURI),
                    map:entry('targetExists', $targetExists),
                    if (empty($targetDoc)) then ()
                    else if ($targetDoc instance of xs:anyAtomicType) then
                        map:entry('errorCode', $targetDoc)
                    else
                        map:entry('targetDoc', $targetDoc),
                    if (not($linkTargetNodesExpected)) then () else
                        map:entry('targetNodes', $linkTargetNodes)
                ))
       
    (: Link Resolution Objects for node items: grouped by containing root node :)                    
    let $lrosNodeItems :=
        for $target in $targetsNode
        let $root := $target/root()
        group by $rootID := $root/generate-id(.)        
        let $nonRootNodes := $target except $root[1]
        
        (: target nodes: 
               if expr linkTargetXP is specified: 
                   union of the expression values obtained for each context node;
                   context nodes: 
                       all non-root nodes, if there are any,
                       the root node otherwise
               otherwise: all non-root nodes obtained from the foxpath
         :)
        let $linkTargetNodes :=
            if (not($linkTargetXP)) then $nonRootNodes
            else
                let $evaluationContextNodes :=
                    if (count($target) eq 1) then $target
                    else $nonRootNodes
                (: Evaluate $linkTargetXP in each appropriate context :)
                for $ecn in $evaluationContextNodes
                let $evaluationContextNext := map:put($evaluationContext, QName('', 'linkContext'), $linkContextItem)
                return
                    i:evaluateXPath($linkTargetXP, $ecn, $evaluationContextNext, false(), true())        
        return
            map:merge((
                map:entry('type', 'linkResolutionObject'),
                map:entry('contextURI', $linkContextURI),
                if ($linkContextItem instance of xs:anyAtomicType) then ()
                else
                    map:entry('contextNode', $linkContextItem),
                map:entry('targetExists', true()),
                map:entry('targetDoc', $root),
                (: Target nodes: only if linkTargetXP specified, or if foxpath produces non-root nodes :)
                if (not($linkTargetXP) and not($nonRootNodes)) then () 
                else
                    map:entry('targetNodes', $linkTargetNodes)
            ))

    let $lros := ($lrosAtomicItems, $lrosNodeItems)
    let $resultFormat := ($resultFormat, 'lro')[1]
    return
        if ($resultFormat eq 'lro') then $lros
        else if ($resultFormat eq 'doc') then ($lros?targetDoc)/.
        else if ($resultFormat eq 'uri') then ($lros[?targetExists]?targetURI) => distinct-values()
        else error(QName((), 'INVALID_ARG'), 
            concat('Invalid value of "resultFormat": ', $resultFormat, ' ; must be one of: lro, doc, uri'))
};

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
declare function f:resolveUriLinks(
                             $contextURI as xs:string,
                             $contextNode as node()?,
                             $linkContextExpr as xs:string?,
                             $linkExpr as xs:string,
                             $linkTargetExpr as xs:string?,
                             $mediatype as xs:string?,
                             $recursive as xs:boolean?,
                             $context as map(xs:string, item()*))
        as map(xs:string, item()*)* {
    let $lros := f:resolveUriLinksRC($contextURI, $contextNode, 
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
 : Recursive helper function of `resolveUriLinks`.
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
declare function f:resolveUriLinksRC(
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
            ! f:resolveUriLinksRC(?targetURI, ?targetDoc, 
                                  $linkContextExpr, $linkExpr, $linkTargetExpr, 
                                  $mediatype, $recursive, 
                                  $context, 
                                  $newPathsSofar, $newErrorsSofar)            
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
 : @param linkTargetExpr an expression mapping the connector nodes to
 :   the link target nodes
 : @param linkContextItem the link context item of the link
 : @param context the processing context
 : @return the link target nodes of the link
 :) 
declare function f:getLinkTargetNodes($connectorNodes as node()+, 
                                      $linkTargetExpr as xs:string?, 
                                      $linkContextItem as node(), 
                                      $context as map(xs:string, item()*))
        as node()* {
    if (not($linkTargetExpr)) then () else
 
    let $evaluationContextNext := map:put($context?_evaluationContext, QName('', 'linkContext'), $linkContextItem)
    for $connectorNode in $connectorNodes        
    return
        i:evaluateXPath($linkTargetExpr, $connectorNode, $evaluationContextNext, true(), true())        
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
