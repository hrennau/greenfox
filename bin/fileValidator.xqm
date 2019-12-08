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
    "filePropertiesConstraint.xqm",
    "xsdValidator.xqm";
    
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
    let $targetCountPerceptions := 
        let $constraint := $gxFile/gx:targetSize
        return
            if (not($constraint)) then () else
            let $error :=
                $gxFile/gx:targetSize/i:validateTargetCount(., $targetCount)
                    /i:augmentErrorElement(., (
                        attribute contextPath {$contextPath},
                        attribute navigationPath {$navigationPath}
                        ), 'first')
            return
                if ($error) then $error
                else
                    <gx:green>{
                        attribute constraintComponent {$constraint/local-name()},                    
                        attribute contextPath {$contextPath},
                        attribute navigationPath {$navigationPath},
                        $constraint/@id/attribute constraintID {.},
                        $constraint/@label/attribute constraintLabel {.}
                    }</gx:green>
                
    let $instancePerceptions :=        
        for $targetPath in $targetPaths
        return
            f:validateFileInstance($targetPath, $gxFile, $context)
            
    let $perceptions := ($targetCountPerceptions, $instancePerceptions)
    return
        $perceptions
};

declare function f:validateFileInstance($filePath as xs:string, $gxFile as element(gx:file), $context as map(*)) 
        as element()* {
    (: let $_LOG := trace($filePath, 'FILE_PATH: ') :) 

    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $filePath)
    let $components := $gxFile/*[not(@deactivated eq 'true')]
    let $mediatype := $gxFile/@mediatype 
    
    (: the required bindings are a subset of potential bindings :)
    let $requiredBindings :=
        let $potentialBindings := ('this', 'doc', 'jdoc', 'csvdoc', 'domain', 'filePath', 'fileName')
        for $child in $components[self::gx:xpath, self::gx:foxpath, self::gx:xsdValid]
        return (
            $child/self::gx:xpath/i:determineRequiredBindingsXPath(@expr, $potentialBindings),            
            $child/self::gx:foxpath/i:determineRequiredBindingsFoxpath(@expr, $potentialBindings),
            $child/self::gx:xsdValid/i:determineRequiredBindingsFoxpath(@xsdFoxpath, $potentialBindings),
            $child/self::gx:xpath/@inFoxpath/i:determineRequiredBindingsFoxpath(., $potentialBindings)
            ) => distinct-values() => sort()

    (: provide required documents :)            
    let $jdoc :=
        if ($mediatype eq 'json' or $requiredBindings = 'json') then
        let $text := unparsed-text($filePath)
        return try {json:parse($text)} catch * {()}
    let $xdoc :=
        let $required := 
            $requiredBindings = 'doc' or
                not($mediatype ne 'xml') and $components/self::gx:xpath
        return
            if (not($required)) then () 
            else if (doc-available($filePath)) then doc($filePath)
            else ()
    let $csvdoc :=
        if ($mediatype eq 'csv' or $requiredBindings = 'csvdoc') then
            let $separator := ($gxFile/@csv.separator, 'comma')[1]
            let $withHeader := ($gxFile/@csv.withHeader, 'no')[1]
            let $names := ($gxFile/@csv.names, 'direct')[1]
            let $withQuotes := ($gxFile/@csv.withQuotes, 'yes')[1]
            let $backslashes := ($gxFile/@csv.backslashes, 'no')[1]
            let $options := map{
                'separator': $separator,
                'header': $withHeader,
                'format': $names,
                'quotes': $withQuotes,
                'backslashes': $backslashes
            }
            let $text := unparsed-text($filePath)
            return try {csv:parse($text, $options)} catch * {()}
         else ()
    let $doc := ($xdoc, $jdoc, $csvdoc)[1]
    
    let $exprContext :=
        map:merge((
            if (not($requiredBindings = 'doc')) then () else map:entry(QName('', 'doc'), $doc),
            if (not($requiredBindings = 'jdoc')) then () else map:entry(QName('', 'jdoc'), $jdoc),
            if (not($requiredBindings = 'csvdoc')) then () else map:entry(QName('', 'csvdoc'), $jdoc),
            if (not($requiredBindings = 'this')) then () else map:entry(QName('', 'this'), $filePath),
            if (not($requiredBindings = 'domain')) then () else map:entry(QName('', 'domain'), $context?_domainPath),
            if (not($requiredBindings = 'filePath')) then () else map:entry(QName('', 'filePath'), $filePath),
            if (not($requiredBindings = 'fileName')) then () else map:entry(QName('', 'fileName'), replace($filePath, '.*[\\/]', ''))
        ))
    
    
    (: perform validations :)
    let $perceptions := (
        for $child in $components[not(self::gx:targetSize)]
        let $error :=
            typeswitch($child)
            case $xpath as element(gx:xpath) return i:validateExpressionValue($xpath, $doc, $exprContext)
            case $foxpath as element(gx:foxpath) return i:validateExpressionValue($foxpath, $filePath, $exprContext)            
            case $xsdValid as element(gx:xsdValid) return i:xsdValidate($filePath, $xsdValid, $exprContext)
            case $lastModified as element(gx:lastModified) return i:validateLastModified($filePath, $lastModified, $context)
            case $fileSize as element(gx:fileSize) return i:validateFileSize($filePath, $fileSize, $context)
            case $fileName as element(gx:fileName) return i:validateFileName($filePath, $fileName, $context)
            case element(gx:targetSize) return ()
            default return error()
        return
            if ($error) then $error/i:augmentErrorElement(., attribute filePath {$filePath}, 'first')
            else
                <gx:green>{
                    attribute filePath {$filePath},
                    attribute constraintComponent {$child/local-name(.)},
                    $child/@id/attribute constraintID {.},
                    $child/@label/attribute constraintLabel {.}
                }</gx:green>
    )
    return
        $perceptions
};
