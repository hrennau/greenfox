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
            let $doc :=
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
                                return
                                    if (
                                        (empty($minColCount) or $minColCount/xs:integer(.) <= min($try/*/*/count(*)))
                                        and
                                        (empty($minRowCount) or $minRowCount/xs:integer(.) <= $try/*/* => count())
                                    ) then $try else ()
                                
                    default return 
                        error(QName((), 'NOT_YET_IMPLEMENTED'),
                            concat('Unexpected mediatype constraint value: ', $mtype))
            return
                if ($doc) then f:validationResult_mediatype('green', $constraint, $eq, $constraint/(@csv.minColumnCount, @csv.minRowCount))
                else f:validationResult_mediatype('red', $constraint, $eq, $constraint/(@csv.minColumnCount, @csv.minRowCount))
        ,
        ()
    )        
};                    
                    
                    
declare function f:validationResult_mediatype($colour as xs:string,
                                              $constraint as element(gx:mediatype),
                                              $property as attribute(),
                                              $additionalAtts as attribute()*)
        as element() {
    let $elemName := if ($colour eq 'red') then 'gx:error' else 'gx:green'        
    let $constraintComponent := concat('mediatype-', $property/local-name(.))   
    return
        element {$elemName}{
            $constraint/@msg,
            attribute constraintComp {$constraintComponent},
            $constraint/@constraintID,
            $constraint/@label/attribute constraintLabel {.},
            $constraint/@*[starts-with(local-name(.), 'csv')],
            $property
        }        
};
