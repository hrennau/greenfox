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
    "tt/_nameFilter.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "docSimilarConstraint.xqm",
    "expressionValueConstraint.xqm",
    "extensionValidator.xqm",
    "filePropertiesConstraint.xqm",
    "focusNodeValidator.xqm",
    "greenfoxTarget.xqm",
    "linkConstraint.xqm",    
    "mediatypeConstraint.xqm",
    "xsdValidator.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFile($gxFile as element(gx:file), $context as map(*)) 
        as element()* {
    let $targetPathsAndTargetValidationResults := f:getTargetPaths($gxFile, $context, $gxFile/gx:targetSize)
    let $targetPaths := $targetPathsAndTargetValidationResults[. instance of xs:anyAtomicType]
    let $targetValidationResults := $targetPathsAndTargetValidationResults[. instance of element()]
(: 
    let $contextPath := $context?_contextPath
    let $targetDecl := $gxFile/(@foxpath, @path, @linkXPath, @recursiveLinkXPath)[1]
    let $targetPathsAndErrorInfos := f:getTargetPaths($gxFile, $context)
    let $targetPaths := $targetPathsAndErrorInfos[. instance of xs:anyAtomicType]
    let $errorInfos := $targetPathsAndErrorInfos[. instance of map(*)]
    
    (: Check targetSize :)
    let $targetCountResults := $gxFile/gx:targetSize 
                               ! i:validateTargetCount(., $targetPaths, $contextPath, $targetDecl)
:)                               
    (: Check instances :)
    let $instanceResults := $targetPaths 
                            ! f:validateFileInstance(., $gxFile, $context)
    
    (: Merge results :)        
    let $results := ($targetValidationResults, $instanceResults)
    return
        $results
};

(:~
 : Validates a file against a file shape.
 :
 : @param filePath the file path
 : @param gxFile the file shape
 : @param context the evaluation context
 : @return validation results
 :)
declare function f:validateFileInstance($filePath as xs:string, 
                                        $gxFile as element(gx:file), 
                                        $context as map(*)) 
        as element()* {
    (: let $_LOG := trace($filePath, 'FILE_PATH: ') :) 

    (: update context - new value of _contextPath :)
    let $context := map:put($context, '_contextPath', $filePath)
    let $context := map:put($context, '_contextName', $filePath ! replace(., '.*\\', ''))
    let $components :=
        let $children := $gxFile/*[not(@deactivated eq 'true')]
        return (
            $children[not(self::gx:ifMediatype)],
            $children/self::gx:ifMediatype[i:matchesMediatype((@eq, @in/tokenize(.)), $filePath)]
                     /*[not(@deactivated eq 'true')]   
        )
    (: Subset of the constraints which are extension constraint definitions :)
    let $extensionConstraints := f:getExtensionConstraints($components)     
    
    (: Extension constraint components needed already now in order to analyze
       if they contain references to xdoc, jdoc, csvdoc :)
    let $extensionConstraintComponents := f:getExtensionConstraintComponents($components)
    
    (: Required bindings are a subset of potential bindings :)
    let $reqBindingsAndDocs := f:getRequiredBindingsAndDocs($filePath, $gxFile, ($components, $extensionConstraintComponents))
    let $reqBindings := $reqBindingsAndDocs?requiredBindings
    (: If expressions reference documents, these are stored in a map :)
    let $reqDocs := 
        map:merge((
            $reqBindingsAndDocs?xdoc ! map:entry('xdoc', .),
            $reqBindingsAndDocs?jdoc ! map:entry('jdoc', .),
            $reqBindingsAndDocs?csvdoc ! map:entry('csvdoc', .),
            $reqBindingsAndDocs?htmldoc ! map:entry('htmldoc', .)
        ))        
    
    (: the document types are mutually exclusive - $doc is the 
       only document obtained (if any) :)
    let $doc := ($reqBindingsAndDocs?xdoc, $reqBindingsAndDocs?jdoc, $reqBindingsAndDocs?csvdoc, $reqBindingsAndDocs?htmldoc)[1]
    let $context := f:prepareEvaluationContext($context, $reqBindings, $filePath, 
        $reqDocs?xdoc, $reqDocs?jdoc, $reqDocs?csvdoc, $reqDocs?htmldoc, ())  
    
    (: perform validations :)
    let $results :=
        (: validate - member resources :)
        let $resourceShapeResults := (
            $components/self::gx:file/i:validateFile(., $context),
            $components/self::gx:folder/i:validateFolder(., $context)
        )
    
        let $valueShapeResults :=
            for $child in $components[not((self::gx:targetSize, self::gx:file, self::gx:folder))] 
            let $error :=
                typeswitch($child)
                case $xpath as element(gx:xpath) return i:validateExpressionValue($xpath, $doc, $filePath, $doc, $context)
                case $foxpath as element(gx:foxpath) return i:validateExpressionValue($foxpath, $filePath, $filePath, $doc, $context)            
                case $links as element(gx:links) return i:validateLinks($links, $doc, $filePath, $doc, $context)                
                case $xsdValid as element(gx:xsdValid) return i:xsdValidate($filePath, $xsdValid, $context)
                case $focusNode as element(gx:focusNode) return i:validateFocusNode($focusNode, $doc, $filePath, $doc, $context)            
                case $lastModified as element(gx:lastModified) return i:validateLastModified($filePath, $lastModified, $context)
                case $fileSize as element(gx:fileSize) return i:validateFileSize($filePath, $fileSize, $context)
                case $fileName as element(gx:fileName) return i:validateFileName($filePath, $fileName, $context)
                case $mediatype as element(gx:mediatype) return i:validateMediatype($filePath, $mediatype, $context)     
                case $docSimilar as element(gx:docSimilar) return i:validateDocSimilar($filePath, $docSimilar, $doc, $doc, $context)
                case $targetSize as element(gx:targetSize) return ()
                default return 
                    if ($child intersect $extensionConstraints) then 
                        f:validateExtensionConstraint($child, ($doc, $filePath)[1], $filePath, $doc, $context)
                    else            
                        error(QName((), 'UNEXPECTED_SHAPE_OR_CONSTRAINT_ELEMENT'), 
                              concat('Unexpected shape or constraint element, name: ', $child/name()))
            return
                if ($error) then $error/i:augmentErrorElement(., attribute filePath {$filePath}, 'first')
                else if ($child/self::gx:focusNode) then ()
                else
                    <gx:green>{
                        attribute filePath {$filePath},
                        attribute constraintComp {$child/local-name(.)},
                        $child/@id/attribute constraintID {.},
                        $child/@label/attribute constraintLabel {.}
                    }</gx:green>
        return
            ($resourceShapeResults, $valueShapeResults)
    return
        $results
};

(:~
 : Provide the names of required variable bindings and required documents.
 : Required documents depend on the mediatype of this file, as well as on 
 : required bindings: 
 : * assign $xdoc if mediatype 'xml' or 'xml-or-json' or required binding 'doc'
 : * assign $jdoc if mediatype 'json' or 'xml-or-json' or required binding 'jdoc'
 : * assign $csvdoc if mediatype 'csv' or 'required binding 'csvdoc'
 :
 : @param filePath file path of this file
 : @param gxFile file shape
 : @param components constraint components in scope, implying requirements
 : @param mediatype the mediatype of the file resource
 : @return a map with key 'requiredBindings' containing a list of required variable
 :   names, key 'xdoc' an XML doc, 'jdoc' an XML representation of the JSON
 :   document, key 'csvdoc' an XML representation of the CSV document
 :)
declare function f:getRequiredBindingsAndDocs($filePath as xs:string,
                                              $gxFile as element(gx:file),
                                              $components as element()*) 
        as map(*) {
    let $mediatype := $gxFile/@mediatype        
    
    (: the required bindings are a subset of potential bindings :)
    let $requiredBindings :=
        let $potentialBindings := ('this', 'doc', 'jdoc', 'csvdoc', 'domain', 'filePath', 'fileName')
        return f:getRequiredBindings($potentialBindings, $components)
        
    let $xdoc :=
        let $required := 
            $mediatype = ('xml', 'xml-or-json')
            or
            not($mediatype) and $components/(
                self::gx:xpath, self::gx:links, self::gx:docSimilar, 
                @validatorXPath, gx:validatorXPath, 
                descendant-or-self::gx:focusNode//(@xpath, gx:xpath, gx:links))    
            or
            $components/self::gx:foxpath/@*[ends-with(name(.), 'XPath')]
            or
            not($mediatype = ('json', 'csv')) and $requiredBindings = 'doc'
        return
            if (not($required)) then () 
            else if (not(i:fox-doc-available($filePath))) then ()
            else i:fox-doc($filePath)
    let $jdoc :=
        if ($xdoc) then () else
        
        let $required :=
            $mediatype = ('json', 'xml-or-json')
            or 
            not($mediatype) and $components/self::gx:xpath
            or
            $components/self::gx:foxpath/@*[ends-with(name(.), 'Foxpath')]
            or
            not($mediatype = ('xml', 'csv')) and $requiredBindings = 'json'
        return
            if (not($required)) then ()
            else
                let $text := i:fox-unparsed-text($filePath, ())
                return try {json:parse($text)} catch * {()}
           
    let $htmldoc :=
        if ($xdoc or $jdoc) then () else
        
        let $required :=
            $mediatype = ('html', 'xml-or-html')
            or 
            not($mediatype) and $components/self::gx:xpath
            or
            $components/self::gx:foxpath/@*[ends-with(name(.), 'Foxpath')]
            or
            not($mediatype = ('xml', 'csv', 'json')) and $requiredBindings = 'html'
        return
            if (not($required)) then ()
            else
                let $text := i:fox-unparsed-text($filePath, ())
                return try {html:parse($text)} catch * {()}
           
    let $csvdoc :=
        if ($mediatype eq 'csv' or $requiredBindings = 'csvdoc') then 
            f:csvDoc($filePath, $gxFile)
         else ()
         
    (: the document types are mutually exclusive - $doc is the 
       only document obtained (if any) :)
    return
        map:merge((
            map:entry('requiredBindings', $requiredBindings),
            $xdoc ! map:entry('xdoc', .),
            $jdoc ! map:entry('jdoc', .),
            $csvdoc ! map:entry('csvdoc', .),
            $htmldoc ! map:entry('htmldoc', .)
        ))
};        