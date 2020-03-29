(:
 : -------------------------------------------------------------------------
 :
 : evaluationContextManager.xqm - functions for managing the evaluation context used for expressions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "foxpathUtil.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns a list of variable names which may be referenced in an
 : expression.
 :
 : @return variable names
 :)
declare function f:getPotentialBindings() as xs:string+ {
    'this',
    'domain', 
    'filePath', 
    'fileName',
    'doc', 
    'jdoc', 
    'csvdoc',
    'htmldoc'
};

(:~
 : Returns for a given shape the components within the scope of evaluation 
 : context required for this shape.
 :
 : Returns a map with three fields:
 : - core components: all components which are not extension constraints
 : - extensionConstraints: constraints based on extension constraint components
 : - extensionConstraintComponents: extension constraint components referenced by extension constraints
 :)
declare function f:getEvaluationContextScope($filePath as xs:string, 
                                             $shape as element())
        as map(xs:string, element()*) {

    let $components := 
        $shape/*/f:getEvaluationContextScopeRC($filePath, $shape, .)
    let $resourceShapes := $components/(self::gx:file, self::folder)
    let $focusNodes := $components/self::gx:focusNode
    let $constraints := $components except ($resourceShapes, $focusNodes)
    
    (: Subset of the constraints which are extension constraint definitions :)
    let $extensionConstraints := f:getExtensionConstraints($constraints)     
    let $coreConstraints := $constraints except $extensionConstraints
    
    (: Extension constraint components :)
    let $extensionConstraintComponents := f:getExtensionConstraintComponents($extensionConstraints)
    return
        map{
            'resourceShapes': $resourceShapes,
            'focusNodes': $focusNodes,
            'coreConstraints': $coreConstraints,
            'extensionConstraints': $extensionConstraints,
            'extensionConstraintComponents': $extensionConstraintComponents
        }
};

(:~
 : Auxilliary function supporting function f:getEvaluationContextScope.
 :
 : @param filePath file path of the shape for which the scope is defined
 : @param shape the shape for which the scope is defined
 : @param component a potential component
 : @return the component if appropriate, as well as all descendant components within
 :   the evaluation scope
 :)
declare function f:getEvaluationContextScopeRC($filePath as xs:string,
                                               $shape as element(),
                                               $component as element())
        as element()* {
    if ($component/@deactivated eq 'true') then () else

    typeswitch($component)
    case element(gx:file) | 
         element(gx:folder) | 
         element(gx:focusNode) 
         return $component
         
    case element(gx:xpath) | 
         element(gx:foxpath) | 
         element(gx:folderContent) |
         element(gx:docSimilar) | 
         element(gx:folderSimilar)
        return $component
        
    case element(gx:focusNode) return $component
        
    case $ifMediatype as element(gx:ifMediatype) return
        $ifMediatype
        [i:matchesMediatype((@eq, @in/tokenize(.)), $filePath)]
        /*/f:getEvaluationContextScopeRC($filePath, $shape, .)
        
    default return (
        $component,
        $component/*/f:getEvaluationContextScopeRC($filePath, $shape, .)
    )        
};        

(:~
 : Provides the names of required variable bindings and required documents.
 : Required documents depend on the mediatype of this file, as well as on 
 : required bindings: 
 : * assign $xdoc if mediatype 'xml' or 'xml-or-json' or required binding 'doc'
 : * assign $jdoc if mediatype 'json' or 'xml-or-json' or required binding 'jdoc'
 : * assign $htmldoc if mediatype 'html' or 'required binding 'htmldoc' 
 : * assign $csvdoc if mediatype 'csv' or 'required binding 'csvdoc'
 :
 : @param filePath file path of this file
 : @param gxFile file shape
 : @param coreComponents core components defining XPath and foxpath expressions
 : @param extensionConstraints constraint declarations referencing extension constraint components
 : @param extensionConstraintComponents extension constraint components 
 : @return a map with key 'requiredBindings' containing a list of required variable
 :   names, key 'xdoc' an XML doc, 'jdoc' an XML representation of the JSON
 :   document, key 'csvdoc' an XML representation of the CSV document
 :)
declare function f:getRequiredBindingsAndDocs($filePath as xs:string,
                                              $gxFile as element(gx:file),
                                              $coreComponents as element()*,
                                              $extensionConstraints as element()*,
                                              $extensionConstraintComponents as element()*,
                                              $resourceShapes as element()*,
                                              $focusNodes as element()*) 
        as map(*) {
    let $allComponents := ($coreComponents, $extensionConstraints, $extensionConstraintComponents, $resourceShapes, $focusNodes)
    let $focusNodes := $allComponents/descendant-or-self::gx:focusNode
    let $mediatype := $gxFile/@mediatype        
    
    (: Required bindings :)
    let $requiredBindings :=
    
        (: A subset of potential bindings, implied by variable references in expressions :)
        let $potentialBindings := f:getPotentialBindings()
        return f:getRequiredBindings($potentialBindings, 
                                     $coreComponents, 
                                     $extensionConstraints,
                                     $extensionConstraintComponents,
                                     $resourceShapes,
                                     $focusNodes) 
                                     
    (: Required documents :)                                    
    let $xdoc :=
        let $required :=            
            $mediatype = ('xml', 'xml-or-json')
            or not($mediatype = ('json', 'csv')) and $requiredBindings = 'doc'
            or not($mediatype) and (
              (: Listing reasons for loading XML document :)
              $coreComponents/(self::gx:xpath, 
                               self::gx:foxpath/@*[ends-with(name(.), 'XPath')],
                               self::gx:links, 
                               self::gx:docSimilar, 
                               gx:validatorXPath, 
                               @validatorXPath), 
              $focusNodes/@xpath
            )    
        return
            if (not($required)) then () 
            else if (not(i:fox-doc-available($filePath))) then ()
            else i:fox-doc($filePath)
    let $jdoc :=
        if ($xdoc) then () else
        
        let $required :=
            $requiredBindings = 'json'
            or
            $mediatype = ('json', 'xml-or-json')
            or 
            not($mediatype) and (
                (: Listing reasons for loading JSON document :)
                $coreComponents/(self::gx:xpath,
                                 self::gx:foxpath/@*[ends-with(name(.), 'Foxpath')],
                                 self::gx:links,
                                 self::gx:docSimilar,
                                 gx:validatorXPath,
                                 @validatorXPath),
                $focusNodes/@xpath
            )
        return
            if (not($required)) then ()
            else
                let $text := i:fox-unparsed-text($filePath, ())
                return try {json:parse($text)} catch * {()}
           
    let $htmldoc :=
        if ($xdoc or $jdoc) then () else
        
        let $required :=
            $requiredBindings = 'html'
            or
            $mediatype = ('html', 'xml-or-html')
        return
            if (not($required)) then ()
            else
                let $text := i:fox-unparsed-text($filePath, ())
                return try {html:parse($text)} catch * {()}
           
    let $csvdoc :=
        let $required :=
            $requiredBindings = 'csvdoc'
            or
            $mediatype eq 'csv'
        return
            if (not($required)) then ()
            else f:csvDoc($filePath, $gxFile)
         
    let $doc := ($xdoc, $jdoc, $htmldoc, $csvdoc) 

    return
        map:merge((
            map:entry('requiredBindings', $requiredBindings),
            $doc ! map:entry('doc', .),
            $xdoc ! map:entry('xdoc', .),
            $jdoc ! map:entry('jdoc', .),
            $csvdoc ! map:entry('csvdoc', .),
            $htmldoc ! map:entry('htmldoc', .)
        ))
};        

(:~
 : Determines the required variable bindings, given a set of in-scope components specifying XPath and
 : foxpath expressions. These bindings are the superset from which the actual bindings for all
 : individual expressions are selected.
 :
 : @param potentialBindings the variable names for which a binding may be required
 : @param coreComponents core components defining XPath and foxpath expressions
 : @param extensionConstraints constraint declarations referencing extension constraint components
 : @param extensionConstraintComponents extension constraint components 
 : @return the actually required variable bindings
 :)
declare function f:getRequiredBindings($potentialBindings as xs:string*, 
                                       $coreComponents as element()*,
                                       $extensionConstraints as element()*,
                                       $extensionConstraintComponents as element()*,
                                       $resourceShapes as element()*,
                                       $focusNodes as element()*)
        as xs:string* {

    let $potentialBindings_params := $extensionConstraintComponents/gx:param/@name/string()
    let $potentialBindings := ($potentialBindings, $potentialBindings_params)

    let $reqBindings :=
        for $component in ($coreComponents, $extensionConstraints, $extensionConstraintComponents,
                           $resourceShapes, $focusNodes)
        let $xpathExpressions := $component/(
            self::gx:xpath/@expr,
            self::gx:validatorXPath,
            @xpath,
            @*[ends-with(name(), 'XPath')]
        )
        let $foxpathExpressions := $component/(
            self::gx:foxpath/@expr,
            self::gx:validatorFoxpath,
            @foxpath,
            @*[ends-with(name(), 'Foxpath')]
        )
        return (
            $xpathExpressions/f:determineRequiredBindingsXPath(., $potentialBindings),
            $foxpathExpressions/f:determineRequiredBindingsFoxpath(., $potentialBindings)
        ) => distinct-values() => sort()
    return $reqBindings   
};        

(:~
 : Returns the variable bindings used by an XPath expression.
 : Only bindings from $candidateBindings are considered.
 :
 : @param expr an XPath or XQuery expression
 : @param candidateBindings names of variable bindings to be checked
 : @return those candidateBindings as are found in the expression
 :) 
declare function f:determineRequiredBindingsXPath($expr as xs:string,
                                                  $candidateBindings as xs:string*)
        as xs:string* {
    let $extendedExpr := f:finalizeQuery($expr, $candidateBindings)
    let $tree := xquery:parse($extendedExpr)
    return $tree//StaticVarRef/@var => distinct-values() => sort()
};

(:~
 : Returns the variable bindings used by a foxpath expression.
 : Only bindings from $candidateBindings are considered.
 :
 : @param expr an XPath or XQuery expression
 : @param candidateBindings names of variable bindings to be checked
 : @return those candidateBindings as are found in the expression
 :) 
declare function f:determineRequiredBindingsFoxpath($expr as xs:string,
                                                    $candidateBindings as xs:string*)
        as xs:string* {
    let $extendedExpr := f:finalizeQuery($expr, $candidateBindings)
    let $tree := f:parseFoxpath($extendedExpr)
    let $_CHECK := 
        if (not($tree/self::errors/error[1])) then () else 
            error(QName((), 'FOXPATH_ERROR'), $tree/error[1]/concat(
                'An error occurred when trying to determine required bindings (Foxpath); ',
                'errCode: ', @code, '; ',
                'errDescription: ', @msg)) 
    return (
        $tree//var[not((parent::let, parent::for))]/@localName => distinct-values() => sort()
    )[. = $candidateBindings]
};

(:~
 : Updates the context so that it contains an evaluation context as required for
 : an expression with known required bindings.
 :
 : @param reqBindings the names of variables referenced by the expression
 : @param context the context
 : @param filePath file path of a file or folder currently processed
 : @param xdoc an XML document
 : @param jdoc an XML document representing a JSON document
 : @param csvdoc an XML document representing a CSV record
 : @return the updated context, containing the new evaluation context implied 
 :   by the required bindings and the values to be bound to them 
 :)
declare function f:prepareEvaluationContext($context as map(xs:string, item()*),
                                            $reqBindings as xs:string*,
                                            $filePath as xs:string,
                                            $xdoc as document-node()?,
                                            $jdoc as document-node()?,
                                            $csvdoc as document-node()?,
                                            $htmldoc as document-node()?,
                                            $params as element(gx:param)*)
        as map(xs:string, item()*) {
    let $doc := ($xdoc, $jdoc, $csvdoc, $htmldoc)[1]    
    let $reqDocs := map:merge((
        $xdoc ! map:entry('xdoc', .),
        $jdoc ! map:entry('jdoc', .),
        $csvdoc ! map:entry('csvdoc', .),
        $doc ! map:entry('doc', .)))
    let $context := 
        let $evaluationContext :=
            map:merge((
                $context?_evaluationContext,
                
                (: Add in-scope document :)
                if (not($reqBindings = 'doc')) then () else map:entry(QName('', 'doc'), $doc),
                if (not($reqBindings = 'xdoc')) then () else map:entry(QName('', 'xdoc'), $xdoc),
                if (not($reqBindings = 'jdoc')) then () else map:entry(QName('', 'jdoc'), $jdoc),
                if (not($reqBindings = 'csvdoc')) then () else map:entry(QName('', 'csvdoc'), $csvdoc),
                if (not($reqBindings = 'htmldoc')) then () else map:entry(QName('', 'htmldoc'), $htmldoc),
                
                (: Add built-in variables - this, filePath, fileName :)
                if (not($reqBindings = 'this')) then () else map:entry(QName('', 'this'), $filePath),
                if (not($reqBindings = 'filePath')) then () else map:entry(QName('', 'filePath'), $filePath),
                if (not($reqBindings = 'fileName')) then () else map:entry(QName('', 'fileName'), replace($filePath, '.*[\\/]', '')),
                if (not($reqBindings = 'domain')) then () else map:entry(QName('', 'domain'), $context?_domain),
                (: _TO_DO_ Support datatypes (xs:integer, ...) :)
                
                (: Add parameter element values :)
                $params ! map:entry(QName('', @name), string(.))                
            ))    
        return map:put($context, '_evaluationContext', $evaluationContext) !
               map:put(., '_reqDocs', $reqDocs)
    return $context        
};  

