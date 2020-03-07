(:
 : -------------------------------------------------------------------------
 :
 : deepSimilarConstraint.xqm - validates a resource against a DeepSimilar constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateDeepSimilar($filePath as xs:string,
                                       $constraintElem as element(gx:deepSimilar),
                                       $node as node(),
                                       $doc as document-node()?,
                                       $context as map(xs:string, item()*))
        as element()* {
    let $evaluationContext := $context?_evaluationContext
    
    let $skipPrettyWS := true()
    let $otherFoxpath := $constraintElem/@otherFoxpath
 
    let $otherDoc :=
        if ($otherFoxpath) then 
            let $other := f:evaluateFoxpath($otherFoxpath, $filePath, $evaluationContext, true())
            return
                typeswitch($other)
                case node() return $other
                case xs:anyAtomicType return 
                    if (doc-available($other)) then doc($other) else ()
                default return ()
        else ()
    return
        if (not($otherDoc)) then
            f:validationResult_deepSimimlar('red', $constraintElem, $constraintElem/@otherFoxpath, 'noOtherDoc', ())
        else
        
    let $d1 := f:normalizeDocForComparison($node, $skipPrettyWS, $constraintElem/*)
    let $d2 := f:normalizeDocForComparison($otherDoc, $skipPrettyWS, $constraintElem/*)
    let $isDeepSimilar := deep-equal($d1, $d2)
    let $colour := if ($isDeepSimilar) then 'green' else 'red'
    return
        f:validationResult_deepSimimlar($colour, $constraintElem, $constraintElem/@otherFoxpath, (), ())
};   

declare function f:normalizeDocForComparison($node as node(), 
                                             $skipPrettyWS as xs:boolean, 
                                             $normItems as element()*)
        as node()? {
    copy $node_ := $node
    modify (
        if (not($skipPrettyWS)) then ()
        else
            let $delNodes := $node_//text()[not(matches(., '\S'))][../*]
            return
                if (empty($delNodes)) then () else delete node $delNodes
        ,
        for $normItem in $normItems
        return
            typeswitch($normItem)
            case $skipItem as element(gx:skipItem) return
                let $kind := $skipItem/@kind
                let $localName := $skipItem/@localName
                let $namespace := $skipItem/@namespace
                let $parentLocalName := $skipItem/@parentLocalName
                let $parentNamespace := $skipItem/@parentNamespace
                
                let $candidates := if ($kind eq 'attribute') then $node_//@* else $node_//*
                let $delNodes := trace(
                    $candidates[not($localName) or local-name() eq $localName]
                               [not(@namespace) or namespace-uri(.) eq $namespace]
                               [not($parentLocalName) or ../local-name(.) eq $parentLocalName]
                               [not(@parentNamespace) or ../namespace-uri(.) eq $parentNamespace]
                               , '___SKIP_NODES: ')
                return
                    if (empty($delNodes)) then () else delete node $delNodes
            default return ()
    )
    return $node_
};


(:~
 : Writes a validation result for a DeepSimilar constraint.
 :
 : @param colour indicates success or error
 : @param constraintElem the element representing the constraint
 : @param constraint an attribute representing the main properties of the constraint
 : @param reasons strings identifying reasons of violation
 : @param additionalAtts additional attributes to be included in the validation result
 :) 
declare function f:validationResult_deepSimimlar($colour as xs:string,
                                                 $constraintElem as element(gx:deepSimilar),
                                                 $constraint as attribute(),
                                                 $reasonCodes as xs:string*,
                                                 $additionalAtts as attribute()*)
        as element() {
    let $elemName := 'gx:' || $colour
    let $constraintComponent :=
        $constraintElem/f:firstCharToUpperCase(local-name(.)) ||
        $constraint/f:firstCharToUpperCase(local-name(.))
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintId := $constraintElem/@constraintID
    let $moreAtts := $constraintElem/(@csv.minColumnCount, @csv.minRowCount)
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraint/local-name(.), ())
        
    return
        element {$elemName}{
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComponent},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            $moreAtts, 
            if (empty($reasonCodes)) then () else attribute reasonCodes {$reasonCodes},
            $additionalAtts
        }        
};

