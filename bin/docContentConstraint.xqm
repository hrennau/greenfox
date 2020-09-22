(:
 : -------------------------------------------------------------------------
 :
 : docContentConstraint.xqm - validates a file resource against DocContent constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/doc-content";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "resourceAccess.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm",
   "linkResolution.xqm",
   "linkValidation.xqm";

import module namespace dcont="http://www.greenfox.org/ns/xquery-functions/doc-content" 
at "docContentUtil.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a DocContent constraint.
 :
 : Bla.
 :
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateDocContentConstraint($constraintElem as element(gx:docContent),
                                                $context as map(xs:string, item()*))
        as element()* {

    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    return
    
    (: Exception - no context document :)
    if (not($context?_targetInfo?doc)) then
        result:validationResult_docContent_exception($constraintElem,
            'Context resource could not be parsed', (), $context)
    else
    
    (: Normal processing :)
    let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)    
    let $options := map{'withNamespaces': $withNamespaces}    
    let $compiledNodePaths := f:compileNodePaths($constraintElem, $options, $context)
    for $constraintNode in $constraintElem/gx:node 
    let $contextNode := ($contextNode, $contextDoc)[1]
    return
        f:validateNodeContentConstraint($constraintElem, $constraintNode, $contextNode, (), (), 
            $compiledNodePaths, $options, $context)
};

declare function f:validateNodeContentConstraint($constraintElem as element(gx:docContent),
                                                 $constraintNode as element(gx:node),                                                 
                                                 $contextNode as node()?,
                                                 $contextPosition as xs:integer?,
                                                 $contextTrail as xs:string?,
                                                 $compiledNodePaths as map(xs:string, item()*),
                                                 $options as map(xs:string, item()*),
                                                 $context as map(xs:string, item()*))
        as element()* {
    let $locNP := $constraintNode/@locNP
    let $trail := string-join(($contextTrail ! concat(., '(', $contextPosition, ')'), $constraintNode/@locNP), '#')
    
    (: Find nodes :)
    let $compiledNodePath := i:datapath($locNP, $constraintElem) ! $compiledNodePaths(.)
    let $nodes := dcont:evaluateCompiledNodePath($compiledNodePath, $contextNode, $constraintNode, $options, $context)
    
    (: Check count :)
    let $results_counts := f:validateNodeContentConstraint_counts(
        $constraintElem, $constraintNode, $contextNode, $nodes, $trail, $options, $context)

    (: Check children :)
    let $results_children :=
        for $node at $pos in $nodes
        for $constraintNode in $constraintNode/gx:node 
        return
            f:validateNodeContentConstraint(
                $constraintElem, $constraintNode, $node, $pos, $trail, $compiledNodePaths, $options, $context)
            
    (: Check closed :)
    let $results_closed := f:validateNodeContentConstraint_closed(
        $constraintElem, $constraintNode, $contextNode, $nodes, $trail, $compiledNodePaths, $options, $context)
    return (
        $results_counts,
        $results_children,
        $results_closed 
    )
};

declare function f:validateNodeContentConstraint_counts(
                                                 $constraintElem as element(gx:docContent),
                                                 $constraintNode as element(gx:node),                                                 
                                                 $contextNode as node()?,
                                                 $valueNodes as node()*,
                                                 $trail as xs:string,
                                                 $options as map(xs:string, item()*),
                                                 $context as map(xs:string, item()*))
        as element()* {
    let $valueCount := count($valueNodes)
    let $countAtts := $constraintNode/(@count, @minCount, @maxCount)
    return    
        (: explicit constraints :)
        if ($countAtts) then
            for $countAtt in $countAtts
            let $ok :=
                switch ($countAtt/local-name(.))
                case 'count' return $valueCount = $countAtt
                case 'minCount' return $valueCount >= $countAtt
                case 'maxCount' return $valueCount <= $countAtt
                default return error()
            let $colour := if ($ok) then 'green' else 'red'
            return
                result:validationResult_docContent_counts(
                    $colour, $constraintElem, $countAtt, $contextNode, $valueCount, $trail, (), $context)
                
        (: implicit constraints :)                        
        else
            let $colour := if ($valueCount eq 1) then 'green' else 'red'
            return
                result:validationResult_docContent_counts(
                    $colour, $constraintElem, $constraintNode, $contextNode, $valueCount, $trail, (), $context) 
}; 

declare function f:validateNodeContentConstraint_closed(
                                                 $constraintElem as element(gx:docContent),
                                                 $constraintNode as element(gx:node),                                                 
                                                 $contextNode as node()?,
                                                 $valueNodes as node()*,
                                                 $trail as xs:string,
                                                 $compiledNodePaths as map(xs:string, item()*),
                                                 $options as map(xs:string, item()*),
                                                 $context as map(xs:string, item()*))
        as element()* {
    let $closed := $constraintNode/@closed/xs:boolean(.)
    return
    
    if (not($closed)) then () else
        
    for $currentContextNode in $valueNodes        
    let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)
    let $cnps := 
        for $locNP in $constraintNode/gx:node/@locNP
        let $cnp := $locNP ! i:datapath(., $constraintElem) ! $compiledNodePaths(.)
        where count($cnp) eq 1 and ($cnp/self::child or $cnp/self::attribute)
        return $cnp            
    let $cnpsAttribute := $cnps[self::attribute]            
    let $cnpsElement := $cnps[self::child]
    let $unexpectedElems :=$currentContextNode/*
        [f:nodeNameMatchesNodePathStep(., $cnpsElement, $withNamespaces, $constraintNode)]
    let $unexpectedAtts := $currentContextNode/@*
        [f:nodeNameMatchesNodePathStep(., $cnpsAttribute, $withNamespaces, $constraintNode)]
    let $unexpectedNodes := ($unexpectedAtts, $unexpectedElems)            
    return 
        if ($unexpectedNodes) then
            $unexpectedNodes/result:validationResult_docContent_closed('red', $constraintElem, $constraintNode, 
                $currentContextNode, ., $trail, (), $context)
        else                    
            result:validationResult_docContent_closed('green', $constraintElem, $constraintNode, 
                $currentContextNode, (), $trail, (), $context)
}; 

declare function f:compileNodePaths($constraintElem as element(gx:docContent),
                                    $options as map(xs:string, item()*),
                                    $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    map:merge(
    
        for $nodeNP in $constraintElem//@locNP
        let $location := i:datapath($nodeNP, $constraintElem)
        let $compiled := f:parseNodePath($nodeNP, $options, $context)
        return
            map:entry($location, $compiled)
    )
};        