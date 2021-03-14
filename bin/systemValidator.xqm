(:
 : -------------------------------------------------------------------------
 :
 : systemValidator.xqm - functions validating a file system tree against a greenfox schema
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "fileShape.xqm",
   "folderShape.xqm",
   "uriUtil.xqm";
    
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
        as item() {
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
    let $report := i:writeValidationReport(
        $gfox, $domain, $results, $reportType, $reportFormat, $options, $context)
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
 : @param domainElem domain element
 : @param externalContext a map representing an initial set of name-value pairs available during validation
 : @return validation results
 :)
declare function f:validateDomain($domainElem as element(gx:domain), 
                                  $context as map(xs:string, item()*))
        as element()* {
    let $context := f:updateProcessingContext_domain($domainElem, $context)
    let $results :=
        for $component in $domainElem/*
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

