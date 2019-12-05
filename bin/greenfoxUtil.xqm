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
    "foxpathEvaluator.xqm",
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
    where $error    
    return
        let $msg := $constraint/@msg
        return
            <gx:error constraintComp="targetCount">{ 
                $constraint/@id/attribute constraintID {.},
                $constraintParams,
                attribute actCount {$targetCount},
                $msg
            }</gx:error>
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



