(:
 : -------------------------------------------------------------------------
 :
 : greenfoxUtil.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_foxpath-uri-operations.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "log.xqm" ;
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns the name of a validation result element.
 :
 : @param colour the validation result colour (green, yellow, red)
 : @return the element name, as a lexical QName
 :)
declare function f:getResultElemName($colour as xs:string)
        as xs:string {
    'gx:' || $colour
}; 

(:~
 : Returns the text of an error message or of an OK message. The message name is the 
 : concatenation of a prefix and the substring 'Msg' or 'MsgOK' - for example 'minCountMsg',
 : or 'minCountMsgOK'.
 :
 : @param colour the result colour, red, yellow or green 
 : @param elems one or more elements which may contain the message attribute
 : @param msgNamePrefix the first part of the message attribute name
 : @return the first message text found, checking the elements in order
 :)
declare function f:getResultMsg($colour as xs:string,
                                $elems as element()+, 
                                $msgNamePrefix as xs:string)
        as xs:string? {
    if ($colour eq 'red') then f:getErrorMsg($elems, $msgNamePrefix, ())
    else if ($colour eq 'yellow') then f:getErrorMsg($elems, $msgNamePrefix, ())
    else if ($colour eq 'green') then f:getOkMsg($elems, $msgNamePrefix, ())
    else error()    
};

(:~
 : Returns the text of an error message or of an OK message. The message name is the 
 : concatenation of a prefix and the substring 'Msg' or 'MsgOK' - for example 'minCountMsg',
 : or 'minCountMsgOK'.
 :
 : @param colour the result colour, red, yellow or green 
 : @param elems one or more elements which may contain the message attribute
 : @param msgNamePrefix the first part of the message attribute name
 : @param defaultMsgRed a default message, in case there is no explicit message and red colour
 : @param defaultMsgRed a default message, in case there is no explicit message and yellow colour 
 : @param defaultMsgRed a default message, in case there is no explicit message and gree colour 
 : @return the first message text found, checking the elements in order
 :)
declare function f:getResultMsg($colour as xs:string,
                                $elems as element()+, 
                                $msgNamePrefix as xs:string,
                                $defaultMsgRed as xs:string?,
                                $defaultMsgYellow as xs:string?,
                                $defaultMsgGreen as xs:string?)
        as xs:string? {
    if ($colour eq 'red') then f:getErrorMsg($elems, $msgNamePrefix, $defaultMsgRed)
    else if ($colour eq 'yellow') then f:getErrorMsg($elems, $msgNamePrefix, $defaultMsgYellow)
    else if ($colour eq 'green') then f:getOkMsg($elems, $msgNamePrefix, $defaultMsgGreen)
    else error()    
};

(:~
 : Returns the text of an error message. The message name is the concatenation
 : of a prefix and the substring 'Msg' - for example 'minCountMsg'.
 :
 : @param elems one or more elements which may contain the message attribute
 : @param msgNamePrefix the first part of the message attribute name
 : @param defaultMsg a default message, in case there is no explicit message
 : @return the first message text found, checking the elements in order
 :)
declare function f:getErrorMsg($elems as element()+, 
                               $msgNamePrefix as xs:string,
                               $defaultMsg as xs:string?)
        as xs:string? {
    ($elems/(@*[local-name(.) eq concat($msgNamePrefix, 'Msg')], @msg)[1], $defaultMsg)[1]    
    ! normalize-space(.)    
};

(:~
 : Returns the text of an OK message. The message name is the concatenation
 : of a prefix and the substring 'MsgOK' - for example 'minCountMsgOK'.
 :
 : @param elems one or more elements which may contain the message attribute
 : @msgNamePrefix the first part of the message attribute name
 : @param defaultMsg a default message, in case there is no explicit message 
 : @return the first message text found, checking the elements in order
 :)
declare function f:getOkMsg($elems as element()+, 
                            $msgNamePrefix as xs:string,
                            $defaultMsg as xs:string?)                            
        as xs:string? {
    ($elems/(@*[local-name(.) eq concat($msgNamePrefix, 'MsgOK')], @msgOK)[1], $defaultMsg)[1]        
    ! normalize-space(.)
};

(:~
 : Creates an augmented copy of an error element, adding specified attributes.
 :
 : @param error an error element
 : @param atts attributes to be added
 : @return augmented error element
 :)
declare function f:augmentErrorElement($error as element(), $atts as attribute()+, $position as xs:string?)
        as element() {
    let $addedAttNames := $atts/node-name(.)        
    let $curAtts := $error/@*[not(node-name(.) = $addedAttNames)]
    return
        element {node-name($error)} {
            if ($position eq 'first') then ($atts, $curAtts) else ($curAtts, $atts),
            $error/node()
        }
};

(:~
 : Returns the regex and the flags string to be used when evaluating a `like` matching.
 :
 : @param like the pattern specified as `like`
 : @param flags the flags to be used, if specified
 : @return the regex string, followed by the flags string
 :)
declare function f:matchesLike($string as xs:string, $like as xs:string, $flags as xs:string?) as xs:boolean {
    let $useFlags := ($flags[string()], 'i')[1]
    let $regex :=
        $like !
        replace(., '[(){}\[\]]', '\\$0') !
        replace(., '\*', '.*') !
        replace(., '\?', '.') !
        concat('^', ., '$')
    return matches($string, $regex, $useFlags)
};

(:~
 : Transforms a glob pattern into a regex.
 :
 : @param pattern a glob pattern
 : @return the equivalent regex
 :)
declare function f:glob2regex($pattern as xs:string)
        as xs:string {
    replace($pattern, '\.', '\\.')
    ! replace(., '\*', '.*') 
    ! replace(., '\?', '.')
    ! replace(., '[()\[\]{}^$]', '\\$0')
    ! concat('^', ., '$')
};   

(:~
 : Transforms a concise occ specification into two numbers,
 : minOccurs and maxOccurs. Infinity is represented by -1.
 :
 : Examples:
 : ? => 0, 1
 : * => 0, -1
 : + => 1, -1
 : 2 => 2
 : 1-2 => 1, 2
 : ,2  => 0, 2
 : 3,  => 3, -1
 :
 : @param occ concise occurrence string
 : @return two integer numbers, representing minOccurs and maxOccurs
 :)
declare function f:occ2minMax($occ as xs:string)
        as xs:integer* {
    if ($occ eq '?') then (0, 1)
    else if ($occ eq '*') then (0, -1)
    else if ($occ eq '+') then (1, -1)
    else if (matches($occ, '^\d+$')) then xs:integer($occ) ! (., .)
    else if (matches($occ, '^\s*\d*\s*-\s*\d*\s*$')) then
        let $numbers := replace($occ, '^\s*(\d*)\s*-\s*(\d*)\s*$', '$1~$2')
        let $number1 :=
            let $str := substring-before($numbers, '~')
            return if (not($str)) then 0 else xs:integer($str)
        let $number2 :=
            let $str := substring-after($numbers, '~')
            return if (not($str)) then -1 else xs:integer($str)
        return ($number1, $number2)
    else ()
};    

(:~
 : Checks if the file at $filePath has one of a set of given mediatypes.
 :
 : @param mediatypes the mediatypes to check
 : @param filePath a file path
 : @return true if $filePath points at a file with one of the given mediatypes, false otherwise 
 :)
declare function f:matchesMediatype($mediatypes as xs:string+, $filePath as xs:string)
        as xs:boolean {
    if (not(i:fox-resource-is-file($filePath))) then false() else
    
    some $mediatype in $mediatypes satisfies (
        if ($mediatype eq 'xml') then i:fox-doc-available($filePath)
        else if ($mediatype eq 'json') then
            let $text := try {i:fox-unparsed-text($filePath, ())} catch * {()}
            return
                if (not($text)) then false()
                else if (not(substring($text, 1, 1) = ('{', '['))) then false()
                else exists(try {json:parse($text)} catch * {()})
        else
            error(QName((), 'NOT_YET_IMPLEMENTED'), concat("Not yet implemented: check against mediatype '", $mediatype, "'")) 
    )
};

declare function f:castAs($item as item(), $type as xs:QName)
        as item()? {
    try {        
        switch($type)
        case QName($i:URI_XSD, 'integer') return $item cast as xs:integer 
        case QName($i:URI_XSD, 'int') return $item cast as xs:int        
        case QName($i:URI_XSD, 'decimal') return $item cast as xs:decimal
        case QName($i:URI_XSD, 'long') return $item cast as xs:long
        case QName($i:URI_XSD, 'short') return $item cast as xs:short
        case QName($i:URI_XSD, 'date') return $item cast as xs:date
        case QName($i:URI_XSD, 'dateTime') return $item cast as xs:dateTime
        case QName($i:URI_XSD, 'duration') return $item cast as xs:duration
        case QName($i:URI_XSD, 'dayTimeDuration') return $item cast as xs:dayTimeDuration
        case QName($i:URI_XSD, 'boolean') return $item cast as xs:boolean
        case QName($i:URI_XSD, 'NCName') return $item cast as xs:NCName        
        default return error(QName((), 'UNKNOWN_TYPE_NAME'), 'Unknown type name: ', $type)
    } catch *:UNKNOWN_TYPE_NAME {error(QName((), 'UNKNOWN_TYPE_NAME'), 'Unknown type name: ', $type)
    } catch * {
        map{
            'errorCode': 'GREENFOX_CAST_ERROR',
            'item': $item,
            'type': $type
        }
    } 
}; 

(:~
 : Returns true if a given item is a map describing a data conversion error.
 :)
declare function f:isCastError($item as item()) as xs:boolean? {
    $item[. instance of map(xs:string, item()*)]?errorCode eq 'GREENFOX_CAST_ERROR'        
};

declare function f:castAs($s as xs:anyAtomicType, $type as xs:QName, $errorElemName as xs:QName?)
        as item()? {
    try {        
        switch($type)
        case QName($i:URI_XSD, 'integer') return $s cast as xs:integer 
        case QName($i:URI_XSD, 'int') return $s cast as xs:int        
        case QName($i:URI_XSD, 'decimal') return $s cast as xs:decimal
        case QName($i:URI_XSD, 'long') return $s cast as xs:long
        case QName($i:URI_XSD, 'short') return $s cast as xs:short
        case QName($i:URI_XSD, 'date') return $s cast as xs:date
        case QName($i:URI_XSD, 'dateTime') return $s cast as xs:dateTime
        case QName($i:URI_XSD, 'duration') return $s cast as xs:duration
        case QName($i:URI_XSD, 'dayTimeDuration') return $s cast as xs:dayTimeDuration
        case QName($i:URI_XSD, 'boolean') return $s cast as xs:boolean
        case QName($i:URI_XSD, 'NCName') return $s cast as xs:NCName        
        default return error(QName((), 'UNKNOWN_TYPE_NAME'), 'Unknown type name: ', $type)
    } catch *:UNKNOWN_TYPE_NAME {error(QName((), 'UNKNOWN_TYPE_NAME'), 'Unknown type name: ', $type)
    } catch * {
        if (exists($errorElemName)) then 
            element {$errorElemName} {
                $s
            }
        else ()
    }
};  

declare function f:castableAs($s as xs:anyAtomicType, $type as xs:QName)
        as xs:boolean {
    exists(f:castAs($s, $type, ()))        
};

(:~
 : Returns a copy of a given string in which the first character is set
 : to lowercase.
 :
 : @param s a string
 : @return the edited string
 :)
declare function f:firstCharToLowerCase($s as xs:string?) as xs:string? {
    if (not($s)) then $s else
        lower-case(substring($s, 1, 1)) || substring($s, 2)
};

(:~
 : Returns a copy of a given string in which the first character is set
 : to uppercase.
 :
 : @param s a string
 : @return the edited string
 :)
declare function f:firstCharToUpperCase($s as xs:string?) as xs:string? {
    if (not($s)) then $s else
        upper-case(substring($s, 1, 1)) || substring($s, 2)
};

(:~
 : Maps a qualified name to a URI.
 :
 : @param qname a qualified name
 : @return a URI representation of the qualified name
 :)
declare function f:qnameToURI($qname as xs:QName?) as xs:string {
    if (empty($qname)) then () else
    
    let $lname := local-name-from-QName($qname)
    let $uri := namespace-uri-from-QName($qname)
    let $sep := '#'[not(matches($uri, '[#/]$'))]
    return $uri || $sep || $lname
};

(:~
 : Returns the data path of a given node. Only local names
 : are considered. A suffix indicating the ([i]) is added
 : unless the one-based index is 1.
 :
 : @param n the node
 : @return the data path string
 :)
declare function f:datapath($n as node()) as xs:string {     
    (
    let $suppressIndex1ForOnlyChild := false()
    for $node in $n/ancestor-or-self::node()
    let $index := 
        typeswitch($node)
        case element() return
            let $raw := 1 + $node/preceding-sibling::*[local-name(.) eq $node/local-name(.)] => count()
            return 
                if ($suppressIndex1ForOnlyChild and $raw eq 1 and count($node/../*) eq 1) then () else $raw ! concat('[', ., ']')
        default return ()            
    return $node/concat(self::attribute()/'@', local-name(.)) || $index
    ) => string-join('/')
};

(:~
 : Returns the data path of a given node. Only local names
 : are considered. A suffix indicating the ([i]) is added
 : unless the one-based index is 1.
 :
 : @param n the node
 : @return the data path string
 :)
declare function f:datapath($n as node(), $context as node()?) as xs:string {     
    (
    let $suppressIndex1ForOnlyChild := false()
    for $node in $n/ancestor-or-self::node()[not($context) or . >> $context]
    let $index := 
        typeswitch($node)
        case element() return
            let $raw := 1 + $node/preceding-sibling::*[local-name(.) eq $node/local-name(.)] => count()
            return 
                if ($suppressIndex1ForOnlyChild and $raw eq 1 and count($node/../*) eq 1) then () else $raw ! concat('[', ., ']')
        default return ()            
    return $node/concat(self::attribute()/'@', local-name(.)) || $index
    ) => string-join('/')
};

declare function f:addDefaultNamespace($doc as node(), $uri as xs:string, $options as map(*)?) as node() {
    f:addDefaultNamespaceRC($doc, $uri, $options)
};

declare function f:addDefaultNamespaceRC($n as node(), $uri as xs:string, $options as map(*)?) as node() {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:addDefaultNamespaceRC(., $uri, $options)}
    case element() return
        let $useName :=    
            let $namespace := namespace-uri($n)
            return
                if ($namespace eq $uri) then QName($uri, local-name($n))
                else node-name($n)
        return
            element {$useName} {
                $n/@* ! f:addDefaultNamespaceRC(., $uri, $options),
                $n/node() ! f:addDefaultNamespaceRC(., $uri, $options)
            }
    default return $n            
};

(:~
 : Returns a copy of the namespace nodes found in an
 : element. Typically used when copying an element,
 : making sure that the copy has the same namespace
 : nodes as the source.
 :
 : @param elem an element node
 : @return copy of the namespace nodes
 :)
declare function f:copyNamespaceNodes($elem as element())
        as namespace-node()* {
    in-scope-prefixes($elem)[string()] ! namespace {.} {namespace-uri-for-prefix(., $elem)}        
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
 : Like file:path-to-native, but making sure that the right separator
 : is used in the argument, as on Unix the wrong separator provokes an error:
 :
 :    basex 'file:path-to-native("\Users\hauke\Projects\ParsQube\XML\greenfox\declarative-amsterdam-2020\data\air")'
 :    Stopped at /Users/hauke/Projects/ParsQube/XML/greenfox/, 1/20:
 :
 :    basex 'file:path-to-native("/Users/hauke/Projects/ParsQube/XML/greenfox/declarative-amsterdam-2020/data/air")'
 :    /Users/hauke/Projects/ParsQube/XML/greenfox/declarative-amsterdam-2020/data/air/
 :
 : If the path is a file URI, it is returned unchanged.
 :
 : If the path contains an archive, the subpath preceding the archive is passed to
 : file:path-to-native, and the remainder is appended. In this case, dir separators
 : are replace with \\.
 :
 : @param path the path to be edited
 : @return the edited path
 :)
declare function f:pathToNative($path as xs:string)
        as xs:string {
    let $pathToArchive := replace($path, '^(.*?)[/\\]#archive#([/\\].*)?', '$1')[. ne $path]
    return
        (: URI is archive URI :)
        if ($pathToArchive) then
            let $withinArchivePath := substring($path, string-length($pathToArchive) + 1)
            let $pathToArchiveAbs := $pathToArchive ! f:pathToNative(.)
            return
                ($pathToArchiveAbs || $withinArchivePath) 
                ! replace(., '/', '\\') 
                ! replace(., '\\$', '') 
        (: URI is a file system URI :)
        else if (matches($path, '^file:/')) then $path
        else
            $path ! f:dirSepToNative(.) ! file:path-to-native(.) ! replace(., '[/\\]$', '')    
}; 

(:~
 : Replaces all occurrences of / or \\ with the directory
 : separator of the current platform.
 :
 : @param path the string to edit
 : @return the edited string
 :)
declare function f:dirSepToNative($path as xs:string)
        as xs:string {
    let $dirSep := file:dir-separator() ! replace(., '\\', '\\\\')
    return replace($path, '[/\\]', $dirSep)
};

(:~
 : Transforms a URI or file system path into a normalized file system
 : path. A normalized file system path looks like 
 :   ".:/*" in Windows (e.g. C:/projects)
 :   "/*" in Unix
 :)
declare function f:uriOrPathToNormPath($uriOrPath as xs:string)
        as xs:string {
    $uriOrPath 
    ! replace(., '\\', '/')
    ! replace(., '^file:/*(/.*)', '$1') (: retain one slash :)
    ! replace(., '^/(.:/.*)', '$1')
};        

(:~
 : Transforms a file system path or URI to a Foxpath
 : representation, using backslash as step separator
 :
 : @param path file system path or URI
 : @return Foxpath representation of the path or URI
 :)
declare function f:pathToFoxpath($path as xs:string)
        as xs:string {
    $path
    ! replace(., 'file:/+', '/')
    ! replace(., '/', '\\')
    ! replace(., '^\\(.:)', '$1')
};

(:~
 : Returns the child resources of a resource.
 :
 : @param path file path or URI of a resource
 : @param name name pattern (optional)
 : @return the file paths or URIs of child resources
 :)
declare function f:resourceChildResources($path as xs:string, $name as xs:string?)
        as xs:string* {
    let $name := ($name, '*')[1]
    let $foxpathOptions := i:getFoxpathOptions(true()) 
    return tt:childUriCollection($path, $name, (), $foxpathOptions)
};

(:~
 : Returns the file size of a resource.
 :
 : @param path file path or URI of a resource
 : @return the file size in bytes
 :)
declare function f:resourceFileSize($path as xs:string)
        as xs:integer {
    let $foxpathOptions := i:getFoxpathOptions(true())
    return tt:fox-file-size($path, $foxpathOptions)
};

(:~
 : Returns the time of last modification of a resource.
 :
 : @param path file path or URI of a resource
 : @return the time of last modification
 :)
declare function f:resourceLastModified($path as xs:string)
        as xs:dateTime {
    let $foxpathOptions := i:getFoxpathOptions(true())
    return tt:fox-file-date($path, $foxpathOptions)
};

(:~
 : Returns the time of last modification of a resource.
 :
 : @param path file path or URI of a resource
 : @return the time of last modification
 :)
declare function f:resourceReadBinary($path as xs:string)
        as xs:base64Binary? {
    let $path_ := f:pathToNative($path)      
    let $path_ := $path
    let $foxpathOptions := i:getFoxpathOptions(true())
    return tt:fox-binary($path_, $foxpathOptions)
};

(:~
 : Returns the name of a resource.
 :
 : @param path file path or URI of a resource
 : @return the name of the resource
 :)
declare function f:resourceName($path as xs:string)
        as xs:string {
    $path ! replace(., '^.*[/\\]', '')
};

(:~
 : Returns a hash key for a file identified by a file path or URI.
 :
 : @param path file path or URI
 : @param keyKind identifies the key of hash key, value one of 'md5', 'sha1', 'sha256'.
 : @return hash key
 :)
declare function f:hashKey($path as xs:string, $keyKind as xs:string)
        as xs:string {
    let $fileContent := f:resourceReadBinary($path)
    let $rawHash :=
        switch($keyKind)
        case 'md5' return hash:md5($fileContent)
        case 'sha1' return hash:sha1($fileContent)
        case 'sha256' return hash:sha256($fileContent)
        default return error()
    return xs:hexBinary($rawHash) ! xs:string(.)
};

(:~
 : Returns the data path of a schema component.
 :)
declare function f:getSchemaPath($node as node(), $context as element()?)
        as xs:string {
    let $raw :=
        string-join(
            for $aos in $node/ancestor-or-self::node()[not($context) or . >> $context]
            return
                typeswitch($aos)
                case element() return
                    concat('gx:', local-name($aos),  
                        (1 + count($aos/preceding-sibling::*[node-name(.) eq $aos/node-name(.)]))
                        ! concat('[', ., ']')
                    )
                case attribute() return concat('@', local-name($aos))            
                default return ''
        , '/')
    let $path := '/'[not($context)][not(substring($raw, 1, 1) eq '/')] || $raw
    return $path
};        

(:~
 : Returns the relative path leading from a resource shape to a constraint node.
 : If the constraint is not contained by a file or folder, the absolute path
 : will be returned
 :
 : _TO_DO_ - this is a simplistic implementation, expecting the resource shape element
 : to be the first file or folder ancestor; think of extension constraints in order
 : to see that this will not always be appropriate.
 :)
declare function f:getSchemaConstraintPath($constraintNode as node())
        as xs:string {
    let $resourceShape := $constraintNode/ancestor::*[self::gx:file, self::gx:folder][1]
    return i:getSchemaPath($constraintNode, $resourceShape)
};   

(:~
 : Resolves a @useDatatype attribute to a qualified name. Rule: if the value has
 : no prefix, the XSD namespace is assumed.
 :
 : @param useDatatype attribute with a datatype to be used
 : @return the qualified type name
 :)
declare function f:resolveUseDatatype($useDatatype as attribute(useDatatype)?)
        as xs:QName? {
    $useDatatype/(
    if (not(contains(., ':'))) then QName($i:URI_XSD, .) else resolve-QName(., ..))
};

declare function f:applyUseDatatypeAndFilterErrors($value as item()*, $useDatatype as xs:QName?, $useString as xs:string*)
        as map(*) {
    let $converted := f:applyUseDatatype($value, $useDatatype, $useString)
    let $errors := if (empty($useDatatype)) then () else $converted[. instance of map(*)]
    let $convertedValues := if (empty($useDatatype)) then $converted else $converted[not(. instance of map(*))]
    return
        map{'ok': empty($errors), 'values': $convertedValues, 'errors': $errors}
};

(:~
 : Casts the items of a value to a datatype. In case of an error, the item is 
 : represented by a map with keys 'item', 'type' and 'errorCode'.
 :
 : @param value the value to be c
 : @param useDatatype attribute with a datatype to be used
 : @return the qualified type name
 :)
declare function f:applyUseDatatype($value as item()*, $useDatatype as xs:QName?, $useString as xs:string*)
        as item()* {            
    if (empty($useDatatype)) then 
        if (empty($useString)) then $value
        else f:applyUseString($value, $useString)
    else $value ! i:castAs(., $useDatatype)        
};        

(:~
 : Edits a string, applying a simple operation like "lower-case".
 :
 : @param value the value to be edited
 : @return the edited value
 :)
declare function f:applyUseString($value as item()*, $useString as xs:string*)
        as item()* {
    if (empty($useString)) then $value else
    let $interm := if ($useString = 'sv') then $value ! string(.) else $value
    let $interm := if ($useString = 'lc') then $interm ! lower-case(.) else $interm
    let $interm := if ($useString = 'uc') then $interm ! upper-case(.) else $interm
    let $interm := if ($useString = 'ns') then $interm ! normalize-space(.) else $interm    
    return $interm
};        




