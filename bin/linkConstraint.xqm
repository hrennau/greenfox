(:
 : -------------------------------------------------------------------------
 :
 : linkConstraint.xqm - validates against a link constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n s    v a l i d a t i n g    l i n k s
 :
 : ============================================================================ :)

(:~
 : Validates constraints referring to links.
 :
 : @param shape the value shape declaring the constraints
 : @param contextItem the initial context item to be used in expressions
 : @param contextFilePath the file path of the file containing the initial context item
 : @param contextDoc the XML document containing the initial context item
 : @param context a set of name-value pairs accessible to processing code
 : @return a set of validation results
 :)
declare function f:validateLinks($shape as element(), 
                                 $contextItem as item()?,
                                 $contextFilePath as xs:string,
                                 $contextDoc as document-node()?,
                                 $context as map(xs:string, item()*))
        as element()* {
    (: let $_DEBUG := trace(count($contextItem), '_#CONTEXT_ITEM: ') :)
    
    (: The focus path identifies the location of the initial context item
       (empty sequence if the initial context item is the root of the 
       context document :)
    let $focusPath :=
        if ($contextItem instance of node() and not($contextItem is $contextDoc)) then
            $contextItem/f:datapath(.)
        else ()        
        
    (: The "context info" gives access to the context file path and the focus path :)        
    let $contextInfo := map:merge((
        $contextFilePath ! map:entry('filePath', .),
        $focusPath ! map:entry('nodePath', .)
    ))

    return
        (: Handle the case that no context item was supplied; this happens if and only
           if the target resource could not be parsed into an XDM tree :)        
        if (empty($contextItem)) then   (: this document could not be parsed :)
            f:validationResult_links('red', $shape, (), 
                                     attribute reason {'Context document could not be parsed'}, 
                                     (), $contextInfo, ())
        else
        
    let $recursive := $shape/@recursive
    let $results := f:validateLinksResolvable($contextItem, $contextFilePath, $shape, $context, $contextInfo)
    return
        $results
};

(:~
 : Validates a LinkResolvable constraint with parameter 'recursive' equal to true.
 :
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param valueShape the value shape containing the constraint
 : @param context the processing context
 : @param contextInfo information about the resource context 
 : @return validation results, red and/or green
 :)
declare function f:validateLinksResolvable(
                             $contextNode as node(),
                             $filepath as xs:string,
                             $valueShape as element(),
                             $context as map(xs:string, item()*),
                             $contextInfo as map(xs:string, item()*))
        as item()* {
    let $resultAdditionalAtts := attribute recursive {true()}
    let $resultOptions := ()
    
    let $expr := $valueShape/@xpath
    let $mediatype := $valueShape/@mediatype
    let $recursive := $valueShape/@recursive/xs:boolean(.)
    let $docsAndErrors := f:resolveLinks($expr, $contextNode, $filepath, $mediatype, $recursive, $context)
    
    let $docs := $docsAndErrors?doc
    let $errors := $docsAndErrors[?error eq 'true']
    (:
    let $colour := if (exists($errors)) then 'red' else 'green'
    let $values :=  if (empty($errors)) then () 
                    else if ($recursive) then 
                        $errors ! <gx:value where="{?filepath}">{?linkValue}</gx:value>
                    else 
                        $errors ! <gx:value>{?linkValue}</gx:value>
    return (
        f:validationResult_links(
                            $colour, $valueShape, (), 
                            $resultAdditionalAtts, $values, 
                            $contextInfo, $resultOptions),
        let $uris := $docsAndErrors ! (?uri, ?linkValue)[1]                            
        return 
            f:validateLinkCount($uris, $valueShape, $contextInfo)
    )
    :)
    return (
        f:validationResult_links_for_linkErrors($errors, $recursive, $valueShape, $contextInfo)
        ,
        let $uris := $docsAndErrors ! (?uri, ?linkValue)[1]                            
        return 
            f:validateLinkCount($uris, $valueShape, $contextInfo)    
    )
};

(:~
 : Validates a link count related constraint (LinkCountMinCount, LinkCountMaxCount, LinkCountCount).
 : It is not checked if the links can be resolved - only their number is considered.
 :
 : @param exprValue expression value producing the links
 : @param cmp link count related constraint
 : @param valueShape the value shape containing the constraint
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateLinkCount($exprValue as item()*,
                                     $valueShape as element(),
                                     $contextInfo as map(xs:string, item()*))
        as element()? {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $valueCount := count($exprValue)
    for $cmp in $valueShape/(@count, @minCount, @maxCount)
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown count comparison operator: ', $cmp))
    return        
        if ($cmpTrue($valueCount, $cmp)) then  
            f:validationResult_linkCount('green', $valueShape, $cmp, $valueCount, 
                                         $resultAdditionalAtts, (), $contextInfo, $resultOptions)
        else 
            let $values := $exprValue ! xs:string(.) ! <xs:value>{.}</xs:value>
            return
                f:validationResult_linkCount('red', $valueShape, $cmp, $exprValue, 
                                             $resultAdditionalAtts, $values, $contextInfo, $resultOptions)
};

(: ============================================================================
 :
 :     f u n c t i o n s    c r e a t i n g    v a l i d a t i o n    r e s u l t s
 :
 : ============================================================================ :)

declare function f:validationResult_links_for_linkErrors($errors as map(*)*,
                                                         $recursive as xs:boolean,
                                                         $valueShape as element(),
                                                         $contextInfo) 
        as element() {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $colour := if (exists($errors)) then 'red' else 'green'
    let $values :=  
        if (empty($errors)) then () 
        else if ($recursive) then 
            $errors ! <gx:value where="{?filepath}">{?linkValue}</gx:value>
        else 
            $errors ! <gx:value>{?linkValue}</gx:value>
    return
        f:validationResult_links(
                            $colour, $valueShape, (), 
                            $resultAdditionalAtts, $values, 
                            $contextInfo, $resultOptions)
};

(:~
 : Creates a validation result for a LinkResolvable constraint.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param exprValue expression value producing the links
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_links($colour as xs:string,
                                          $valueShape as element(),
                                          $exprValue as item()*,
                                          $additionalAtts as attribute()*,
                                          $additionalElems as element()*,
                                          $contextInfo as map(xs:string, item()*),
                                          $options as map(*)?)
        as element() {
    let $exprAtt := $valueShape/@xpath        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^link', '') ! lower-case(.)    
    let $constraintConfig := 
        map{'constraintComp': 'LinkResovableConstraint', 'atts': ('mediatype')}
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valueShape/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-linkResolvable')
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, 'link', ())
        else i:getErrorMsg($valueShape, 'link', ())
    let $elemName := 
        switch($colour)
        case 'red' return 'gx:red'
        default return concat('gx:', $colour)
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute valueShapeID {$valueShapeId},  
            $filePath,
            $focusNode,
            $standardAtts,
            $useAdditionalAtts,
            $valueCountAtt,            
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            $additionalElems
        }       
};

(:~
 : Creates a validation result for a LinkCount related constraint (LinkMinCount,
 : LinkMaxCount, LinkCount.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param valueShape the shape declaring the constraint
 : @param exprValue expression value producing the links
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_linkCount($colour as xs:string,
                                              $valueShape as element(),
                                              $constraint as node()*,
                                              $exprValue as item()*,
                                              $additionalAtts as attribute()*,
                                              $additionalElems as element()*,
                                              $contextInfo as map(xs:string, item()*),
                                              $options as map(*)?)
        as element() {
    let $exprAtt := $valueShape/@xpath        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^link', '') ! lower-case(.)    
    let $constraint1 := $constraint[1]
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(count) return map{'constraintComp': 'LinkCount', 'atts': ('count')}
        case attribute(minCount) return map{'constraintComp': 'LinkMinCount', 'atts': ('minCount')}
        case attribute(maxCount) return map{'constraintComp': 'LinkMaxCount', 'atts': ('maxCount')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := $valueShape/@*[local-name(.) = $standardAttNames]
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $valueShapeId := $valueShape/@valueShapeID
    let $constraintId := concat($valueShapeId, '-', $constraint1/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}
    let $focusNode := $contextInfo?nodePath ! attribute nodePathe {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($valueShape, $constraint/local-name(.), ())
        else i:getErrorMsg($valueShape, $constraint/local-name(.), ())
    let $elemName := 'gx:' || $colour
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute valueShapeID {$valueShapeId},  
            $filePath,
            $focusNode,
            $standardAtts,
            $useAdditionalAtts,
            $valueCountAtt,            
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            $additionalElems
        }       
};

(: ============================================================================
 :
 :     f u n c t i o n s    r e s o l v i n g    l i n k s
 :
 : ============================================================================ :)

(:~
 : Resolves links specified by an expression producing the file paths (relative or
 : absolute) of link targets. Returns for each link a map providing URI and document 
 : node (if resolvable), or URI, original link value, file path of the document 
 : containing the link and error flag (otherwise). If $recursive is true, links are 
 : resolved recursively.
 :
 : @param expr expression producing the file paths of link targets (relative or absolute)
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param mediatype the mediatype of link targets
 : @param recursive flag indicating if links are resolved recursively
 : @param context the processing context
 : @return maps describing links, either containing the resolved target or information about 
 :   failure to resolve the link
 :)
declare function f:resolveLinks(
                             $expr as xs:string,
                             $contextNode as node(),
                             $filepath as xs:string,
                             $mediatype as xs:string?,
                             $recursive as xs:boolean,
                             $context as map(xs:string, item()*))
        as map(xs:string, item()*)* {
    let $linkMaps := f:resolveLinksRC($expr, $contextNode, $filepath, $mediatype, $recursive, $context, (), ())
    return
        $linkMaps
};

(:~
 : Recursive helper function of `resolveLinks`.
 :
 : @param expr expression producing the file paths of linke targets (relative or absolute)
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param mediatype the mediatype of link targets
 : @param recursive flag indicating if links are resolved recursively
 : @param context the processing context
 : @param pathsSofar file paths of link targets already visited and successfully resolved
 : @param errorsSofar file paths of link targets already visited and found unresolvable 
 : @return maps describing links, either containing the resolved target or information about 
 :   failure to resolve the link
 :)
declare function f:resolveLinksRC($expr as xs:string,
                                  $contextNode as node(),
                                  $filepath as xs:string,                                  
                                  $mediatype as xs:string?,
                                  $recursive as xs:boolean,
                                  $context as map(xs:string, item()*),
                                  $pathsSofar as xs:string*,
                                  $errorsSofar as xs:string*)
        as map(xs:string, item()*)* {
           
    let $exprValue := trace(f:resolveLinkExpression($expr, $contextNode, $context) , '_EXPR_VALUE: ')
    let $targetsAndErrors :=   
        for $linkValue in $exprValue
        let $baseUri := (
            $linkValue[. instance of node()]/ancestor-or-self::*[1]/base-uri(.),
            $filepath
        )[1]
        let $uri := trace(resolve-uri($linkValue, $baseUri) , '_URI: ')
        where not($uri = ($pathsSofar, $errorsSofar))
        return
            (: If the link value cannot be resolved to a URI, an error is detected :)
            if (not($uri)) then
                map{'uri': '', 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}            
        
            else if ($mediatype = 'json') then            
                if (not(unparsed-text-available($uri))) then 
                    map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                else
                    let $text := unparsed-text($uri)
                    let $jdoc := try {json:parse($text)} catch * {()}
                    return 
                        if (not($jdoc)) then 
                            map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                        else 
                            map{'uri': $uri, 'doc': $jdoc}
                        
            else if ($mediatype = 'xml') then 
                if (not(doc-available($uri))) then 
                    map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                else 
                    map{'uri': $uri, 'doc': doc($uri)}
            else
                if (i:resourceExists($uri)) then
                    map{'uri': $uri, 'linkValue': string($linkValue)}
                else
                    map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
    
    let $errorInfos := $targetsAndErrors[?error eq 'true'][?uri eq '' or not(?uri = $errorsSofar)]
    let $targetInfos := $targetsAndErrors[not(?error eq 'true')][not(?uri = $pathsSofar)]
    
    let $newErrors := $errorInfos?uri    
    let $newPaths := $targetInfos?uri
    let $nextDocs := $targetInfos?doc
    
    let $newPathsSofar := ($pathsSofar, $newPaths)
    let $newErrorsSofar := ($errorsSofar, $newErrors)
    return (
        $errorInfos,   (: these are errors not yet observed :)
        $targetInfos,   (: these are targets not yet observed :)
        if (not($recursive)) then () else
            $targetInfos 
            ! f:resolveLinksRC($expr, ?doc, ?uri, $mediatype, $recursive, $context, $newPathsSofar, $newErrorsSofar)
    )
};

(:~
 : Resolves the link expression in the context of an XDM node to a value.
 :
 : The expression is retrieved from the shape element, and the evaluation context
 : is retrieved from the processing context.
 :
 : @param doc document in the context of which the expression must be resolved
 : @param valueShape the value shape specifying the link constraints
 : @param context context for evaluations
 : @return the expression value
 :)
declare function f:resolveLinkExpression($expr as xs:string,
                                         $contextNode as node(),
                                         $context as map(xs:string, item()*))
        as item()* {
    let $exprLang := 'xpath'
    let $evaluationContext := $context?_evaluationContext    
    let $exprValue :=
        switch($exprLang)
        case 'xpath' return i:evaluateXPath($expr, $contextNode, $evaluationContext, true(), true())
        default return error(QName((), 'SCHEMA_ERROR'), "'Missing attribute - <links> element must have an 'xpath' attribute")
    return $exprValue        
};        

(:
(:~
 : Validates a LinkResolvable constraint with parameter 'recursive' equal to false.
 :
 : @param contextNode the context node
 : @param valueShape the value shape containing the constraint
 : @param context general context information
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateLinksResolvable($contextNode as node(),
                                           $valueShape as element(),
                                           $context as map(xs:string, item()*),
                                           $contextInfo as map(xs:string, item()*))
        as element()* {
           
    let $resultAdditionalAtts := attribute recursive {false()}        
    let $resultOptions := ()
    
    let $exprValue := f:resolveLinkExpression($contextNode, $valueShape, $context)    
    let $filepath := $contextInfo?filepath        
    let $mediatype := $valueShape/@mediatype
    let $errors :=    
        for $linkValue in $exprValue
        let $baseUri := (
            $linkValue[. instance of node()]/ancestor-or-self::*[1]/base-uri(.),
            $filepath
        )[1]
        let $uri := try {resolve-uri($linkValue, $baseUri)} catch * {()}
        return
            (: If the link value cannot be resolved to a URI, an error is detected :)
            if (not($uri)) then $linkValue
            
            (: If mediatype is xml, the uri must point to well-formed XML :)
            else if ($mediatype eq 'xml') then $linkValue[not(doc-available($uri))]            
              
            else if ($mediatype = ('json', 'text')) then            
                let $text := if (not(unparsed-text-available($uri))) then ()
                             else unparsed-text($uri)
                return
                    (: If mediatype is json or text, the uri must point to text :)
                    if (not($text)) then $linkValue
                    else
                        let $jdoc := try {json:parse($text)} catch * {()}
                        (: If mediatype is json, the uri must point to well-formed JSON :)
                        return $linkValue[not($jdoc)]

            else
                (: If no mediatype was specified, the uri must point to a resource :)
                $linkValue[not(i:resourceExists($uri))]
                
    let $colour := if (exists($errors)) then 'red' else 'green'
    let $values := if (empty($errors)) then () else 
                   $errors ! string(.) => f:extractValues_linkConstraint($valueShape)
    return (
        (: Write results for links which could not be resolved :)
        f:validationResult_links($colour, $valueShape, $exprValue, 
                                 $resultAdditionalAtts, $values, 
                                 $contextInfo, $resultOptions),
        (: Write results for count constraints :)                                  
        f:validateLinkCount($exprValue, $valueShape, $contextInfo)
    )                                 
};

(:~
 : Validates a LinkResolvable constraint with parameter 'recursive' equal to true.
 :
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param valueShape the value shape containing the constraint
 : @param context the processing context
 : @param contextInfo information about the resource context 
 : @return validation results, red and/or green
 :)
declare function f:validateRecursiveLinksResolvable(
                             $contextNode as node(),
                             $filepath as xs:string,
                             $valueShape as element(),
                             $context as map(xs:string, item()*),
                             $contextInfo as map(xs:string, item()*))
        as item()* {
    let $resultAdditionalAtts := attribute recursive {true()}
    let $resultOptions := ()
    (:
    let $docsAndErrors := f:validateRecursiveLinksResolvableRC($contextNode, $filepath, $valueShape, $context, (), ())
     :)
    let $expr := $valueShape/@xpath
    let $mediatype := $valueShape/@mediatype
    let $recursive := $valueShape/@recursive
    let $docsAndErrors := f:resolveLinks($expr, $contextNode, $filepath, $mediatype, $recursive, $context)
    
    let $docs := $docsAndErrors?doc
    let $errors := $docsAndErrors[?error eq 'true']
    
    let $colour := if (exists($errors)) then 'red' else 'green'
    let $values := if (empty($errors)) then () else $errors ! <gx:value where="{?filepath}">{?linkValue}</gx:value>
    return (
        f:validationResult_links($colour, $valueShape, (), 
                                 $resultAdditionalAtts, $values, 
                                 $contextInfo, $resultOptions),
        f:validateLinkCount($docsAndErrors?uri, $valueShape, $contextInfo)
    )        
};

(:~
 : Recursive helper function of `validateRecursiveLinksResolvable`.
 :
 : @param contextNode context node to be used when evaluating the link producing expression
 : @param filepath the file path of the resource currently investigated
 : @param valueShape the value shape containing the constraint
 : @param context the processing context
 : @param pathsSofar file paths of link targets already visited and successfully resolved
 : @param errorsSofar file paths of link targets already visited and found unresolvable 
 : @return maps describing links, either found resolvable or unresolvable
 :)
declare function f:validateRecursiveLinksResolvableRC($contextNode as node(),
                                                      $filepath as xs:string,
                                                      $valueShape as element(),
                                                      $context as map(xs:string, item()*),
                                                      $pathsSofar as xs:string*,
                                                      $errorsSofar as xs:string*)
        as item()* {
           
    let $exprValue := f:resolveLinkExpression($contextNode, $valueShape, $context)
    let $mediatype := $valueShape/@mediatype
    let $targetsAndErrors :=   
        for $linkValue in $exprValue
        let $baseUri := (
            $linkValue[. instance of node()]/ancestor-or-self::*[1]/base-uri(.),
            $filepath
        )[1]
        let $uri := resolve-uri($linkValue, $baseUri)
        where not($uri = ($pathsSofar, $errorsSofar))
        return
            (: If the link value cannot be resolved to a URI, an error is detected :)
            if (not($uri)) then
                map{'uri': '', 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}            
        
            else if ($mediatype = 'json') then            
                if (not(unparsed-text-available($uri))) then 
                    map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                else
                    let $text := unparsed-text($uri)
                    let $jdoc := try {json:parse($text)} catch * {()}
                    return 
                        if (not($jdoc)) then 
                            map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                        else 
                            map{'uri': $uri, 'doc': $jdoc}
                        
            else (: if not JSON, XML is assumed :) 
                if (not(doc-available($uri))) then 
                    map{'uri': $uri, 'linkValue': string($linkValue), 'error': 'true', 'filepath': $filepath}
                else 
                    map{'uri': $uri, 'doc': doc($uri)}
    
    let $errorInfos := $targetsAndErrors[?error eq 'true'][?uri eq '' or not(?uri = $errorsSofar)]
    let $targetInfos := $targetsAndErrors[?doc][not(?uri = $pathsSofar)]
    
    let $newErrors := $errorInfos?uri    
    let $newPaths := $targetInfos?uri
    let $nextDocs := $targetInfos?doc
    
    let $newPathsSofar := ($pathsSofar, $newPaths)
    let $newErrorsSofar := ($errorsSofar, $newErrors)
    return (
        $errorInfos,   (: these are errors not yet observed :)
        $targetInfos,   (: these are targets not yet observed :)
        $targetInfos ! f:validateRecursiveLinksResolvableRC(?doc, ?uri, $valueShape, $context, $newPathsSofar, $newErrorsSofar)
    )
};
:)

(:
(:~
 : Resolves the link expression in the context of an XDM node to a value.
 :
 : The expression is retrieved from the shape element, and the evaluation context
 : is retrieved from the processing context.
 :
 : @param doc document in the context of which the expression must be resolved
 : @param valueShape the value shape specifying the link constraints
 : @param context context for evaluations
 : @return the expression value
 :)
declare function f:resolveLinkExpression($contextNode as node(),
                                         $valueShape as element(),
                                         $context as map(xs:string, item()*))
        as item()* {
    let $expr := $valueShape/@xpath
    let $exprLang := 'xpath'
    let $evaluationContext := $context?_evaluationContext    
    let $exprValue :=
        switch($exprLang)
        case 'xpath' return i:evaluateXPath($expr, $contextNode, $evaluationContext, true(), true())
        default return error(QName((), 'SCHEMA_ERROR'), "'Missing attribute - <links> element must have an 'xpath' attribute")
    return $exprValue        
};        
:)

(:
(:~
 : Creates 'gx:value' elements describing constraint violating items.
 :
 : @param exprValue the expression value
 : @param valueShape value shape declaring the constraint
 : @return sequence of 'gx:value' elements describing constraint violating expression value items
 :)
declare function f:extractValues_linkConstraint($exprValue as item()*, $valueShape as element())
        as element()* {
    let $reporterXPath := $valueShape/@reporterXPath        
    return
        if ($reporterXPath) then
            for $item in $exprValue
            let $rep := i:evaluateSimpleXPath($reporterXPath, $item)    
            return
                <gx:value>{$rep}</gx:value>
        else
            for $item in $exprValue
            return
                typeswitch($item)
                case xs:anyAtomicType | attribute() return string($item) ! <gx:value>{.}</gx:value>
                case element() return
                    if ($item/not((@*, *))) then string ($item) ! <gx:value>{.}</gx:value>
                    else <gx:valueNodePath>{i:datapath($item)}</gx:valueNodePath>
                default return ()                
};        
:)
