(:
 : -------------------------------------------------------------------------
 :
 : docContentUtil.xqm - utility functions for the validation of DocContent constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/doc-content";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "resourceAccess.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Evaluates a node path.
 :
 :)
declare function f:evaluateNodePath($nodePath as xs:string,
                                    $contextNode as node()?,
                                    $options as map(xs:string, item()*)?,
                                    $context as map(xs:string, item()*))
        as node()* {
    
    if (not($contextNode)) then () else
    
    let $steps := trace(f:parseNodePath($nodePath, $options, $context) , '_STEPS: ')
    let $value := f:evaluateNodePathRC($steps, $contextNode, $options, $context)
    return $value
};

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
    if (starts-with($nodePath, '//')) then (
        <root/>,
        $nodePath ! f:parseNodePathRC(., $options, $context)
    (: /foo... :)
    ) else if (starts-with($nodePath, '/')) then (
        <root/>,
        $nodePath ! f:parseNodePathRC(., $options, $context)
    (: .../foo, ../foo, .//foo :)
    ) else if (starts-with($nodePath, '...')) then (
        $nodePath ! f:parseNodePathRC(., $options, $context)
    (: foo... :)        
    ) else ('/' || $nodePath) ! f:parseNodePathRC(., $options, $context)
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
    let $_DEBUG := trace($nodePath, '_NODE_PATH: ')
    let $fn_parseStep :=        
        function($text, $char1) {
            let $cont := trace(replace($text, '^'||$char1||'+\s*', '') , '_CONT: ')
            let $nameEtc := trace(replace($cont, '^(.*)?([./].*)', '$1'||$sep||'$2') , '_NAME_PLUS: ')
            let $name := if (contains($nameEtc, $sep)) then substring-before($nameEtc, $sep) else $nameEtc
            let $regex := i:glob2regex($name)
            let $remains := substring-after($nameEtc, $sep)[string()]
            return
                map{'name': attribute name {$name},
                    'regex': attribute regex {$regex} [$name ne $regex],
                    'remains': $remains} 
         
        }
    return
    
    if (starts-with($nodePath, '//')) then
        let $parts := $fn_parseStep($nodePath, '/')
        return (
            <descendant>{$parts?name, $parts?regex}</descendant>,
            $parts?remains ! f:parseNodePathRC(., $options, $context)
        )    
    else if (starts-with($nodePath, '/')) then
        let $parts := $fn_parseStep($nodePath, '/')
        return (
            <child>{$parts?name, $parts?regex}</child>,
            $parts?remains ! f:parseNodePathRC(., $options, $context)
        )    
    else if (starts-with($nodePath, '...')) then
        let $parts := $fn_parseStep($nodePath, '\.')
        return (
            <ancestor>{$parts?name, $parts?regex}</ancestor>,
            $parts?remains ! f:parseNodePathRC(., $options, $context)
        )    
    else if (starts-with($nodePath, '..')) then
        let $parts := $fn_parseStep($nodePath, '\.')
        return (
            <parent>{$parts?name, $parts?regex}</parent>,
            $parts?remains ! (., $options, $context)
        )    
    else if (starts-with($nodePath, '.')) then
        replace($nodePath, '^\.\s*', '')[string()] ! f:parseNodePathRC(., $options, $context)
    else error()    
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
                                      $options as map(xs:string, item()*)?,
                                      $context as map(xs:string, item()*))
        as node()* {
    let $head := trace(head($steps) , '_HEAD: ')
    let $tail := tail($steps)
    let $nextNodes :=
        typeswitch($head)
        case element(root) return $contextNode/root()
        case element(child) return
            if ($head/@regex) then $contextNode/*[matches(local-name(.), $head/@regex)]
            else $contextNode/*[local-name(.) eq $head/@name]
        case element(descendant) return
            if ($head/@regex) then $contextNode/descendant::*[matches(local-name(.), $head/@regex)]
            else $contextNode/descendant::*[local-name(.) eq $head/@name]
        default return error()  
    return 
        if (not($tail)) then $nextNodes/.
        else $nextNodes/f:evaluateNodePathRC($tail, ., $options, $context)/.
};
