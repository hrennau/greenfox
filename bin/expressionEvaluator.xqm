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
 : @param context the evaluation context
 : @param addVariableDeclarations if true, a prolog is added to the query which declares the external variables
 : @param addContextItem if true, the context item is added to the context with key ''
 : @return the expression value
 :)
declare function f:evaluateXPath($xpath as xs:string, 
                                 $contextItem as item()?, 
                                 $context as map(xs:QName, item()*),
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
 : @param contextItem the context item
 : @param context the evaluation context
 : @param addVariableDeclarations if true, a prolog is added to the query which declares the external variables
 : @return the expression value
 :)
declare function f:evaluateFoxpath($foxpath as xs:string, 
                                   $contextItem as item()?, 
                                   $context as map(xs:QName, item()*),
                                   $addVariableDeclarations as xs:boolean)
        as item()* {
    let $isContextUri := not($contextItem instance of node())
    let $foxpathOptions := f:getFoxpathOptions($isContextUri)
    let $foxpathAugmented :=
        if (not($addVariableDeclarations)) then $foxpath
        else
            let $candidateBindings := map:keys($context) ! ( 
                if (. instance of xs:string or . instance of xs:untypedAtomic) then . 
                else local-name-from-QName(.))
            let $requiredBindings := i:determineRequiredBindingsFoxpath($foxpath, $candidateBindings)
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
declare function f:evaluateFoxpath($foxpath as xs:string, $contextItem as item()?)
        as item()* {
    f:evaluateFoxpath($foxpath, $contextItem, (), false())
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
    (:
    let $_DEBUG := trace($components/name(), 'COMP_NAMES: ')        
    let $_DEBUG := trace($potentialBindings, '_POTENTIAL_BINDINGS: ')
     :)    
    for $component in $components[self::gx:xpath, self::gx:foxpath, self::gx:xsdValid, self::gx:constraintComponent]
    let $potentialBindings_params := $component/self::gx:constraintComponent/gx:param/@name/string()
    let $potentialBindings := ($potentialBindings, $potentialBindings_params)
    let $reqBindings := (
        $component/self::gx:xsdValid/@*[ends-with(name(), 'Foxpath')]/i:determineRequiredBindingsFoxpath(., $potentialBindings),    
        $component/self::gx:xpath/@expr/i:determineRequiredBindingsXPath(., $potentialBindings),
        $component/self::gx:xpath/@*[ends-with(name(), 'XPath')]/i:determineRequiredBindingsXPath(., $potentialBindings),
        $component/self::gx:xpath/@*[ends-with(name(), 'Foxpath')]/i:determineRequiredBindingsFoxpath(., $potentialBindings),
        $component/self::gx:foxpath/@expr/i:determineRequiredBindingsFoxpath(., $potentialBindings),
        $component/self::gx:foxpath/@*[ends-with(name(), 'XPath')]/i:determineRequiredBindingsXPath(., $potentialBindings),
        $component/self::gx:foxpath/@*[ends-with(name(), 'XPath')]/i:determineRequiredBindingsFoxpath(., $potentialBindings),
        $component/gx:xpathExpr/i:determineRequiredBindingsXPath(., $potentialBindings),        
        $component/gx:foxpathExpr/i:determineRequiredBindingsXPath(., $potentialBindings),
        $component/self::gx:xpath/(gx:xpath, gx:foxpath)/f:getRequiredBindings($potentialBindings, .),
        $component/self::gx:foxpath/(gx:xpath, gx:foxpath)/f:getRequiredBindings($potentialBindings, .)
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
    let $tree := f:parseFoxpath($extendedExpr)
    let $_CHECK := if ($tree/self::errors) then error() else ()
    return (
        $tree//var[not((parent::let, parent::for))]/@localName => distinct-values() => sort()
    )[. = $candidateBindings]
};

(:~
 : Updates the context so that it contains an evulation context as required for
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
                                            $params as element(gx:param)*)
        as map(xs:string, item()*) {
    let $doc := ($xdoc, $jdoc, $csvdoc)[1]        
    let $context := 
        let $evaluationContext :=
            map:merge((
                $context?_evaluationContext,
                if (not($reqBindings = 'doc')) then () else map:entry(QName('', 'doc'), $doc),
                if (not($reqBindings = 'xdoc')) then () else map:entry(QName('', 'xdoc'), $xdoc),
                if (not($reqBindings = 'jdoc')) then () else map:entry(QName('', 'jdoc'), $jdoc),
                if (not($reqBindings = 'csvdoc')) then () else map:entry(QName('', 'csvdoc'), $csvdoc),
                if (not($reqBindings = 'this')) then () else map:entry(QName('', 'this'), $filePath),
                if (not($reqBindings = 'filePath')) then () else map:entry(QName('', 'filePath'), $filePath),
                if (not($reqBindings = 'fileName')) then () else map:entry(QName('', 'fileName'), replace($filePath, '.*[\\/]', '')),
                if (not($reqBindings = 'domain')) then () else map:entry(QName('', 'domain'), $context?_domainPath),
                (: _TO_DO_ Support datatypes (xs:integer, ...) :)
                $params ! map:entry(QName('', @name), string(.))                
            ))    
        return map:put($context, '_evaluationContext', $evaluationContext)
    return $context        
};        
                                            

