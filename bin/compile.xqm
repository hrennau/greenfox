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
 : Compiles a quality descriptor and returns an augmented copy of the descriptor, plus
 : a context map. The context map consists of the context map contained by the
 : quality descriptor, extended/overwritten by the name-value pairs supplied as
 : external context. In the augmented descriptor, components with a component
 : reference are replaced with the referenced component, augmented with the
 : attributes and content elements of the referencing component.
 :)
declare function f:compileGfox($gxdoc as element(gx:greenFox), $externalContext as map(*)) 
        as item()+ {
    let $context := map:merge((
        $externalContext,
        for $field in $gxdoc/gx:context/gx:field
        let $name := $field/@name
        let $value := $field/@value
        return
            if (map:contains($externalContext, $name)) then () else 
                map:entry($name, $value)
        )                
    )
    return (
        f:compileGfoxRC($gxdoc, $context, ()),
        $context
    )
};

(:~
 : Recursive helper function of `f:compileGfox`.
 :
 : @param n a node of the quality descriptor currently processed.
 : @return the processing result
 :)
declare function f:compileGfoxRC($n as node(), $context as map(*), $callContext as map(*)?) as node() {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:compileGfoxRC(., $context, $callContext)}
    case element(gx:greenFox) return
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
