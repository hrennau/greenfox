(:
 : -------------------------------------------------------------------------
 :
 : linkUtil.xqm - utility functions for link processing
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/greenlink";

import module namespace tt="http://www.ttools.org/xquery-functions"  
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "log.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Resolves a link XPath expression in the context of a context node.
 :
 : The expression is retrieved from the shape element, and the evaluation context
 : is retrieved from the processing context.
 :
 : @param doc document in the context of which the expression must be resolved
 : @param valueShape the value shape specifying the link constraints
 : @param context context for evaluations
 : @return the expression value
 :)
declare function f:resolveLinkExpressionXP($expr as xs:string,
                                           $contextNode as node(),
                                           $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext :=
        i:newEvaluationContext_linkContextItem($contextNode, $context)    
    let $exprValue :=
        i:evaluateXPath($expr, $contextNode, $evaluationContext, true(), true())
    return $exprValue        
};        

(:~
 : Resolves a link Foxpath expression in the context of a context URI.
 :
 : The expression is retrieved from the shape element, and the evaluation context
 : is retrieved from the processing context.
 :
 : @param doc document in the context of which the expression must be resolved
 : @param valueShape the value shape specifying the link constraints
 : @param context context for evaluations
 : @return the expression value
 :)
declare function f:resolveLinkExpressionFOX($expr as xs:string,
                                            $contextURI as xs:string,
                                            $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    return
        i:evaluateFoxpath($expr, $contextURI, $evaluationContext, true())
};        
