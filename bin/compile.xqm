(:
 : -------------------------------------------------------------------------
 :
 : compile.xqm - functions compiling a greenfox schema, producing an augmented copy.
 :
 : Changes:
 : - variable substitution (using the `context` element)
 : - add @xml:base to the root element
 : - add id attributes: @id, @valueShapeID, @resourceShapeID :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n    c o m p i l i n g    t h e    s c h e m a
 :
 : ============================================================================ :)

(:~
 : Compiles a greenfox schema and returns an augmented copy of the schema, plus
 : a context map. The context map consists of the context map contained by the
 : schema, extended/overwritten by the name-value pairs supplied as
 : external context. 
 :
 : The following documentation is currently not valid:
 :   In the augmented schema, components with a component
 :   reference are replaced with the referenced component, augmented with the
 :   attributes and content elements of the referencing component.
 :
 : @param gfox a greenfox schema
 : @param params a string encoding parameter value assignments supplied by the user
 : @param domain the path of the domain, as supplied by the user
 : @return the augmented schema, and a context map
 :)
declare function f:compileGreenfox($gfox as element(gx:greenfox), 
                                   $params as xs:string?,
                                   $domain as xs:string?) 
        as item()+ {
        
    (: The external context contains the parameter values supplied by the user via 
       parameter 'params', augmented with $domain and the schema path :)
    let $externalContext := f:externalContext($params, $domain, $gfox)        
        
    (: Merge context contents with externally supplied name-value pairs,
       and perform variable substitutions :)
    let $context := f:editContext($gfox/gx:context, $externalContext)
    
    (: Perform variable substitution :)
    let $gfox2 := f:substituteVariablesRC($gfox, $context)
    let $gfox3 := f:compileGreenfox_addIds($gfox2)
    let $gfox4 := f:compileGreenfox_addResourceShapeIds($gfox3)
    return
        ($gfox4, $context)
};

(: ============================================================================
 :
 :     f u n c t i o n    m a n a g i n g    t h e    c o n t e x t
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
            let $schemaLocation := $gfox/base-uri(.) ! i:pathToNative(.)
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
                $domain ! i:pathToNative(.) ! map:put($prelim2, 'domain', .)
        (: Without domain parameter :)                
        else  
            (: If domain name-value pair: edit value (making path absolute) :)        
            let $domainFromNvpair := map:get($prelim2, 'domain')
            return           
                if ($domainFromNvpair) then
                    $domainFromNvpair ! i:pathToNative(.) ! map:put($prelim2, 'domain', .)
                else $prelim2
    return
        $prelim3
};

(:~
 : Edits a schema context, overwriting default values with external values
 : and performing variable substitution.
 :
 : @param context the schema context
 : @param externalContext a context assembled from externally supplied values
 : @return the edited context
 :)
declare function f:editContext($context as element(gx:context),
                               $externalContext as map(xs:string, item()*))
        as map(xs:string, item()*) {
    (: Collect entries, overwriting schemaq values with external values :)        
    let $entries := (        
        if ($context/gx:field[@name eq 'schemaPath']) then ()
        else $externalContext?schemaPath ! map:entry('schemaPath', .)
        ,
        if ($context/gx:field[@name eq 'domain']) then ()
        else $externalContext?domain ! map:entry('domain', .)
        ,
        for $field in $context/gx:field
        let $name := $field/@name/string()
        let $value := ($externalContext($name), $field/@value)[1]
        return
            map:entry($name, $value)
    )
    return 
        (: Perform variable substitution :)    
        map:merge(
            if (empty($entries)) then () else
                f:editContextRC($entries, $externalContext, map{})
        )        
};

(:~
 : Auxiliary function of function `f:editontext`.
 :
 :)
declare function f:editContextRC($contextEntries as map(xs:string, item()*)+,
                                 $externalContext as map(xs:string, item()*),
                                 $substitutionContext as map(xs:string, item()*))
        as map(xs:string, item()*)+ {
    let $head := head($contextEntries)
    let $tail := tail($contextEntries)
    
    let $name := map:keys($head)
    let $value := $head($name)
    let $augmentedValue := 
        let $raw := f:substituteVars($value, $substitutionContext, ())
        return
            if ($name eq 'domain') then i:pathToNative($raw)
            else $raw
    let $augmentedEntry := map:entry($name, $augmentedValue)    
    let $newSubstitutionContext := map:merge(($substitutionContext, $augmentedEntry))
    return (
        $augmentedEntry,
        if (empty($tail)) then () else
            f:editContextRC($tail, $externalContext, $newSubstitutionContext)
    )            
};        

(: ============================================================================
 :
 :     f u n c t i o n s    s u b s t i t u t i n g    v a r i a b l e    r e f e r e n c e s
 :
 : ============================================================================ :)
 
 (:~
 : Returns an augmented copy of a greenfox schema. Changes:
 : (a) @xml:base added to the root element
 : (b) text nodes and attributes: variable substitution
 :
 : @param n a node of the greenfox schema currently processed.
 : @param context a set of external variables
 : @return the processing result
 :)
declare function f:substituteVariablesRC($n as node(), $context as map(xs:string, item()*)) as node() {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:substituteVariablesRC(., $context)}
    
    (: Copies the root element, adds an @xml:base if not yet present :)
    case element(gx:greenfox) return
        element {node-name($n)} {
            i:copyNamespaceNodes($n),
            $n/@* ! f:substituteVariablesRC(., $context),
            if ($n/@xml:base) then () else attribute xml:base {base-uri($n)},
            $n/node() ! f:substituteVariablesRC(., $context) 
        }

    (: Context - add entries from external context not contained by schema context :)
    case element(gx:context) return
        element {node-name($n)} {
            map:keys($context)[not(. = $n/gx:field/@name)] 
            ! <field xmlns="http://www.greenfox.org/ns/schema" name="{.}" value="{$context(.)}"/>,
            $n/* ! f:substituteVariablesRC(., $context)
        }
        
    case element(gx:field) return
        let $name := $n/@name
        return
            element {node-name($n)} {
                $n/@name ! f:substituteVariablesRC(., $context),
                $n/attribute value {($context($name), @value)[1]}
            }
        
    (: Copies the element :)
    case element() return
        element {node-name($n)} {
            i:copyNamespaceNodes($n),
            $n/@* ! f:substituteVariablesRC(., $context),
            $n/node() ! f:substituteVariablesRC(., $context)            
        }
        
    (: text node - variable substitution :)
    case text() return text {f:substituteVars($n, $context, ())}
    
    (: attribute - variable substitution :)
    case attribute() return 
    attribute {node-name($n)} {f:substituteVars($n, $context, ())}
    
    default return $n        
};

(:~
 : Substitutes variable references with variable values. The references have the form ${name} or
 : @{name}. References using the dollar character are resolved using $context, and references
 : using the @ character are resolved using $callContext.
 :
 : @param s a string
 : @param context a context which is a map associating key strings with value strings
 : @param callContext a second context
 : @return a copy of the string with all variable references replaced with variable values
 :)
declare function f:substituteVars($s as xs:string?, 
                                  $context as map(xs:string, item()*), 
                                  $callContext as map(xs:string, item()*)?) 
        as xs:string? {
    let $s2 := f:substituteVarsAux($s, $context, '\$')
    return
        if (empty($callContext)) then $s2    
        else f:substituteVarsAux($s2, $callContext, '@') 
};

(:~
 : Auxiallary function of `f:substituteVars`.
 :
 : @param s a string
 : @param context a context which is a map associating key strings with value strings
 : @param prefixChar character signalling a variable reference 
 : @return a copy of the string with all variable references replaced with variable values
 :) 
declare function f:substituteVarsAux($s as xs:string?, 
                                     $context as map(xs:string, item()*), 
                                     $prefixChar as xs:string) as xs:string? {
    let $sep := codepoints-to-string(30000)
    let $parts := replace($s, concat('^(.*?)(', $prefixChar, '\{.*?\})(.*)'), 
                              concat('$1', $sep, '$2', $sep, '$3'))
    return
        if ($parts eq $s) then $s   (: no matches :)
        else
            let $partStrings := tokenize($parts, $sep)
            let $prefix := $partStrings[1]
            let $varRef := $partStrings[2]
            let $postfix := $partStrings[3][string()]
            let $varName := $varRef ! substring(., 3) ! substring(., 1, string-length(.) - 1)
            let $varValue := $context($varName) ! f:substituteVarsAux(., $context, $prefixChar)           
            return
                concat($prefix, ($varValue, $varRef)[1], 
                       $postfix ! f:substituteVarsAux(., $context, $prefixChar))                
};


(: ============================================================================
 :
 :     f u n c t i o n s    a d d i n g    I D    a t t r i b u t e s
 :
 : ============================================================================ :)

(:~
 : Adds @id and further attributes to selected elements. Added attributes:
 : @id, @resourceShapeID, @valueShapeID.
 :
 : Special rules:
 : - @resourceShapeID is added to `file` and `folder` elements only
 : - @valueShapeID is added to `xpath`, `foxpath` and `links` elements only
 : - on `mediatype`elements, the ID attribute is called `constraintID`, 
 :   rather than `id`.
 :
 : Selected elements: all elements except for `context` and its descendants.
 :
 : @param gfox a greenfox schema
 : @return an augmented copy, containing the added attributes
 :)
declare function f:compileGreenfox_addIds($gfox as element(gx:greenfox)) {
    copy $gfox_ := $gfox
    modify
        let $elems := ($gfox_//*) except ($gfox_/gx:context/descendant-or-self::*)
        for $elem in $elems
        group by $localName := local-name($elem)
        return
            for $e at $pos in $elem
            
            (: Add @id attribute :)
            let $idAtt := $e/@id
            let $idValue := ($idAtt, concat($localName, '_', $pos))[1]
            let $idName :=
                switch($localName)
                case 'mediatype' return 'constraintID'
                case 'folderContentSimilar' return 'constraintID'
                case 'docSimilar' return 'constraintID'
                case 'deepSimilar' return 'constraintID'
                default return 'id'
                
            (: Add further attributes, if applicable (@resourceShapeID, @valueShapeID) :)
            let $furtherAtts:=
                typeswitch($elem[1])
                case element(gx:file) | element(gx:folder) return
                    if ($elem/@resourceShapeID) then ()
                    else attribute resourceShapeID {$idValue}
                case element(gx:xpath) | element(gx:foxpath) | element(gx:links) return
                    if ($elem/@valueShapeID) then ()
                    else attribute valueShapeID {$idValue}
                default return ()
            return
            (: Delete existing @id, add @id and further attributes :)
            (
                $idAtt/(delete node .),
                insert node (attribute {$idName} {$idValue}, $furtherAtts) as first into $e                
            )                
    return $gfox_                
};

declare function f:compileGreenfox_addResourceShapeIds($gfox as element(gx:greenfox)) {
    f:compileGreenfox_addResourceShapeIdsRC($gfox)
};

declare function f:compileGreenfox_addResourceShapeIdsRC($n as node()) {
    typeswitch($n)
    
    (: `file` and `folder` are just copied :)
    case element(gx:file) | element(gx:folder) return
        element {node-name($n)} {
            i:copyNamespaceNodes($n),
            $n/@* ! f:compileGreenfox_addResourceShapeIdsRC(.),
            $n/node() ! f:compileGreenfox_addResourceShapeIdsRC(.)
        }
     
    (: Special treatment of `TargetSize` obsolete
    
    (: TargetSize - add @resourceShapeID :)        
    case element(gx:targetSize) return
        let $resourceShapeID := $n/ancestor::*[self::gx:file, self::gx:folder][1]/@resourceShapeID
        return
            element {node-name($n)} {
                i:copyNamespaceNodes($n),
                $resourceShapeID,
                $n/@* ! f:compileGreenfox_addResourceShapeIdsRC(.),
                $n/node() ! f:compileGreenfox_addResourceShapeIdsRC(.)
            }
    :)
    
    (: Divers elements - add @resourceShapeID :)
    case element() return
        let $resourceShapeID :=
            if ($n/(self::gx:xpath,
                    self::gx:foxpath,
                    self::gx:links,   
                    self::gx:targetSize,
                    self::gx:fileName,                    
                    self::gx:fileSize, 
                    self::gx:lastModified, 
                    self::gx:mediatype,
                    self::gx:folderContentSimilar,
                    self::gx:docSimilar,
                    self::gx:deepSimilar,
                    self::gx:folderContent,
                    self::gx:xsdValid)) then  
                $n/ancestor::*[self::gx:file, self::gx:folder][1]/@resourceShapeID
            else ()                
        return
            element {node-name($n)} {
                i:copyNamespaceNodes($n),
                $resourceShapeID,
                $n/@* ! f:compileGreenfox_addResourceShapeIdsRC(.),
                $n/node() ! f:compileGreenfox_addResourceShapeIdsRC(.)
            }
    default return $n        
};

(: ============================================================================
 :
 :     f u n c t i o n s    c u r r e n t l y    n o t    u s e d
 :
 : ============================================================================ :)

(:~
 : Inspects a component and returns another component which it references, 
 : or the original component if it does not reference another component. 
 : A reference is expressed by an @ref attribute. The referenced component 
 : is the checklib element with an @id attribute matching the value of @ref 
 : and with a local name matching the local name of the referencing component.
 :
 : NOTE: This function is currently not used.
 :
 : @param gxComponent a component possibly referencing another component
 : @return the original component, if it does not have a reference, or the
 :   referenced component
 :)
declare function f:compileGreenfox_resolveReference($gxComponent as element()) as element() {
    if (not($gxComponent/@ref)) then $gxComponent else
    
    let $gxname := local-name($gxComponent)
    let $target := $gxComponent/root()//gx:checklib/*[local-name(.) eq $gxname][@id eq $gxComponent/@ref]
    return
        $target
};


