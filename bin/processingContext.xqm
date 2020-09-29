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
   "greenfoxUtil.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Updates the processing context by updating the _resourceRelationships entry.
 : New relationships are parsed from <linkDef> elements and added to the context,
 : overwriting any existing relationship with the same name.
 :
 : @param context the current processing context
 : @param linkDefs Link Definition elements
 : @return the updated processing context
 :)
declare function f:updateContextResourceRelationships($context as map(*),
                                                      $linkDefs as element(gx:linkDef)*)
        as map(*) {
    let $newRelationships := link:parseLinkDefs($linkDefs)
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

(: ============================================================================
 :
 :     I n i t i a l    c o n t e x t
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
declare function f:initialContext($gfox as element(gx:greenfox), 
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
    let $entries := (        
        if ($contextElem/gx:field[@name eq 'schemaPath']) then ()
        else $externalContext?schemaPath ! map:entry('schemaPath', .)
        ,
        if ($contextElem/gx:field[@name eq 'domain']) then ()
        else $externalContext?domain ! map:entry('domain', .)
        ,
        for $field in $contextElem/gx:field
        let $name := $field/@name/string()
        let $value := ($externalContext($name), $field/@value)[1]
        return
            map:entry($name, $value)
    )
    let $entries2 := f:editContextEntries($entries)
    return 
        (: Perform variable substitution :)    
        map:merge(
            $entries2
        )        
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
                    let $apath := i:pathToAbsolutePath($raw)
                    let $path := $apath ! i:normalizeAbsolutePath(.)
                    return trace( $path , '___DOMAIN_PATH: ')
                }
                catch * {
                    error(QName((), 'INVALID_SCHEMA'), 
                        concat("### INVALID SCHEMA - context variable 'domain' not a valid path, please correct and retry;&#xA;### value: ", $raw))}
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
            let $schemaLocation := $gfox/base-uri(.) ! i:pathToAbsolutePath(.)
            return map:put($prelim, 'schemaPath', $schemaLocation)

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
                $domain ! i:pathToAbsolutePath(.) ! map:put($prelim2, 'domain', .)
        (: Without domain parameter :)                
        else  
            (: If domain name-value pair: edit value (making path absolute) :)        
            let $domainFromNvpair := map:get($prelim2, 'domain')
            return           
                if ($domainFromNvpair) then
                    $domainFromNvpair ! i:pathToAbsolutePath(.) ! map:put($prelim2, 'domain', .)
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
    let $missingValues := 
        $contextElem/gx:field[not(@value)]/@name
        [not(map:contains($externalContext, .))]
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



