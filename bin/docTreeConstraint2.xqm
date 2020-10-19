(:
 : -------------------------------------------------------------------------
 :
 : docTreeConstraint.xqm - validates a file resource against DocTree constraints
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/doc-tree2";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "resourceAccess.xqm";

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkDefinition.xqm",
   "linkHyperdoc.xqm",
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
declare function f:validateDocTreeConstraint($constraintElem as element(),
                                             $context as map(xs:string, item()*))
        as element()* {

    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $contextDoc := $targetInfo?doc
    let $contextNode := $targetInfo?focusNode
    return
    
    (: Exception - no context document :)
    if ($constraintElem/self::gx:docTree and not($context?_targetInfo?doc)) then
        result:validationResult_docTree_exception($constraintElem,
            'Context resource could not be parsed', (), $context)
    else
    
    (: Normal processing :)
    let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)    
    let $options := map{'withNamespaces': $withNamespaces}    
    let $compiledNodePaths := f:compileNodePaths($constraintElem, $options, $context)
    return
    
    (: Hyperdoc validation :)
    if ($constraintElem/self::gx:hyperdocTree) then
        let $hyperdocAndLinkResults := link:getLinkHyperdoc($constraintElem, $context)
        let $hyperdoc := $hyperdocAndLinkResults?hyperdoc
        let $linkResults := $hyperdocAndLinkResults?linkValidationResults
        return (
            $linkResults,
            
            if (not($hyperdoc)) then
                result:validationResult_docTree_exception($constraintElem,
                    'Hyperdoc could not be created', (), $context)            
            else
                for $constraintNode in $constraintElem/gx:node
                return
                    f:validateDocTree_node($constraintElem, $constraintNode, $hyperdoc, (), (), 
                        $compiledNodePaths, $options, $context)
    )
    (: Target resource doc validation :)    
    else
        let $useContextNode := ($contextNode, $contextDoc)[1]    
        for $constraintNode in $constraintElem/gx:node 
        
        (: Validation returns a map containing results (and further information of intermediate use) :)
        let $results :=
            f:validateDocTree_node($constraintElem, $constraintNode, $useContextNode, (), (), 
                $compiledNodePaths, $options, $context)
        (: Extract all results :)                
        for $key in map:keys($results)
        where starts-with($key, 'results_')
        return $results($key)
};

declare function f:validateDocTree_particle($constraintElem as element(),
                                            $modelParticle as element(),                                                 
                                            $contextNode as node()?,
                                            $contextPosition as xs:integer?,
                                            $contextTrail as xs:string?,
                                            $compiledNodePaths as map(xs:string, item()*),
                                            $options as map(xs:string, item()*),
                                            $context as map(xs:string, item()*))
        as map(xs:string, item()*)* {
    typeswitch($modelParticle)
    case element(gx:node) return 
        f:validateDocTree_node($constraintElem, $modelParticle, $contextNode, $contextPosition, 
            $contextTrail, $compiledNodePaths, $options, $context)
    case element(gx:oneOf) return 
        f:validateDocTree_oneOf($constraintElem, $modelParticle, $contextNode, $contextPosition, 
            $contextTrail, $compiledNodePaths, $options, $context)
    case element(gx:nodeGroup) return 
        f:validateDocTree_nodeGroup($constraintElem, $modelParticle, $contextNode, $contextPosition, 
            $contextTrail, $compiledNodePaths, $options, $context)
    default return error()            
};

(:~
 : Validates a oneOf model particle.
 :)
declare function f:validateDocTree_oneOf($constraintElem as element(),
                                         $modelParticle as element(),                                                 
                                         $contextNode as node()?,
                                         $contextPosition as xs:integer?,
                                         $contextTrail as xs:string?,
                                         $compiledNodePaths as map(xs:string, item()*),
                                         $options as map(xs:string, item()*),
                                         $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $trail := string-join(($contextTrail ! concat(., '(', $contextPosition, ')'), 'oneOf'), '#')
    
    let $datapathParticle := i:datapath($modelParticle, $constraintElem)
    let $nodeIdParticle := generate-id($modelParticle)
    
    (: Write an array of arrays, with one member array per oneOf branch :) 
    let $branchResults := array{  
            for $branch at $pos in $modelParticle/* 
            return array{
                f:validateDocTree_particle(
                    $constraintElem, $branch, $contextNode, $contextPosition, 
                    $contextTrail, $compiledNodePaths, $options, $context)
            }
    }
    (: Indexes of "green branches", those without red count results :)
    let $indexGreenBranch :=
        for $pos in 1 to array:size($branchResults)
        let $member := $branchResults($pos)
        let $memberMaps := array:flatten($member)
        return
            if (empty($memberMaps?results_count/self::gx:red)) then $pos
            else ()

    (: Results from green branch :)
    let $results_greenBranchRaw := 
        if (count($indexGreenBranch) eq 1) then
            array:flatten($branchResults($indexGreenBranch))?*
        else ()
    let $results_greenBranch := $results_greenBranchRaw[. instance of node()]
    let $results_greenBranchMaps := $results_greenBranchRaw[. instance of map(*)]
    
    (: The choice result is green if exactly one branch is green :)            
    let $results_oneOf :=
        let $colour := if (count($indexGreenBranch) eq 1) then 'green' else 'red'
        return
            result:validationResult_docTree_oneOf(
                $colour, $constraintElem, $modelParticle, $contextNode,
                $indexGreenBranch, $trail, (), $context)   

    (: OneOfInfo: maps the oneOf node ID to the index of the green branch :)
    let $oneOfInfo := map:merge((
        map:entry($nodeIdParticle, $indexGreenBranch[count(.) eq 1]),
        $results_greenBranchMaps))
    let $results :=
        map{'info_oneOf': $oneOfInfo,
            'results_choice': $results_oneOf,
            'results_greenBranch': $results_greenBranch
        }
    return $results
};

declare function f:validateDocTree_nodeGroup($constraintElem as element(),
                                             $modelParticle as element(),                                                 
                                             $contextNode as node()?,
                                             $contextPosition as xs:integer?,
                                             $contextTrail as xs:string?,
                                             $compiledNodePaths as map(xs:string, item()*),
                                             $options as map(xs:string, item()*),
                                             $context as map(xs:string, item()*))
        as map(xs:string, item()*)* {

    for $child at $pos in $modelParticle/* 
    return
        f:validateDocTree_particle(
            $constraintElem, $child, $contextNode, $contextPosition, 
            $contextTrail, $compiledNodePaths, $options, $context)
};

(:~
 : Validates resource contents against a model node. Returns a map with
 : three fields:
 : - results_counts - validation results obtained from count constraints
 : - results_closed - validation results of a closed constraint
 : - results_children - validation results obtained from the validation of 
 :   child model nodes.
 :
 : @param constraintElem element representing the DocTree constraints
 : @param constraintNode a model node representing an instance node
 : @param contextNode ?
 : @param contextPosition ?
 : @param contextTrail ?
 : @param compiledNodePaths ?
 : @param options evaluation options
 : @param context the processing context
 : @return a map with three fields, results_count the validation results from
 :   count constraints, results_closed the validation results from a DocTreeClosed
 :   constraint, results_children the validation results from child validation
 :)
declare function f:validateDocTree_node($constraintElem as element(),
                                        $constraintNode as element(gx:node),                                                 
                                        $contextNode as node()?,
                                        $contextPosition as xs:integer?,
                                        $contextTrail as xs:string?,
                                        $compiledNodePaths as map(xs:string, item()*),
                                        $options as map(xs:string, item()*),
                                        $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $locNP := $constraintNode/@locNP
    (: New context trail is previous context trail with current @locNP appended :)
    let $trail := string-join(($contextTrail ! concat(., '(', $contextPosition, ')'), $constraintNode/@locNP), '#')
    (: Switch controling whether to consider namespaces :)
    let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)
    
    (: Find instance nodes :)
    let $compiledNodePath := i:datapath($locNP, $constraintElem) ! $compiledNodePaths(.)
    let $nodes := dcont:evaluateCompiledNodePath($compiledNodePath, $contextNode, $constraintNode, $options, $context)
    
    (: Check count :)
    let $results_counts := f:validateNodeContentConstraint_counts(
        $constraintElem, $constraintNode, $contextNode, $nodes, $trail, $options, $context)
        
    (: Check counts of shortcut attributes 
       - for all attributes without '?' it is checked if the attribute exists 
         and a count result (red or green) is generated :)
    let $results_counts_shortcut_atts := 
        f:validateNodeContentConstraint_shortcutAttCounts($constraintElem, $constraintNode, $nodes, $trail, $options, $context)

    (: Validate all instances of the node model :)  
    let $instance_results :=
    
        for $node at $pos in $nodes
    
        (: Check children :)
        let $resultmaps_children :=
            for $constraintNode in $constraintNode/* 
            return
                f:validateDocTree_particle(
                    $constraintElem, $constraintNode, $node, $pos, $trail, $compiledNodePaths, $options, $context)
     
        (: Validation results obtained from validation of child model nodes :)
        let $results_children :=
            for $resultmap in $resultmaps_children
            for $key in map:keys($resultmap)
            where starts-with($key, 'results_')
            return $resultmap($key)
        
        (: Information about relevant OneOf branches (required for validation of DocTreeClosed) :)
        let $info_oneOf := map:merge($resultmaps_children?info_oneOf)
     
        (: Flag - any OneOf error encountered when validating child model nodes? :)
        let $withOneOfError := exists($results_children/self::gx:red[@constraintComp eq 'DocTreeOneOf'])
     
        (: Check closed :)
        let $results_closed := 
            if (not($constraintNode/@closed/xs:boolean(.))) then ()
            else if ($withOneOfError) then
                result:validationResult_docTree_closed_exception(
                    $constraintElem, $constraintNode, 
                    "DocTreeClosed check canceled because of DocTreeOneOf error in content", 
                    (), (), $context) 
            else
                f:validateNodeContentConstraint_closed(
                    $constraintElem, $constraintNode, $contextNode, $node, $trail, 
                    $compiledNodePaths, $info_oneOf, $options, $context)
        
        (: Complete validation results :)        
        let $result :=
            map{
                'results_children': $results_children,
                'results_closed': $results_closed
            }
        return
            $result
        
    let $overallResult :=
        map{
            'results_count': ($results_counts, $results_counts_shortcut_atts),
            'results_children': $instance_results?results_children,
            'results_closed': $instance_results?results_closed
        }
    return
        $overallResult
};

(: Returns the content model of a model node. The content model consists of two lists,
   a list of attribute descriptors and a list of element descriptors. The descriptors
   are node path step elements leading to an attribute or an element. The description
   of the attribute or element is provided by that element.
   
   Expected attributes and child elements are determined by examination of the paths 
   on the child model nodes; considered: all paths either consisting of or beginning 
   with an attribute or child step.
   
   @param constraintElem the constraint element declaring the DocTree constraints
   @param modelNode the doctree model of a tree node
   @param infoOneOf a map associating the node IDs os oneOf model particles with 
     the index of the valid branch (1, 2, ...)
   @param compiledNodePaths a map associating the location path of node path expressions
     with the compiled path elements
   @return a map with two fields, 'atts' and 'elems' containing the descriptors of
     content attributes and elements
 :)
declare function f:getContentModel($constraintElem as element(),
                                   $modelParticle as element(gx:node),
                                   $infoOneOf as map(xs:string, item()*),
                                   $compiledNodePaths as map(xs:string, item()*))
        as map(xs:string, item()*) {
    let $step1AttributeOrChild := $modelParticle/*/f:getContentModelRC($constraintElem, ., $infoOneOf, $compiledNodePaths)
    let $step1Attribute := $step1AttributeOrChild[self::attribute]            
    let $step1Element := $step1AttributeOrChild[self::child]
    return
        map{
            'atts': $step1Attribute,
            'elems': $step1Element
        }
};

declare function f:getContentModelRC($constraintElem as element(),
                                     $modelParticle as element(),
                                     $infoOneOf as map(xs:string, item()*),
                                     $compiledNodePaths as map(xs:string, item()*))
        as element()* {
    let $nodeIdModelParticle := generate-id($modelParticle)
    return
    
    typeswitch($modelParticle)
    case element(gx:node) return
        let $locNP := $modelParticle/@locNP
        let $cnp := $locNP ! i:datapath(., $constraintElem) ! $compiledNodePaths(.)
        where count($cnp) ge 1 and ($cnp[1]/self::child or $cnp[1]/self::attribute)
        return $cnp[1]  
    case element(gx:nodeGroup) return
        for $child in $modelParticle/* return
            f:getContentModelRC($constraintElem, $child, $infoOneOf, $compiledNodePaths)
    case element(gx:oneOf) return
        let $indexGreenBranch := $infoOneOf($nodeIdModelParticle)
        return
            if (count($indexGreenBranch) ne 1) then
            (:
                let $_DEBUG := trace($modelParticle, '+++ ONE_OF_GROUP: ')
                return
             :)                
                    error(QName((), 'SYSTEM_ERROR'), 
                        concat('Not exactly one green branch of oneOf; ',
                           'particle node id: ', $nodeIdModelParticle,
                           '; ', count($indexGreenBranch), ' green branch indexes', 
                            concat(': ', string-join($indexGreenBranch ! string(.), ', '))[count($indexGreenBranch) gt 0]))
            else
                $modelParticle/*[$indexGreenBranch]/f:getContentModelRC($constraintElem, ., $infoOneOf, $compiledNodePaths)
    default return error()        
};        

(:
=============================================================================================================
:)
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
declare function f:validateNodeContentConstraint($constraintElem as element(),
                                                 $constraintNode as element(gx:node),                                                 
                                                 $contextNode as node()?,
                                                 $contextPosition as xs:integer?,
                                                 $contextTrail as xs:string?,
                                                 $compiledNodePaths as map(xs:string, item()*),
                                                 $options as map(xs:string, item()*),
                                                 $context as map(xs:string, item()*))
        as element()* {
    let $locNP := $constraintNode/@locNP
    (: New context trail is previous context trail with current @locNP appended :)
    let $trail := string-join(($contextTrail ! concat(., '(', $contextPosition, ')'), $constraintNode/@locNP), '#')
    (: Switch controling whether to consider namespaces :)
    let $withNamespaces := $constraintElem/@withNamespaces/xs:boolean(.)
    
    (: Find instance nodes :)
    let $compiledNodePath := i:datapath($locNP, $constraintElem) ! $compiledNodePaths(.)
    let $nodes := dcont:evaluateCompiledNodePath($compiledNodePath, $contextNode, $constraintNode, $options, $context)
    
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
        $constraintElem, $constraintNode, $contextNode, $nodes, $trail, $compiledNodePaths, (), $options, $context)
        
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
                                                 $constraintElem as element(),
                                                 $constraintNode as element(gx:node),                                                 
                                                 $contextNode as node()?,
                                                 $valueNodes as node()*,
                                                 $trail as xs:string,
                                                 $options as map(xs:string, item()*),
                                                 $context as map(xs:string, item()*))
        as element()* {
    let $constraintCompPrefix := $constraintElem/local-name(.) ! i:firstCharToUpperCase(.)       
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
                    $colour, $constraintElem, $useConstraintNode, $constraintCompPrefix || 'MinCount', (), 
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
                    $colour, $constraintElem, $useConstraintNode, $constraintCompPrefix || 'MaxCount', (), 
                    $contextNode, $count, $trail, (), $context)
        )                        
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
                                                 $constraintElem as element(),
                                                 $constraintNode as element(gx:node),                                                 
                                                 $contextNode as node()?,
                                                 $valueNodes as node()*,
                                                 $trail as xs:string,
                                                 $compiledNodePaths as map(xs:string, item()*),
                                                 $infoOneOf as map(xs:string, item()*)*,
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
    let $contentModel := f:getContentModel($constraintElem, $constraintNode, $infoOneOf, $compiledNodePaths)
    let $cnpsAttribute := $contentModel?atts            
    let $cnpsElement := $contentModel?elems
       
    (: Unexpected elements = child elements of instance node which do not match a child path :)
    let $unexpectedElems :=$currentContextNode/*
        [not(dcont:nodeNameMatchesNodePathStep(., $cnpsElement, (), (), $withNamespaces, $constraintNode))]
        
    (: Unexpected attributes = attributes of instance node which do not match a child path :) 
    
    let $unexpectedAtts := $currentContextNode/@*
        [not(dcont:nodeNameMatchesNodePathStep(., $cnpsAttribute, $furtherAttLocalNames, $furtherAttQNames, $withNamespaces, $constraintNode))]
        
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

declare function f:compileNodePaths($constraintElem as element(),
                                    $options as map(xs:string, item()*),
                                    $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
    map:merge(
    
        for $nodeNP in $constraintElem//@locNP
        let $location := i:datapath($nodeNP, $constraintElem)
        let $compiled := dcont:parseNodePath($nodeNP, $options, $context)
        return
            map:entry($location, $compiled)
    )
};        