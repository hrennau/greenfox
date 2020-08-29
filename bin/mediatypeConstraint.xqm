(:
 : -------------------------------------------------------------------------
 :
 : mediatypeConstraint.xqm - validates a resource against a Mediatype constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "greenfoxUtil.xqm",
   "resourceAccess.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a resource against a Mediatype constraint.
 :
 : @param contextURI file path of the resource
 : @param constraintElem the element representing the Mediatype constraint
 : @param context processing context
 : @return validation result elements
 :)
declare function f:validateMediatype($contextURI as xs:string, 
                                     $constraintElem as element(gx:mediatype), 
                                     $context as map(xs:string, item()*))
        as element()* {
        
    let $eq := $constraintElem/@eq
    let $eqItems := $constraintElem/@eq/tokenize(.)
    return
        if (not($eq)) then () else 
        
            let $docAndFacetResults :=
                for $mtype in $eqItems
                return
                    switch($mtype)
                    
                    (: Check XML :)
                    case 'xml' return try {i:fox-doc($contextURI)} catch * {()}
                    
                    (: Check JSON :)
                    case 'json' return
                        let $text := i:fox-unparsed-text($contextURI, ())
                        let $char1 := replace($text, '^\s*(.).*$', '$1', 's')
                        return
                            if (not($char1 = ('{', '['))) then ()
                            else try {json:parse($text)} catch * {()}
                            
                    (: Check CSV :)
                    case 'csv' return 
                        let $doc := f:csvDoc($contextURI, $constraintElem)
                        let $facetResults := if (not($doc)) then () else
                            let $checkAtts := $constraintElem/(
                                @csv.minColumnCount, @csv.maxColumnCount, @csv.minRowCount, @csv.maxRowCount)
                            
                            let $actMinColCount := min($doc/*/*/count(*))                            
                            let $actMaxColCount := max($doc/*/*/count(*))
                            let $actRowCount := $doc/*/* => count()
                            
                            for $checkAtt in $checkAtts
                            let $violatingValue :=
                                typeswitch($checkAtt)
                                case attribute(csv.minColumnCount) return $actMinColCount[. < $checkAtt]
                                case attribute(csv.maxColumnCount) return $actMaxColCount[. > $checkAtt]
                                case attribute(csv.minRowCount) return $actRowCount[. < $checkAtt]
                                case attribute(csv.maxRowCount) return $actRowCount[. > $checkAtt]
                                default return error()
                            let $colour := if ($violatingValue) then 'red' else 'green'
                            let $violationInfoAtt := if (not($violatingValue)) then () else
                                let $attName := $checkAtt/local-name(.) ! replace(., '^csv.(min|max)', 'csv.Act')
                                return attribute {$attName} {$violatingValue}
                            return
                                result:validationResult_mediatype(
                                    $colour, $constraintElem, $checkAtt, $context, $violationInfoAtt)
                        return ($doc, $facetResults)
                default return 
                        error(QName((), 'NOT_YET_IMPLEMENTED'),
                            concat('Unexpected mediatype constraint value: ', $mtype))
            return
                let $results := $docAndFacetResults/(self::gx:red, self::gx:yellow, self::gx:green)
                let $doc := $docAndFacetResults except $results
                return (
                    $results,
                    let $colour := if ($doc) then 'green' else 'red'
                    return 
                        result:validationResult_mediatype(
                            $colour, $constraintElem, $eq, $context, ())
                )
};                    

