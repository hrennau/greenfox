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
declare function f:validateFocusNode($focusNodeShape as element(), 
                                     $contextItem as item()?,
                                     $contextFilePath as xs:string,
                                     $contextDoc as document-node()?,
                                     $context as map(xs:string, item()*))
        as element()* {
    let $xpath := $focusNodeShape/@xpath
    let $foxpath := $focusNodeShape/@foxpath
    
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
        return (
            (: for every XPath shape :)
            for $xpathShape in $focusNodeShape/gx:xpath
            return
                i:validateExpressionValue($xpathShape, $exprValueItem, $contextFilePath, $contextDoc, $context)
            ,                
            (: for every Foxpath shape :)
            for $foxpathShape in $focusNodeShape/gx:foxpath
            return
                i:validateExpressionValue($foxpathShape, $exprValueItem, $contextFilePath, $contextDoc, $context)
            ,
            (: for every child focus shape :)
            for $focus in $focusNodeShape/gx:focusNode
            return
                i:validateFocusNode($focus, $exprValueItem, $contextFilePath, $contextDoc, $context)
        )
    return
        $results
};
