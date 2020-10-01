(:
 : -------------------------------------------------------------------------
 :
 : docTreeConstraint.xqm - validates a file resource against DocTree constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/doc-tree";
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

import module namespace dcont="http://www.greenfox.org/ns/xquery-functions/doc-tree" 
at "docTreeUtil.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a DocTree constraint.
 :
 : Bla.
 :
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateDocTreeConstraint($constraintElem as element(gx:docTree),
                                             $context as map(xs:string, item()*))
        as element()* {

    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    let $useContextNode := ($contextNode, $contextDoc)[1]
    return
    
    (: Exception - no context document :)
    if (not($context?_targetInfo?doc)) then
        result:validationResult_docTree_exception($constraintElem,
            'Context resource could not be parsed', (), $context)
    else
    
    (: Normal processing :)
    let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)    
    let $options := map{'withNamespaces': $withNamespaces}    
    let $compiledNodePaths := f:compileNodePaths($constraintElem, $options, $context)
    for $constraintNode in $constraintElem/gx:node 
    return
        f:validateNodeContentConstraint($constraintElem, $constraintNode, $useContextNode, (), (), 
            $compiledNodePaths, $options, $context)
};

(:~
 : Validates a file resource or a focus node from a file resource against
 : a DocTree constraint group.
 :
 : @param constraintElem element representing the constraint group
 : @param constraintNode a node representing a particular constraint
 : @param contextNode ?
 : @param contextPosition ?
 : @param contextTrail ?
 : @param compiledNodePaths ?
 : @param options evaluation options
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateNodeContentConstraint($constraintElem as element(gx:docTree),
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
    let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)
    
    (: Find nodes :)
    let $compiledNodePath := i:datapath($locNP, $constraintElem) ! $compiledNodePaths(.)
    (:
    let $_DEBUG := trace($locNP,'+++ LOC_NP: ')
    let $_DEBUG := trace($compiledNodePath, '+++ COMPILED_NODE_PATH: ')
     :)
    let $nodes := dcont:evaluateCompiledNodePath($compiledNodePath, $contextNode, $constraintNode, $options, $context)
    (: let $_DEBUG := trace($compiledNodePaths, '+++ COMPILED_NODE_PATHS: '):)
    
    (: Check count :)
    let $results_counts := f:validateNodeContentConstraint_counts(
        $constraintElem, $constraintNode, $contextNode, $nodes, $trail, $options, $context)
        
    (: Check counts of shortcut attributes 
       - for all attributes without '?' it is checked if the attribute exists 
         and a count result (red or green) is generated :)
    let $results_counts_shortcut_atts := 
        f:validateNodeContentConstraint_shortcutAttCounts($constraintElem, $constraintNode, $nodes, $trail, $options, $context)

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
        $results_counts_shortcut_atts,
        $results_children,
        $results_closed 
    )
};

(:~
 : Checks the instance nodes corresponding to a model node against the cardinality
 : constraints of the model node. If the model node has no cardinality constraints,
 : it has an implicit constraint 'count=1'.
 :
 : @param constraintElem the constraint element declaring the DocTree constraints
 : @param constraintNode a model node
 : @param contextNode the current context node used as a context when determing the instance nodes
 : @param valueNodes the instance nodes corresponding to the model node
 : @param trail a textual representation of the model path leading to this model node
 : @param options options controlling the evaluation
 : @param context the processing context
 : @return validation results :)
declare function f:validateNodeContentConstraint_counts(
                                                 $constraintElem as element(gx:docTree),
                                                 $constraintNode as element(gx:node),                                                 
                                                 $contextNode as node()?,
                                                 $valueNodes as node()*,
                                                 $trail as xs:string,
                                                 $options as map(xs:string, item()*),
                                                 $context as map(xs:string, item()*))
        as element()* {
    let $count := count($valueNodes)    
    let $att := $constraintNode/@count return    
        if ($att) then
            let $ok := $count eq $att/xs:integer(.) 
            let $colour := if ($ok) then 'green' else 'red'
            return
                result:validationResult_docTree_counts(
                    $colour, $constraintElem, $att, 'DocTreeCount', (), 
                    $contextNode, $count, $trail, (), $context)
        else (                
            let $att := $constraintNode/@minCount return
            (: if (not($att)) then () else :)
            let $minCount := ($att/xs:integer(.), 1)[1]
            let $ok := $count ge $minCount 
            let $colour := if ($ok) then 'green' else 'red'
            let $useConstraintNode := ($att, $constraintNode)[1]
            return
                result:validationResult_docTree_counts(
                    $colour, $constraintElem, $useConstraintNode, 'DocTreeMinCount', (), 
                    $contextNode, $count, $trail, (), $context)
            ,
            let $att := $constraintNode/@maxCount return
            (: if (not($att)) then () else :)
            if ($att eq 'unbounded') then () else
            let $maxCount := ($att/xs:integer(.), 1)[1]
            let $ok := $count le $maxCount 
            let $colour := if ($ok) then 'green' else 'red'
            let $useConstraintNode := ($att, $constraintNode)[1]
            return
                result:validationResult_docTree_counts(
                    $colour, $constraintElem, $useConstraintNode, 'DocTreeMaxCount', (), 
                    $contextNode, $count, $trail, (), $context)
        )                        
(:   
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
                result:validationResult_docTree_counts(
                    $colour, $constraintElem, $countAtt, (), $contextNode, $valueCount, $trail, (), $context)
                
        (: implicit constraints :)                        
        else
            let $colour := if ($valueCount eq 1) then 'green' else 'red'
            return
                result:validationResult_docTree_counts(
                    $colour, $constraintElem, $constraintNode, (), $contextNode, $valueCount, $trail, (), $context)
:)                    
}; 

(:~
 : Checks the instance nodes corresponding to a model node against the presence of
 : mandatory attributes represented by shortcut notation (@atts).
 :
 : @param constraintElem the constraint element declaring the DocTree constraints
 : @param constraintNode a model node
 : @param valueNodes the instance nodes corresponding to the model node
 : @param trail a textual representation of the model path leading to this model node
 : @param options options controlling the evaluation
 : @param context the processing context
 : @return validation results :)
declare function f:validateNodeContentConstraint_shortcutAttCounts(
                                                 $constraintElem as element(),
                                                 $constraintNode as element(gx:node),
                                                 $valueNodes as node()*,
                                                 $trail as xs:string,
                                                 $options as map(xs:string, item()*),
                                                 $context as map(xs:string, item()*))                                                 
        as element()* {
    let $attsConstraintNode := $constraintNode/@atts
    let $shortcutAttNames := $attsConstraintNode/tokenize(.)[not(ends-with(., '?'))]    
    return
        if (empty($shortcutAttNames)) then () else
        
        let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)
        let $fn_getAttName :=
            if ($withNamespaces) then
                function($lexName) {
                    if (contains($lexName, ':')) then resolve-QName($lexName, $constraintNode) 
                    else QName((), $lexName)                
                }
            else function($lexName) {replace($lexName, '^.+:', '')}
                
        let $fn_getAttNode :=
            if ($withNamespaces) then 
                function($parent, $attQName) {$parent/@*[node-name(.) eq $attQName]}
            else 
                function($parent, $attLname) {$parent/@*[local-name(.) eq $attLname]}

        for $shortcutAttName in $shortcutAttNames       
        let $attName := $fn_getAttName($shortcutAttName)
        for $valueNode at $pos in $valueNodes
        let $att := $fn_getAttNode($valueNode, $attName)
        let $colour := if ($att) then 'green' else 'red'
        let $newContextNode := $valueNode
        let $newTrail := $trail || '(' || $pos || ')' || '#@' || $attName
        return
            result:validationResult_docTree_counts(
                $colour, $constraintElem, $attsConstraintNode, (), string($attName), $newContextNode, count($att), $newTrail, (), $context)

(:            
        if ($withNamespaces) then
            for $shortcutAttName in $shortcutAttNames       
            let $attQName :=
                if (contains($shortcutAttName, ':')) then resolve-QName($shortcutAttName, $constraintNode)
                else QName((), $shortcutAttName)
            for $node at $pos in $nodes
            let $att := $node/@*[node-name(.) eq $attQName]
            let $colour := if ($att) then 'green' else 'red'
            let $newContextNode := $node
            let $newTrail := $trail || '(' || $pos || ')' || '#@' || $attLname
            return
                result:validationResult_docTree_counts(
                    $colour, $constraintElem, $attsConstraintNode, string($attQName), $newContextNode, count($att), $newTrail, (), $context)
        else
            for $shortcutAttName in $shortcutAttNames       
            let $attLname := trace($shortcutAttName ! replace(., '^.+:', '') , '+++ ATT_LNAME: ')
            for $node at $pos in $nodes
            let $att := $node/@*[local-name(.) eq $attLname]
            let $colour := if ($att) then 'green' else 'red'
            let $newContextNode := $node
            let $newTrail := $trail || '(' || $pos || ')' || '#@' || $attLname
            return
                (: Note that $node is passed on as context node :)
                result:validationResult_docTree_counts(
                    $colour, $constraintElem, $attsConstraintNode, $attLname, $newContextNode, count($att), $newTrail, (), $context)
:)                    
};

(:~
 : Checks the instance nodes corresponding to a model node against a DocTreeClosed
 : constraint. 
 :
 : @param constraintElem the constraint element declaring the DocTree constraints
 : @param constraintNode a model node
 : @param contextNode the current context node used as a context when determing the instance nodes
 : @param valueNodes the instance nodes corresponding to the model node
 : @param trail a textual representation of the model path leading to this model node
 : @param options options controlling the evaluation
 : @param context the processing context
 : @return validation results :)
declare function f:validateNodeContentConstraint_closed(
                                                 $constraintElem as element(gx:docTree),
                                                 $constraintNode as element(gx:node),                                                 
                                                 $contextNode as node()?,
                                                 $valueNodes as node()*,
                                                 $trail as xs:string,
                                                 $compiledNodePaths as map(xs:string, item()*),
                                                 $options as map(xs:string, item()*),
                                                 $context as map(xs:string, item()*))
        as element()* {
    (: let $_DEBUG := trace($compiledNodePaths, '___CPN: ') :)        
    let $closed := $constraintNode/@closed/xs:boolean(.)
    return if (not($closed)) then () else

    let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)
    let $shortcutAttNames := $constraintNode/@atts/tokenize(.) ! replace(., '\?$', '') 
    let $furtherAttLocalNames :=
        if ($withNamespaces) then () else $shortcutAttNames ! replace(., '^.+:', '')
    let $furtherAttQNames :=
        if (not($withNamespaces)) then () else (
            $shortcutAttNames[contains(., ':')] ! resolve-QName(., $constraintNode),
            $shortcutAttNames[not(contains(., ':'))] ! QName((), .))

    for $currentContextNode in $valueNodes        
    
    (: Expected attributes and child elements are determined by examination 
         of the paths on the child model nodes; considered:
         all paths either consisting of or beginning with an attribute or child step
     :)
    let $cnpsAttributeOrChild := 
        for $locNP in $constraintNode/gx:node/@locNP
        let $cnp := $locNP ! i:datapath(., $constraintElem) ! $compiledNodePaths(.)
        where count($cnp) eq 1 and ($cnp/self::child or $cnp/self::attribute)
        return $cnp            
    let $cnpsAttribute := $cnpsAttributeOrChild[self::attribute]            
    let $cnpsElement := $cnpsAttributeOrChild[self::child]
        
    (: Unexpected elements = child elements of instance node which do not match a child path :)
    let $unexpectedElems :=$currentContextNode/*
        [not(f:nodeNameMatchesNodePathStep(., $cnpsElement, (), (), $withNamespaces, $constraintNode))]
        
    (: Unexpected attributes = attributes of instance node which do not match a child path :) 
    
    let $unexpectedAtts := $currentContextNode/@*
        [not(f:nodeNameMatchesNodePathStep(., $cnpsAttribute, $furtherAttLocalNames, $furtherAttQNames, $withNamespaces, $constraintNode))]
        
    let $unexpectedNodes := ($unexpectedAtts, $unexpectedElems)
    
    let $_DEBUG :=
        if (not($currentContextNode/local-name(.) eq 'geoxxx')) then () else (
            let $_DEBUG := trace($currentContextNode/local-name(.), '___LOCAL_NAME: ')
            let $_DEBUG := trace($currentContextNode/@*/name() => string-join(', '), '___ATT_NAMES: ')
            let $_DEBUG := trace($furtherAttLocalNames => string-join(', '), '___FURTHER_ATT_LOCAL_NAMES: ')
            let $_DEBUG := trace($unexpectedAtts, '___UNEXPECTED_ATTS: ')
            let $_DEBUG := trace($cnpsAttribute, '___CNPS_ATTRIBUTE: ')
            return ()
        )
    
    
    return 
        if ($unexpectedNodes) then
            $unexpectedNodes/result:validationResult_docTree_closed('red', $constraintElem, $constraintNode, 
                $currentContextNode, ., $trail, (), $context)
        else                    
            result:validationResult_docTree_closed('green', $constraintElem, $constraintNode, 
                $currentContextNode, (), $trail, (), $context)
}; 

declare function f:compileNodePaths($constraintElem as element(gx:docTree),
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