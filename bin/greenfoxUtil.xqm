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
    replace($pattern, '\*', '.*') 
    ! replace(., '\?', '.')
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
    if (not(file:is-file($filePath))) then false() else
    
    some $mediatype in $mediatypes satisfies (
        if ($mediatype eq 'xml') then doc-available($filePath)
        else if ($mediatype eq 'json') then
            let $text := try {unparsed-text($filePath)} catch * {()}
            return
                if (not($text)) then false()
                else if (not(substring($text, 1, 1) = ('{', '['))) then false()
                else exists(try {json:parse($text)} catch * {()})
        else
            error(QName((), 'NOT_YET_IMPLEMENTED'), concat("Not yet implemented: check against mediatype '", $mediatype, "'")) 
    )
};

(:~
 : Parses a file into a csv document.
 :
 : @param filePath the file path
 : @param params an element which may have attributes controllig the parsing
 : @return the csv document, or the empty sequence of parsing is not successful
 :)
declare function f:csvDoc($filePath as xs:string, $params as element())
        as document-node()? {
    let $separator := ($params/@csv.separator, 'comma')[1]
    let $withHeader := ($params/@csv.withHeader, 'no')[1]
    let $names := ($params/@csv.names, 'direct')[1]
    let $withQuotes := ($params/@csv.withQuotes, 'yes')[1]
    let $backslashes := ($params/@csv.backslashes, 'no')[1]
    let $options := map{
        'separator': $separator,
        'header': $withHeader,
        'format': $names,
        'quotes': $withQuotes,
        'backslashes': $backslashes
    }
    let $text := unparsed-text($filePath)
    return try {csv:parse($text, $options)} catch * {()}
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
        case QName($i:URI_XSD, 'dateTime') return $s cast as xs:dateTime
        case QName($i:URI_XSD, 'duration') return $s cast as xs:duration
        case QName($i:URI_XSD, 'dayTimeDuration') return $s cast as xs:dayTimeDuration
        case QName($i:URI_XSD, 'boolean') return $s cast as xs:boolean
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

(:
(:~
 : Returns the target paths of a resource shape.
 :
 : The target is identified either by a path (@path)
 : or by a foxpath expression (@foxpath). The path is
 : appended to the context path. The foxpath is
 : evaluated.
 :
 : @param resourceShape a file or folder shape
 : @param context a map of variable bindings
 : @return the target paths :)
declare function f:getTargetPaths($resourceShape as element(), $context as map(xs:string, item()*))
        as xs:string* {
    let $isExpectedResourceKind :=
        let $isDir := $resourceShape/self::gx:folder
        return function($r) {if ($isDir) then file:is-dir($r) else file:is-file($r)}
    let $contextPath := $context?_contextPath     
    let $evaluationContext := $context?_evaluationContext
    let $targetPaths :=
        let $path := $resourceShape/@path
        let $foxpath := $resourceShape/@foxpath
        return
            if ($path) then 
                concat($contextPath, '\', $resourceShape/@path)
                [file:exists(.)]
                [$isExpectedResourceKind(.)]
            else 
                i:evaluateFoxpath($foxpath, $contextPath, $evaluationContext, true())
                [$isExpectedResourceKind(.)]
    return $targetPaths        
};        
:)


