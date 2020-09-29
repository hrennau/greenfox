(:
 : -------------------------------------------------------------------------
 :
 : docTreeUtil.xqm - utility functions for the validation of DocTree constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/doc-tree";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "resourceAccess.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : ===============================================================================
 :
 :     E v a l u a t e    n o d e    p a t h   
 :
 : =============================================================================== 
 :)

(:~
 : Evaluates a node path.
 :
 :)
declare function f:evaluateNodePath($nodePath as xs:string,
                                    $contextNode as node()?,
                                    $namespaceContext as element()?,
                                    $options as map(xs:string, item()*)?,
                                    $context as map(xs:string, item()*))
        as node()* {
    
    if (not($contextNode)) then () else
    let $steps := f:parseNodePath($nodePath, $options, $context)
    return
        f:evaluateCompiledNodePath($steps, $contextNode, $namespaceContext, $options, $context)
};


declare function f:evaluateCompiledNodePath($compiledNodePath as element()+,
                                    $contextNode as node()?,
                                    $namespaceContext as element()?,
                                    $options as map(xs:string, item()*)?,
                                    $context as map(xs:string, item()*))
        as node()* {
    if (not($contextNode)) then () else
    
    (: Enhance options, adding namespace bindings namespaces.prefix.namespace-uri :)
    let $options :=
        if (not($namespaceContext)) then $options
        else
            let $namespaces := map:merge(
                for $prefix in in-scope-prefixes($namespaceContext)
                return map:entry($prefix, namespace-uri-for-prefix($prefix, $namespaceContext)))
            return map:put($options, 'namespaces', $namespaces)
    let $value := f:evaluateNodePathRC($compiledNodePath, $contextNode, $namespaceContext, $options, $context)
    return $value
};

(:~
 : Recursive helper function of `f:evaluateNodePath`.
 :
 : @param steps elements representing the steps of the parsed node path
 : @param contextNode the current context node
 : @param options options controling the interpretation of the node path
 : @param context the evaluation context
 : @return the nodes identified by the node path
 :)
declare function f:evaluateNodePathRC($steps as element()+,                                      
                                      $contextNode as node()?,
                                      $namespaceContext as element()?,
                                      $options as map(xs:string, item()*)?,
                                      $context as map(xs:string, item()*))
        as node()* {
    let $withNamespaces := $options?withNamespaces
    let $head := head($steps)
    let $tail := tail($steps)
    let $nextNodesRaw :=
        typeswitch($head)
        case element(root) return $contextNode/root()
        case element(child) return
            if ($head/@regex) then $contextNode/*[matches(local-name(.), $head/@regex)]
            else $contextNode/*[local-name(.) eq $head/@name]
        case element(attribute) return
            if ($head/@regex) then $contextNode/@*[matches(local-name(.), $head/@regex)]
            else $contextNode/@*[local-name(.) eq $head/@name]
        case element(descendant) return
            if ($head/@regex) then $contextNode/descendant::*[matches(local-name(.), $head/@regex)]
            else $contextNode/descendant::*[local-name(.) eq $head/@name]
        case element(descendant-attribute) return
            if ($head/@regex) then $contextNode//@*[matches(local-name(.), $head/@regex)]
            else $contextNode//@*[local-name(.) eq $head/@name]
        case element(ancestor) return
            if ($head/@regex) then $contextNode/ancestor::*[matches(local-name(.), $head/@regex)]
            else if ($head/@name) then  $contextNode/ancestor::*[local-name(.) eq $head/@name]
            else $contextNode/ancestor::*
        case element(parent) return
            if ($head/@regex) then $contextNode/ancestor::*[matches(local-name(.), $head/@regex)]
            else if ($head/@name) then $contextNode/parent::*[local-name(.) eq $head/@name]
            else $contextNode/..
        case element(self) return $contextNode            
        default return error()
        
    (: Evaluate prefix :)
    let $nextNodes :=
        if (not($head/@name)) then $nextNodesRaw else
        
        let $prefix := $head/@prefix return

        if (not($prefix)) then
            if (not($withNamespaces)) then $nextNodesRaw
            else $nextNodesRaw[not(namespace-uri(.))]
        else if ($prefix eq '*') then $nextNodesRaw
        else
            let $namespace := $options?namespaces($head/@prefix)
            return
                if (empty($namespace)) then 
                    error(QName((), 'INVALID_NODE_PATH'), concat('No namespace binding for prefix: ', 
                        $head/@prefix))
                else $nextNodesRaw[namespace-uri(.) eq $namespace]
    let $nextNodes :=
        let $index := $head/@index/xs:integer(.)
        return
            if (empty($index)) then $nextNodes
            else
                let $nodes :=
                    typeswitch($head)
                    case element(ancestor) | element(parent) return reverse($nextNodes)
                    default return $nextNodes
                return
                    if ($index lt 0) then $nodes[last() + 1 + $index]
                    else $nodes[$index]
    return 
        if (not($tail)) then $nextNodes/.
        else $nextNodes/f:evaluateNodePathRC($tail, ., $namespaceContext, $options, $context)/.
};

(:~
 : ===============================================================================
 :
 :     P a r s e    n o d e    p a t h   
 :
 : ===============================================================================
 :)

(:~
 : Parses a node path.
 :
 : @param nodePath text of the node path
 : @param options options controling interpretation of the node path
 : @param context evaluation context
 : @return node path parsed into a sequence of elements
 :)
declare function f:parseNodePath($nodePath as xs:string,
                                 $options as map(xs:string, item()*)?,
                                 $context as map(xs:string, item()*))
        as element()+ {
    (: //foo... :)
    if (starts-with($nodePath, '//')) then
        (<root/>, $nodePath ! f:parseNodePathRC(., $options, $context))
    (: /foo... :)
    else if (starts-with($nodePath, '/')) then
        (<root/>, $nodePath ! f:parseNodePathRC(., $options, $context))
    (: .../foo :)
    else if (starts-with($nodePath, '...')) then
        $nodePath ! f:parseNodePathRC(., $options, $context)
    (: ../foo :)
    else if (starts-with($nodePath, '..')) then
        $nodePath ! f:parseNodePathRC(., $options, $context)
    (: ./foo :)
    else if (matches($nodePath, '^\s*\.\s*$')) then
        <self/>
    else if (starts-with($nodePath, '.')) then
        $nodePath ! replace(., '^\.\s*', '') ! f:parseNodePathRC(., $options, $context)
    (: foo... :)        
    else ('/' || $nodePath) ! f:parseNodePathRC(., $options, $context)
};

(:~
 : Recursive helper function of `f:parseNodePath`.
 :
 : @param nodePath text of the node path
 : @param options options controling interpretation of the node path
 : @param context evaluation context
 : @return node path parsed into a sequence of elements
 :)
declare function f:parseNodePathRC($nodePath as xs:string,
                                   $options as map(xs:string, item()*)?,
                                   $context as map(xs:string, item()*))
        as element()+ {
    let $sep := codepoints-to-string(30000) return
    
    let $fn_parseStep := 
        (: Argument $char1 is / or \. :)
        function($text, $char1) {
            let $cont := replace($text, '^'||$char1||'+\s*', '')
            let $nameEtc := replace($cont, '^(.*?)?(/.*)', '$1'||$sep||'$2')
(:          let $nameEtc := replace($cont, '^(.*)?([./].*)', '$1'||$sep||'$2') :)  (: 20200926 :)
            let $nameIndex := (if (contains($nameEtc, $sep)) then substring-before($nameEtc, $sep) else $nameEtc)
                         [string()]
            let $name := (
                if (not(contains($nameIndex, '['))) then $nameIndex
                else replace($nameIndex, '\s*\[.+', '') )[string()]
            let $index :=
                if (not(contains($nameIndex, '['))) then ()
                else replace($nameIndex, '^.*\[\s*(-?\d+).*', '$1')
            let $localNameAndPrefix := 
                if (not(contains($name, ':'))) then $name
                else (substring-after($name, ':'), substring-before($name, ':'))
            (: let $localNameRaw := $localNameAndPrefix[1] :)
            let $isAttribute := starts-with($name, '@')[.]            
            (: let $localName := $localNameRaw ! replace(., '^@', '') :)
            let $localName := $localNameAndPrefix[1] ! replace(., '^@', '')
            let $prefix := $localNameAndPrefix[2] ! replace(., '^@', '')
            let $regex := $localName ! i:glob2regex(.)
            let $remains := substring-after($nameEtc, $sep)[string()]
            return
                map{'name': $localName ! attribute name {.},
                    'prefix': $prefix ! attribute prefix {.},   
                    'regex': attribute regex {$regex} ['^'||$localName||'$' ne $regex],
                    'index': $index ! attribute index {.},
                    'isAttribute': $isAttribute ! attribute isAttribute {.},
                    'remains': $remains} 
         
        }
    return
    
    (: Descentant step :)
    if (starts-with($nodePath, '//')) then
        let $parts := $fn_parseStep($nodePath, '/')
        return (
            if ($parts?isAttribute) then
                <descendant-attribute>{$parts?name, $parts?regex, $parts?prefix, $parts?index}</descendant-attribute>
            else
                <descendant>{$parts?name, $parts?regex, $parts?prefix, $parts?index}</descendant>,
            $parts?remains ! f:parseNodePathRC(., $options, $context)
        )    
    else if (starts-with($nodePath, '/')) then
        let $parts := $fn_parseStep($nodePath, '/')
        return (
            if ($parts?isAttribute) then
                <attribute>{$parts?name, $parts?regex, $parts?prefix, $parts?index}</attribute>
            else
                <child>{$parts?name, $parts?regex, $parts?prefix, $parts?index}</child>,
            $parts?remains ! f:parseNodePathRC(., $options, $context)
        )    
    else if (starts-with($nodePath, '...')) then
        let $parts := $fn_parseStep($nodePath, '\.')
        return (
            <ancestor>{$parts?name, $parts?regex, $parts?prefix, $parts?index}</ancestor>,
            $parts?remains ! f:parseNodePathRC(., $options, $context)
        )    
    else if (starts-with($nodePath, '..')) then
        let $parts := $fn_parseStep($nodePath, '\.')
        return (
            <parent>{$parts?name, $parts?regex, $parts?prefix, $parts?index}</parent>,
            $parts?remains ! f:parseNodePathRC(., $options, $context)
        )    
    else if (starts-with($nodePath, '.')) then
        replace($nodePath, '^\.\s*', '')[string()] ! f:parseNodePathRC(., $options, $context)
    else error()    
};

(:~
 : ===============================================================================
 :
 :     U t i l i t y    f u n c t i o n s   
 :
 : =============================================================================== 
 :)

(:~
 : Returns true if the name of a given node matches the name constraints
 : of at least one compiled node path step. This function is used
 : when checking closed constraints, comparing the names of attributes
 : and elements against the child and attribute paths used by the
 : <node> child elements of the <node> element to be checked, representing
 : the content model to be checked.
 :
 : @param node the name whose name is checked
 : @param steps compiled node path steps
 : @param withNamespaces if true, lack of prefix means no target namespace
 : @param namespaceContext element used as namespace context
 : @return true if the node name matches at least one step
 :)
declare function f:nodeNameMatchesNodePathStep($node as node(), 
                                               $steps as element()*, 
                                               $furtherLocalNames as xs:string*,
                                               $furtherQNames as xs:QName*,
                                               $withNamespaces as xs:boolean?, 
                                               $namespaceContext as element())
        as xs:boolean {
    let $lname := $node/local-name(.)
    return
    (
    some $step in $steps satisfies
    (
        $step/@regex/matches($lname, .) or
        $step/@name eq $lname
    ) and 
    (
        not($step/@prefix) and (not($withNamespaces) or not($step/namespace-uri(.)))
        or
        $step/@prefix/namespace-uri-for-prefix(., $namespaceContext) eq $node/namespace-uri(.)
    )
    )
    or not($withNamespaces) and $lname = $furtherLocalNames    
    or ($withNamespaces) and $node/node-name(.) = $furtherQNames

       
};        

