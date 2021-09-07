(:
 : -------------------------------------------------------------------------
 :
 : processingContext.xqm - functions for managing the processing context
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "foxpathUtil.xqm",
   "greenfoxUtil.xqm",
   "uriUtil.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     I n i t i a l    p r o c e s s i n g    c o n t e x t
 :
 : ============================================================================ :)

(:~
 : Creates the initial processing context. Its content reflect ...
 : - schema element <context>
 : - schema elements <linkDef>
 : - user-supplied arguments
 :
 : @param gfox a greenfox schema
 : @param params a string encoding parameter value assignments supplied by the user
 : @param domain the path of the domain, as supplied by the user
 : @return the initial context
 :)
declare function f:initialProcessingContext($gfox as element(gx:greenfox), 
                                            $params as xs:string?,
                                            $domain as xs:string?)
        as map(xs:string, item()*) {
        
    (: Parse the external context, supplied by the user as name/value pairs :)
    let $externalContext := f:parseExternalContext($params, $domain, $gfox)
    
    (: Check the external context :)
    let $_CHECK := f:checkExternalContext($externalContext, $gfox/gx:context)
    
    (: Build processing context map :)
    let $fields := $gfox/gx:context/gx:field
    let $substitutionContext := $externalContext
    let $entries := f:initialProcessingContextRC($fields, $substitutionContext)
    return map:merge($entries)
};

(:~
 : Auxiliary function supporting function `f:initialProcessingContext`. Adds for each
 : field in $fields a map entry. If the value is an expression, it is resolved.
 : Performs variable substitutions. Normalizes 'domain', 'domainURI', 'domainFOX'.
 : Adds variables: any variable from 'domain', 'domainURI', 'domainFOX' triggers
 : the addition of the other two variables.
 :)
declare function f:initialProcessingContextRC(
                        $fields as element(gx:field)+,
                        $substitutionContext as map(xs:string, item()*))
        as map(xs:string, item()*)* {
    let $head := head($fields)
    return if (empty($head)) then () else    
    let $tail := tail($fields)
    let $name := $head/@name/string()
    let $litValue := $head/($substitutionContext($name), @value/string())[1] ! f:substituteVars(., $substitutionContext, ())
    let $valueXP := $head/@valueXP/string() ! f:substituteVars(., $substitutionContext, ())
    let $valueFOX := $head/@valueFOX/string() ! f:substituteVars(., $substitutionContext, ())
    
    (: Raw value :)
    let $value :=
        (: Literal value :)
        if (exists($litValue)) then $litValue
        
        (: Foxpath expression - context = schemaURI :)
        else if ($valueFOX) then
            let $schemaURI := $substitutionContext?schemaURI
            let $evaluationContext := i:mapKeysToQName($substitutionContext)
            return
                i:evaluateFoxpath($valueFOX, $schemaURI, $evaluationContext, true())
                
        (: XPath expression :)                
        else if ($valueXP) then
            let $evaluationContext := i:mapKeysToQName($substitutionContext)
            return
                i:evaluateXPath($valueXP, (), $evaluationContext, true(), true())
    
    (: Value after substitutions :)
    let $substitutedValue := f:substituteVars($value, $substitutionContext, ())[exists($value)]
    
    (: Check :)
    let $_CHECK := f:checkProcessingContextVariable($name, $substitutedValue, $valueXP, $valueFOX)
    
    (: Finalized value :)
    let $finalizedValue := f:normalizeProcessingContextVariable($name, $substitutedValue)               
             
    (: Map entry :)                
    let $entry := map:entry($name, $finalizedValue)
    
    (: Additional entries :)
    
    (: Each one from 'domain', 'domainURI', 'domainFOX' triggers the other two :)
    let $additionalEntries :=
        if ($name eq 'domain') then
            let $foxpath := i:pathToAbsoluteFoxpath($finalizedValue)
            return (                                        
                map:entry('domainURI', $finalizedValue),
                map:entry('domainFOX', $foxpath)
        ) else if ($name eq 'domainFOX') then
            let $uri := i:pathToAbsoluteUriPath($finalizedValue)
            return (
                map:entry('domainURI', $uri),
                map:entry('domain', $uri)
        ) else if ($name eq 'domainURI') then
            let $foxpath := i:pathToAbsoluteFoxpath($finalizedValue)
            return (
                map:entry('domain', $finalizedValue),
                map:entry('domainFOX', $foxpath)
        ) else ()
        
    (: Update substitution context :)
    let $newSubstitutionContext := map:merge(($substitutionContext, $entry, $additionalEntries))
    return (
        $entry,
        $additionalEntries,
        if (empty($tail)) then () else
            f:initialProcessingContextRC($tail, $newSubstitutionContext)
    )            
};        

(:~
 : Checks the normalized value of a context variable, throwing an exception
 : in case of an invalid value.
 :
 : @param name the variable name
 : @param value the variable value
 : @return the normalized value
 :)
declare function f:checkProcessingContextVariable($name as xs:string, 
                                                  $value as xs:string?,
                                                  $valueXP as xs:string?,
                                                  $valueFOX as xs:string?)
        as xs:string? {
    if ($name = ('domain', 'domainFOX', 'domainURI')) then
        if (exists($value)) then () else
            let $expr := ($valueFOX, $valueXP)[1]
            return
                error(QName((), 'INVALID_SCHEMA'), 
                    concat("### INVALID SCHEMA - expression for context variable '", $name, 
                    "' does not identify an existence resource, ",
                    "please correct and retry;&#xA;### expression: ", $expr))
    else ()        
};

(:~
 : Returns the normalized value of a context variable.
 :
 : @param name the variable name
 : @param value the variable value
 : @return the normalized value
 :)
declare function f:normalizeProcessingContextVariable($name as xs:string, $value as xs:string?)
        as xs:string? {
              
    (: variable 'domain' :)    
    if ($name eq 'domain') then 
        try {i:pathToAbsoluteUriPath($value)}
        catch * {
            error(QName((), 'INVALID_SCHEMA'), 
            concat("### INVALID SCHEMA - context variable 'domain' not a valid path, ",
            "please correct and retry;&#xA;### value: ", $value ! i:normalizeAbsolutePath(.)))}
            
    (: variable 'domainFOX' :)
    else if ($name eq 'domainFOX') then 
        try {i:pathToAbsoluteFoxpath($value)}
        catch * {
            error(QName((), 'INVALID_SCHEMA'), 
            concat("### INVALID SCHEMA - context variable 'domainFOX' not a valid Foxpath, ",
            "please correct and retry;&#xA;### value: ", $value ! i:normalizeAbsolutePath(.)))}
            
    (: variable 'domainURI' :)
    else if ($name eq 'domainURI') then  
        try {i:pathToAbsoluteUriPath($value)}
        catch * {
        error(QName((), 'INVALID_SCHEMA'), 
            concat("### INVALID SCHEMA - context variable 'domainURI' not a valid path, ",
            "please correct and retry;&#xA;### value: ", $value ! i:normalizeAbsolutePath(.)))}
            
    else $value
};


(: ============================================================================
 :
 :     U p d a t e    p r o c e s s i n g    c o n t e x t
 :
 : ============================================================================ :)

(:~
 : Updates the processing context by updating the _resourceRelationships entry.
 : New link definitions are parsed from <linkDef> elements and added to the context,
 : overwriting any existing link definitions with the same name.
 :
 : The function is called from function compileGreenfox(), module compile.xqm.
 :
 : @param context the current processing context
 : @param linkDefs Link Definition elements
 : @return the updated processing context
 :)
declare function f:updateProcessingContext_resourceRelationships(
                                             $context as map(*),
                                             $linkDefs as element(gx:linkDef)*)
        as map(*) {
    let $newRelationships := link:parseLinkDefs($linkDefs, $context)
    return if (empty($newRelationships)) then $context else
        
    let $newNames := $newRelationships ! map:keys(.)    
    let $currentRelationships := $context?_resourceRelationships
    return 
        if (empty($currentRelationships)) then 
            map:put($context, '_resourceRelationships', $newRelationships)
        else
            let $currentNames := $currentRelationships ! map:keys(.)
            return
                map:merge((
                    $newRelationships,
                    $currentNames[not(. = $newNames)] ! $currentRelationships(.)
                ))
};    

(:~
 : Updates the processing context as required in order to begin validation of the domain.
 :
 : The processing context is extended by the following entries:
 : _contextPath - domain URI
 : _domain - domain URI
 : _domainPath - domain path
 : _domainName - domain name
 : _evaluationContext - the evaluation context, mapping QNames to values
 : _targetInfo - {contextURI - domainURI}
 : _reqDocs - (empty)
 : _externalVars - names of external variables
 :
 : The evaluation context is filled with the following entries:
 : - domain - domain URI
 : - domainName - domain name
 : - external variables
 :
 : @param domainElem domain element
 : @param context the current processing context
 : @return updated processing context
 :)
declare function f:updateProcessingContext_domain($domainElem as element(gx:domain), 
                                                  $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $dpath := $domainElem/(@uri, @path)[1]
    let $domainPath := try {$dpath ! i:pathToAbsolutePath(.)} catch * {()}
    return
        if (not($domainPath)) then
            error(QName((), 'INVALID_ARG'), concat('Domain not found: ', $dpath))
        else
                
    let $domainURI := $domainPath ! i:pathToUriCompatible(.)
    let $domainName := $domainElem/@name/string()
    
    (: Evaluation context, containing entries available as 
       external variables to XPath and foxpath expressions;
       initial entries: domain, domainName:)
    let $evaluationContext :=
        map:merge((
            map:entry(QName((), 'domain'), $domainURI),
            map:entry(QName((), 'domainName'), $domainName),
            f:mapKeysToQName($context)
        ))

    (: Processing context, containing entries available to
       the processing code; initial entries :)
    let $context :=
        map:merge((
            $context,
            map:entry('_contextPath', $domainURI),
            map:entry('_evaluationContext', $evaluationContext),            
            map:entry('_domain', $domainURI),
            map:entry('_domainPath', $domainPath),            
            map:entry('_domainName', $domainName),
            map:entry('_targetInfo', map{'contextURI': $domainURI}),
            map:entry('_reqDocs', ()),
            map:entry('_externalVars', map:keys($context))
        ))
    return
        $context    
};

 (: ============================================================================
 :
 :     P a r s i n g / c h e c k i n g    c o n t e x t
 :
 : ============================================================================ :)

(:~
 : Maps the value of a parameters string to a set of name-value pairs.
 :
 : The string consists of semicolon-separated name=value pairs. Within
 : parameter values, any occurrence of backslash or semicolon must be
 : escaped by a preceding backslash.
 :
 : Augmentation:
 : (1) Add value pairs 'schemaURI', 'schemaFOX':
 :     schemaURI - schema path, using slashes (no preceding file://)
 :     schemaFOX - schema path, using backslashes
 : (2) If function parameter $domain is supplied or a 'domain' name-value pair
 :     exists: add name-value pairs ...
 :       domainURI - domain path, using slashes (no preceding file://)
 :       domainFOX - domain path, using backslashes
 :     and set 'domain' to the same value as 'domainURI'. 
 :
 : @param params a parameters string containing semicolon-separated name-value pairs
 : @param domain the value of call parameter 'domain', should be the path of the domain folder
 : @param gfox the greenfox schema
 : @return a map expressing the name-value pairs
 :)
declare function f:parseExternalContext($params as xs:string?, 
                                        $domain as xs:string?,
                                        $gfox as element(gx:greenfox)) 
        as map(xs:string, item()*) {
    let $gfoxContext := $gfox/gx:greenfox/gx:context    
    let $nvPairs := tokenize($params, '\s*;\s*')   (: _TO_DO_ unsafe parsing :)
    let $prelim :=
        map:merge(
            $nvPairs ! 
            map:entry(replace(., '\s*=.*', ''), 
                      replace(., '^.*?=\s*', ''))
        )

    (: Add 'schemaURI', 'schemaFOX' entries :)                
    let $prelim2 :=
        let $schemaLocation := $gfox/base-uri(.)            
        let $schemaLocationFOX := try {$schemaLocation ! i:pathToAbsoluteFoxpath(.)} catch * {()} 
        let $schemaLocationURI := try {$schemaLocation ! i:pathToAbsoluteUriPath(.)} catch * {()} 
        return 
            if (not($schemaLocationFOX)) then
                error(QName((), 'INVALID_ARG'), concat('Invalid schema path: ', $schemaLocation))
            else                    
                map:put($prelim, 'schemaFOX', $schemaLocationFOX)
                ! map:put(., 'schemaURI', $schemaLocationURI)

    (: If entry 'domain' exists:
       - normalize entry: absolute path, using slashes;
       - add entries domainFOX and domainURI :)
    let $prelim3 :=
        let $useDomain := ($domain, map:get($prelim2, 'domain'))[1]
        return
            if (not($useDomain)) then $prelim2
            else
                (: Add 'domain' entries (domain, domainFOX, domainURI) :)
                let $domainFOX := try {$useDomain ! i:pathToAbsoluteFoxpath(.)} catch * {()} 
                let $domainURI := trace(try {$useDomain ! i:pathToAbsoluteUriPath(.)} catch * {()} , '_DOMAIN_URI: ') 
                return
                    if (not($domainFOX) or not($domainURI)) then 
                        error(QName((), 'INVALID_ARG'), concat('Domain not found: ', $useDomain))
                    else                        
                        map:put($prelim2, 'domain', $domainURI)
                        ! map:put(., 'domainFOX', $domainFOX)
                        ! map:put(., 'domainURI', $domainURI)                        
    return
        $prelim3
};

(:~
 : Checks if the external context contains a value for each context field without
 : default value. Also checks that the external context contains only the names
 : of variables declared within the context element or added by the system
 : (schemaFOX, schemaURI, domainFOX, domainURI).
 :
 : @param externalContext external context map
 : @param contextElem the context element of the schema
 : @return empty sequence, if check ok, otherwise an exception is thrown
 :)
declare function f:checkExternalContext($externalContext as map(*), 
                                        $contextElem as element(gx:context))
        as empty-sequence() {
    let $internalKeys := $contextElem/gx:field/@name/string()        
    let $externalKeys := map:keys($externalContext)
    let $externalKeysUnknown := $externalKeys
        [not(. = ($internalKeys, 'schemaURI', 'schemaFOX', 'domainURI', 'domainFOX', 'domain'))] => sort()
        
    (: Issue #1: unknown variable names :)
    return
        if (exists($externalKeysUnknown)) then
            let $plural := 's'[count($externalKeysUnknown) gt 1]
            return
                error(QName((), 'INVALID_ARG'), 
                    concat('Unknown parameter', $plural, ': ', 
                        string-join($externalKeysUnknown, ', '))) 
        else

    (: Issue #2: missing mandatory values :)
    let $missingValues :=
        $contextElem/gx:field[empty((@value, @valueXP, @valueFOX))]/@name[not(map:contains($externalContext, .))]
    return
        if (empty($missingValues)) then ()
        else
            let $missingValuesString1 := string-join($missingValues, ', ')
            let $missingValuesString2 := string-join($missingValues ! concat('-p "', ., ' =..."') => string-join(' '))
            return
                error(QName((), 'MISSING_INPUT'),
                        concat('Missing context values for required context fields: ', 
                               $missingValuesString1,
                               '. Please supply values using option -p: ', 
                               $missingValuesString2))
};



