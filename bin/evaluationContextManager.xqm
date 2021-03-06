(:
 : -------------------------------------------------------------------------
 :
 : evaluationContextManager.xqm - functions for managing the evaluation context used for expressions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "foxpathUtil.xqm",
   "greenfoxUtil.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns a list of variable names which may be referenced in an
 : expression.
 :
 : @return variable names
 :)
declare function f:getPotentialBindings($context as map(xs:string, item()*)) 
        as xs:string+ {
    'doc', 
    'focusNode',
    'lines',
    'fileName',
    'filePath',    
    'domain',
    
    'targetDoc',
    'targetNode',    
    'linkContext',
    'item',
    'value',
    $context?_externalVars
    
};

(:~
 : Returns a new processing context, containing an evaluation context
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
    let $expressionsMap := f:getEvaluationContextExpressions($componentsMap)
    
    (: Required bindings are a subset of potential bindings :)
    let $reqBindingsAndDocs := f:getRequiredBindingsAndDocs($filePath, $resourceShape, 
        $componentsMap, $expressionsMap, $context)
            
    let $reqBindings := $reqBindingsAndDocs?requiredBindings    
    let $reqDocs := $reqBindingsAndDocs?requiredDocs 

    (: Update the evaluation context so that it contains an entry for each
       variable references found in the in-scope components;
       this excludes, however, variables which cannot be determined before
       specific expressions have been evaluted: @item, @linkContext, @targetDoc, @targetNode.
     :)
    let $context := f:prepareEvaluationContext($reqDocs?doc, $reqDocs?lines, $reqBindings, $filePath, $context)        
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
        return (
            $component,
            $component/*/f:getEvaluationContextScopeRC($filePath, $shape, .)
        )
       
    case element(gx:focusNode) return (
        $component,
        $component/*/f:getEvaluationContextScopeRC($filePath, $shape, .)
    )
    
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
 :     G e t    a l l    i n - s c o p e    e x p r e s s i o n s
 :
 : ===============================================================================
 :)
 
 (:~
  : Returns a map containing all expressions found in the components and link definitions
  : in-scope for a resource shape.
  :
  : Result map:
  : xpath: XPath expressions evaluated in the context of the shape target resource
  : xpath2: XPath expressions evaluated in the context of a link target resource  
  : foxpath: Foxpath expressions evaluated in the context of the shape target resource
  : foxpath2: Foxpath expressions evaluated in the context of a link target resource
  : linepath: Linepath expressions evaluated in the context of the shape target resource  
  : linepath2: Linepath expressions evaluated in the context of a link target resource  
  :
  : @param evaluationScopeComponents a map containing the components in-scope for a resource shape
  : @return a map containing XPath, Foxpath and linepath expressions
  :)
 declare function f:getEvaluationContextExpressions($evaluationScopeComponents as map(*))
        as map(*) {
    let $resourceShapes := $evaluationScopeComponents?resourceShapes
    let $focusNodes := $evaluationScopeComponents?focusNodes
    let $coreConstraints := $evaluationScopeComponents?coreConstraints
    let $extensionConstraints := $evaluationScopeComponents?extensionConstraints
    let $extensionConstraintComponents := $evaluationScopeComponents?extensionConstraintComponents
    let $ldos := $evaluationScopeComponents?linkDefs
    let $components := ($resourceShapes, $focusNodes, $coreConstraints, $extensionConstraints, $extensionConstraintComponents)
   
    let $valuePairComponents := $components/(self::gx:valueCompared, self::gx:foxvalueCompared)
    let $valuePairComponentsExpr2XP := $valuePairComponents/@expr2XP
    let $valuePairComponentsExpr2FOX := $valuePairComponents/@expr2FOX
    let $valuePairComponentsExpr2LP := $valuePairComponents/(@expr2LP, @filter2LP, @map2LP)
    
    let $xpathExpressions2 := (
        $ldos?targetXP,
        $valuePairComponentsExpr2XP
    ) => distinct-values()
    let $foxpathExpressions2 := (
        $valuePairComponentsExpr2FOX
    ) => distinct-values()
    let $linepathExpressions2 := (
        $valuePairComponentsExpr2LP
    ) => distinct-values()
    
    let $xpathExpressions := (
        $ldos?hrefXP ! .,
        $ldos?uriXP ! .,
        $ldos?contextXP ! .,
        $ldos?templateVars?* ! @valueXP,
        $components/(
            @xpath, 
            (@*[name() ! ends-with(., 'XP')]) except $valuePairComponentsExpr2XP
        )) => distinct-values()

    let $linepathExpressions := (
        $components/(@*[name() ! ends-with(., 'LP')] except $valuePairComponentsExpr2LP)
        ) => distinct-values()

    let $foxpathExpressions := (
        $ldos?foxpath ! ., 
        $ldos?templateVars?* ! @valueFOX,
        $components/(
            @foxpath, 
            @*[ends-with(name(), 'FOX')] except $valuePairComponentsExpr2FOX
    )) => distinct-values()
    
    return 
        (: xpath2, foxpath2: expressions evaluated in the context of a link target resource :)
        map{
            'xpath': $xpathExpressions,
            'xpath2': $xpathExpressions2,
            'foxpath': $foxpathExpressions,
            'foxpath2': $foxpathExpressions2,
            'linepath': $linepathExpressions,
            'linepath2': $linepathExpressions2
        }
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
                                              $componentsMap as map(*),
                                              $expressionsMap as map(*),
                                              $context as map(xs:string, item()*)) 
        as map(*) {
    let $requiredBindings := f:getRequiredBindings($expressionsMap, $context)
    let $requiredDocs := f:getRequiredDocs($filePath, $resourceShape, $componentsMap, $expressionsMap, $requiredBindings, $context)
    return
        map:merge((
            map:entry('requiredBindings', $requiredBindings),
            map:entry('requiredDocs', $requiredDocs)
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
                                   $componentsMap as map(*),
                                   $expressionsMap as map(*),
                                   $requiredBindings as xs:string*,                                   
                                   $context as map(xs:string, item()*))
        as map(*)? {
    if (not($resourceShape/self::gx:file)) then () else
    
    let $resourceShapes := $componentsMap?resourceShapes
    let $focusNodes := $componentsMap?focusNodes
    let $coreConstraints := $componentsMap?coreConstraints
    let $extensionConstraints := $componentsMap?extensionConstraints
    let $extensionConstraintComponents := $componentsMap?extensionConstraintComponents
    let $ldos := $componentsMap?linkDefs
    
    let $components := ($resourceShapes, $focusNodes, $coreConstraints, $extensionConstraints, $extensionConstraintComponents)
    let $mediatypes := $resourceShape/@mediatype/tokenize(.)
    let $nodeTreeRequired := f:nodeTreeRequired($componentsMap, $expressionsMap, $ldos)
    
    (: XML document :)
    let $xdoc :=
        let $required :=            
            $mediatypes = 'xml'
            or $requiredBindings = 'doc' and not($mediatypes = ('json', 'csv')) 
            or empty($mediatypes) and $nodeTreeRequired
    return
        if (not($required)) then () 
        else if (not(i:fox-doc-available($filePath))) then ()
        else i:fox-doc($filePath)
        
    (: JSON document :)
    let $jdoc := if ($xdoc) then () else
        
        let $required := $mediatypes = 'json' or $requiredBindings = 'json'
            or empty($mediatypes) and $nodeTreeRequired                    
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
    let $lines :=
        let $required := exists($expressionsMap?linepath) or $requiredBindings = 'lines'
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
            $lines ! map:entry('lines', .)
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
 declare function f:getRequiredBindings($expressionsMap as map(*),
                                        $context as map(xs:string, item()*))
        as xs:string* {     
    let $potentialBindings := f:getPotentialBindings($context) 
    return (
        $expressionsMap?xpath ! f:determineRequiredBindingsXPath(., $potentialBindings),
        $expressionsMap?xpath2 ! f:determineRequiredBindingsXPath(., $potentialBindings),
        $expressionsMap?foxpath ! f:determineRequiredBindingsFoxpath(., $potentialBindings),
        $expressionsMap?foxpath2 ! f:determineRequiredBindingsFoxpath(., $potentialBindings),
        $expressionsMap?linepath ! f:determineRequiredBindingsXPath(., $potentialBindings),
        $expressionsMap?linepath2 ! f:determineRequiredBindingsXPath(., $potentialBindings)
    ) => distinct-values() => sort()
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
 : Returns true if a given set of schema components contains a component which
 : requires a node tree, false otherwise.
 :
 : @param components a set of schema components, e.g. constraint elements and shapes
 : @return true if the input contains a component which requires a node tree
 :)
declare function f:nodeTreeRequired($componentsMap as map(*),
                                    $expressionsMap as map(*), 
                                    $ldos as map(*)*)
        as xs:boolean {
    exists((
        $componentsMap?coreConstraints/
            (self::gx:docTree, self::gx:docSimilar, self::gx:xsdValid),
        $expressionsMap?xpath,
        $ldos?requiresContextNode[. eq true()]
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
declare function f:prepareEvaluationContext($doc as document-node()?,
                                            $lines as document-node()?,
                                            $reqBindings as xs:string*,
                                            $filePath as xs:string,
                                            $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
        
    let $targetInfo := map{'contextURI': $filePath, 'doc': $doc, 'lines': $lines}    
    let $reqDocs := map:merge((
        $doc ! map:entry('doc', .),
        $lines ! map:entry('lines', .)
    ))
    let $evaluationContext :=
        map:merge((
            $context?_evaluationContext,                
            if (not($reqBindings = 'doc')) then () else map:entry(QName('', 'doc'), $doc),
            if (not($reqBindings = 'focusNode')) then () else map:entry(QName('', 'focusNode'), $doc),
            if (not($reqBindings = 'lines')) then () else map:entry(QName('', 'lines'), $lines),
            if (not($reqBindings = 'filePath')) then () else map:entry(QName('', 'filePath'), $filePath),
            if (not($reqBindings = 'fileName')) then () else map:entry(QName('', 'fileName'), replace($filePath, '.*[\\/]', ''))
        ),
        map{'duplicates': 'use-last'}   (: New values override old values :)
        )
    let $context := 
        map:put($context, '_targetInfo', $targetInfo)
        ! map:put(., '_evaluationContext', $evaluationContext)
        ! map:put(., '_reqDocs', $reqDocs)        
    return $context        
}; 

(:~
 : Extends the evaluation context, adding the current focus node.
 :
 : @param focusNode current focus node
 : @param context the evaluation context
 : @return updated evaluation context
 :)
declare function f:updateEvaluationContext_focusNode($focusNode as node(), 
                                                     $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $targetInfo := $context?_targetInfo
    let $newTargetInfo := map:put($targetInfo, 'focusNode', $focusNode) 
                          ! map:put(., 'focusNodePath', $focusNode/i:datapath(.))
    let $newEvaluationContext := 
        $context?_evaluationContext 
        ! map:put(., QName((), 'focusNode'), $focusNode)                          
    let $newContext := 
        map:put($context, '_targetInfo', $newTargetInfo) 
        ! map:put(., '_evaluationContext', $newEvaluationContext)
    return $newContext
};        

(:~
 : Extends the evaluation context, adding parameters passed to a constraint.
 :
 : @param params parameter elements with @name attribute and value as text content
 : @param context the evaluation context
 : @return updated evaluation context
 :)
declare function f:updateEvaluationContext_params($params as element(gx:param)*, 
                                                  $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $evaluationContext := map:merge((
        $context?_evaluationContext,
        $params ! map:entry(QName('', @name), string(.))
    ),
    map{'duplicates': 'use-last'}   (: New values override old values :)
    )
    return
        map:put($context, '_evaluationContext', $evaluationContext)
};        

(:~
 : Returns a copy of the current evaluation context augmented with an entry 'linkContext'
 : which is the current link context.
 :
 : @param linkContextItem the current link context item
 : @param context the processing context
 : @return the updated processing context
 :) 
declare function f:newEvaluationContext_linkContextItem($linkContextItem as item(), 
                                                        $context as map(xs:string, item()*))
        as map(*) {
    let $newEvaluationContext := 
        $context?_evaluationContext 
        ! map:put(., QName('', 'linkContext'), $linkContextItem)
    return $newEvaluationContext
};

(:~
 : Returns a copy of the current evaluation context augmented ready for use by $expr2*
 : in a *Pair or *Compared constraint.
 :
 : @param value1 the value returned by expression 1
 : @param item1 an item from the value of expression 1; only set if @expr2Context = item
 : @param linkContextItem the current link context item; only set when using a link def, 
 :   that is when the constraint is a *Compared constraint
 : @param targetDoc the link target resource as a document; only set when using a link def, 
 :    and the link target is parsed into a node tree; using a link def means that the 
 :    constraint is a *Compared constraint 
 : @param targetNode a node from the link target; only set when using a link def, and the 
 :    link target is parsed into a node tree; can be the document node or a node returned by 
 :    @targetXP; using a link def means that the constraint is a *Compared constraint
 : @param context the processing context
 : @return the updated processing context
 :) 
declare function f:newEvaluationContext_expr2($value1 as item()*,
                                              $item1 as item()?,
                                              $linkContextItem as item()?,                                              
                                              $targetDoc as document-node()?,
                                              $targetNode as node()?,
                                              $context as map(xs:string, item()*))
        as map(*) {
    let $newEc := $context?_evaluationContext ! map:put(., QName((), 'value'), $value1)    
    return
        if (empty(($item1, $linkContextItem, $targetDoc, $targetNode))) then $newEc else
        
        let $newEc := if (empty($item1)) then $newEc else map:put($newEc, QName((), 'item'), $item1)
        let $newEc := if (empty($linkContextItem)) then $newEc else map:put($newEc, QName((), 'linkContext'), $linkContextItem)        
        let $newEc := if (empty($targetDoc)) then $newEc else map:put($newEc, QName((), 'targetDoc'), $targetDoc)                
        let $newEc := if (empty($targetNode)) then $newEc else map:put($newEc, QName((), 'targetNode'), $targetNode)
        return $newEc
};

(:~
 : Returns a the evaluation context, augmented by values related to a link resolution.
 :
 : @param lro a Link Resolution Object
 : @param context the processing context
 : @return the updated processing context
 :)
declare function f:newEvaluationContext_lro($lro as map(xs:string, item()*), 
                                            $context as map(xs:string, item()*))
        as map(*) {
    let $newEvaluationContext := $context?_evaluationContext
    return
        $newEvaluationContext ! f:extendEvaluationContext_lro($lro, ., $context)
};

(:~
 : Returns a copy of the current evaluation context, augmented by values related to
 : a link resolution.
 :
 : @param lro a Link Resolution Object
 : @param evaluationContext the evaluation context to be extended
 : @param context the processing context
 : @return the updated processing context
 :) 
declare function f:extendEvaluationContext_lro(
                                   $lro as map(xs:string, item()*),
                                   $evaluationContext as map(xs:QName, item()*),
                                   $context as map(xs:string, item()*))
        as map(*) {
    let $newEc := $evaluationContext    
    return
        let $newEc := 
            if (empty($lro?contextItem)) then $newEc else 
                map:put($newEc, QName((), 'linkContext'), $lro?contextItem)        
        let $newEc := 
            if (empty($lro?targetDoc)) then $newEc else 
                map:put($newEc, QName((), 'targetDoc'), $lro?targetDoc)                
        let $newEc := 
            if (empty($lro?targetNodes)) then $newEc else 
                map:put($newEc, QName((), 'targetNodes'), $lro?targetNodes)
        return $newEc
};
