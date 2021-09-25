(:
 : -------------------------------------------------------------------------
 :
 : uriUtil.xqm - tools for processing URIs
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/uri-util";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath-uri-operations.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(: =================================================================
    A new set of URI tools, intended to replace the current tools 
   =================================================================
 :)

(:~
 : Resolves a URI to an absolute URI. If the input URI is absolute, it is
 : returned unchanged; otherwise it is resolved against the base URI.
 : Initial upward steps (..) are resolved.
 :
 : @param uri the URI to be resolved
 : @param baseUri base URI against which to resolve
 : @return the resolved URI
 :)
declare function f:resolveUri($uri as xs:string, $baseUri as xs:string?)
        as xs:string {
            
    if (f:isUriAbsolute($uri)) then $uri
    else
        let $baseUri := if ($baseUri) then $baseUri else f:defaultBaseUri()
        let $upstep := starts-with($uri, '../')
        return
            if (not($upstep)) then
                let $baseUri := $baseUri ! replace(., '[^/]+$', '')
                return concat($baseUri, $uri)
            else
                let $baseUri := $baseUri ! replace(., '[^/]+/[^/]*$', '')
                return f:resolveUri(substring($uri, 4), $baseUri)
};   

(:~
 : Returns the default base URI. It is the absolute file URI pointing to
 : the current working directory, yet without URI schema.
 :
 : @returns the default base URI
 :)
declare function f:defaultBaseUri()
        as xs:string {
    file:current-dir() ! replace(., '\\', '/') ! replace(., '/$', '')        
};

(:~
 : Returns true if a given URI points to an existent file or folder,
 : false otherwise.
 :
 : @param uri a URI
 : @return true if the URI points to a file system resource
 :)
declare function f:isUriResolvable($uri as xs:string) 
        as xs:boolean {
    let $pathToArchive := replace($uri, '(^.*?)/#archive#/.*', '$1')
    return
        let $exists := 
            try {if (file:resolve-path($pathToArchive)) then true() else false()} 
            catch * {false()}
        return
            if ($exists and $pathToArchive ne $uri) then 
                let $pathWithinArchive := replace($uri, '.*?/#archive#/(.*)', '$1')
                return
                    f:doesArchivePathExist($pathWithinArchive, $pathToArchive)
            else $exists
};        

(:~
 : Returns true if a given pair of URI paths points to a resource within a given archive.
 :
 : @param pathToArchive file system path pointing at an archive file
 : @param pathWithinArchive a path within archive contents
 : @return true if the within-archive path points at a resource within the archive
 :   identified by the to-archive path 
 :)
declare function f:doesArchivePathExist($pathToArchive as xs:string, $pathWithinArchive as xs:string)
        as xs:boolean {
    true() (: _TO_DO_ :)        
};

(:~
 : Returns true if a given URI is absolute, false otherwise.
 :)
declare function f:isUriAbsolute($uri as xs:string) as xs:boolean {
    matches($uri, '^( / | [a-zA-Z]:/ | \i\c*:/ )', 'x')
};

