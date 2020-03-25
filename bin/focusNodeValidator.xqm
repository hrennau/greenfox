(:
 : -------------------------------------------------------------------------
 :
 : focusNodeValidator.xqm - validates the focus nodes selected by gx:focusNode
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "expressionEvaluator.xqm",
    "extensionValidator.xqm",
    "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a context item against a focus node shape.
 :
 : @param focusNodeShape a focus node shape
 : @param contextItem an XDM item to be used as context item
 : @param contextFilePath the file path of the document containing the context item
 : @param contextDoc the document containing the context item
 : @param context a context of name value pairs
 : @return validation results
 :)
declare function f:validateFocusNodeXXX($focusNodeShape as element(), 
                                     $contextItem as item()?,
                                     $contextFilePath as xs:string,
                                     $contextDoc as document-node()?,
                                     $context as map(xs:string, item()*))
        as element()* {
    let $xpath := $focusNodeShape/@xpath
    let $foxpath := $focusNodeShape/@foxpath
    let $components :=
        let $children := $focusNodeShape/*[not(@deactivated eq 'true')]
        return (
            $children[not(self::gx:ifMediatype)],
            $children/self::gx:ifMediatype[i:matchesMediatype((@eq, @in/tokenize(.)), $contextFilePath)]
                     /*[not(@deactivated eq 'true')]   
        )
    (: let $_DEBUG := trace(string-join($components/name(), '; '), '_FOCUS_NODE_COMPONENT_NAMES: ') :)
    
    (: Subset of the constraints which are extension constraint definitions :)
    let $extensionConstraints := f:getExtensionConstraints($components)     
    (: let $_DEBUG := trace(string-join($extensionConstraints/name(), '; '), '_FOCUS_NODE_EXTENSION_NAMES: ') :)
    
    let $evaluationContext := $context?_evaluationContext
    let $exprValue :=    
        if ($xpath) then 
            i:evaluateXPath($xpath, $contextItem, $evaluationContext, true(), true())
        else if ($foxpath) then  
            f:evaluateFoxpath($foxpath, $contextItem, $evaluationContext, true())
        else error(QName((), 'SCHEMA_ERROR'), 'Missing expression')
    let $results :=
        (: for every item of the expression value :)
        for $exprValueItem in $exprValue
        for $component in $components
        (: let $_DEBUG := trace($component/name(), '_FOCUS_NODE_COMPONENT_NAME: ') :)
        return
            typeswitch($component)
            
            case $xpathShape as element(gx:xpath) return
                i:validateExpressionValue($contextFilePath, $xpathShape, $exprValueItem, $contextDoc, $context)
            case $foxpathShape as element(gx:foxpath) return
                i:validateExpressionValue($contextFilePath, $foxpathShape, $exprValueItem, $contextDoc, $context)
            case $focusNode as element(gx:focusNode) return                
                i:validateFocusNode($focusNode, $exprValueItem, $contextFilePath, $contextDoc, $context)
            case $targetSize as element(gx:targetSize) return
                i:validateTargetCount($targetSize, $exprValue, $contextFilePath, ($xpath, $foxpath)[1])
                
            case $docSimilar as element(gx:docSimilar) return                
                i:validateDocSimilar($contextFilePath, $docSimilar, $exprValueItem, $contextDoc, $context)
                
            default return 
                if ($component intersect $extensionConstraints) then
                    f:validateExtensionConstraint($contextFilePath, $component, $exprValueItem, $contextDoc, $context)
                else            
                    error(QName((), 'UNEXPECTED_SHAPE_OR_CONSTRAINT_ELEMENT'), 
                          concat('Unexpected shape or constraint element, name: ', $component/name()))
    return
        $results
};
