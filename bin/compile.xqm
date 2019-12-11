(:
 : -------------------------------------------------------------------------
 :
 : compile.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Compiles a greenfox schema and returns an augmented copy of the descriptor, plus
 : a context map. The context map consists of the context map contained by the
 : schema, extended/overwritten by the name-value pairs supplied as
 : external context. In the augmented descriptor, components with a component
 : reference are replaced with the referenced component, augmented with the
 : attributes and content elements of the referencing component.
 :
 : @param gfox a greenfox schema
 : @param externalContext a set of external variables
 :)
declare function f:compileGfox($gxdoc as element(gx:greenfox), 
                               $externalContext as map(*)) 
        as item()+ {
    let $context := map:merge(
        for $field in $gxdoc/gx:context/gx:field
        let $name := $field/@name
        let $value := ($externalContext($name), $field/@value)[1]
        return
            map:entry($name, $value) 
    )
    let $gxdoc2 := f:compileGfoxRC($gxdoc, $context)
    let $gxdoc3 := f:compileGfox_addIds($gxdoc2)
    let $gxdoc4 := f:compileGfox_addIds2($gxdoc3)
    return
        ($gxdoc4, $context)
};

(:~
 : Recursive helper function of `f:compileGfox`.
 :
 : @param n a node of the greenfox schema currently processed.
 : @param context a set of external variables
 : @return the processing result
 :)
declare function f:compileGfoxRC($n as node(), $context as map(*)) as node() {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:compileGfoxRC(., $context)}
    
    case element(gx:greenfox) return
        element {node-name($n)} {
            $n/@* ! f:compileGfoxRC(., $context),
            if ($n/@xml:base) then () else attribute xml:base {base-uri($n)},
            $n/node() ! f:compileGfoxRC(., $context) 
        }
    case element() return
        element {node-name($n)} {
            $n/@* ! f:compileGfoxRC(., $context),
            $n/node() ! f:compileGfoxRC(., $context)            
        }
        
    (: text - variable substitution :)
    case text() return text {f:substituteVars($n, $context, ())}
    
    (: attribute - variable substitution :)
    case attribute() return attribute {node-name($n)} {f:substituteVars($n, $context, ())}
    
    default return $n        
};

(:
(:~
 : Recursive helper function of `f:compileGfox`.
 :
 : @param n a node of the greenfox schema currently processed.
 : @return the processing result
 :)
declare function f:compileGfoxRC($n as node(), $context as map(*), $callContext as map(*)?) as node() {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:compileGfoxRC(., $context, $callContext)}
    case element(gx:greenfox) return
        element {node-name($n)} {
            $n/@* ! f:compileGfoxRC(., $context, $callContext),
            if ($n/@xml:base) then () else attribute xml:base {base-uri($n)},
            (: in-scope-prefixes($n) ! namespace {.} {namespace-uri-for-prefix(., $n)}, :)
            $n/node() ! f:compileGfoxRC(., $context, $callContext) 
        }
    case element() return
        (: $elem is either the referenced component, or the original component :)
        let $elem := 
            if ($n/@ref) then f:compileGfox_resolveReference($n)
            else $n
        (: in case of a reference, the $callContext is augmented by the name-value pairs
           of attributes with a __ name :)
        let $newCallContext :=
            if (not($n/@ref)) then $callContext
            else
                (: extend call context with name-value pairs from __ attributes :)
                let $paramAtts := $n/@*[starts-with(local-name(), '__')]
                return
                    map:merge(($callContext,
                        for $paramAtt in $paramAtts
                        let $name := $paramAtt/substring(local-name(.), 3)
                        return map:entry($name, $paramAtt/string())
                    ))
        return        
            element {node-name($elem)} {
                ($elem/@* | $n/(@* except @ref)) ! f:compileGfoxRC(., $context, $newCallContext),
                $elem/node() ! f:compileGfoxRC(., $context, $newCallContext),
                (: in case of a reference, append content to the content of the referenced component :)
                if (not($n/@ref)) then () else $n/*/f:compileGfoxRC(., $context, ())
            }
    (: text - variable substitution :)
    case text() return text {f:substituteVars($n, $context, $callContext)}
    (: attribute - variable substitution :)
    case attribute() return attribute {node-name($n)} {f:substituteVars($n, $context, $callContext)}
    default return $n        
};
:)

(:~
 : Inspects a component and returns another component which it references, or the original 
 : component if it does not reference another component. A reference is expressed by an 
 : @ref attribute. The referenced component is the checklib element with an @id attribute 
 : matching the value of @ref and with a local name matching the local name of the 
 : referencing component.
 :
 : @param gxComponent a component possibly referencing another component
 : @return the original component, if it does not have a reference, or the
 :   referenced component
 :)
declare function f:compileGfox_resolveReference($gxComponent as element()) as element() {
    if (not($gxComponent/@ref)) then $gxComponent else
    
    let $gxname := local-name($gxComponent)
    let $target := $gxComponent/root()//gx:checklib/*[$gxname eq local-name(.)][@id eq $gxComponent/@ref]
    return
        $target
};

(:~
 : Substitutes variable references with variable values. The references have the form ${name} or
 : @{name}. References using the dollar character are resolved using $context, and references
 : using the @ character are resolved using $callContext.
 :
 : @param s a string
 : @param context a context which is a map associating key strings with value strings
 : @param callContext a second context
 : @return a copy of the string with all variable references replaced with variable values
 :)
declare function f:substituteVars($s as xs:string?, $context as map(*), $callContext as map(*)?) as xs:string? {
    let $s2 := f:substituteVarsAux($s, $context, '\$')
    return
        if (empty($callContext)) then $s2    
        else f:substituteVarsAux($s2, $callContext, '@') 
};

(:~
 : Auxiallary function of `f:substituteVars`.
 :
 : @param s a string
 : @param context a context which is a map associating key strings with value strings
 : @param callContext a second context
 : @return a copy of the string with all variable references replaced with variable values
 :) 
declare function f:substituteVarsAux($s as xs:string?, $context as map(*), $prefixChar as xs:string) as xs:string? {
    let $sep := codepoints-to-string(30000)
    let $parts := replace($s, concat('^(.*?)(', $prefixChar, '\{.*?\})(.*)'), concat('$1', $sep, '$2', $sep, '$3'))
    return
        if ($parts eq $s) then $s
        else
            let $partStrings := tokenize($parts, $sep)
            let $prefix := $partStrings[1]
            let $varRef := $partStrings[2]
            let $postfix := $partStrings[3][string()]
            let $varName := $varRef ! substring(., 3) ! substring(., 1, string-length(.) - 1)
            let $varValue := $context($varName)            
            return
                concat($prefix, ($varValue, $varRef)[1], $postfix ! f:substituteVarsAux(., $context, $prefixChar))                
};

(:~
 : Maps the value of a string to a set of name-value pairs.
 :
 : @param params a string containing concatenated name-value pairs
 : @return a map expressing the pairs a key-value pairs
 :)
declare function f:externalContext($params as xs:string?) as map(*) {
    let $nvpairs := tokenize($params, '\s*;\s*')
    return
        map:merge(
            $nvpairs ! 
            map:entry(replace(., '\s*=.*', ''), 
                      replace(., '^.*?=\s*', '')
            )
        )
};

declare function f:compileGfox_addIds($gfox as element(gx:greenfox)) {
    copy $gfox_ := $gfox
    modify
        let $elems := ($gfox_//*) except ($gfox_/gx:context/descendant-or-self::*)
        for $elem in $elems
        group by $localName := local-name($elem)
        return
            for $e at $pos in $elem
            let $idAtt := $e/@id
            let $id := ($idAtt, concat($localName, '_', $pos))[1]
            let $furtherAtts:= trace(
                typeswitch($elem[1])
                case element(gx:file) | element(gx:folder) return
                    attribute resourceShapeID {$id}
                case element(gx:xpath) | element(gx:foxpath) return
                    attribute valueShapeID {$id}
                default return () , 'FURTHER_ATTS: ')
            return (
                $idAtt/(delete node .),
                insert node ($furtherAtts, attribute id {$id}) as first into $e                
            )                
    return $gfox_                
};

declare function f:compileGfox_addIds2($gfox as element(gx:greenfox)) {
    f:compileGfox_addIds2RC($gfox)
};

declare function f:compileGfox_addIds2RC($n as node()) {
    typeswitch($n)
    case element(gx:file) | element(gx:folder) return
        element {node-name($n)} {
            $n/@* ! f:compileGfox_addIds2RC(.),
            $n/node() ! f:compileGfox_addIds2RC(.)
        }
    case element(gx:targetSize) return
        let $resourceShapeID := $n/ancestor::*[self::gx:file, self::gx:folder][2]/@resourceShapeID
        return
            element {node-name($n)} {
                $resourceShapeID,
                $n/@* ! f:compileGfox_addIds2RC(.),
                $n/node() ! f:compileGfox_addIds2RC(.)
            }
    case element() return
        let $resourceShapeID :=
            if ($n/(self::gx:xpath,
                    self::gx:foxpath,
                    self::gx:fileSize, 
                    self::gx:lastModified, 
                    self::gx:mediatype,
                    self::gx:folderContent,
                    self::gx:xsdValid
               )) then  
                $n/ancestor::*[self::gx:file, self::gx:folder][1]/@resourceShapeID
            else ()                
        return
            element {node-name($n)} {
                $resourceShapeID,
                $n/@* ! f:compileGfox_addIds2RC(.),
                $n/node() ! f:compileGfox_addIds2RC(.)
            }
    default return $n        
};

