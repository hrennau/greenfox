(:
 : -------------------------------------------------------------------------
 :
 : linkDefinition.xqm - functions for managing link definitions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/greenlink";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    
    
import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkResolution.xqm";

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "foxpathUtil.xqm",
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
            let $ldo := $linkDefElem/f:parseLinkDef(., $context)
            return
                if (empty($ldo)) then
                    error(QName((), 'INVALID_SCHEMA'), concat('Element does not reference or ',
                        'define a valid link definition; element name: ', name($linkDefElem)))    
                else $ldo                        
(:            
            let $linkName := trace($linkDefElem/(@linkName, @link)[1] , '+++ LINK_NAME: ')
            return
                if ($linkName) then
                    let $try := link:linkDefObject($linkName, $context)
                    return
                        if (empty($try)) then error((), concat('Unknown link name: ', $linkName))
                        else $try
                else
                    (: Try to parse the element into a Link Definition; if not possible,
                       the empty sequence is returned :)
                    link:parseLinkDef($linkDefElem, $context)
:)                    
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
declare function f:parseLinkDefs($linkDefs as element()*, $context as map(xs:string, item()*))
        as map(*) {
    map:merge(        
        for $linkDef in $linkDefs
        let $name := $linkDef/@name/string()
        let $ldo := f:parseLinkDef($linkDef, $context)
        return map:entry($name, $ldo)
    )
};    

(:~
 : Parses an element into a Link Definition Object. Parsing fails if none
 : of the following items is found:
 : - @foxpath
 : - @hrefXP
 : - @uriXP
 : - @uri
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
declare function f:parseLinkDef($linkDef as element(),
                                $context as map(xs:string, item()*))
        as map(*)? {
    let $referenced := $linkDef/@linkName/f:linkDefObject(., $context)    
    let $foxpath := ($linkDef/(@navigateFOX, @foxpath)[1]/string(), $referenced?foxpath)[1]
    let $hrefXP := ($linkDef/@hrefXP/string(), $referenced?hrefXP)[1]
    let $uriXP := ($linkDef/@uriXP/string(), $referenced?uriXP)[1]
    let $uri := ($linkDef/@uri/string(), $referenced?uri)[1]    
    let $uriTemplate := ($linkDef/@uriTemplate, $referenced?uriTemplate)[1]
    let $mirrorRef := $referenced?mirror
    let $reflector1URI := $linkDef/@reflector1URI/string()
    let $reflector2URI := $linkDef/@reflector2URI/string()
    let $reflector1FOX := $linkDef/@reflector1FOX/string()
    let $reflector2FOX := $linkDef/@reflector2FOX/string()
    let $reflectedReplaceSubstring := $linkDef/@reflectedReplaceSubstring/string()
    let $reflectedReplaceWith := $linkDef/@reflectedReplaceWith/string()
    let $recursive := ($linkDef/@recursive/string(), $referenced?recursive)[1]
    let $contextXP := ($linkDef/@contextXP/string(), $referenced?contextXP)[1]
    let $targetXP := ($linkDef/@targetXP/string(), $referenced?targetXP)[1]            
    let $mediatype := ($linkDef/@mediatype/string(), $referenced?mediatype)[1]
    let $csvSeparator := ($linkDef/@csv.separator/string(), $referenced?csv.separator)[1]
    let $csvHeader := ($linkDef/@csv.header/string(), $referenced?csv.header)[1]
    let $csvFormat := ($linkDef/@csv.format/string(), $referenced?csv.format)[1]
    let $csvLax := ($linkDef/@csv.lax/string(), $referenced?csv.lax)[1]
    let $csvQuotes := ($linkDef/@csv.quotes/string(), $referenced?csv.quotes)[1]
    let $csvBackslashes := ($linkDef/@csv.backslashes/string(), $referenced?csv.backslashes)[1]
    let $templateVarsDef := $linkDef/gx:templateVar
    let $templateVarsRef := $referenced?templateVars
    let $constraintsDef := $linkDef[self::gx:linkDef]/gx:targetSize
    let $constraintsRef := $referenced?constraints
    
    (: Build the map of templates vars; key=name, value=XML element with @value :)
    let $templateVarsMap :=
        if (empty($templateVarsDef)) then $templateVarsRef
        else if (empty($templateVarsRef)) then 
            if (empty($templateVarsDef)) then () 
            else map:merge($templateVarsDef/map:entry(@name, .))
        else
            map:merge((
                let $names := ($templateVarsDef/@name, map:keys($templateVarsRef)) => distinct-values()
                for $name in $names return
                    map:entry($name, ($templateVarsDef[@name eq $name], $templateVarsRef($name))[1])
            ))
    (: Build the map of mirror parameters :)            
    let $mirrorMap :=
        if (empty(($reflector1URI, $reflector2URI, $reflector1FOX, $reflector2FOX, $reflectedReplaceSubstring, $reflectedReplaceWith))) then $mirrorRef        
        else if (empty($mirrorRef)) then
            map{
                'reflector1URI': $reflector1URI,
                'reflector2URI': $reflector2URI,
                'reflector1FOX': $reflector1FOX,
                'reflector2FOX': $reflector2FOX,
                'reflectedReplaceSubstring': $reflectedReplaceSubstring,
                'reflectedReplaceWith': $reflectedReplaceWith
            }
        else            
            map{
                'reflector1URI': ($reflector1URI, $mirrorRef?reflector1URI)[1],
                'reflector2URI': ($reflector2URI, $mirrorRef?reflector2URI)[1],
                'reflector1FOX': ($reflector1FOX, $mirrorRef?reflector1FOX)[1],
                'reflector2FOX': ($reflector2FOX, $mirrorRef?reflector2FOX)[1],
                'reflectedReplaceSubstring': ($reflectedReplaceSubstring, $mirrorRef?reflectedReplaceSubstring)[1],
                'reflectedReplaceWith': ($reflectedReplaceWith, $mirrorRef?reflectedReplaceWith)[1]
            }
    return
        if (empty((
            $foxpath, $hrefXP, $uriXP, $uri, $uriTemplate, $mirrorMap,
                $recursive, $contextXP, $targetXP, $constraintsRef, $templateVarsMap))) then () 
        else
    
    let $ldo :=       
        map:merge(        
            let $connector :=
                if ($foxpath) then 'foxpath'
                else if ($hrefXP) then 'hrefExpr'
                else if ($uriXP) then 'uriExpr'
                else if ($uri) then 'uri'                
                else if ($uriTemplate) then 'uriTemplate'
                else if (exists($mirrorMap)) then 'mirror'
                else error(QName((), 'INVALID_SCHEMA'), 'Cannot determine link connector')
        
            let $requiresContextNode :=
                    $connector = ('links', 'hrefExpr', 'uriExpr', 'uriTemplate')
                    or $contextXP
            let $mediatype :=
                if ($mediatype) then $mediatype 
                else if ($targetXP) then 'xml' 
                else if ($recursive and $requiresContextNode) then 'xml'
                else () 
            let $csvProperties := (
                $csvSeparator ! map:entry('csv.separator', .),
                $csvHeader ! map:entry('csv.header', .),
                $csvFormat ! map:entry('csv.format', .),
                $csvLax ! map:entry('csv.lax', .),
                $csvQuotes ! map:entry('csv.quotes', .),
                $csvBackslashes ! map:entry('csv.backslashes', .)
            )
            return
                map:merge((
                    $connector ! map:entry('connector', .),
                    $requiresContextNode ! map:entry('requiresContextNode', .),                    
                    $foxpath ! map:entry('foxpath', .),
                    $hrefXP ! map:entry('hrefXP', .),
                    $uriXP ! map:entry('uriXP', .),
                    $uri ! map:entry('uri', .),                    
                    $uriTemplate ! map:entry('uriTemplate', .),                    
                    $mediatype ! map:entry('mediatype', .),
                    $recursive ! map:entry('recursive', string(.)),
                    $contextXP ! map:entry('contextXP', string(.)),
                    $targetXP ! map:entry('targetXP', string(.)),   
                    $csvProperties,                    
                    $templateVarsMap ! map:entry('templateVars', .),
                    $mirrorMap ! map:entry('mirror', .),
                    ($constraintsDef, $constraintsRef)[1] ! map:entry('constraints', .)                            
                )))
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
declare function f:getLinkMMediatype($ldo as map(xs:string, item()*),
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
             @countTargetNodes, @minCountTargetNodes, @maxCountTargetNodes,
             @countTargetDocsPerContextPoint, @minCountTargetDocsPerContextPoint, @maxCountTargetDocsPerContextPoint,
             @countTargetNodesPerContextPoint, @minCountTargetNodesPerContextPoint, @maxCountTargetDonesPerContextPoint))             
            then 'xml'
        else ()
};        
