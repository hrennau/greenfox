import module namespace f="http://www.ttools.org/xquery-functions" 
at "foxpath.xqm", 
   "tt/_foxpath-parser.xqm", 
   "tt/_foxpath-util.xqm",
   "tt/_foxpath-processorDependent.xqm";
    
declare namespace soap="http://schemas.xmlsoap.org/soap/envelope/";

declare variable $foxpath external;
declare variable $context external := ();
declare variable $vars as xs:string? external := ();
declare variable $utreeDirs as xs:string? external := ();
declare variable $ugraphEndpoints as xs:string? external := ();
declare variable $isFile as xs:boolean? external := false();
declare variable $mode as xs:string? external := 'eval';   (: eval | parse :)
declare variable $sep as xs:string? external := '/';       (: / | \ :)

let $options := map:merge((
    map:entry('IS_CONTEXT_URI', true()),
    if ($sep = ('\', 'X')) then (
        map:entry('FOXSTEP_SEPERATOR', '\'),
        map:entry('NODESTEP_SEPERATOR', '/')
    ) else if ($sep eq '%') then (
        map:entry('FOXSTEP_SEPERATOR', '/'),
        map:entry('NODESTEP_SEPERATOR', '%')
    ) else (
        map:entry('FOXSTEP_SEPERATOR', '/'),
        map:entry('NODESTEP_SEPERATOR', '\')
    ),
    if (not($utreeDirs)) then () else
        map:entry('UTREE_DIRS', $utreeDirs),
    if (not($ugraphEndpoints)) then () else
        map:entry('UGRAPH_ENDPOINTS', $ugraphEndpoints)
))

let $externalVariables :=
    if (not($vars)) then ()
    else
        map:merge(
            for $item in tokenize($vars, '#######')[string()]
            let $name := replace($item, '^\s*(.*?)\s*:.*', '$1')
            let $value := replace($item, '^.*?:\s*(.*?)\s*$', '$1')
            let $value := xs:untypedAtomic($value)
            let $qname := QName((), $name) 
            return map:entry($qname, $value)
        )
        
let $foxpathExpr :=
    if (not($isFile)) then $foxpath
    else 
        let $uriPart := replace($foxpath, '#.*', '')
        let $fragmentId := replace($foxpath, '^.*#', '')[. ne $foxpath]
        let $uri := file:path-to-uri($uriPart)
        return
            if (not(file:exists($uri))) then <error>{concat('File not found: ', $uri)}</error>
            else
                if (not($fragmentId)) then
                    replace(unparsed-text($uri) , '&#xD;&#xA;', '&#xA;')
                else
                    let $lib := 
                        try {doc($uri)} 
                        catch * {<error>{concat('When using a fragment identifiert, the URI must be a valid XML doc; not an XML doc: ', $uri)}</error>}
                    return
                        if ($lib/self::error) then $lib
                        else
                            let $fragment := $lib//foxpath[@name eq $fragmentId]
                            return
                                if (not($fragment)) then
                                    <error>{concat('foxpath lib does not contain an expression with this name: ', $fragmentId,
                                    '; &#xA;valid names: ', string-join(sort(('', $lib//foxpath/@name)), '&#xA;   '))}</error>
                                else
                                    $lib//foxpath[@name eq $fragmentId]/replace(., '^\s+|\s$', '')
                       
let $context :=
    if ($context) then $context
    else f:currentDirectory()
return    
    if ($foxpathExpr instance of element(error)) then string($foxpathExpr)
    else
        if ($mode eq 'parse') then f:parseFoxpath($foxpathExpr, $options)
        else f:resolveFoxpath($foxpathExpr, $options, $context, $externalVariables)
