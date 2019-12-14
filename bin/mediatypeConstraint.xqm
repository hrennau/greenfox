(:
 : -------------------------------------------------------------------------
 :
 : mediatypeConstraint.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateMediatype($filePath as xs:string, $constraint as element(gx:mediatype), $context)
        as element()* {
    let $constraintId := $constraint/@id
    let $constraintLabel := $constraint/@label
    
    let $eq := $constraint/@eq
    let $eqItems := $constraint/@eq/tokenize(.)
    return (
        if (not($eq)) then () else 
            let $docEtc:=
                for $mtype in $eqItems
                return
                    switch($mtype)
                    case 'xml' return try {doc($filePath)} catch * {()}
                    case 'json' return
                        let $text := unparsed-text($filePath)
                        let $char1 := replace($text, '^\s*(.).*$', '$1', 's')
                        return
                            if (not($char1 = ('{', '['))) then ()
                            else try {json:parse($text)} catch * {()}
                    case 'csv' return 
                        let $try := f:csvDoc($filePath, $constraint)
                        return
                            if (not($try)) then () 
                            else
                                let $minColCount := $constraint/@csv.minColumnCount
                                let $minRowCount := $constraint/@csv.minRowCount
                                let $violationsEtc := (
                                    if (not($minColCount)) then ()
                                    else 
                                        let $actMinColCount := min($try/*/*/count(*))
                                        return
                                            if ($minColCount <= $actMinColCount) then ()
                                            else (
                                                'csv.minColumnCount', 
                                                attribute actualCsvMinColumnCount {$actMinColCount}
                                            )
                                         
                                    ,
                                    if (not($minRowCount)) then () 
                                    else
                                        let $rowCount := $try/*/* => count()
                                        return
                                            if ($minRowCount <= $rowCount) then ()
                                            else (
                                                'csv.minRowCount', 
                                                attribute actualCsvRowCount {$rowCount}
                                            )

                                            
                                )
                                return
                                    if (empty($violationsEtc)) then $try
                                    else
                                        let $violations := $violationsEtc[. instance of xs:string]
                                        let $additionalAtts := $violationsEtc[. instance of attribute()]
                                        return
                                            f:validationResult_mediatype('red', $constraint, 'eq', $violations, $additionalAtts) 
                    default return 
                        error(QName((), 'NOT_YET_IMPLEMENTED'),
                            concat('Unexpected mediatype constraint value: ', $mtype))
            return
                let $results := $docEtc/(self::gx:error, self::gx:yellow)
                let $doc := $docEtc except $results
                return 
                    if ($results) then $results
                    else if ($doc) then f:validationResult_mediatype('green', $constraint, 'eq', (), ())
                    else f:validationResult_mediatype('red', $constraint, 'eq', (), ())
        ,
        ()
    )        
};                    
                    
declare function f:validationResult_mediatype($colour as xs:string,
                                              $constraint as element(gx:mediatype),
                                              $facet as xs:string,
                                              $violations as xs:string*,
                                              $additionalAtts as attribute()*)
        as element() {
    let $elemName := 
        switch($colour)
        case 'red' return 'gx:error'
        default return concat('gx:', $colour)
    let $constraintComponent := 'mediatype'   
    return
        element {$elemName}{
            $constraint/@msg,
            attribute constraintComp {$constraintComponent},
            attribute constraintFacet {$facet},
            $constraint/@resourceShapeID,
            $constraint/@constraintID,
            $constraint/@label/attribute constraintLabel {.},
            $constraint/(@* except (@resourceShapeID, @constraintID, @label)),
            if (empty($violations)) then () else attribute violations {$violations},
            $additionalAtts
        }        
};

