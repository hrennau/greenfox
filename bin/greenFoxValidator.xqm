(:
 : -------------------------------------------------------------------------
 :
 : domainValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_foxpath.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "fileValidator.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateGreenFox($gfox as element(gx:greenfox)) 
        as element()* {
    let $errors := (
    
        let $xpathExpressions := $gfox//gx:xpath[not(ancestor-or-self::*[@deactivated eq 'true'])]/@expr
        for $expr in $xpathExpressions
        
        let $requiredBindings := i:determineRequiredBindingsXPath($expr, ('this', 'doc', 'jdoc', 'csvdoc'))        
        let $augmentedExpr := i:finalizeQuery($expr, $requiredBindings)
        
        return
            try {
                let $plan := xquery:parse($augmentedExpr)
                return ()
            } catch * {
                <gx:error code="INVALID_XPATH" msg="Invalid XQuery expression" expr="{$expr}" file="{base-uri($expr/..)}" loc="{$expr/f:greenfoxLocation(.)}">{
                    $err:code ! attribute err:code {.},
                    $err:description ! attribute err:description {.},
                    $err:value ! attribute err:value {.},
                    ()
                }</gx:error>
            }                
               
        ,
        let $foxpathExpressions := $gfox/descendant-or-self::*[not(ancestor-or-self::*[@deactivated eq 'true'])]/@foxpath
        for $expr in $foxpathExpressions        
        let $plan := f:parseFoxpath($expr)
        
        return
            if ($plan/self::*:errors) then
                <gx:error code="INVALID_FOXPATH" msg="Invalid foxpath expression" expr="{$expr}" file="{base-uri($expr/..)}" loc="{$expr/f:greenfoxLocation(.)}">{
                    $plan
                }</gx:error>
    )
    return
        <gx:invalidGreenFox countErrors="{count($errors)}" xmlns:err="http://www.w3.org/2005/xqt-errors">{$errors}</gx:invalidGreenFox>[$errors]
};

declare function f:greenfoxLocation($node as node()) as xs:string {
    (
        for $node in $node/ancestor-or-self::node()
        let $index := 1 + $node/count(preceding-sibling::*[node-name(.) eq $node/node-name(.)])
        return
            if ($node/self::attribute()) then $node/concat('@', local-name(.))
            else if ($node/self::element()) then $node/concat(local-name(.), '[', $index, ']')
            else ''            
    ) => string-join('/')
};
