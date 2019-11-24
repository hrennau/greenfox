(:
 : -------------------------------------------------------------------------
 :
 : domainValidator.xqm - Document me!
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
    "folderValidator.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a system. The quality descriptor is compiled and the compiled form is used
 : to validate all domains. The function returns any errors, wrapped in an `errors`
 : element.
 :
 : @param gx a quality descriptor
 : @param externalContext a context specified by the caller
 : @return validation errors, if any
 :)
declare function f:validateSystem($gx as element(gx:greenFox), $context as map(*)) {
    let $errors :=
        for $domain in $gx/gx:domain return f:validateDomain($domain, $context)
    return
        <gx:errors count="{count($errors/descendant-or-self::gx:error)}">{$errors}</gx:errors>
        [$errors]
};

(:~
 : Validates a domain. The validation context is reinitialized by setting _contextPath
 : to a base URI and _domainName to a domain name.
 :
 : Feature at risk: currently, the top-level descriptors are expected to be
 : folder descriptors - this may change, allowing any descriptors to be
 : top-level.
 :
 : @param gxDomain quality descriptor of a domain
 : @param context a map representing name-value pairs available during validation
 : @return validation errors, if any
 :)
declare function f:validateDomain($gxDomain as element(gx:domain), $context as map(*))
        as element()* {
    let $baseURI := $gxDomain/@path
    let $name := $gxDomain/@name
    let $context := map:put($context, '_contextPath', $baseURI)
    let $context := map:put($context, '_domainName', $name)
    let $errors :=
        for $component in $gxDomain/(* except gx:context)
        return
            typeswitch($component)
            case element(gx:folder) return f:validateFolder($component, $context)
            default return error()
    return
        if (empty($errors)) then () else
            <gx:domainErrors>{
                $gxDomain/@id/attribute domainID {.},
                $gxDomain/@label/attribute domainLabel {.},
                attribute count {count($errors/descendant-or-self::gx:error)},
                attribute domainPath {$baseURI},
                $errors
            }</gx:domainErrors>
};

