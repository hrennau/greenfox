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
    "expressionEvaluator.xqm",
    "log.xqm" ;
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates the target count of a resource shape.
 :
 : @param shape a resource shape
 : @targetCount the number of instances belonging to the target of the shape
 : @return elements signaling violations of the count constraints
 :) 
declare function f:validateTargetCount($constraint as element(), $targetCount as xs:integer)
        as element()* {
    let $constraintParams := $constraint/(@count, @minCount, @maxCount)  
    
    let $count := $constraint/@count/xs:integer(.)
    let $minCount := $constraint/@minCount/xs:integer(.)
    let $maxCount := $constraint/@maxCount/xs:integer(.)
    let $error := (
        exists($count) and $count ne $targetCount
        or
        exists($minCount) and $minCount gt $targetCount
        or 
        exists($maxCount) and $maxCount lt $targetCount
    )
    return
        if ($error) then
            let $msg := $constraint/@msg
            return
                <gx:error>{ 
                    attribute constraintComp {'targetSize'},
                    $constraint/@resourceShapeID,
                    $constraint/@id/attribute constraintID {.},
                    $constraintParams,
                    attribute actCount {$targetCount},
                    $msg
                }</gx:error>
        else                
            <gx:green>{
                    attribute constraintComp {'targetSize'},
                    $constraint/@resourceShapeID,
                    $constraint/@id/attribute constraintID {.},
                    $constraintParams,
                    attribute actCount {$targetCount}
            }</gx:green>
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
 : Augments an XPath or foxpath expression by adding a prolog containing
 : (a) a namespace declaration for prefix 'gx', (b) external variable
 : bindings for the given variable names.
 :
 : @param query the expression to be augmented
 : @param contextNames the names of the external variables
 : @return the augmented expression
 :)
declare function f:finalizeQuery($query as xs:string, $contextNames as xs:anyAtomicType*)
        as xs:string {
    let $prolog := ( 
'declare namespace gx="http://www.greenfox.org/ns/schema";',
for $contextName in $contextNames 
let $varName := 
    if ($contextName instance of xs:QName) then string-join((prefix-from-QName($contextName), local-name-from-QName($contextName)), ':')     
    else $contextName
    return concat('declare variable $', $varName, ' external;')
    ) => string-join('&#xA;')
    return concat($prolog, '&#xA;', $query)
};

declare function f:determineRequiredBindingsXPath($query as xs:string,
                                                  $candidateBindings as xs:string*)
        as xs:string* {
    let $query := f:finalizeQuery($query, $candidateBindings)
    let $_DEBUG := file:write('DEBUG_QUERY.txt', $query)
    let $tree := xquery:parse($query)
    return $tree//StaticVarRef/@var => distinct-values() => sort()
};

declare function f:determineRequiredBindingsFoxpath($query as xs:string,
                                                    $candidateBindings as xs:string*)
        as xs:string* {
    let $query := f:finalizeQuery($query, $candidateBindings)
    let $_DEBUG := file:write('DEBUG_QUERY.txt', $query)
    let $tree := f:parseFoxpath($query)
    return (
        $tree//var[not((parent::let, parent::for))]/@localName => distinct-values() => sort()
    )[. = $candidateBindings]
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



