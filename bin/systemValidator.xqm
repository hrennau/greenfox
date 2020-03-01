(:
 : -------------------------------------------------------------------------
 :
 : systemValidator.xqm - functions validating a file system tree against a greenfox schema
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
    "folderValidator.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a file system tree against a greenfox schema.
 :
 : @param gfox a compiled greenfox schema
 : @param context a set of name-value pairs providing an environment for validation
 : @param reportType type of validation report
 : @param format format of validation report
 : @param options options contolling validation and the writing of the validation report
 : @return validation report
 :)
declare function f:validateSystem($gfox as element(gx:greenfox), 
                                  $context as map(xs:string, item()*),
                                  $reportType as xs:string, 
                                  $reportFormat as xs:string,
                                  $options as map(*))
        as element() {
    let $domains := $gfox/gx:domain
    
    (: Initial check - only one domain allowed :)
    return if (count($domains) gt 1) then error(QName((), 'NOT_YET_IMPLEMENTED'), 
        concat('Currently a schema must not contain more than one domain; ',
               '#domains found: ', count($domains)))
    else
    
    for $domain in $domains
    
    (: Collect validation results :)
    let $results := f:validateDomain($domain, $context)
    
    (: Construct validation report :)
    let $report := i:writeValidationReport($gfox, $domain, $context, $results, 
                                           $reportType, $reportFormat, $options)
    return
        $report
};

(:~
 : Validates a domain. Initializes the evaluation context (providing expression 
 : variables) and reinitializes the processing context (accessible to processing 
 : code). 
 :
 : Evaluation context: domain, domainName.
 : Processing context: _domain, _domainName, _contextPath, _evaluationContext. 
 :
 : @param gxDomain domain element
 : @param context a map representing an initial set of name-value pairs available during validation
 : @return validation results
 :)
declare function f:validateDomain($gxDomain as element(gx:domain), 
                                  $context as map(xs:string, item()*))
        as element()* {
    let $baseURI := $gxDomain/@path ! (
                    if (starts-with(., 'basex://')) then . 
                    else file:path-to-native(.))
    let $name := $gxDomain/@name/string()
    
    (: Evaluation context, containing entries available as 
       external variables to XPath and foxpath expressions;
       initial entries: domain, domainName:)
    let $evaluationContext :=
        map:merge((
            map:entry(QName((), 'domain'), $baseURI),
            map:entry(QName((), 'domainName'), $name)
        ))
        
    (: Processing context, containing entries available to
       the processing code; initial entries:
       _domain, _domainName, _contextPath,  _evaluationContext :)
    let $context := 
        map:merge((
            $context,
            map:entry('_domain', $baseURI),
            map:entry('_domainName', $name),
            map:entry('_contextPath', $baseURI),            
            map:entry('_evaluationContext', $evaluationContext)
        ))   
        
    let $results :=
        for $component in $gxDomain/*
        return
            typeswitch($component)
            case element(gx:folder) return f:validateFolder($component, $context)
            case element(gx:file) return f:validateFile($component, $context)
            case element(gx:context) return ()
            case element(gx:constraintComponents) return ()
            default return error(QName($i:URI_GX, 'UNEXPEDTED_SCHEMA_CONTENTS'), 
                concat('Unexpected folder contents; component name: ', $component/name(.),
                '; the error SHOULD have been detected by schema validation ',
                'against the greenfox metaschema; ',
                'the creation of a github issue would be much appreciated.'))
    return
        $results
};

