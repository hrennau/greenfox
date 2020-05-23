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
                                       $constraintElems as element()*,  (: required when inferring mediatype :)
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    
    let $relDef := f:linkDefinitionObject($relName, $context)
    let $connector := $relDef?connector
    let $values :=
        if (empty($relDef)) then error()
        else if ($connector eq 'foxpath') then
            f:resolveRelationship_foxpath($relDef, $resultFormat, $constraintElems, $filePath, $context)
        else if ($connector eq 'links') then
            f:resolveRelationship_links($relDef, $resultFormat, $constraintElems, $filePath, $context)
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
                                       $constraintElems as element()*,  (: required when inferring mediatype :)                                       
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

declare function f:resolveRelationship_links(
                                       $ldo as map(xs:string, item()*),
                                       $resultFormat as xs:string,  (: uri | doc | relobject :)
                                       $constraintElems as element()*,  (: required when inferring mediatype :)                                       
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
        
    let $contextNode := $context?_reqDocs?doc
    return            
        link:resolveLdo($ldo, $resultFormat, $filePath, $contextNode, $context)                              

(:        
    let $evaluationContext := $context?_evaluationContext
    let $reqDocs := $context?_reqDocs
    
    let $linkContextURI := $filePath
    let $linkContextDoc := $reqDocs?doc    
    let $linkContextXP := $ldo?linkContextXP
    let $linkXP := $ldo?linkXP
    let $linkTargetXP := $ldo?linkTargetXP    
    let $mediatype := f:getLinkTargetMediatype($ldo, (), $constraintElems)
(:    
        let $explicit := $ldo?mediatype
        return if (not($explicit) and $linkTargetXP) then 'xml' else $explicit
 :)        
    let $recursive := $ldo?recursive
    return
        link:resolveUriLinks(
                      $linkContextURI, $linkContextDoc, $linkContextXP, $linkXP, $linkTargetXP,
                      $mediatype, $recursive, $context)
:)                      
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
 : Parses resource relationships defined by <linkDef> elements into a
 : map. Each relationship is represented by a field whose name is the
 : name of the relationship and whose value is a map describing the
 : relationship.
 :
 : @param linkDefs schema elements from which to parse the relationships
 : @return a map representing the relationships parsed from the <linkDef> elements
 :)
declare function f:parseResourceRelationships($linkDefs as element()*)
        as map(*) {
    map:merge(        
        for $linkDef in $linkDefs
        let $name := $linkDef/@name/string()
        let $ldo := f:parseLinkDefinition($linkDef)
        return map:entry($name, $ldo)
    )
};    

(:~
 : Parses a link definition into a Link Definition Object.
 :
 : @param linkDef an element defining a link
 : @return a Link Definition Object
 :)
declare function f:parseLinkDefinition($linkDef as element())
        as map(*) {
    let $ldo :=        
        map:merge(        
            let $recursive := $linkDef/(@linkRecursive, @recursive)[1]/string()
            let $linkContextXP := $linkDef/@linkContextXP/string()
            let $linkTargetXP := $linkDef/@linkTargetXP/string()            
            let $foxpath := $linkDef/@foxpath/string() 
            let $hrefXP := $linkDef/@hrefXP/string()
            let $uriXP := $linkDef/@uriXP/string()
            let $uriReflectionBase := $linkDef/@uriReflectionBase/string()
            let $uriReflectionShift := $linkDef/@uriReflectionShift/string()
            let $linkXP := $linkDef/@linkXP/string()
            let $constraints := $linkDef/gx:constraints
            let $uriTemplate := $linkDef/gx:uriTemplate
            let $connector :=
                let $connectorExplicit := $linkDef/@connector/string()
                return
                    if ($connectorExplicit) then $connectorExplicit
                    else if ($linkXP) then 'links'
                    else if ($foxpath) then 'foxpath'
                    else if ($hrefXP) then 'hrefExpr'
                    else if ($uriXP) then 'uriExpr'
                    else if ($uriTemplate) then 'uriTemplate'
                    else if ($uriReflectionBase) then 'uriReflection'                    
                    else error()
        
            let $requiresContextNode :=
                    $connector = ('links', 'hrefExpr', 'uriExpr', 'uriTemplate')
                    or $linkContextXP
            let $mediatype :=
                let $mediatypeExplicit := $linkDef/@mediatype/string()
                return
                    if ($mediatypeExplicit) then $mediatypeExplicit
                    else if ($recursive and $requiresContextNode
                             or $linkTargetXP)
                        then 'xml'
                    else () 
            return
                map:merge((
                    $connector ! map:entry('connector', .),
                    $mediatype ! map:entry('mediatype', .),
                    $recursive ! map:entry('recursive', .),
                    $requiresContextNode ! map:entry('requiresContextNode', .),
                    $linkContextXP ! map:entry('linkContextXP', .),
                    $linkTargetXP ! map:entry('linkTargetXP', .),                   
                    $foxpath ! map:entry('foxpath', .),
                    $hrefXP ! map:entry('hrefXP', .),
                    $uriXP ! map:entry('uriXP', .),
                    $uriTemplate ! map:entry('uriTemplate', .),
                    $uriReflectionBase ! map:entry('uriReflection', 
                        map{'base': $uriReflectionBase, 
                            'shift': $uriReflectionShift}),
                    $linkXP ! map:entry('linkXP', .),                            
                    $constraints ! map:entry('constraints', $constraints)
                ))
    )
    return $ldo
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
declare function f:getLinkNamesReferenced($components as element()*)
        as xs:string* {
    $components//(@link, @ref[parent::gx:links])
    => distinct-values()
}; 

declare function f:getLinkDefs($components as element()*, 
                               $context as map(xs:string, item()*))
        as map(*)* {
    let $linkNames := f:getLinkNamesReferenced($components) => distinct-values()
    return $linkNames ! f:linkDefinitionObject(., $context)
}; 

(:~
 : Returns the expected mediatype of link targets. The mediatype is either
 : explicitly specified (@mediatype), or can be inferred from link
 : definition details (@recursive), or can be inferred from link
 : constraints (@countTargetDocs, @countTargetNodes)
 :
 : @param ldo link definition object
 : @param lde link defining element
 : @param constraintElems link constraining elements
 : @return explicit or inferred mediatype, or the empty sequence
 :)
declare function f:getLinkTargetMediatype($ldo as map(xs:string, item()*),
                                          $lde as element()?,
                                          $constraintElems as element()*)
        as xs:string? {
    let $allConstraintElems := ($ldo?constraints, $constraintElems)
    let $explicit := $ldo?mediatype
    return
        if ($explicit) then $explicit
        else if ($ldo?recursive) then 'xml'
        else if ($lde/@recursive) then 'xml'
        else if ($allConstraintElems/
            (@countTargetDocs, @minCountTargetDocs, @maxCountTargetDocs,
             @countTargetNodes, @minCountTargetNodes, @maxCountTargetNodes))
            then 'xml'
        else ()
};        
