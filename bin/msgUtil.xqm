(:
 : -------------------------------------------------------------------------
 :
 : msgUtil.xqm - utility functions for constructing messages
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/msg";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Constructs a default message for a validation result.
 :
 : A validation result is obtained when validating a single resource
 : against a single constraint. The result is red (error), yellow 
 : (warning) or green (pass).
 :
 : @param result a validation result
 : @return message text
 :)
declare function f:defaultMsg($result as element())
        as xs:string {
    switch($result/@constraintComp)
    
    case "TargetCount" return f:defaultMsg_targetCount($result)
    case "TargetMinCount" return f:defaultMsg_targetCount($result)
    case "TargetMaxCount" return f:defaultMsg_targetCount($result)
    
    case "LinkTargetDocsCount" return f:defaultMsg_linkTargetDocsCount($result)
    case "LinkTargetDocsMinCount" return f:defaultMsg_linkTargetDocsCount($result)
    case "LinkTargetDocsMaxCount" return f:defaultMsg_linkTargetDocsCount($result)
    
    case "TargetSizeLinkResolution" return f:defaultMsg_targetSizeLinkResolution($result)
    default return 
        "(under construction: default msg for "||$result/@constraintComp||" result)"
};

(:~
 : Constructs a default message for a TargetSize constraint.
 :
 : @param result a validation result
 : @return message text
 :)
declare function f:defaultMsg_targetCount($result as element())
        as xs:string {
    let $valueCount := $result/@valueCount/xs:integer(.)
    let $count := $result/@count/xs:integer(.)
    let $minCount := $result/@minCount/xs:integer(.)
    let $maxCount := $result/@maxCount
    let $targetContextPath := $result/@targetContextPath
    let $target := f:linkDescription($result, $targetContextPath)
    return
    
    typeswitch($result)
    case element(gx:red) return
        let $countText :=
            if ($count) then 
                if ($valueCount eq 0) then "No resource found: ["||$target||"]"
                else $valueCount||" resources found, but expected "||$count||" : "||$target
            else if ($minCount) then                            
                if ($valueCount eq 0) then "No resource found: ["||$target||"]"
                else $valueCount||" resources found, but expected at least "||$minCount||" : "||$target
            else if ($maxCount) then                            
                $valueCount||" resources found, but expected at most "||$maxCount||" : "||$target
            else 
                "(under construction: default msg for TargetSize constraint, constraint not a count* constraint)"
        return
            $countText
    case element(gx:green) return 
        "(under construction: default msg for TargetSize constraint, green result)"
    default return
        "(under construction: default msg for TargetSize constraint, "||local-name($result)||" result)"
};

(:~
 : Constructs a default message for a LinkTargetDocsCount constraint.
 :
 : @param result a validation result
 : @return message text
 :)
declare function f:defaultMsg_linkTargetDocsCount($result as element())
        as xs:string {
    let $valueCount := $result/@valueCount/xs:integer(.)
    let $count := $result/@countTargetDocs/xs:integer(.)
    let $minCount := $result/@minCountTargetDocs/xs:integer(.)
    let $maxCount := $result/@maxCountTargetDocs
    let $targetContextPath := $result/@targetContextPath
    let $target := f:linkDescription($result, $result/../(@file, @folder))
    return
    
    typeswitch($result)
    case element(gx:red) return
        let $countText :=
            if ($count) then 
                if ($valueCount eq 0) then "No link target document: ["||$target||"]"
                else $valueCount||" link target documents found, but expected "||$count||" : "||$target
            else if ($minCount) then                            
                if ($valueCount eq 0) then "No link target document: '"||$target||"'"
                else $valueCount||" link target documents found, but expected at least "||$minCount||" : "||$target
            else if ($maxCount) then                            
                $valueCount||" link target documents found, but expected at most "||$maxCount||" : "||$target
            else 
                "(under construction: default msg for LinkTargetDocsCount constraint, constraint not a linkTargetDocCount* constraint)"
        return
            $countText
    case element(gx:green) return 
        "(under construction: default msg for LinkTargetDocsCount constraint, green result)"
    default return
        "(under construction: default msg for LinkTargetDocsCount constraint, "||local-name($result)||" result)"
};

(:~
 : Constructs a default message for a TargetSizeLinkResolution constraint.
 :
 : @param result a validation result
 : @return message text
 :)
declare function f:defaultMsg_targetSizeLinkResolution($result as element())
        as xs:string {
    let $target := f:linkDescription($result, $result/../(@file, @folder))
    return
        
    typeswitch($result)
    case element(gx:red) return
        "Link could not be resolved: ["||$target||"]"
    case element(gx:green) return 
        "(under construction: default msg for LinkTargetDocsCount constraint, green result)"
    default return
        "(under construction: default msg for LinkTargetDocsCount constraint, "||local-name($result)||" result)"
};

(:~
 : Returns a string summarizing a link or navigation, as for
 : example used by a shape.
 :
 : @param element an element either defining or referencing a link
 : @return a string summarizing the link
 :)
declare function f:linkDescription($elem as element(), $contextURI as xs:string)
        as xs:string {
(:        
    <xs:attributeGroup name="LinkDefAttGroup">
        <xs:attribute name="foxpath" type="xs:string"/>
        <xs:attribute name="navigateFOX" type="xs:string"/>
        <xs:attribute name="uri" type="xs:string"/>        
        <xs:attribute name="contextXP" type="xs:string"/>
        <xs:attribute name="targetXP" type="xs:string"/>        
        <xs:attribute name="hrefXP" type="xs:string"/>
        <xs:attribute name="uriXP" type="xs:string"/>
        <xs:attribute name="uriTemplate" type="xs:string"/>
        <xs:attribute name="reflector1URI" type="xs:string"/>
        <xs:attribute name="reflector2URI" type="xs:string"/>
        <xs:attribute name="reflector1FOX" type="xs:string"/>
        <xs:attribute name="reflector2FOX" type="xs:string"/>
        <xs:attribute name="reflectedReplaceSubstring" type="xs:string"/>
        <xs:attribute name="reflectedReplaceWith" type="xs:string"/>
        <xs:attribute name="recursive" type="xs:boolean"/>        
        <xs:attribute name="mediatype" type="xs:string"/>        
        <xs:attributeGroup ref="t:CsvOptionsAttGroup"/>
    </xs:attributeGroup>
:)    
    let $linkName := $elem/@linkName
    let $uri := $elem/@uri
    let $navigateFOX := $elem/@navigateFOX
    let $hrefXP := $elem/@hrefXP
    let $uriXP := $elem/@uriXP
    let $uriTemplate := $elem/@uriTemplate
    let $reflector1URI := $elem/@reflector1URI/concat('reflector1 URI=', .)
    let $reflector2URI := $elem/@reflector2URI/concat('reflector2 URI=', .)    
    let $reflector1FOX := $elem/@reflector1FOX/concat('reflector1-Foxpath=', .)
    let $reflector2FOX := $elem/@reflector2FOX/concat('reflector2-Foxpath=', .)
    return
        if ($linkName) then concat('link-name=', $linkName)
        else if ($uri) then concat('URI=', $contextURI, '/', $uri)
        else if ($navigateFOX) then concat('Foxpath=', $navigateFOX ! normalize-space(.))
        else if ($hrefXP) then concat('href-XPath=', $hrefXP ! normalize-space(.))
        else if ($uriXP) then concat('URI-XPath=', $uriXP ! normalize-space(.))
        else if ($uriTemplate) then concat('URI-template=', $uriTemplate ! normalize-space(.))
        else if (exists(($reflector1URI, $reflector1FOX))) then
            ($reflector1URI, $reflector2URI, $reflector1FOX, $reflector2FOX) => string-join(', ')
        else
            '(under construction: link summary)'
        
};        
