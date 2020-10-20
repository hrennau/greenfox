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
 :     U p d a t e    p r o c e s s i n g    c o n t e x t
 :
 : ============================================================================ :)

(:~
 : Updates the processing context by updating the _resourceRelationships entry.
 : New relationships are parsed from <linkDef> elements and added to the context,
 : overwriting any existing relationship with the same name.
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
 : @param domainElem domain element
 : @param context the current processing context
 : @return validation results
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
            map:entry(QName((), 'domainName'), $domainName)
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
            map:entry('_reqDocs', ())
        ))
    return
        $context    
};

(: ============================================================================
 :
 :     I n i t i a l    p r o c e s s i n g    c o n t e x t
 :
 : ============================================================================ :)

(:~
 : Creates the initial processing context. Its context reflect ...
 : - schema element <context>
 : - schema elements <linkDef> which are immediate child elements of the root element
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
        
    (: Parse the external context. It has been supplied by the user as a
       concatenated list of name/value pairs. :)
    let $externalContext := f:externalContext($params, $domain, $gfox)
    
    (: Check the external context :)
    let $_CHECK := f:checkExternalContext($externalContext, $gfox/gx:context)
        
    (: Collect entries, overwriting schema values with external values :)
    let $contextElem := $gfox/gx:context
    let $domainEC := $externalContext?domain
    let $domainIC := $contextElem/gx:field[@name eq 'domain']/@value/string()
    let $entries := (        
        if ($contextElem/gx:field[@name eq 'schemaPath']) then ()
        else $externalContext?schemaPath ! map:entry('schemaPath', .)
        ,
        if ($contextElem/gx:field[@name eq 'domain']) then ()
        else $externalContext?domain ! map:entry('domain', .)
        ,
        if ($contextElem/gx:field[@name eq 'domainURI']) then ()
        else ($domainEC, $domainIC)[1] ! map:entry('domainURI', .)
        ,
        for $field in $contextElem/gx:field
        let $name := $field/@name/string()
        let $value := ($externalContext($name), $field/@value)[1]
        return
            map:entry($name, $value)
    )
    (: Replace variable references :)
    let $entries2 := f:editContextEntries($entries)
    return map:merge($entries2)   
};

(:~
 : Edits context entries, replacing variable references. An entry may reference
 : earlier entries as a variable.
 :)
declare function f:editContextEntries($contextEntries as map(xs:string, item()*)+)
        as map(xs:string, item()*)+ {
    f:editContextEntriesRC($contextEntries, map{})        
};        

(:~
 : Auxiliary function of function `f:editContextEntries`.
 :
 :)
declare function f:editContextEntriesRC($contextEntries as map(xs:string, item()*)+,
                                        $substitutionContext as map(xs:string, item()*))
        as map(xs:string, item()*)+ {
    let $head := head($contextEntries)
    let $tail := tail($contextEntries)
    
    let $name := map:keys($head)
    let $value := $head($name)
    let $augmentedValue := 
        let $raw := f:substituteVars($value, $substitutionContext, ())
        return
            if ($name eq 'domain') then 
                try {
                    let $apath := i:pathToAbsoluteFoxpath($raw)
                    let $path := $apath ! i:normalizeAbsolutePath(.)
                    (: let $_DEBUG := trace($path, '___DOMAIN_PATH: ') :)
                    return $path
                }
                catch * {
                    error(QName((), 'INVALID_SCHEMA'), 
                        concat("### INVALID SCHEMA - context variable 'domain' not a valid path, ",
                        "please correct and retry;&#xA;### value: ", $raw ! i:normalizeAbsolutePath(.)))}
            else if ($name eq 'domainURI') then  
                try {
                    let $apath := i:pathToAbsoluteFoxpath($raw)
                    let $path := $apath ! i:normalizeAbsolutePath(.)
                    (: let $_DEBUG := trace($path, '___DOMAIN_PATH: ') :)
                    let $uri := $path ! i:pathToUriCompatible(.)
                    return $uri
                }
                catch * {
                    error(QName((), 'INVALID_SCHEMA'), 
                        concat("### INVALID SCHEMA - context variable 'domain' not a valid path, ",
                        "please correct and retry;&#xA;### value: ", $raw ! i:normalizeAbsolutePath(.)))}
            else $raw
    let $augmentedEntry := map:entry($name, $augmentedValue)    
    
    let $newSubstitutionContext := map:merge(($substitutionContext, $augmentedEntry))
    return (
        $augmentedEntry,
        if (empty($tail)) then () else
            f:editContextEntriesRC($tail, $newSubstitutionContext)
    )            
};        

 (: ============================================================================
 :
 :     P a r s i n g    e x t e r n a l    c o n t e x t
 :
 : ============================================================================ :)

(:~
 : Maps the value of a parameters string to a set of name-value pairs.
 :
 : Augmentation:
 : (1) If function parameter $domain is supplied: add 'domain' name-value pair 
 :     Otherwise, if the parameters string contains a 'domain' emtry: 
 :     edit 'domain' name-value pair, making the path absolute
 : (2) Add 'schemaPath' name-value pair, where the value is the file path of the schema -
 :     unless the parameters string contains a 'schemaPath' parameter, or the 'context' element 
 :     of the schema has a 'schemaPath' field with a default value 
 :
 : @param params a parameters string containing semicolon-separated name-value pairs
 : @param domain the value of call parameter 'domain', should be the path of the domain folder
 : @param gfox the greenfox schema
 : @return a map expressing the name-value pairs
 :)
declare function f:externalContext($params as xs:string?, 
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

    (: Add 'schemaPath' entry :)                
    let $prelim2 :=
        if (map:contains($prelim, 'schemaPath')) then $prelim
        else if ($gfoxContext/field[@name eq 'schemaPath']/@value) then $prelim
        else 
            let $schemaLocation := $gfox/base-uri(.)            
            let $schemaLocationAbs := 
                try {$schemaLocation ! i:pathToAbsoluteFoxpath(.) ! i:normalizeAbsolutePath(.)} 
                catch * {()} 
            return 
                if ($schemaLocationAbs) then
                    map:put($prelim, 'schemaPath', $schemaLocationAbs)                
                else
                    error(QName((), 'INVALID_ARG'), concat('Invalid schema path: ', $schemaLocation))                    

    (: Add or edit 'domain' entry;
       normalization: absolute path, using back slashes :)
    let $prelim3 :=
        (: domain parameter specified :)
        if ($domain) then
            if (map:contains($prelim2, 'domain')) then
                error(QName((), 'INVALID_ARG'),
                    concat("Ambiguous input - you supplied parameter 'domain' and also ",
                           "parameter 'params' with a 'domain' entry; aborted.'"))
            else
                (: Add 'domain' entry, value from call parameter 'domain' :)
                let $domainAbs := 
                    try {$domain ! i:pathToAbsoluteFoxpath(.) ! i:normalizeAbsolutePath(.)} 
                    catch * {()} 
                return
                    if ($domainAbs) then 
                        map:put($prelim2, 'domain', $domainAbs)
                    else 
                        error(QName((), 'INVALID_ARG'), concat('Domain not found: ', $domain))
                        
        (: Without domain parameter :)                
        else  
            (: If domain name-value pair: edit value (making path absolute) :)        
            let $domainFromNvpair := map:get($prelim2, 'domain')
            return           
                if ($domainFromNvpair) then
                    let $domainFromNvPairAbs := 
                        try {$domainFromNvpair ! i:pathToAbsoluteFoxpath(.) ! i:normalizeAbsolutePath(.)} 
                        catch * {()}
                    return
                        if ($domainFromNvPairAbs) then 
                            map:put($prelim2, 'domain', $domainFromNvPairAbs)
                        else 
                            error(QName((), 'INVALID_ARG'), concat('Domain not found: ', $domain))
                else $prelim2
    return
        $prelim3
};

(:~
 : Checks if the external context contains a value for each context field
 : without default value.
 :
 : @param externalContext external context map
 : @param contextElem the context element from the schema
 : @return empty sequence, if check ok, or throws an error otherwise
 :)
declare function f:checkExternalContext($externalContext as map(*), 
                                        $contextElem as element(gx:context))
        as empty-sequence() {
    let $internalKeys := $contextElem/gx:field/@name/string()        
    let $externalKeys := map:keys($externalContext)
    let $externalKeysUnknown := $externalKeys[not(. = $internalKeys)][not(. eq 'schemaPath')] => sort()
    return
        if (exists($externalKeysUnknown)) then
            let $plural := 's'[count($externalKeysUnknown) gt 1]
            return
                error(QName((), 'INVALID_ARG'), 
                    concat('Unknown parameter', $plural, ': ', 
                        string-join($externalKeysUnknown, ', '))) 
        else
        
    let $missingValues :=
        $contextElem/gx:field[not(@value)]/@name[not(map:contains($externalContext, .))]
    return
        if (empty($missingValues)) then ()
        else
            let $missingValuesString1 := string-join($missingValues, ', ')
            let $missingValuesString2 := string-join($missingValues ! concat(., '=...')) => string-join(';')
            return
                error(QName((), 'MISSING_INPUT'),
                        concat('Missing context values for required context fields: ', 
                               $missingValuesString1,
                               '; please supply values using call parameter "params": params="', 
                               $missingValuesString2, '"'))
};



