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
                    case 'xml' return try {doc-available($filePath)} catch * {()}
                    case 'json' return
                        let $text := unparsed-text($filePath)
                        let $char1 := replace($text, '^\s*(.).*', '$1')
                        return
                            if (not($char1 = ('{', '['))) then ()
                            else try {json:parse($text)} catch * {()}
                    case 'csv' return f:csvDoc($filePath, $constraint)
                    default return 
                        error(QName((), 'NOT_YET_IMPLEMENTED'),
                            concat('Unexpected mediatype constraint value: ', $mtype))
            return
                if ($doc) then () else f:constructError_mediatype($constraint, $eq, ())
        ,
        ()
    )        
};                    
                    
                    
declare function f:constructError_mediatype($constraint as element(gx:mediatype),
                                            $property as attribute(),
                                            $additionalAtts as attribute()*)
        as element(gx:error) {
    let $constraintComponent := concat('mediatype-', $property/local-name(.))   
    return
        <gx:error>{
            $constraint/@msg,
            attribute constraintComp {$constraintComponent},
            $constraint/@id/attribute constraintID {.},
            $constraint/@label/attribute constraintLabel {.}
        }</gx:error>        
};
