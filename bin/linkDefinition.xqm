(:
 : -------------------------------------------------------------------------
 :
 : linkDefinition.xqm - functions for managing link definitions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/greenlink";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkResolution.xqm";

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "foxpathUtil.xqm",
    "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns the Link Definition Object identified by a relationship name
 :
 : @param relName relationship name
 : @param context processing context
 : @return the Link Definition Object, or the empty sequence, if no object is found
 :)
declare function f:linkDefObject($linkName as xs:string, 
                                 $context as map(xs:string, item()*))
        as map(*)? {
    $context?_resourceRelationships($linkName)        
};        

(:~
 : Returns the link definition defined or referenced by a given item.
 : The item can be the link name, given by a string or attribute; it
 : may be a Link Definition Object; and it may be an element either
 : referencing a link definition (via @linkName) or providing a
 : local link definition.
 :
 : @param linkDef link definition providing item
 : @param context processing context
 : @return Link Definition Object, or the empty sequence if no object
 :   can be found or constructed
 :)
declare function f:getLinkDefObject($linkDef as item(),
                                    $context as map(xs:string, item()*))
        as map(*)? {
    let $ldo :=        
        typeswitch($linkDef)
        (: Link name, as a string :)
        case $linkName as xs:string return
            let $lookup := link:linkDefObject($linkName, $context)
            return
                if (empty($lookup)) then error((), concat('Unknown link name: ', $linkName))
                else $lookup
        (: Link name, as an attribute :)
        case $linkName as attribute() return
            let $lookup := link:linkDefObject($linkName, $context)
            return
                if (empty($lookup)) then error((), concat('Unknown link name: ', $linkName))
                else $lookup
        (: Link Definition Object :)
        case $linkDefObject as map(*) return $linkDefObject
        (: Element referencing or providing a local link definition :)
        case $linkDefElem as element() return
            let $linkName := $linkDefElem/(@linkName, @link)[1]
            return
                if ($linkName) then
                    let $try := link:linkDefObject($linkName, $context)
                    return
                        if (empty($try)) then error((), concat('Unknown link name: ', $linkName))
                        else $try
                else
                    let $parsed := link:parseLinkDef($linkDefElem)
                    return
                        if (empty($parsed)) then error((), 
                            concat('Element cannot be parsed into a link definition object; element name: ', $linkDefElem/name()))
                        else $parsed
        default return error((), 'Parameter $linkDef must be a string, an object or an element')
    return $ldo        
};

(:
declare function f:resolveRelationship($relName as xs:string,
                                       $resultFormat as xs:string, (: uri | doc | lro :)
                                       $constraintElems as element()*,  (: required when inferring mediatype :)
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    
    let $relDef := f:linkDefObject($relName, $context)
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

    let $contextURI := $filePath
    let $contextDoc := $reqDocs?doc
    let $contextXP := $ldo?contextXP
    let $foxpath := $ldo?foxpath
    let $targetXP := $ldo?targetXP
    let $targetMediatype := $ldo?mediatype
    return
        link:resolveFoxLinks(
             $contextURI, $contextDoc, $contextXP, 
             $foxpath, $targetXP,
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
        link:resolveLinkDef($ldo, $resultFormat, $filePath, $contextNode, $context)                              
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
declare function f:parseLinkDefs($linkDefs as element()*)
        as map(*) {
    map:merge(        
        for $linkDef in $linkDefs
        let $name := $linkDef/@name/string()
        let $ldo := f:parseLinkDef($linkDef)
        return map:entry($name, $ldo)
    )
};    

(:~
 : Parses a link definition into a Link Definition Object. Parsing
 : fails if none of the following items is found:
 : - @uriXP
 : - @hrefXP
 : - @foxpath
 : - @uriReflectionBase
 : - gx:uriTemplate
 :
 : @param linkDef an element defining a link
 : @return a Link Definition Object
 :)
declare function f:parseLinkDef($linkDef as element())
        as map(*) {
    let $recursive := $linkDef/(@linkRecursive, @recursive)[1]/string()
    let $contextXP := $linkDef/@contextXP/string()
    let $targetXP := $linkDef/@targetXP/string()            
    let $foxpath := $linkDef/@foxpath/string() 
    let $hrefXP := $linkDef/@hrefXP/string()
    let $uriXP := $linkDef/@uriXP/string()
    let $uriReflectionBase := $linkDef/@uriReflectionBase/string()
    let $uriReflectionShift := $linkDef/@uriReflectionShift/string()
    let $linkXP := $linkDef/@linkXP/string()
    let $uriTemplate := $linkDef/gx:uriTemplate
    let $constraints := $linkDef/gx:constraints    
    return
        if (empty((
            $hrefXP, $uriXP, $uriReflectionBase, $linkXP, $uriTemplate, $foxpath))) then () else
            
    let $ldo :=        
        map:merge(        
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
                    or $contextXP
            let $mediatype :=
                let $mediatypeExplicit := $linkDef/@mediatype/string()
                return
                    if ($mediatypeExplicit) then $mediatypeExplicit
                    else if ($recursive and $requiresContextNode
                             or $targetXP)
                        then 'xml'
                    else () 
            return
                map:merge((
                    $connector ! map:entry('connector', .),
                    $mediatype ! map:entry('mediatype', .),
                    $recursive ! map:entry('recursive', .),
                    $requiresContextNode ! map:entry('requiresContextNode', .),
                    $contextXP ! map:entry('contextXP', .),
                    $targetXP ! map:entry('targetXP', .),                   
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
    $components//(@link, @linkName)
    => distinct-values()
}; 

declare function f:getLinkDefs($components as element()*, 
                               $context as map(xs:string, item()*))
        as map(*)* {
    let $linkNames := f:getLinkNamesReferenced($components) => distinct-values()
    return $linkNames ! f:linkDefObject(., $context)
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
