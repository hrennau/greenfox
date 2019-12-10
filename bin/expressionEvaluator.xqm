(:
 : -------------------------------------------------------------------------
 :
 : expressionEvaluator.xqm - functions for evaluating expressions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Evaluates an XPath expression.
 :
 : @param xpath an XPath expression
 : @param contextItem the context item
 : @param externalVariableBindings a map of variable bindings
 : @param addVariableDeclarations if true, a prolog is added to the query which declares the external variables
 : @param addContextItem if true, the context item is added to the context with key ''
 : @return the expression value
 :)
declare function f:evaluateXPath($xpath as xs:string, 
                                 $contextItem as item()?, 
                                 $context as map(*),
                                 $addVariableDeclarations as xs:boolean,
                                 $addContextItem as xs:boolean)
        as item()* {
    let $xpathUsed :=
        if (not($addVariableDeclarations)) then $xpath
        else i:finalizeQuery($xpath, map:keys($context))
    let $contextUsed :=
        if (not($addContextItem)) then $context
        else map:put($context, '', $contextItem)
    return xquery:eval($xpathUsed, $contextUsed)
};

(:~
 : Evaluates a foxpath expression.
 :
 : @param foxpath a foxpath expression
 : @param context the context item
 : @param externalVariableBindings a map of variable bindings
 : @param addVariableDeclarations if true, a prolog is added which declares the external variables
 : @return the expression value
 :)
declare function f:evaluateFoxpath($foxpath as xs:string, 
                                   $context as item()?, 
                                   $externalVariableBindings as map(*)?,
                                   $addVariableDeclarations as xs:boolean)
        as item()* {
    let $isContextUri := not($context instance of node())
    (: let $_DEBUG := trace($externalVariableBindings, '§§§§§§§§§§§ E_V_B: ') :)
    let $foxpathOptions := f:getFoxpathOptions($isContextUri)
    let $foxpathAugmented :=
        if (not($addVariableDeclarations)) then $foxpath
        else
            let $requiredBindings := map:keys($externalVariableBindings)
            return i:finalizeQuery($foxpath, $requiredBindings)
    return tt:resolveFoxpath($foxpathAugmented, $foxpathOptions, $context, $externalVariableBindings)
};

(:~
 : Evaluates a foxpath expression.
 :
 : @param foxpath a foxpath expression
 : @param context the context item
 : @return the expression value
 :)
declare function f:evaluateFoxpath($foxpath as xs:string, $context as item()?)
        as item()* {
    f:evaluateFoxpath($foxpath, $context, (), false())
};

declare function f:parseFoxpath($foxpath as xs:string)
        as item()* {
    let $foxpathOptions := f:getFoxpathOptions(true()) 
    return tt:parseFoxpath($foxpath, $foxpathOptions)
};

declare function f:getFoxpathOptions($isContextUri as xs:boolean) 
        as map(*) {
    map{    
        'IS_CONTEXT_URI': $isContextUri,
        'FOXSTEP_SEPERATOR': '\',
        'NODESTEP_SEPERATOR': '/'
    }        
};        
