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
 : @param contextURI the file path of the file containing the initial context item 
 : @param contextDoc the XML document containing the initial context item
 : @param contextNode the initial context node to be used in expressions
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateDocContentConstraint($contextURI as xs:string,
                                                $contextDoc as document-node()?,
                                                $contextNode as node()?,
                                                $constraintElem as element(gx:docContent),
                                                $context as map(xs:string, item()*))
        as element()* {
    
    (: Exception - no context document :)
    if (not($context?_targetInfo?doc)) then
        result:validationResult_docContent_exception($constraintElem,
            'Context resource could not be parsed', (), $context)
    else
    
    (: Normal processing :)
    for $constraint in $constraintElem/gx:node 
    let $contextNode := ($contextNode, $contextDoc)[1]
    return
        f:validateNodeContentConstraint($contextURI, $contextNode, $constraint, $context)
};

declare function f:validateNodeContentConstraint($contextURI as xs:string,
                                                 $contextNode as node()?,
                                                 $constraintNode as element(gx:node),
                                                 $context as map(xs:string, item()*))
        as element()* {
    let $constraintElem := $constraintNode/ancestor::gx:docContent[1]        
    let $locNP := $constraintNode/@locNP
    let $closed := $contextNode/@closed
    
    (: Find nodes :)
    let $nodes := dcont:evaluateNodePath($locNP, $contextNode, (), $context)
    
    (: Check count :)
    let $valueCount := count($nodes)
    let $countAtts := $constraintNode/(@count, @minOccurs, @maxOccurs)
    let $results_counts :=
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
                result:validationResult_docContent_counts($colour, $constraintElem, $countAtt, $valueCount, (), $context)
                
        (: implicit constraints :)                        
        else
            let $colour := if ($valueCount eq 1) then 'green' else 'red'
            return
                result:validationResult_docContent_counts(
                    $colour, $constraintElem, $constraintNode, $valueCount, attribute implicitCount {1}, $context)
                    
    (: Check children :)
    let $results_children :=
        for $node in $nodes
        for $constraint in $constraintNode/gx:node 
        return
            f:validateNodeContentConstraint($contextURI, $node, $constraint, $context)
    return (
        $results_counts,
        $results_children
    )
};
