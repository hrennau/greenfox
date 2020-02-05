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
 : Validates a file system tree against a greenfox schema.
 :
 : @param gx a compiled greenfox schema
 : @param context a set of name-value pairs providing an environment for validation
 : @param reportType type of validation report
 : @param format format of validation report
 : @param options options contolling validation and the writing of the validation report
 : @return validation errors, if any
 :)
declare function f:validateSystem($gfox as element(gx:greenfox), 
                                  $context as map(xs:string, item()*),
                                  $reportType as xs:string, 
                                  $reportFormat as xs:string,
                                  $options as map(*))
        as element() {
    let $domains := $gfox/gx:domain
    return if (count($domains) gt 1) then error(QName((), 'NOT_YET_IMPLEMENTED'), 
        concat('Currently a schema must not contain more than one domain; #domains found: ', count($domains)))
    else
    
    for $domain in $gfox/gx:domain    
    let $perceptions := f:validateDomain($domain, $context)
    let $report := i:writeValidationReport($gfox, $domain, $context, $perceptions, $reportType, $reportFormat, $options)
    return
        $report
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
 : @param context a map representing an initial set of name-value pairs available during validation
 : @return validation errors, if any
 :)
declare function f:validateDomain($gxDomain as element(gx:domain), 
                                  $context as map(xs:string, item()*))
        as element()* {
    let $baseURI := $gxDomain/@path/string()
    let $name := $gxDomain/@name/string()
    
    let $evaluationContext :=
        map:merge((
            map:entry(QName((), 'domain'), $baseURI),
            map:entry(QName((), 'domainName'), $name)
        ))
    let $context := 
        map:merge((
            $context,
            map:entry('_contextPath', $baseURI),
            map:entry('_domainName', $name),
            map:entry('_domainPath', $baseURI),
            map:entry('_evaluationContext', $evaluationContext)
        ))            
    let $perceptions :=
        for $component in $gxDomain/(* except gx:context)
        return
            typeswitch($component)
            case element(gx:folder) return f:validateFolder($component, $context)
            case element(gx:file) return f:validateFile($component, $context)
            case element(gx:constraintComponents) return ()
            default return error()
    return
        $perceptions
};

