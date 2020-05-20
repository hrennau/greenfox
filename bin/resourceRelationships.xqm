(:
 : -------------------------------------------------------------------------
 :
 : resourceRelationships.xqm - functions for managing resource relationships
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "foxpathUtil.xqm",
    "greenfoxUtil.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/link-resolver" at
    "linkResolver.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns the Link Definition Object identified by a relationship name
 :
 : @param relName relationship name
 : @param context processing context
 : @return the Link Definition Object, or the empty sequence, if no object is found
 :)
declare function f:linkDefinitionObject($relName as xs:string, 
                                        $context as map(xs:string, item()*))
        as map(*)? {
    $context?_resourceRelationships($relName)        
};        

declare function f:resolveRelationship($relName as xs:string,
                                       $resultFormat as xs:string, (: uri | doc | lro :)
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    
    let $relDef := f:linkDefinitionObject($relName, $context)
    let $connector := $relDef?connector
    let $values :=
        if (empty($relDef)) then error()
        else if ($connector eq 'foxpath') then
            f:resolveRelationship_foxpath($relDef, $resultFormat, $filePath, $context)
        else if ($connector eq 'links') then
            f:resolveRelationship_links($relDef, $resultFormat, $filePath, $context)
        else error()
    return
        $values
};

(:~
 : Resolves a Link Definition Object with connector type 'foxpath'.
 :
 : @param ldo Link Definition Object
 : @param resultFormat the result format
 : @param filePath file path of the context resource
 : @param context the processing context
 : @return the Link Resolution Objects, or values derived from them
 :)
declare function f:resolveRelationship_foxpath(
                                       $ldo as map(xs:string, item()*),
                                       $resultFormat as xs:string,  (: uri | doc | lro :)
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $reqDocs := $context?_reqDocs    

    let $linkContextURI := $filePath
    let $linkContextDoc := $reqDocs?doc
    let $linkContextXP := $ldo?linkContextXP
    let $foxpath := $ldo?foxpath
    let $linkTargetXP := $ldo?linkTargetXP
    let $targetMediatype := $ldo?mediatype
    return
        link:resolveFoxLinks(
             $linkContextURI, $linkContextDoc, $linkContextXP, 
             $foxpath, $linkTargetXP,
             $targetMediatype, $resultFormat, $context)
};

(:
declare function f:resolveRelationship_foxpath(
                                       $ldo as map(xs:string, item()*),
                                       $resultFormat as xs:string,  (: uri | doc | lro :)
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $reqDocs := $context?_reqDocs
    
    let $linkContextDoc := $reqDocs?doc
    let $foxpath := $ldo?foxpath 
    let $linkContextXP := $ldo?linkContextXP
    let $linkTargetXP := $ldo?linkTargetXP
    let $mediatype := $ldo?mediatype
    
    let $unparsedTextEncoding := ()
    
    let $linkContextItems :=
        if (not($linkContextXP)) then $filePath
        else i:evaluateXPath($linkContextXP, $linkContextDoc, $evaluationContext, true(), true())

    (: For each Link Context Item ... :)
    for $linkContextItem in $linkContextItems
    
    (: Determine targets - may be URIs, may be documents, may be within-document nodes :)
    let $targets := f:evaluateFoxpath($foxpath, $linkContextItem, $evaluationContext, true())
    
    let $targetsAtomic := $targets[. instance of xs:anyAtomicType]
    let $targetsNode := $targets[. instance of node()]

    (: Linke Resolution Objects for atomic items (URIs) :)
    let $lrosAtomicItems :=
        for $target in $targetsAtomic 
        return        
            let $targetURI := $target
            let $targetExists := i:fox-resource-exists($targetURI)
                
            (: target document - will either be a node, or an error code :)
            let $targetDoc :=
                if (not($targetExists)) then () else
                    
                if ($mediatype eq 'json') then
                    if (not(f:fox-unparsed-text-available($targetURI, $unparsedTextEncoding))) then 'nofind_text'
                    else
                        let $text := f:fox-unparsed-text($targetURI, $unparsedTextEncoding)
                        return
                            let $jdoc := try {json:parse($text)} catch * {()}
                            return
                                if (not($jdoc)) then 'not_json'
                                else $jdoc
                else if ($mediatype eq 'xml' or $linkTargetXP) then
                    if (not(i:fox-resource-exists($targetURI))) then 'not_xml'
                    else doc($targetURI)
            let $linkTargetNodesExpected :=
                if (not($linkTargetXP)) then false()
                else if (empty($targetDoc)) then false()
                else if (not($targetDoc instance of node())) then false()
                else
                    true()
            let $linkTargetNodes :=
                if (not($linkTargetNodesExpected)) then ()
                else
                    let $evaluationContextNext := map:put($evaluationContext, QName('', 'linkContext'), $linkContextItem)
                    return i:evaluateXPath($linkTargetXP, $targetDoc, $evaluationContextNext, true(), true())
            return
                map:merge((
                    map:entry('type', 'linkResolutionObject'),
                    map:entry('contextURI', $filePath),
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
        
        (: target nodes: if expr linkTargetXP is specified: 
                            union of its values obtained for each context;
                            context to be used: all non-root nodes, if there are any,
                            the root node otherwise
                         otherwise: all non-root nodes obtained from the foxpath
         :)
        let $linkTargetNodes :=
            if (not($linkTargetXP)) then $nonRootNodes
            else
                let $evaluationContextNodes :=
                    if (count($target) eq 1) then $target
                    else $nonRootNodes
                for $ecn in $evaluationContextNodes
                let $evaluationContextNext := map:put($evaluationContext, QName('', 'linkContext'), $linkContextItem)
                return
                    i:evaluateXPath($linkTargetXP, $ecn, $evaluationContextNext, false(), true())
        
        return
            map:merge((
                map:entry('type', 'linkResolutionObject'),
                map:entry('contextURI', $filePath),
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
:)

declare function f:resolveRelationship_links(
                                       $ldo as map(xs:string, item()*),
                                       $resultFormat as xs:string,  (: uri | doc | relobject :)
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $reqDocs := $context?_reqDocs
    
    let $linkContextURI := $filePath
    let $linkContextDoc := $reqDocs?doc    
    let $linkContextXP := $ldo?linkContextXP
    let $linkXP := $ldo?linkXP
    let $linkTargetXP := $ldo?linkTargetXP    
    let $mediatype := 
        let $explicit := $ldo?mediatype
        return if (not($explicit) and $linkTargetXP) then 'xml' else $explicit
    let $recursive := $ldo?recursive
    return
        link:resolveUriLinks(
                      $linkContextURI, $linkContextDoc, $linkContextXP, $linkXP, $linkTargetXP,
                      $mediatype, $recursive, $context)
};   

(:
(:~
 : Resolves a resource relationship name to a set of target resources. Resolution
 : context is the file path of the focus resource. The target resources may
 : be represented by file paths or by nodes, dependent on the specification
 : of the resource relationship.
 :
 : @param relName relationship name
 : @param filePath file path of the focus resource
 : @param context processing context
 : @return the target documents of the relationship, resolved in the
 :   context of the file path
 :)
declare function f:relationshipTargets($relName as xs:string,
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    
    let $relDef := $context?_resourceRelationships($relName)
    let $connector := $relDef?connector
    let $targets :=
        if (empty($relDef)) then error()
        else if ($connector eq 'foxpath') then
            f:relationshipTargets_foxpath($relDef, $filePath, $context)
        else if ($connector eq 'links') then
            f:relationshipTargets_links($relDef, $filePath, $context)
        else error()
    return
        $targets
};

(:~
 : Resolves a resource relationship name to a set of target resources, in the case
 : of relationship kind 'foxpath'. 
 :
 : @param relName relationship name
 : @param filePath file path of the focus resource
 : @param context processing context
 : @return the target documents of the relationship, resolved in the
 :   context of the file path
 :)
declare function f:relationshipTargets_foxpath(
                                       $resourceRelationship as map(xs:string, item()*),
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $foxpath := $resourceRelationship?foxpath 
    return    
        if ($foxpath) then
            f:evaluateFoxpath($foxpath, $filePath, $evaluationContext, true())
        else error()
};

declare function f:relationshipTargets_links(
                                       $resourceRelationship as map(xs:string, item()*),
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $reqDocs := $context?_reqDocs
    
    let $linkContextExpr := $resourceRelationship?linkContextXP
    let $linkExpr := $resourceRelationship?linkXP
    let $linkTargetExpr := $resourceRelationship?linkTargetXP
    let $mediatype := $resourceRelationship?mediatype
    let $recursive := $resourceRelationship?recursive    
    let $contextNode := $reqDocs?doc
    
    let $lrObjects := link:resolveLinks(
                             $filePath,
                             $contextNode,
                             $linkContextExpr,
                             $linkExpr,
                             $linkTargetExpr,
                             $mediatype,
                             $recursive,
                             $context)
    return
        $lrObjects
        (:
        if ($mediatype eq 'xml') then $lrObjects?targetResource
        else if ($mediatype eq 'json') then $lrObjects?targetResource
        else $lrObjects?uri
        :)
};
:)

(:~
 : Parses resource relationships defined by <setRel> elements into a
 : map. Each relationship is represented by a field whose name is the
 : name of the relationship and whose value is a map describing the
 : relationship.
 :
 : @param setRels schema elements from which to parse the relationships
 : @return a map representing the relationships parsed from the <setRel> elements
 :)
declare function f:parseResourceRelationships($setRels as element(gx:setRel)*)
        as map(*) {
    map:merge(        
        for $setRel in $setRels
        let $name := $setRel/@name/string()
        let $recursive := $setRel/@recursive
        let $mediatype := $setRel/@mediatype
        
        let $foxpath := $setRel/@foxpath/string()
        
        let $linkContextXP := $setRel/@linkContextXP
        let $linkXP := $setRel/@linkXP
        let $linkTargetXP := $setRel/@linkTargetXP
        
        let $connector :=
            let $explicit := $setRel/@connector/string()
            return
                if ($explicit) then $explicit
                else if ($foxpath) then 'foxpath'
                else error()
        let $constraints := $setRel/gx:constraints
        return
            map:entry(
                $name,
                map:merge((
                    map:entry('relName', $name),
                    map:entry('connector', $connector),                    
                    $recursive ! map:entry('recursive', .),
                    $mediatype ! map:entry('mediatype', .),
                    
                    $foxpath ! map:entry('foxpath', .),
                    
                    $linkContextXP ! map:entry('linkContextXP', .),
                    $linkXP ! map:entry('linkXP', .),
                    $linkTargetXP ! map:entry('linkTargetXP', .),
                    $constraints ! map:entry('constraints', $constraints)
                ))
            )
    )
};    

(:~
 : Returns the names of all resource relationships referenced within a
 : component.
 :
 : This function incapsulates the knowledge in items (attributes,
 : elements) contain relationship names. It is called, for example,
 : by function 'getRequiredBindings', which needs to find all expressions
 : used by a set of components.
 :
 : @param component the component to be investigated
 : @return the relationship names
 :)
declare function f:getRelationshipNamesReferenced($components as element()*)
        as xs:string* {
    $components//(@rel, @contextRel)
    => distinct-values()
}; 

declare function f:getRelationshipDefinitions($components as element()*, 
                                              $context as map(xs:string, item()*))
        as map(*)* {
    let $relNames := f:getRelationshipNamesReferenced($components) => distinct-values()
    return $relNames ! f:linkDefinitionObject(., $context)
};        

(:
declare function f:resolveRelationship_foxpath_obsolete(
                                       $resourceRelationship as map(xs:string, item()*),
                                       $resultFormat as xs:string,  (: uri | doc | relobject :)
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $reqDocs := $context?_reqDocs
    
    let $linkContextDoc := $reqDocs?doc
    let $foxpath := $resourceRelationship?foxpath 
    let $linkContextXP := $resourceRelationship?linkContextXP
    let $linkTargetXP := $resourceRelationship?linkTargetXP
    
    let $linkContextItems :=
        if (not($linkContextXP)) then $filePath
        else i:evaluateXPath($linkContextXP, $linkContextDoc, $evaluationContext, true(), true())

    (: For each source context node ... :)
    for $linkContextItem in $linkContextItems
    
    (: Determine target resources (file system level) :)
    let $targets := f:evaluateFoxpath($foxpath, $linkContextItem, $evaluationContext, true())
    for $target in $targets
    let $targetContextNode :=
        if ($target instance of node()) then $target
        else if ($linkTargetXP) then doc($target)
        else doc($target)
        (: _TO_DO_ Parse only if required - due to mediatype etc. :)
    let $_DEBUG := trace(count($targetContextNode), '_COUNT_TARGET_CONTEXT_NODES: ')    
    let $targetNodes :=
        if (not($linkTargetXP)) then ()
        else 
            let $evaluationContextNext := map:put($evaluationContext, QName('', 'linkContext'), $linkContextItem)
            return
                i:evaluateXPath($linkTargetXP, $targetContextNode, $evaluationContextNext, true(), true())
    let $sourceNode := 
        if (not($linkContextXP)) then '#root'
        else $linkContextItem
    let $uri :=
        if ($target instance of xs:anyAtomicType) then $target
        else if ($target instance of node()) then
            let $baseURI := $target/base-uri(.)
            return $baseURI
    return trace(
        map:merge((
            map:entry('type', 'relObject'),
            map:entry('linkContextNode', $sourceNode),
            map:entry('uri', $uri),
            if (not($targetNodes)) then () else
                map:entry('linkTargetNodes', $targetNodes)
        )) , '_REL_OBJECT: ')
};
:)