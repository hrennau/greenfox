(:
 : -------------------------------------------------------------------------
 :
 : resourceRelationships.xqm - functions for managing resource relationships
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
 : Resolves a resource relationship name to a set of target resources. Resolution
 : context is the file path of the focus resource. The target resources may
 : be represented by file paths or by nodes, dependent on the specification
 : of the resource relationship.
 :
 : @param relName relationship name
 : @param filePath file path of the focus resource
 : @param context processing context
 : @return the target documents of the relationship, resolved in the
 :   context of the file path
 :)
declare function f:relationshipTargets($relName as xs:string,
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
        
    let $context := f:prepareEvaluationContext($context, 'filePath', $filePath, (), (), (), (), ())
        
    let $resourceRelationship := $context?_resourceRelationships($relName)
    let $targets :=
        if (empty($resourceRelationship)) then error()
        else if ($resourceRelationship?relKind eq 'foxpath') then
            f:relationshipTargets_foxpath($resourceRelationship, $filePath, $context)
        else error()
    return
        $targets
};

(:~
 : Resolves a resource relationship name to a set of target resources, in the case
 : of relationship kind 'foxpath'. 
 :
 : @param relName relationship name
 : @param filePath file path of the focus resource
 : @param context processing context
 : @return the target documents of the relationship, resolved in the
 :   context of the file path
 :)
declare function f:relationshipTargets_foxpath(
                                       $resourceRelationship as map(xs:string, item()*),
                                       $filePath as xs:string,
                                       $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $foxpath := $resourceRelationship?foxpath 
    return    
        if ($foxpath) then
            f:evaluateFoxpath($foxpath, $filePath, $evaluationContext, true())
        else error()
};

(:~
 : Parses resource relationships defined by <setRel> elements into a
 : map. Each relationship is represented by a field whose name is the
 : name of the relationship and whose value is a map describing the
 : relationship.
 :
 : @param setRels schema elements from which to parse the relationships
 : @return a map representing the relationships parsed from the <setRel> elements
 :)
declare function f:parseResourceRelationships($setRels as element(gx:setRel)*)
        as map(*) {
    map:merge(        
        for $setRel in $setRels
        let $name := $setRel/@name/string()
        let $foxpath := $setRel/@foxpath/string()
        let $relKind :=
            if ($foxpath) then 'foxpath'
            else error()
        return
            map:entry(
                $name,
                map:merge((
                    map:entry('relKind', $relKind),
                    map:entry('relName', $name),
                    $foxpath ! map:entry('foxpath', .)
                ))
            )
    )
};        