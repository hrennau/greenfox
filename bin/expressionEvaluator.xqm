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
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

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
