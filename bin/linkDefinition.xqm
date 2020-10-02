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
 : Returns the Link Definition defined or referenced by a given item.
 : The item can be the link name, given by a string or attribute; it
 : may be a Link Definition object; and it may be an element either
 : referencing a Link Definition (via @linkName) or providing a
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
                    (: Try to parse the element into a Link Definition; if not possible,
                       the empty sequence is returned :)
                    link:parseLinkDef($linkDefElem)
        default return error((), 'Parameter $linkDef must be a string, an object or an element')
    return $ldo        
};

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
 : Parses an element into a Link Definition Object. Parsing fails if none
 : of the following items is found:
 : - @foxpath
 : - @hrefXP
 : - @uriXP
 : - @uriTemplate
 : - @uriReflectionBase
 :
 : When parsing fails, the element does not represent a Link Definition and
 : the empty sequence is returned.
 :
 : @param linkDef an element defining a link
 : @return a Link Definition Object, or the empty sequence if the element does not
 :   represent a Link Definition
 :)
declare function f:parseLinkDef($linkDef as element())
        as map(*)? {
    let $foxpath := $linkDef/@foxpath/string()
    let $hrefXP := $linkDef/@hrefXP/string()
    let $uriXP := $linkDef/@uriXP/string()
    let $uriTemplate := $linkDef/@uriTemplate
    let $uriReflectionBase := $linkDef/@uriReflectionBase/string()    
    return
        if (empty((
            $foxpath, $hrefXP, $uriXP, $uriTemplate, $uriReflectionBase))) then () else
            
    let $recursive := $linkDef/@recursive/string()
    let $contextXP := $linkDef/@contextXP/string()
    let $targetXP := $linkDef/@targetXP/string()            
    let $uriReflectionShift := $linkDef/@uriReflectionShift/string()
    let $constraints := $linkDef/gx:constraints    
    let $templateVars := $linkDef/gx:templateVar            
    let $ldo :=        
        map:merge(        
            let $connector :=
                if ($foxpath) then 'foxpath'
                else if ($hrefXP) then 'hrefExpr'
                else if ($uriXP) then 'uriExpr'
                else if ($uriTemplate) then 'uriTemplate'
                else if ($uriReflectionBase) then 'uriReflection'                    
                else error()
        
            let $requiresContextNode :=
                    $connector = ('links', 'hrefExpr', 'uriExpr', 'uriTemplate')
                    or $contextXP
            let $targetMediatype :=
                let $explicit := $linkDef/@targetMediatype/string()
                return
                    if ($explicit) then $explicit 
                    else if ($targetXP) then 'xml' 
                    else if ($recursive and $requiresContextNode) then 'xml'
                    else () 
            let $csvAtts :=
                $linkDef/(@csv.separator, @csv.header, @csv.format, @csv.lax, @csv.quotes, @csv.backslashes)
            return
                map:merge((
                    $connector ! map:entry('connector', .),
                    $requiresContextNode ! map:entry('requiresContextNode', .),                    
                    $foxpath ! map:entry('foxpath', .),
                    $hrefXP ! map:entry('hrefXP', .),
                    $uriXP ! map:entry('uriXP', .),
                    $uriTemplate ! map:entry('uriTemplate', .),                    
                    $targetMediatype ! map:entry('targetMediatype', .),
                    $recursive ! map:entry('recursive', string(.)),
                    $contextXP ! map:entry('contextXP', string(.)),
                    $targetXP ! map:entry('targetXP', string(.)),   
                    $csvAtts ! map:entry(local-name(.), string(.)),
                    
                    if (not($templateVars)) then () else
                        map:entry('templateVars', map:merge($templateVars ! map:entry(@name, .))),
                        
                    $uriReflectionBase ! map:entry('uriReflection', 
                        map{'base': $uriReflectionBase, 
                            'shift': $uriReflectionShift}),
                            
                    $constraints ! map:entry('constraints', $constraints)                            
                ))
    )
    return $ldo
};    

(:~
 : Returns the names of all Link Definitions referenced within a set of components.
 :
 : This function encapsulates the knowledge about items (attributes,
 : elements) containing link names. It is called, for example, by function 
 : 'getRequiredBindings', which needs to find all expressions used by a set 
 : of components.
 :
 : @param component the components to be investigated
 : @return the relationship names
 :)
declare function f:getLinkNamesReferenced($components as element()*)
        as xs:string* {
    $components//@linkName => distinct-values()
}; 

(:~
 : Returns the Link Definition objects referenced within a set of components.
 :
 : @param component the components to be investigated
 : @return the relationship names
 :)
declare function f:getLinkDefs($components as element()*, 
                               $context as map(xs:string, item()*))
        as map(*)* {
    let $linkNames := f:getLinkNamesReferenced($components) => distinct-values()
    return $linkNames ! f:linkDefObject(., $context)
}; 

(:~
 : Returns the Link Definition object identified by a link name.
 :
 : @param linkName link name
 : @param context the processing context
 : @return the Link Definition object, or the empty sequence, if no object is found
 :)
declare function f:linkDefObject($linkName as xs:string, 
                                 $context as map(xs:string, item()*))
        as map(*)? {
    $context?_resourceRelationships($linkName)        
};        

(:~
 : Returns the expected mediatype of link targets. The mediatype is either
 : explicitly specified (@mediatype), or can be inferred from link
 : definition details (@recursive), or can be inferred from link
 : constraints (@countTargetDocs, @countTargetNodes, 
 : @countTargetDocsPerContextPoint, @countTargetNodesPerContextPoint)
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
    let $explicit := $ldo?targetMediatype
    return
        if ($explicit) then $explicit
        else if ($ldo?recursive) then 'xml'
        else if ($lde/@recursive) then 'xml'
        else if ($allConstraintElems/
            (@countTargetDocs, @minCountTargetDocs, @maxCountTargetDocs,
             @countTargetNodes, @minCountTargetNodes, @maxCountTargetNodes,
             @countTargetDocsPerContextPoint, @minCountTargetDocsPerContextPoint, @maxCountTargetDocsPerContextPoint,
             @countTargetNodesPerContextPoint, @minCountTargetNodesPerContextPoint, @maxCountTargetDonesPerContextPoint))             
            then 'xml'
        else ()
};        
