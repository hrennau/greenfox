(:
 : -------------------------------------------------------------------------
 :
 : uriUtil.xqm - tools for processing URIs
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath-uri-operations.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns the drive prefix (e.g. "c:") of a path or URI, if it
 : contains such a prefix, the empty sequence otherwise.
 :
 : @param path a path or URI
 : @return the drive prefix, or the empty sequence
 :)
declare function f:driveFromPath($path as xs:string)
        as xs:string? {
    $path ! replace(., '^(file:/+)? ([a-zA-Z]:).*', '$2', 'x')[. ne $path[1]]        
};

(:~
 : Returns the URI of an existent resource, or an empty sequence if
 : the input data cannot be resolved to an existent resource.
 :
 : @param uri relative or absolute URI or path
 : @param baseUri base URI to be used for resolving the resource
 : @param resourceKind if specified, the expected kind of resource, value 'file' or 'folder'
 : @return a resource URI or an empty string 
 :) 
declare function f:existentResourceUri($uri as xs:string, 
                                       $baseUri as xs:string?, 
                                       $resourceKind as xs:string?)
        as xs:string? {
                   
    let $useUri := string-join(($baseUri, $uri), '/') 
                   ! f:normalizeAbsolutePath(.)
                   ! f:pathToUriCompatible(.)
    return
        $useUri
        [f:fox-resource-exists($useUri)]
        [not($resourceKind) or (
         if ($resourceKind eq 'file') then f:fox-resource-is-file(.)
         else if ($resourceKind eq 'folder') then f:fox-resource-is-dir(.)
         else error())]
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
declare function f:resolveUri($uri as xs:string, $baseUri as xs:string)
        as xs:string {
    if (matches($uri, '^(/|[a-zA-Z]:/|\i\c*:/)')) then $uri
    else
        let $backstep := starts-with($uri, '../')
        let $baseUri := replace($baseUri, '/$', '') 
                        ! replace(., '[^/]+$', '')
        return 
            if (not($backstep)) then concat($baseUri, $uri)
            else f:resolveUri(substring($uri, 4), $baseUri)
};        

(:~
 : Maps a URI to the image reflected by a mirror.
 :
 : @param uri a URI
 : @param reflector1 reflector reflecting the input URI
 : @param reflector2 reflector reflecting the output URI
 : @param reflectedReplaceSubstring resource name editing - replacement from substring 
 : @param reflectedReplaceWith resource name editing - replacement to substring 
 : @return the image URI, if the resource exists, an empty sequence otherwise
 :) 
declare function f:getImage($uri as xs:string, 
                            $reflector1 as xs:string, 
                            $reflector2 as xs:string,
                            $reflectedReplaceSubstring as xs:string?,
                            $reflectedReplaceWith as xs:string?)
        as xs:string? {
        
    (: Normalize URIs to make them comparable :)
    let $uris:= f:normalizeURISet(($uri, $reflector1, $reflector2))
    let $uri := $uris[1]
    let $reflector1 := $uris[2]
    let $reflector2 := $uris[3]
    
    let $pathReflector1ToUri :=
        if (matches($uri, concat($reflector1, '(/.*)?$'))) then
            substring-after($uri, concat($reflector1, '/'))
            
        else if (matches ($reflector1, concat($uri, '(/.*)?$'))) then
            let $countSteps :=
                (substring-after($reflector1, concat($uri, '/'))
                ! tokenize(., '\s*/\s*')) => count()
            return
                (for $i in 1 to $countSteps return '..') => string-join('/')
        else ()
    return
        (: Lefthook which is not ancestor or descendant of $uri not supported :)
        if (empty($pathReflector1ToUri)) then () else
        
    let $pathReflector1ToUriEdited :=
        if (empty($reflectedReplaceSubstring)) then $pathReflector1ToUri
        else
            let $parts := replace($pathReflector1ToUri, '^(.*?)?([^/]+)$', '$1~~~$2')
            let $path := substring-before($parts, '~~~')
            let $name := substring-after($parts, '~~~')
            let $newName := replace($name, $reflectedReplaceSubstring, $reflectedReplaceWith)
            return
                concat($path, $newName)
        
    let $imagePath := concat($reflector2, '/', $pathReflector1ToUriEdited)
    (:
    let $exists := file:exists($imagePath)    
    return $imagePath[$exists] ! f:normalizeAbsolutePath(.)
    :)
    return $imagePath ! f:normalizeAbsolutePath(.)
};

(: Normlizes an absolute path by removing step/.., step/step/../.. etc.
 :
 : Examples:
 : /a/b/c/.. => /a/b
 : /a/b/c/../.. => /a 
 : /a/b/c/../../.. => / 
 : /a/b/c/../d => /a/b/d
 : /a/b/c/../../d => /a/b/d 
 : /a/.. => /
 : / .. => INVALID, NOT ABSOLUTE
 :
 : @param path the path to be edited
 : @return the edited path
 :)
declare function f:normalizeAbsolutePath($path as xs:string)
        as xs:string {
    let $norm := replace($path, '^(.*?)   [/\\] [^/\\]*?[/\\]   \.\.   (.*)', '$1$2', 'x')                 
    return
        if ($norm eq $path) then $norm 
        else if (not($norm)) then substring($path, 1, 1)
        else $norm ! f:normalizeAbsolutePath(.)
};

(:~
 : Normalizes a set of URIs or paths so that the first URI can be
 : compared with the others. It is assumed that in the case of the
 : first URI containing a drive prefix, following URIs which are 
 : paths (no schema URI) without drive prefix should be augmented
 : by inserting the drive prefix at the begining.
 :
 : Example: URIs: c:/a/b/c, /x/y/z
 : => c:/a/b/c, c:/x/y/z
 :)
declare function f:normalizeURISet($uris as xs:string+)
        as xs:string+ {
    let $uris2 := $uris ! replace(., '\\', '/')       
    let $drive := $uris[1] ! f:driveFromPath(.)         
    return
        if (empty($drive)) then $uris2
        else (
            $uris2[1],
            tail($uris2) ! (if (not(f:driveFromPath(.))) then concat($drive, .) else .) 
        )
};

(:~
 : Transforms a path into a representation which can be used where a URI
 : is expected. Replaces backward slash with forward slash and removes trailing
 : slash or backward slah.
 :
 : @param path the path to be edited
 : @return URI compatible copy of the path
 :)
declare function f:pathToUriCompatible($path as xs:string)
        as xs:string {
    $path ! replace(., '\\', '/') ! replace(., '/$', '')        
}; 

(:~
 : Removes from a URI or path the file URI scheme, if present.
 :
 : @param uri the uri or path to be edited
 : @return edited uri or path
 :)
declare function f:removeFileUriSchema($uri as xs:string)
        as xs:string {
    (: Remove leading 'file:/+' :)
    let $path :=
        if (matches($uri, '^file:/+[a-zA-Z]:')) then replace($uri, '^file:/+', '')
        else replace($uri, '^file:/*(/([^/].*)?)$', '$1')
    return $path    
};

