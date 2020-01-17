(:
 : -------------------------------------------------------------------------
 :
 : extensionValidator.xqm - validates against an extension constraint component
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_foxpath.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "expressionValueConstraint.xqm",
    "filePropertiesConstraint.xqm",
    "mediatypeConstraint.xqm",
    "xsdValidator.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateAgainstExtension($resource as element(), 
                                            $constraint as element(), 
                                            $contextItem as item(), 
                                            $context as map(*)) 
        as element()* {
}        
