(:
 : -------------------------------------------------------------------------
 :
 : linkResolver.xqm - functions resolving links
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm",
    "log.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n s    r e s o l v i n g    l i n k s
 :
 : ============================================================================ :)

(:~
 : Resolves links specified by an expression producing the file paths (relative or
 : absolute) of link targets. Returns for each link a link object, which is a map
 : providing the link value (as obtained from the expression), the link URI (obtained
 : by resolving against the base URI), the filepath of the link defining document
 : (often called the "context"), the parsed target document (if mediatype is XML or 
 : JSON and if the link could be resolved) and an optional error code. Absence/presence 
 : of an errorCode means successful/failed link resolution. If $recursive is true, 
 : links are resolved recursively. Recursive resolving means that the expression 
 : producing the link values is applied to the documents obtained by resolving the 
 : link.
 :
 : @param expr expression producing the file paths of link targets (relative or absolute)
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param mediatype the mediatype of link targets
 : @param recursive flag indicating if links are resolved recursively
 : @param context the processing context
 : @return maps describing links, either containing the resolved target or information about 
 :   failure to resolve the link
 :)
declare function f:resolveLinks(
                             $expr as xs:string,
                             $contextNode as node(),
                             $filepath as xs:string,
                             $mediatype as xs:string?,
                             $recursive as xs:boolean?,
                             $context as map(xs:string, item()*))
        as map(xs:string, item()*)* {
    let $linkMaps := f:resolveLinksRC($expr, $contextNode, $filepath, $mediatype, $recursive, $context, (), ())
    
    (: There may be duplicates to be removed, as recursive descents happen in parallel :)
    let $linkMapsDedup :=
        for $linkMap in $linkMaps
        group by $uri := $linkMap?uri
        return
            if (not($uri)) then $linkMap
            else $linkMap[1]
    return
        $linkMapsDedup
};

(:~
 : Recursive helper function of `resolveLinks`.
 :
 : @param expr expression producing the file paths of linke targets (relative or absolute)
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param mediatype the mediatype of link targets
 : @param recursive flag indicating if links are resolved recursively
 : @param context the processing context
 : @param pathsSofar file paths of link targets already visited and successfully resolved
 : @param errorsSofar file paths of link targets already visited and found unresolvable 
 : @return maps describing links, either containing the resolved target or information about 
 :   failure to resolve the link
 :)
declare function f:resolveLinksRC($expr as xs:string,
                                  $contextNode as node(),
                                  $filepath as xs:string,                                  
                                  $mediatype as xs:string?,
                                  $recursive as xs:boolean?,
                                  $context as map(xs:string, item()*),
                                  $pathsSofar as xs:string*,
                                  $errorsSofar as xs:string*)
        as map(xs:string, item()*)* {
    (: let $_DEBUGWRITE := file:append('DEBUG.txt', concat('#_FILEPATH: ', $filepath, '&#xA;')) :)
    
    let $exprValue := f:resolveLinkExpression($expr, $contextNode, $context)    
    let $targetsAndErrors :=   
        for $linkValue in $exprValue
        (:
        let $baseUri := (
            $linkValue[. instance of node()]/ancestor-or-self::*[1]/base-uri(.)
                      [string()]
                      [. ne static-base-uri()],
            $filepath
        )[1]
        :)
        let $baseUri := $filepath
        let $uri := i:fox-resolve-uri($linkValue, $baseUri)
        (:
        let $_DEBUGWRITE := file:append('DEBUG.txt', concat('#_LINKVALU: ', $linkValue, '&#xA;'))
        let $_DEBUGWRITE := file:append('DEBUG.txt', concat('#_URI_____: ', $uri, '&#xA;'))
         :)
        where not($uri = ($pathsSofar, $errorsSofar))
        return
            let $_DEBUG := i:DEBUG($uri, 'links', 2, '_URI_TO_RESOLVE: ') return
            (: If the link value cannot be resolved to a URI, an error is detected :)
            if (not($uri)) then
                map{'type': 'linkResolutionReport',
                    'linkValue': string($linkValue),                
                    'uri': '',
                    'errorCode': 'no_uri', 
                    'filepath': $filepath}            
        
            else if ($mediatype = 'json') then            
                if (not(i:fox-unparsed-text-available($uri, ()))) then 
                    map{'type': 'linkResolutionReport',
                        'linkValue': string($linkValue), 
                        'uri': $uri, 
                        'errorCode': 'nofind_text', 
                        'filepath': $filepath}
                else
                    let $text := i:fox-unparsed-text($uri, ())
                    let $jdoc := try {json:parse($text)} catch * {()}
                    return 
                        if (not($jdoc)) then 
                            map{'type': 'linkResolutionReport',
                                'linkValue': string($linkValue), 
                                'uri': $uri, 
                                'errorCode': 'not_json', 
                                'filepath': $filepath}
                        else 
                            map{'type': 'linkResolutionReport',
                                'linkValue': string($linkValue),
                                'uri': $uri, 
                                'doc': $jdoc,
                                'filepath': $filepath}
                        
            else if ($mediatype = 'xml') then
                if (not(i:fox-doc-available($uri))) then 
                    let $_DEBUG := i:DEBUG($uri, 'links', 1, '_LINK_RESOLVING_XML#FAILURE: ') return
                    map{'type': 'linkResolutionReport',
                        'linkValue': string($linkValue),
                        'uri': $uri, 
                        'errorCode': 'not_xml', 
                        'filepath': $filepath}
                else 
                    let $_DEBUG := i:DEBUG($uri, 'links', 1, '_LINK_RESOLVING_XML#SUCCESS: ') return
                    map{'type': 'linkResolutionReport',
                        'linkValue': string($linkValue),
                        'uri': $uri, 
                        'doc': i:fox-doc($uri), 
                        'filepath': $filepath}
            else
                if (i:fox-resource-exists($uri)) then
                    map{'type': 'linkResolutionReport',
                        'linkValue': string($linkValue),
                        'uri': $uri, 
                        'filepath': $filepath}
                else
                    map{'type': 'linkResolutionReport',
                        'linkValue': string($linkValue),
                        'uri': $uri,                         
                        'errorCode': 'no_resource', 
                        'filepath': $filepath}
    
    let $errorInfos := $targetsAndErrors[?errorCode][not(?uri = $errorsSofar)]
    let $targetInfos := $targetsAndErrors[not(?errorCode)][not(?uri = $pathsSofar)]
    
    let $newErrors := $errorInfos?uri    
    let $newPaths := $targetInfos?uri
    let $nextDocs := $targetInfos?doc
    
    let $newPathsSofar := ($pathsSofar, $newPaths)
    let $newErrorsSofar := ($errorsSofar, $newErrors)
    return (
        $errorInfos,   (: these are errors not yet observed :)
        $targetInfos,   (: these are targets not yet observed :)
        if (not($recursive)) then () else
            $targetInfos 
            ! f:resolveLinksRC($expr, ?doc, ?uri, $mediatype, $recursive, $context, $newPathsSofar, $newErrorsSofar)
    )
};

(:~
 : Resolves the link expression in the context of an XDM node to a value.
 :
 : The expression is retrieved from the shape element, and the evaluation context
 : is retrieved from the processing context.
 :
 : @param doc document in the context of which the expression must be resolved
 : @param valueShape the value shape specifying the link constraints
 : @param context context for evaluations
 : @return the expression value
 :)
declare function f:resolveLinkExpression($expr as xs:string,
                                         $contextNode as node(),
                                         $context as map(xs:string, item()*))
        as item()* {
    let $exprLang := 'xpath'
    let $evaluationContext := $context?_evaluationContext    
    let $exprValue :=
        switch($exprLang)
        case 'xpath' return i:evaluateXPath($expr, $contextNode, $evaluationContext, true(), true())
        default return error(QName((), 'SCHEMA_ERROR'), "'Missing attribute - <links> element must have an 'xpath' attribute")
    return $exprValue        
};        
