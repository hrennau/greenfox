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

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkDefinition.xqm";

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
    'htmldoc',
    'linkContext'
};

(:~
 : Returns a nex processing context, containing an evaluation context
 : adapted to a new focus resource.
 :
 : @param @filePath the file path of the focus resource
 : @param @resourceShape the resource shape element
 : @param context the current processing context, containing the evaluation
 :   context of the current focus resource of the *parent shape*
 : @return the updated processing context
 :)
declare function f:adaptContext($filePath as xs:string, 
                                $resourceShape as element(), 
                                $context as map(*))
        as map(*) {
    (: Determine in-scope components 
         = all components to be evaluated in the context of this file resource :)
    let $componentsMap := i:getEvaluationContextScope($filePath, $resourceShape, $context)
    let $resourceShapes := $componentsMap?resourceShapes
    let $focusNodes := $componentsMap?focusNodes
    let $coreConstraints := $componentsMap?coreConstraints
    let $extensionConstraints := $componentsMap?extensionConstraints
    let $extensionConstraintComponents := $componentsMap?extensionConstraintComponents
    let $ldos := $componentsMap?linkDefs
    let $constraints := ($coreConstraints, $extensionConstraints)
    
    (: Required bindings are a subset of potential bindings :)
    let $reqBindingsAndDocs := 
        f:getRequiredBindingsAndDocs(
            $filePath, 
            $resourceShape, 
            $coreConstraints, 
            $extensionConstraints, 
            $extensionConstraintComponents,
            $ldos,
            $resourceShapes,
            $focusNodes,
            $context)
            
    let $reqBindings := $reqBindingsAndDocs?requiredBindings    
    let $reqDocs := 
        map:merge((
            $reqBindingsAndDocs?xdoc ! map:entry('xdoc', .),
            $reqBindingsAndDocs?jdoc ! map:entry('jdoc', .),
            $reqBindingsAndDocs?csvdoc ! map:entry('csvdoc', .),
            $reqBindingsAndDocs?htmldoc ! map:entry('htmldoc', .),
            $reqBindingsAndDocs?linesdoc ! map:entry('linesdoc', .)
        ))        

    (: Update the evaluation context so that it contains an entry for each
       variable references found in the in-scope components;
       this excludes, however, variables which cannot be determined before
       specific expressions have been evaluted: @item, @linkContext, @targetDoc, @targetNode.
     :)
    let $context := f:prepareEvaluationContext($context, $reqBindings, $filePath, 
        $reqDocs?xdoc, $reqDocs?jdoc, $reqDocs?csvdoc, $reqDocs?htmldoc, $reqDocs?linesdoc, ())        
    return $context   
};

(:~
 : ===============================================================================
 :
 :     G e t    a l l    i n - s c o p e    c o m p o n e n t s
 :
 : ===============================================================================
 :)

(:~
 : Returns for a given shape the components within the scope of its evaluation 
 : context.
 :
 : The components are returned in groups, contained by a map with five fields:
 : - resource shapes
 : - focus nodes
 : - core components: all components which are not extension constraints
 : - extensionConstraints: constraints based on extension constraint components
 : - extensionConstraintComponents: extension constraint components referenced by extension constraints
 : - link definitions
 :
 : @param filePath file path of the focus resource
 : @param shape the shape currently processed
 : @param context the processing context
 : @return a map providing the components
 :)
declare function f:getEvaluationContextScope($filePath as xs:string, 
                                             $shape as element(),
                                             $context as map(xs:string, item()*))
        as map(xs:string, item()*) {

    let $components := 
        $shape/*/f:getEvaluationContextScopeRC($filePath, $shape, .)
    let $resourceShapes := $components/(self::gx:file, self::folder)
    let $focusNodes := $components/self::gx:focusNode
    let $constraints := $components except ($resourceShapes, $focusNodes)
    
    (: Subset of the constraints which are extension constraint definitions :)
    let $extensionConstraints := f:getExtensionConstraints($constraints)     
    let $coreConstraints := $constraints except $extensionConstraints
    let $linkDefs := link:getLinkDefs($components, $context)
    (:
    let $_DEBUG := trace($filePath, '_FILE_PATH: ')
    let $_DEBUG := trace($components/name() => distinct-values(), '_COMP_NAMES: ')
    let $_DEBUG := trace($linkDefs?name => distinct-values(), 'LINK_DEF_NAMES: ')
     :)
    (: Extension constraint components :)
    let $extensionConstraintComponents := f:getExtensionConstraintComponents($extensionConstraints)
    return
        map{
            'resourceShapes': $resourceShapes,
            'focusNodes': $focusNodes,
            'coreConstraints': $coreConstraints,
            'extensionConstraints': $extensionConstraints,
            'extensionConstraintComponents': $extensionConstraintComponents,
            'linkDefs': $linkDefs
        }
};

(:~
 : Auxiliary function supporting function f:getEvaluationContextScope.
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
         element(gx:docTree) |
         element(gx:value) |
         element(gx:values) |    
         element(gx:valuePair) |
         element(gx:valuePairs) |
         element(gx:valueCompared) |
         element(gx:valuesCompared) |
         element(gx:foxvalue) |
         element(gx:foxvalues) |    
         element(gx:foxvaluePair) |
         element(gx:foxvaluePairs) |
         element(gx:foxvalueCompared) |
         element(gx:foxvaluesCompared) |
         element(gx:contentCorrespondence) |
         element(gx:folderSimilar) |
         element(gx:links)
        return $component
       
    case element(gx:focusNode) return $component
    
    (: ifMediatype - continue with children, if mediatype matched :)    
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
 : ===============================================================================
 :
 :     G e t    r e q u i r e d    b i n d i n g s    &    d o c s
 :
 : ===============================================================================
 :)

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
 : @param context the processing context
 : @return a map with key 'requiredBindings' containing a list of required variable
 :   names, key 'xdoc' an XML doc, 'jdoc' an XML representation of the JSON
 :   document, key 'csvdoc' an XML representation of the CSV document
 :)
declare function f:getRequiredBindingsAndDocs($filePath as xs:string,
                                              $resourceShape as element(),
                                              $coreComponents as element()*,
                                              $extensionConstraints as element()*,
                                              $extensionConstraintComponents as element()*,
                                              $ldos as map(*)*,                                              
                                              $resourceShapes as element()*,
                                              $focusNodes as element()*,
                                              $context as map(xs:string, item()*)) 
        as map(*) {
    let $allComponents := ($coreComponents, $extensionConstraints, $extensionConstraintComponents, $resourceShapes, $focusNodes)
    let $focusNodes := $allComponents[. instance of node()]/descendant-or-self::gx:focusNode
    let $mediatype := $resourceShape/@mediatype        
    
    (: Required bindings :)
    let $requiredBindings :=    
        (: A subset of potential bindings, implied by variable references in expressions :)
        let $potentialBindings := f:getPotentialBindings()
        return f:getRequiredBindings($potentialBindings, 
                                     $coreComponents, 
                                     $extensionConstraints,
                                     $extensionConstraintComponents,
                                     $ldos,
                                     $resourceShapes,
                                     $focusNodes,
                                     $context) 
    (: Required documents :)   
    let $requiredDocs := 
        f:getRequiredDocs($filePath, $resourceShape, $ldos, $requiredBindings, $allComponents, $context)
        
(:    
        if (not($resourceShape/self::gx:file)) then () else
        let $mediatypes := tokenize($mediatype)
        let $xdoc :=
            let $required :=            
                $mediatypes = ('xml', 'json')
                or not($mediatypes = ('json', 'csv')) and $requiredBindings = 'doc'
                or not($mediatype) and (f:nodeTreeRequired($allComponents, $context) or exists($ldos[?requiresContextNode]))
            return
                if (not($required)) then () 
                else if (not(i:fox-doc-available($filePath))) then ()
                else i:fox-doc($filePath)
        let $jdoc :=
            if ($xdoc) then () else
        
            let $required :=
                $requiredBindings = 'json' or
                $mediatypes = ('json', 'xml') or 
                not($mediatype) and (f:nodeTreeRequired($allComponents, $context) or exists($ldos[?requiresContextNode]))                    
            return
                if (not($required)) then ()
                else try {i:fox-json-doc($filePath, ())} catch * {()}
           
        let $htmldoc :=
            if ($xdoc or $jdoc) then () else
        
            let $required :=
                $requiredBindings = 'html' or
                $mediatypes = ('html', 'xml')
            return
                if (not($required)) then ()
                else
                    let $text := i:fox-unparsed-text($filePath, ())
                    return try {html:parse($text)} catch * {()}
           
        let $csvdoc :=
            let $required :=
                $requiredBindings = 'csvdoc' or
                $mediatype eq 'csv'
            return
                if (not($required)) then ()
                else f:csvDoc($filePath, $resourceShape, ())
         

        let $linesdoc :=
            let $required := f:linesTreeRequired($allComponents)
            return
                if (not($required)) then () 
                else
                    let $lines := i:fox-unparsed-text-lines($filePath, ()) ! <line>{.}</line>
                    return
                        document {<lines count="{count($lines)}" xml:base="{$filePath}">{$lines}</lines>}

        let $doc := ($xdoc, $jdoc, $htmldoc, $csvdoc) 
        return
            map:merge((
                $doc ! map:entry('doc', .),
                $xdoc ! map:entry('xdoc', .),
                $jdoc ! map:entry('jdoc', .),
                $csvdoc ! map:entry('csvdoc', .),
                $htmldoc ! map:entry('htmldoc', .),
                $linesdoc ! map:entry('linesdoc', .)
            ))
:)    
    return
        map:merge((
            map:entry('requiredBindings', $requiredBindings),
            $requiredDocs
        ))
};        

(:~
 : Determines the required variable documents, given a set of in-scope components 
 : specifying XPath, Foxpath and Linepath expressions.
 :
 : @param filePath file path of this file
 : @param resourceShape the element representing the resource shape
 : @param allComponents the components in scope when dealing with this file
 : @param context processing context
 : @return a map containing the required documents
 :)
declare function f:getRequiredDocs($filePath as xs:string,
                                   $resourceShape as element(),
                                   $ldos as map(xs:string, item()*)*,
                                   $requiredBindings as xs:string*,
                                   $allComponents as element()*,
                                   $context as map(xs:string, item()*))
        as map(*)? {
    if (not($resourceShape/self::gx:file)) then () else
    
    let $mediatypes := $resourceShape/@mediatype/tokenize(.)
    
    (: XML document :)
    let $xdoc :=
        let $required :=            
            $mediatypes = 'xml'
            or $requiredBindings = 'doc' and not($mediatypes = ('json', 'csv')) 
            or empty($mediatypes) and 
                (f:nodeTreeRequired($allComponents, $context) 
                 or exists($ldos[?requiresContextNode]))
    return
        if (not($required)) then () 
        else if (not(i:fox-doc-available($filePath))) then ()
        else i:fox-doc($filePath)
        
    (: JSON document :)
    let $jdoc := if ($xdoc) then () else
        
        let $required := $mediatypes = 'json' or $requiredBindings = 'json'
            or empty($mediatypes)  
               and (f:nodeTreeRequired($allComponents, $context) 
                    or exists($ldos[?requiresContextNode]))                    
        return
            if (not($required)) then () else
                try {i:fox-json-doc($filePath, ())} catch * {()}
           
    (: HTML document :)
    let $htmldoc := if ($xdoc or $jdoc) then () else
        
        let $required := $mediatypes = 'html' or $requiredBindings = 'html'
        return
            if (not($required)) then () else
                let $text := i:fox-unparsed-text($filePath, ())
                return try {html:parse($text)} catch * {()}
     
    (: CSV document :)
    let $csvdoc :=
        let $required := $mediatypes = 'csv' or $requiredBindings = 'csvdoc'
        return
            if (not($required)) then () else
                f:csvDoc($filePath, $resourceShape, ())
         
    (: lines document :)
    let $linesdoc :=
        let $required := f:linesTreeRequired($allComponents)
        return
            if (not($required)) then () else 
                let $lines := i:fox-unparsed-text-lines($filePath, ()) ! <line>{.}</line>
                return
                    document {
                        <lines count="{count($lines)}" xml:base="{$filePath}">{
                            $lines
                        }</lines>}

    let $doc := ($xdoc, $jdoc, $htmldoc, $csvdoc) 
    return
        map:merge((
            $doc ! map:entry('doc', .),
            $xdoc ! map:entry('xdoc', .),
            $jdoc ! map:entry('jdoc', .),
            $csvdoc ! map:entry('csvdoc', .),
            $htmldoc ! map:entry('htmldoc', .),
            $linesdoc ! map:entry('linesdoc', .)
        ))
};

(:~
 : Determines the required variable bindings, given a set of in-scope components 
 : specifying XPath and foxpath expressions. These bindings are the superset from 
 : which the actual bindings for all individual expressions are selected.
 :
 : @param potentialBindings the variable names for which a binding may be required
 : @param coreComponents core components defining XPath and foxpath expressions
 : @param extensionConstraints constraint declarations referencing extension constraint components
 : @param extensionConstraintComponents extension constraint components 
 : @param context the processing context
 : @return the actually required variable bindings
 :)
declare function f:getRequiredBindings($potentialBindings as xs:string*, 
                                       $coreComponents as element()*,
                                       $extensionConstraints as element()*,
                                       $extensionConstraintComponents as element()*,
                                       $ldos as map(*)*,
                                       $resourceShapes as element()*,
                                       $focusNodes as element()*,
                                       $context as map(xs:string, item()*))
        as xs:string* {

    let $potentialBindings_params := $extensionConstraintComponents/gx:param/@name/string()
    let $potentialBindings := ($potentialBindings, $potentialBindings_params)
    let $components := ($coreComponents, $extensionConstraints, $extensionConstraintComponents,
                        $resourceShapes, $focusNodes)
    let $reqBindings :=
        let $xpathExpressions := (
            $ldos?hrefXP ! .,
            $ldos?uriXP ! .,
            $ldos?contextXP ! .,
            $ldos?targetXP ! .,
            $ldos?templateVars?* ! @exprXP,
            $components/(@xpath, @*[name() ! (ends-with(., 'XP') or ends-with(., 'LP'))])
        ) => distinct-values()            
        let $foxpathExpressions := (
            $ldos?foxpath ! .,         
            $components/(@foxpath, @*[ends-with(name(), 'FOX')])
        ) => distinct-values()
        return (
            $xpathExpressions ! f:determineRequiredBindingsXPath(., $potentialBindings),
            $foxpathExpressions ! f:determineRequiredBindingsFoxpath(., $potentialBindings)
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
 : Updates the context so that it contains an evaluation context as required 
 : for an expression with known required bindings.
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
                                            $linesdoc as document-node()?,
                                            $params as element(gx:param)*)
        as map(xs:string, item()*) {
    (: let $_DEBUG := trace($reqBindings, concat('___FILEPATH: ', $filePath, ' ; ___REQ_BINDINGS: ')) :)
    let $doc := ($xdoc, $jdoc, $csvdoc, $htmldoc)[1]
    
    let $reqDocs := map:merge((
        $doc ! map:entry('doc', .),
        $linesdoc ! map:entry('linesdoc', .)
    ))

    let $context := 
        let $evaluationContext :=
            map:merge((
                $context?_evaluationContext,                
                if (not($reqBindings = 'doc')) then () else map:entry(QName('', 'doc'), $doc),
                if (not($reqBindings = 'linesdoc')) then () else map:entry(QName('', 'linesdoc'), $linesdoc),
                if (not($reqBindings = 'this')) then () else map:entry(QName('', 'this'), $filePath),
                if (not($reqBindings = 'filePath')) then () else map:entry(QName('', 'filePath'), $filePath),
                if (not($reqBindings = 'fileName')) then () else map:entry(QName('', 'fileName'), replace($filePath, '.*[\\/]', '')),
                if (not($reqBindings = 'domain')) then () else map:entry(QName('', 'domain'), $context?_domain),
                (: Add parameter element values :)
                $params ! map:entry(QName('', @name), string(.))                
            ),
            map{'duplicates': 'use-last'}   (: New values override old values :)
            )  
        return map:put($context, '_evaluationContext', $evaluationContext) !
               map:put(., '_reqDocs', $reqDocs) !
               map:put(., '_targetInfo', map{'contextURI': $filePath, 'doc': $doc})
    return $context        
}; 

(:~
 : Returns true if a given set of schema components contains a component which
 : requires a node tree, false otherwise.
 :
 : @param components a set of schema components, e.g. constraint elements and shapes
 : @return true if the input contains a component which requires a node tree
 :)
declare function f:nodeTreeRequired($components as element()*, $context as map(xs:string, item()*))
        as xs:boolean? { 
    (: let $_DEBUG := trace($components/name() => string-join(', '), '_COMPONENT_NAMES: ') return :)        
        
    exists($components/(
        self::gx:focusNode,
        self::gx:docSimilar,
        self::gx:docTree,
        self::gx:value, self::gx:values,    
        self::gx:valuePair, self::gx:valuePairs,
        self::gx:valueCompared, self::gx:valuesCompared,
        self::gx:foxvaluePair[.//(@expr1XP, @expr2XP)],
        self::gx:foxvaluePairs[.//(@expr1XP, @expr2XP)],
        self::gx:foxvalueCompared[.//(@expr1XP, @expr2XP)],
        self::gx:foxvaluesCompared[.//(@expr1XP, @expr2XP)],
        self::gx:links[not(@linkName)][link:parseLinkDef(., $context)?requiresContextNode], 
        self::gx:file[not(@linkName)][link:parseLinkDef(., $context)?requiresContextNode],
        gx:validatorXPath, 
        @validatorXPath,
                      
        self::gx:xpath, 
        self::gx:foxpath/@*[ends-with(name(.), 'XPath')],
        self::gx:contentCorrespondence      
    ))
};        

(:~
 : Returns true if a given set of schema components contains a component which
 : requires a lines tree, false otherwise.
 :
 : @param components a set of schema components, e.g. constraint elements and shapes
 : @return true if the input contains a component which requires a node tree
 :)
declare function f:linesTreeRequired($components as element()*)
        as xs:boolean? { 
     (: let $_DEBUG := trace($components/name() => string-join(', '), '_COMPONENT_NAMES: ') return :)         

    exists($components/(
        (self::gx:value, self::gx:values)[.//(@exprLP, @filterLP, @mapLP)], 
        (self::gx:valuePair, self::gx:valuePairs)[.//(@expr1LP, @expr2LP, @filter1LP, @filter2LP, @map1LP, @map2LP)], 
        (self::gx:valueCompared, self::gx:valuesCompared)[.//(@expr1LP, @expr2LP, @filter1LP, @filter2LP, @map1LP, @map2LP)], 
        (self::gx:foxvaluePair, self::gx:foxvaluePairs)[.//(@expr1LP, @expr2LP, @filter1LP, @filter2LP, @map1LP, @map2LP)],
        (self::gx:foxvalueCompared, self::gx:foxvalueCompared)[.//(@expr1LP, @expr2LP, @filter1LP, @filter2LP, @map1LP, @map2LP)]
    ))

};        

(:
 : -------------------------------------------------------------------------
 :
 : U p d a t e s
 :
 : -------------------------------------------------------------------------
 :)

(:~
 : Extends the evaluation context, adding the current focus node.
 :
 : @param focusNode current focus node
 : @param context the evaluation context
 : @return updated evaluation context
 :)
declare function f:updateEvaluationContext_focusNode($focusNode as node(), $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $targetInfo := $context?_targetInfo
    let $newTargetInfo := map:put($targetInfo, 'focusNode', $focusNode) ! map:put(., 'focusNodePath', $focusNode/i:datapath(.))
    return map:put($context, '_targetInfo', $newTargetInfo)
};        

(:~
 : Returns a copy of the current evaluation context augmented with an entry 'linkContext'
 : which is the current link context.
 :
 : @param linkContextItem the current link context item
 : @param context the processing context
 : @return the updated processing context
 :) 
declare function f:newEvaluationContext_linkContextItem($linkContextItem as item(), $context as map(xs:string, item()*))
        as map(*) {
    let $newEvaluationContext := 
        $context?_evaluationContext 
        ! map:put(., QName('', 'linkContext'), $linkContextItem)
    return $newEvaluationContext
};

(:~
 : Returns a copy of the current evaluation context augmented ready for used by $expr2*.
 :
 : @param linkContextItem the current link context item
 : @param context the processing context
 : @return the updated processing context
 :) 
declare function f:newEvaluationContext_expr2($item as item()?,
                                              $targetDoc as document-node()?,
                                              $targetNode as node()?,
                                              $context as map(xs:string, item()*))
        as map(*) {
    let $newEc := $context?_evaluationContext
    return
        if (empty(($item, $targetDoc, $targetNode))) then $newEc else
        
        let $newEc := if (empty($item)) then $newEc else map:put($newEc, QName((), 'item'), $item)
        let $newEc := if (empty($targetDoc)) then $newEc else map:put($newEc, QName((), 'targetDoc'), $targetDoc)                
        let $newEc := if (empty($targetNode)) then $newEc else map:put($newEc, QName((), 'targetNode'), $targetNode)
        return $newEc
};