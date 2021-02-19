(:
 : -------------------------------------------------------------------------
 :
 : greenfoxVarUtil.xqm - tools for performing variable substitutions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_request.xqm",
   "tt/_reportAssistent.xqm",
   "tt/_errorAssistent.xqm",
   "tt/_foxpath-uri-operations.xqm",
   "tt/_log.xqm",
   "tt/_nameFilter.xqm",
   "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "log.xqm" ;
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Substitutes variable references with variable values. The references have the form ${name} or
 : @{name}. References using the dollar character are resolved using $context, and references
 : using the @ character are resolved using $callContext.
 :
 : Value items which are not atomic are returned unchanged.
 :
 : @param value a value
 : @param context a context which is a map associating key strings with value strings
 : @param callContext a second context
 : @return a copy of the string with all variable references replaced with variable values
 :)
declare function f:substituteVars($value as item()*, 
                                  $context as map(xs:string, item()*), 
                                  $callContext as map(xs:string, item()*)?) 
        as item()* {
    for $item in $value
    return
        if (not($item instance of xs:anyAtomicType)) then $item
        else
            let $s := f:substituteVarsAux($item, $context, '\$')
            return
                if (empty($callContext)) then $s    
                else f:substituteVarsAux($s, $callContext, '@') 
};

(:~
 : Auxiallary function of `f:substituteVars`.
 :
 : @param s a string
 : @param context a context which is a map associating key strings with value strings
 : @param prefixChar character signalling a variable reference 
 : @return a copy of the string with all variable references replaced with variable values
 :) 
declare function f:substituteVarsAux($s as xs:anyAtomicType?, 
                                     $context as map(xs:string, item()*), 
                                     $prefixChar as xs:string) as xs:string? {
    let $s := string($s)                                     
    let $sep := codepoints-to-string(30000)
    let $parts := replace($s, concat('^(.*?)(', $prefixChar, '\{.*?\})(.*)'), 
                              concat('$1', $sep, '$2', $sep, '$3'),
                              's')
    return
        if ($parts eq $s) then $s   (: no matches :)
        else
            let $partStrings := tokenize($parts, $sep)
            let $prefix := $partStrings[1]
            let $varRef := $partStrings[2]
            let $postfix := $partStrings[3][string()]
            let $varName := $varRef ! substring(., 3) ! substring(., 1, string-length(.) - 1)
            let $varValue :=
                let $items :=
                    if (not($varName = map:keys($context))) then
                        error(QName((), 'INVALID_SCHEMA'), concat('Variable reference cannot be resolved: ', $varName))
                    else
                        $context($varName) ! f:substituteVarsAux(., $context, $prefixChar)       
                return
                    if (count($items) gt 1) then string-join($items, ' ')
                    else $items
            return
                concat($prefix, ($varValue, $varRef)[1], 
                       $postfix ! f:substituteVarsAux(., $context, $prefixChar))                
};

