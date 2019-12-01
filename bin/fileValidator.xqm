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
    "tt/_foxpath.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "expressionValueConstraint.xqm",
    "filePropertiesConstraint.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFile($gxFile as element(gx:file), $context as map(*)) 
        as element()* {
    let $contextPath := $context?_contextPath
    let $navigationPath := $gxFile/(@foxpath, @path)[1]
    let $targetPaths :=
        let $path := $gxFile/@path
        let $foxpath := $gxFile/@foxpath
        return
            if ($path) then concat($contextPath, '\', $gxFile/@path)[file:exists(.)][file:is-file(.)]
            else f:evaluateFoxpath($foxpath, $contextPath)[file:is-file(.)]
            
    (: check: targetSize :)
    let $targetCount := count($targetPaths)   
    let $targetCountErrors := $gxFile/gx:targetSize/i:validateTargetCount(., $targetCount)
        /i:augmentErrorElement(., (
            attribute contextFilePath {$contextPath},
            attribute navigationPath {$navigationPath}
            ), 'first')
    
    let $instanceErrors :=        
        for $targetPath in $targetPaths
        return
            f:validateFileInstance($targetPath, $gxFile, $context)
            
    let $errors := ($targetCountErrors, $instanceErrors)
    return
        <gx:fileSetErrors>{
            $gxFile/@id/attribute fileID {.},
            $gxFile/@label/attribute fileLabel {.},
            attribute count {count($errors)},
            $errors
        }</gx:fileSetErrors>[$errors]
            
};

declare function f:validateFileInstance($filePath as xs:string, $gxFile as element(gx:file), $context as map(*)) 
        as element()* {
    (: let $_LOG := trace($filePath, 'FILE_PATH: ') :) 

    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $filePath)
    let $components := $gxFile/*[not(@deactivated eq 'true')]
    let $mediatype := $gxFile/@mediatype 
    
    let $requiredBindings := trace(
        for $child in $components[self::gx:xpath, self::gx:foxpath]
        return (
            $child/self::gx:xpath/i:determineRequiredBindingsXPath(@expr, ('this', 'doc', 'jdoc', 'csvdoc')),
            $child/self::gx:foxpath/i:determineRequiredBindingsFoxpath(@expr, ('this', 'doc', 'jdoc', 'csvdoc'))
            ) => distinct-values() => sort(), '### REQUIRED BINDINGS: ')
            
    let $jdoc :=
        if ($mediatype eq 'json' or $requiredBindings = 'json') then
        let $text := unparsed-text($filePath)
        return try {json:parse($text)} catch * {()}
    let $xdoc := trace(
        let $required := 
            $requiredBindings = 'doc'
            or
            not($mediatype ne 'xml') and $components/self::gx:xpath
        return
            if (not($required)) then () 
            else if (doc-available($filePath)) then doc($filePath)
            else () , 'XDOC: ')
    let $csvdoc := ()            
    let $doc := ($xdoc, $jdoc, $csvdoc)[1]
    
    let $exprContext := 
        map:merge((
            if (not($requiredBindings = 'doc')) then () else map:entry(QName('', 'doc'), $doc),
            if (not($requiredBindings = 'jdoc')) then () else map:entry(QName('', 'jdoc'), $jdoc),
            if (not($requiredBindings = 'csvdoc')) then () else map:entry(QName('', 'csvdoc'), $jdoc),
            if (not($requiredBindings = 'this')) then () else map:entry(QName('', 'this'), $filePath)
        ))
    
    
    (: perform validations :)
    let $errors := (
        for $child in $gxFile/*[not(@deactivated eq 'true')]
        let $raw :=
            typeswitch($child)
            case $xpath as element(gx:xpath) return i:validateExpressionValue($xpath, $doc, $context)
            case $foxpath as element(gx:foxpath) return i:validateExpressionValue($foxpath, $filePath, $exprContext)            
            case $lastModified as element(gx:lastModified) return i:validateLastModified($filePath, $lastModified, $context)
            case $fileSize as element(gx:fileSize) return i:validateFileSize($filePath, $fileSize, $context)
            case $fileName as element(gx:fileName) return i:validateFileName($filePath, $fileName, $context)
            case element(gx:targetSize) return ()
            default return error()
        return
            $raw/i:augmentErrorElement(., attribute filePath {$filePath}, 'first')
    )
    return
        <gx:fileErrors>{
            $gxFile/@id/attribute fileID {.},
            $gxFile/@label/attribute fileLabel {.},
            attribute count {count($errors)},
            attribute filePath {$filePath},
            $errors
        }</gx:fileErrors>
        [$errors]
};
