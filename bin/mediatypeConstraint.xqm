(:
 : -------------------------------------------------------------------------
 :
 : mediatypeConstraint.xqm - validates a resource against a Mediatype constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm",
    "resourceAccess.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a resource against a Mediatype constraint.
 :
 : @param filePath file path of the resource
 : @param constraintElem the element representing the Mediatype constraint
 : @param context processing context
 : @return validation result element
 :)
declare function f:validateMediatype($filePath as xs:string, 
                                     $constraintElem as element(gx:mediatype), 
                                     $context as map(xs:string, item()*))
        as element()* {
        
    let $eq := $constraintElem/@eq
    let $eqItems := $constraintElem/@eq/tokenize(.)
    return (
        if (not($eq)) then () else 
            let $docOrErrors :=
                for $mtype in $eqItems
                return
                    switch($mtype)
                    case 'xml' return try {i:fox-doc($filePath)} catch * {()}
                    case 'json' return
                        let $text := i:fox-unparsed-text($filePath, ())
                        let $char1 := replace($text, '^\s*(.).*$', '$1', 's')
                        return
                            if (not($char1 = ('{', '['))) then ()
                            else try {json:parse($text)} catch * {()}
                    case 'csv' return 
                        let $doc := f:csvDoc($filePath, $constraintElem)
                        return
                            if (not($doc)) then () 
                            (: a CSV document may be submitted to additional constraint facets :)
                            else
                                let $minColCount := $constraintElem/@csv.minColumnCount
                                let $minRowCount := $constraintElem/@csv.minRowCount
                                let $violationsEtc := (
                                    if (not($minColCount)) then ()
                                    else 
                                        let $actMinColCount := min($doc/*/*/count(*))
                                        return
                                            if ($minColCount <= $actMinColCount) then ()
                                            else (
                                                'csv.minColumnCount', 
                                                attribute actualCsvMinColumnCount {$actMinColCount}
                                            )
                                         
                                    ,
                                    if (not($minRowCount)) then () 
                                    else
                                        let $rowCount := $doc/*/* => count()
                                        return
                                            if ($minRowCount <= $rowCount) then ()
                                            else (
                                                'csv.minRowCount', 
                                                attribute actualCsvRowCount {$rowCount}
                                            )

                                            
                                )
                                return
                                    if (empty($violationsEtc)) then $doc
                                    else
                                        let $violations := $violationsEtc[. instance of xs:string]
                                        let $additionalAtts := $violationsEtc[. instance of attribute()]
                                        return
                                            f:validationResult_mediatype('red', $constraintElem, 'eq', $violations, $additionalAtts) 
                    default return 
                        error(QName((), 'NOT_YET_IMPLEMENTED'),
                            concat('Unexpected mediatype constraint value: ', $mtype))
            return
                let $errors := $docOrErrors/(self::gx:red, self::gx:yellow)
                let $doc := $docOrErrors except $errors
                return 
                    if ($errors) then $errors
                    else if ($doc) then f:validationResult_mediatype('green', $constraintElem, $eq, (), ())
                    else f:validationResult_mediatype('red', $constraintElem, $eq, (), ())
        ,
        ()
    )        
};                    

(:~
 : Writes a validation result for a mediatype constraint.
 :
 : @param colour indicates success or error
 : @param constraintElem the element representing the constraint
 : @param constraint an attribute representing the main properties of the constraint
 : @param reasons strings identifying reasons of violation
 : @param additionalAtts additional attributes to be included in the validation result
 :) 
declare function f:validationResult_mediatype($colour as xs:string,
                                              $constraintElem as element(gx:mediatype),
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

