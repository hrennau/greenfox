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
                                   $contextItem as item()?, 
                                   $context as map(*)?,
                                   $addVariableDeclarations as xs:boolean)
        as item()* {
    let $isContextUri := not($contextItem instance of node())
    let $foxpathOptions := f:getFoxpathOptions($isContextUri)
    let $foxpathAugmented :=
        if (not($addVariableDeclarations)) then $foxpath
        else
        (:
            let $requiredBindings := map:keys($context)
            return i:finalizeQuery($foxpath, $requiredBindings)
         :)

            let $candidateBindings := map:keys($context)
            let $requiredBindings := trace(i:determineRequiredBindingsFoxpath($foxpath, $candidateBindings) , '_REQ_BINDINGS: ')
            return i:finalizeQuery($foxpath, $requiredBindings)
    (: ensure that context keys are QNames :)            
    let $context :=
        if ($context instance of map(xs:QName, item()*)) then $context
        else
            map:merge(
                for $key in map:keys($context)
                let $value := $context($key)
                let $storeKey := if ($key instance of xs:QName) then $key else QName((), $key)
                return map:entry($storeKey, $value) 
            )
    return tt:resolveFoxpath($foxpathAugmented, $foxpathOptions, $contextItem, $context)
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

(:~
 : Augments an XPath or foxpath expression by adding a prolog containing
 : (a) a namespace declaration for prefix 'gx', (b) external variable
 : bindings for the given variable names.
 :
 : @param query the expression to be augmented
 : @param contextNames the names of the external variables
 : @return the augmented expression
 :)
declare function f:finalizeQuery($query as xs:string, 
                                 $contextNames as xs:anyAtomicType*)
        as xs:string {
    let $prolog := ( 
'declare namespace gx="http://www.greenfox.org/ns/schema";',
for $contextName in $contextNames 
let $varName := 
    if ($contextName instance of xs:QName) then string-join((prefix-from-QName($contextName), local-name-from-QName($contextName)), ':')     
    else $contextName
    return concat('declare variable $', $varName, ' external;')
    ) => string-join('&#xA;')
    return concat($prolog, '&#xA;', $query)
};

(:~
 : Determines the required variable bindings, given a set of in-scope components specifying XPath and
 : foxpath expresions.
 :
 : @param potentialBindings the variable names for which a binding may be required
 : @param components components defining XPath and foxpath expressions
 : @return the actually required variable bindngs
 :)
declare function f:getRequiredBindings($potentialBindings as xs:string*, 
                                       $components as element()*)
        as xs:string* {
    for $component in $components[self::gx:xpath, self::gx:foxpath, self::gx:xsdValid]
    return (
        $component/self::gx:xpath/@expr/i:determineRequiredBindingsXPath(., $potentialBindings),
        $component/self::gx:xpath/@*[ends-with(name(), 'XPath')]/i:determineRequiredBindingsXPath(., $potentialBindings),
        $component/self::gx:xpath/@*[ends-with(name(), 'Foxpath')]/i:determineRequiredBindingsFoxpath(., $potentialBindings),
        $component/self::gx:foxpath/@expr/i:determineRequiredBindingsFoxpath(., $potentialBindings),
        $component/self::gx:foxpath/@*[ends-with(name(), 'XPath')]/i:determineRequiredBindingsXPath(., $potentialBindings),
        $component/self::gx:foxpath/@*[ends-with(name(), 'XPath')]/i:determineRequiredBindingsFoxpath(., $potentialBindings),
        $component/gx:xpath/i:determineRequiredBindingsXPath(., $potentialBindings),        
        $component/gx:foxpath/i:determineRequiredBindingsXPath(., $potentialBindings)
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
    let $_DEBUG := file:write('DEBUG_QUERY.txt', $extendedExpr)
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
    let $_DEBUG := file:write('DEBUG_QUERY.txt', $extendedExpr)
    let $tree := tt:parseFoxpath($extendedExpr)
    return (
        $tree//var[not((parent::let, parent::for))]/@localName => distinct-values() => sort()
    )[. = $candidateBindings]
};

