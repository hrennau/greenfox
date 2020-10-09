(:
 : -------------------------------------------------------------------------
 :
 : resourceAccess.xqm - functions accessing resource contents and resource properties
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath-uri-operations.xqm";
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "resourceAccess.xqm",
   "uriUtil.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns a string representation of a resource.
 :
 : @param uri the URI or file path of the resource
 : @param encoding the encoding of the resource content
 : @param options options controlling the evaluation
 : @return the text of the resource, or the empty sequence if retrieval fails
 :)
declare function f:fox-unparsed-text($uri as xs:string, 
                                     $encoding as xs:string?)
        as xs:string? {
    tt:fox-unparsed-text($uri, $encoding, ())        
};

declare function f:fox-unparsed-text-available($uri as xs:string, 
                                               $encoding as xs:string?)
        as xs:boolean {
    let $text := try {tt:fox-unparsed-text($uri, $encoding, ())} catch * {()}
    return exists($text)
};

(:~
 : Returns the lines of a string representation of a resource.
 :
 : @param uri the URI or file path of the resource
 : @param encoding the encoding of the resource content
 : @param options options controlling the evaluation
 : @return the text of the resource, or the empty sequence if retrieval fails
 :)
declare function f:fox-unparsed-text-lines($uri as xs:string, 
                                           $encoding as xs:string?)
        as xs:string* {
    tt:fox-unparsed-text-lines($uri, $encoding, ())        
};

(:~
 : Returns an XML document identified by URI or file path. If the
 : URI points to an archive file, an @xml:base attribute is
 : added to the root element, along with a @fox:base-xml-added
 : attribute. If you do not want this addition, use the function
 : variant 'fox-doc-no-base-xml'.
 :
 : @param uri the URI or file path of the resource
 : @param options options controlling the evaluation
 : @return the document, or the empty sequence if retrieval or parsing fails
 :)
declare function f:fox-doc($uri as xs:string) as document-node()? {
    let $options := map{'addXmlBase': true()}
    return f:fox-doc($uri, $options)        
};

declare function f:fox-doc-no-base-xml($uri as xs:string) as document-node()? {
    tt:fox-doc($uri, map{'addBaseXml': false()})        
};

declare function f:fox-doc($uri as xs:string, $options as map(xs:string, item()*)) as document-node()? {
    tt:fox-doc($uri, $options)        
};

declare function f:fox-json-doc($uri as xs:string, $options as map(xs:string, item()*)?) as document-node()? {
    tt:fox-json-doc($uri, $options)        
};

(:~
 : Returns true if a given URI or file path points to a well-formed XML document.
 :
 : @param uri the URI or file path of the resource
 : @param options options controlling the evaluation
 : @return true if the URI points to a well-formed XML document
 :)
declare function f:fox-doc-available($uri as xs:string)
        as xs:boolean {
    tt:fox-doc-available($uri, ())        
};

(:~
 : Returns an XML representation of the CSV record identified by URI or file path.
 :
 : @param uri the URI or file path of the resource
 : @param separator the separator character (or token `comma` or token `semicolon`)
 : @param header if 'yes', the first row contains column headers
 : @param names if 'direct', column names are used as element names;
 :              if 'attributes', column names are provided by @name
 : @param quotes if 'yes', quotes at start and end of field are treated as control characters
 : @param backslashes if 'yes', \n, \t and \r are replaced by the corresponding control characters
 : @param options options controlling the evaluation
 : @return an XML document representing JSON data, or the empty sequence if 
 :     retrieval or parsing fails
 :)
declare function f:fox-csv-doc($uri as xs:string,
                               $separator as xs:string,
                               $header as xs:string,
                               $names as xs:string,
                               $quotes as xs:string,
                               $backslashes as xs:string,
                               $options as map(*)?)
        as document-node()? {
    tt:fox-csv-doc($uri, $separator, $header, $names, $quotes, $backslashes, $options)
};

(:~
 : Returns an XML representation of the CSV record identified by URI or file path.
 :
 : @param filePath the file path
 : @param params one or several elements which may have attributes controllig the parsing
 : @return the csv document, or the empty sequence of parsing is not successful
 :)
declare function f:csvDoc($filePath as xs:string, $params as element()*, $paramsMap as map(xs:string, item()*)?)
        as document-node()? {
    let $separator := ($params/@csv.separator, $paramsMap?csv.separator,  'comma')[1]
    let $header := ($params/@csv.header, $paramsMap?csv.header, 'no')[1]
    let $format := ($params/@csv.format, $paramsMap?csv.format, 'direct')[1]
    let $quotes := ($params/@csv.quotes, $paramsMap?quotes, 'yes')[1]
    let $backslashes := ($params/@csv.backslashes, $paramsMap?backslashes, 'no')[1]
    return
        f:fox-csv-doc($filePath, $separator, $header, $format, $quotes, $backslashes, ())
};   

(:~
 : Returns the base URI for a given node.
 :
 : @param node as node
 : @return the base URI
 :)
declare function f:fox-base-uri($node as node())
        as xs:string {
    let $raw := $node/base-uri(.)
    return
        $raw ! replace(., '%23', '#')
};        

(:~
 : Resolves a URI to an absolute URI. If the input URI is absolute, it is
 : returned unchanged; otherwise it is resolved against the base URI.
 : Initial upward steps (..) are resolved.
 :
 : @param uri the URI to be resolved
 : @param baseUri base URI against which to resolve
 : @return the resolved URI
 :)
declare function f:fox-resolve-uri($uri as xs:string, $baseUri as xs:string)
        as xs:string {
    if (matches($uri, '^(/|[a-zA-Z]:/|\i\c*:/)')) then $uri
    else
        let $backstep := starts-with($uri, '../')
        let $baseUri := replace($baseUri, '/$', '') 
                        ! replace(., '[^/]+$', '')
        return 
            if (not($backstep)) then concat($baseUri, $uri)
            else f:fox-resolve-uri(substring($uri, 4), $baseUri)
};        

(:~
 : Checks if a URI or URI compatible path can be resolved to a resource.
 :
 : @param path file path or URI to be checked
 : @return true if the path can be resolved, false otherwise
 :)
declare function f:fox-resource-exists($uri as xs:string)
        as xs:boolean {
    let $foxpathOptions := i:getFoxpathOptions(true()) 
    return tt:fox-file-exists($uri, $foxpathOptions)
};

(:~
 : Checks if a URI or URI compatible path points to a file, not a folder.
 :
 : @param path file path or URI to be checked
 : @return true if the path can be resolved, false otherwise
 :)
declare function f:fox-resource-is-file($uri as xs:string)
        as xs:boolean {
    let $foxpathOptions := i:getFoxpathOptions(true())
    return tt:fox-is-file($uri, $foxpathOptions)
};

(:~
 : Checks if a URI or URI compatible path points to a folder, not a file.
 :
 : @param path file path or URI to be checked
 : @return true if the path can be resolved, false otherwise
 :)
declare function f:fox-resource-is-dir($uri as xs:string)
        as xs:boolean {
    let $foxpathOptions := i:getFoxpathOptions(true())
    return tt:fox-is-dir($uri, $foxpathOptions)
};

declare function f:pathToAbsoluteFoxpath($path as xs:string)
        as xs:string {
    f:pathToAbsolutePath($path) ! replace(., '/', '\\')
};

(:~
 : Resolves a path to an absolute path, assuming that the context
 : is the file system.
 :
 : This function is used in order to normalize path values contained
 : by the schema, e.g. the domain path. The functionality could
 : also be defined as 'resolve-uri' with an implicit must not
 : be confused with 'resolve-uri', which 
 :
 : @param path the path
 : @return the absolute path
 :)
declare function f:pathToAbsolutePath($path as xs:string)
        as xs:string {
    (: Remove leading 'file:/+' :)
    let $path := i:removeFileUriSchema($path)
    (:
        if (matches($path, '^file:/+[a-zA-Z]:')) then replace($path, '^file:/+', '')
        else replace($path, '^file:/*(/([^/].*)?)$', '$1')
     :)        
    let $pathRaw :=  
        (: Path leading to the archive which will be entered :)
        let $archiveFilePath := replace($path, '^(.*?)[/\\]#archive#([/\\].*)?', '$1')[. ne $path]
        return
            (: Case 1: URI is an archive URI
                       => deliver a Foxpath, which means: use only backslash :)
            if ($archiveFilePath) then
                let $archiveContentPath := 
                    substring($path, string-length($archiveFilePath) + 1)
                    ! replace(., '/', '\\') 
                return
                    (: Unclear if the replace with \\ applies to the complete URI or only the within-archive path :)
                    f:pathToAbsolutePath($archiveFilePath) || ($archiveContentPath ! replace(., '/', '\\'))
                    
            else
                let $uriSchema := replace($path, '^(\i\c+:/+).*', '$1')[. ne $path]
                return
                    (: Case 2: Non-file URI schema 
                               => deliver a Foxpath, which means: use only backslash :)
                    if ($uriSchema) then 
                        let $uriPath := 
                            substring($path, 1 + string-length($uriSchema)) 
                            ! replace(., '/', '\\') (: Not file URI: deliver Foxpath, therefore: backslash :)
                        return
                            $uriSchema || $uriPath
                    (: Case 3: URI is a file path => make absolute :)
                    else
                        $path ! f:dirSepToNative(.) ! i:normalizeAbsolutePath(.) ! file:path-to-native(.) 
    return 
        $pathRaw ! replace(., '[/\\]$', '')    
}; 

declare function f:resolveModuleBasedPath($path as xs:string)
        as xs:string {
    (resolve-uri('') || '/' || $path)
    ! file:path-to-native(.)   (: URI turned into path :)
    ! f:normalizeAbsolutePath(.)
};        




