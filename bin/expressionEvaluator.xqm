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
    "foxpathUtil.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Evaluates an XPath expression.
 :
 : If $addVariableDeclarations is true, the expression is augmented by
 : inserting a prolog with variable declarations.
 :
 : If $addContextItem is true, the context item is added to the evaluation
 : context.
 :
 : @param xpath an XPath expression
 : @param contextItem the context item
 : @param evaluationContext the evaluation context
 : @param addVariableDeclarations if true, a prolog is added to the query which declares the external variables
 : @param addContextItem if true, the context item is added to the context with key ''
 : @return the expression value
 :)
declare function f:evaluateXPath($xpath as xs:string, 
                                 $contextItem as item()?, 
                                 $evaluationContext as map(xs:QName, item()*),
                                 $addVariableDeclarations as xs:boolean,
                                 $addContextItem as xs:boolean)
        as item()* {
    let $xpathEffective :=
        if (not($addVariableDeclarations)) then $xpath
        else i:finalizeQuery($xpath, map:keys($evaluationContext))
    let $evaluationContextEffective :=
        if (not($addContextItem)) then $evaluationContext
        else map:put($evaluationContext, '', $contextItem)
    return xquery:eval($xpathEffective, $evaluationContextEffective)
};

declare function f:evaluateSimpleXPath($xpath as xs:string, 
                                       $contextItem as item()?)
        as item()* {
    xquery:eval($xpath, map{'': $contextItem})        
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
    let $foxpathOptions := i:getFoxpathOptions($isContextUri)
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
    let $foxpathOptions := i:getFoxpathOptions(true()) 
    return tt:parseFoxpath($foxpath, $foxpathOptions)
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
 : Constructs a filter-map expression, which optionally filters the lines of a lines
 : document and optionally maps them to a value. 
 :
 : A lines document has a <lines> root and one <line> child per text line.
 :
 : The expression is specified by a map with the following entries:
 : ?exprKind - must be 'filterMapLP' (mandatory)
 : ?filterLP - an XPath expression used to filter the lines (optional)
 : ?mapLP - an XPath expressioon used to map a line to a value (optional)
 : Both expressions are to be evaluated in the context of a single line.
 :
 : If ?filterLP is not specified, the expression will map all lines.
 : If ?mapLP is not specified, the expression will return selected lines without changes
 : If none of the expressions is specified, the expression will return all lines without changes
 :
 : @param filterMapLP a map describing a filterMap expression
 : @return an XPath expression which captures the filtering and mapping behaviour as specified
 :)
declare function f:constructFilterMapExpr($filterMapLP as map(xs:string, xs:string))
        as xs:string {

    let $expr :=    
        'trace(' ||
        '/lines/line' || ($filterMapLP?filterLP ! concat('[', ., ']')) || 
        $filterMapLP?mapLP ! concat('/(', ., ')') ||
        ', "_EXPR_VALUE: ")'

    let $_DEBUG := trace($expr, '_FILTER_MAP_EXPR: ')
    return $expr
};        

