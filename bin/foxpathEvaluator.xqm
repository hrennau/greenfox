(:
 : -------------------------------------------------------------------------
 :
 : foxpathEvaluator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Evaluates a foxpath expression.
 :
 : @param foxpath a foxpath expression
 : @param context the context item
 : @return the expression value
 :)
declare function f:evaluateFoxpath($foxpath as xs:string, $context as item()?)
        as item()* {
    let $isContextUri := not($context instance of node())
    let $foxpathOptions := 
        map{    
            'IS_CONTEXT_URI': $isContextUri,
            'FOXSTEP_SEPERATOR': '\',
            'NODESTEP_SEPERATOR': '/'
        }
    let $foxpathContext := map{}
    return tt:resolveFoxpath($foxpath, $foxpathOptions, $context, $foxpathContext)
};

declare function f:parseFoxpath($foxpath as xs:string)
        as item()* {
    let $foxpathOptions := 
        map{    
            'IS_CONTEXT_URI': true(),
            'FOXSTEP_SEPERATOR': '\',
            'NODESTEP_SEPERATOR': '/'
        }
    return tt:parseFoxpath($foxpath, $foxpathOptions)
};
