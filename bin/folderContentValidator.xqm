(:
 : -------------------------------------------------------------------------
 :
 : folderContentValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_foxpath.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "expressionEvaluator.xqm",
    "expressionValueConstraint.xqm",
    "fileValidator.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFolderContent($folderPath as xs:string, $constraint as element(gx:folderContent), $context as map(*)) 
        as element()* {
    (: determine expectations :)
    let $_constraint := f:validateFolderContent_compile($constraint)
    let $closed := $_constraint/@closed
    let $msgFolderContent := $_constraint/@msg

    (: determine member files and folders :)
    let $members := file:list($folderPath, false(), '*') ! replace(., '[/\\]$', '')
    let $memberFiles := $members[file:is-file(concat($folderPath, '/', .))]
    let $memberFolders := $members[not(. = $memberFiles)]

    let $errors_unexpectedMembers :=
        if (not($_constraint/@closed eq 'true')) then () else
        
        for $member in $members
        let $descriptors := $_constraint/(gx:member, if ($member = $memberFiles) then gx:memberFile else gx:memberFolder)
        let $expected := 
            some $d in $descriptors satisfies matches($member, $d/@regex, 'i')
        where not($expected)
        return
            <gx:error>{
                $_constraint/@msg,
                attribute constraintComponent {'folderContent'},
                attribute facet {'unexpectedMember'},
                $_constraint/@id/attribute constraintID {.},
                $_constraint/@label/attribute constraintLabel {.},
                attribute member {$member}
            }</gx:error>
            
            
    let $errors_missingMembers :=
        for $d in $_constraint/*[not(@minOccurs eq '0')]
        let $candMembers := trace( if ($d/self::gx:memberFile) then $memberFiles 
                            else if ($d/self::gx:memberFolder) then $memberFolders 
                            else $members , '### CAND_MEMBERS: ')                                 
        let $found := $candMembers[matches(., $d/@regex, 'i')]
        let $facet :=
            if (empty($found)) then 'missingMember'
            else if ($d/@maxOccurs/xs:integer(.) = -1) then ()
            else if ($d/@maxOccurs/xs:integer(.) > count($found)) then 'tooManyMembers'
            else ()
        where $facet
        return
            <gx:error>{
                $_constraint/@msg,
                attribute constraintComponent {'folderContent'},
                attribute facet {$facet},
                attribute memberName {$d/@glob},
                if ($d/@maxOccurs = 1) then () else $d/@maxOccurs/attribute maxOccurs {.},
                $_constraint/@id/attribute constraintID {.},
                $_constraint/@label/attribute constraintLabel {.},
                attribute member {$d/@name}
            }</gx:error>
    return (
        $errors_missingMembers, 
        $errors_unexpectedMembers
    )    
};

declare function f:validateFolderContent_compile($folderContent as element(gx:folderContent))
        as element(gx:folderContent) {
        
    let $minMaxOccurs :=
        function($elem) {
            let $limits :=
                if ($elem/@occ) then $elem/@occ/i:occ2minMax(.)
                else (
                    ($elem/@minOccurs, 1)[1] ! xs:integer(.),
                    ($elem/@maxOccurs, -1)[1] ! xs:integer(.) 
                )
            return (
                attribute minOccurs {$limits[1]},
                attribute maxOccurs {$limits[2]}
            )
        }
    return trace(
    
    <gx:folderContent>{
        $folderContent/@*,
        if ($folderContent/@closed) then () else attribute closed {'false'},
        
        for $member in $folderContent/*
        return
            typeswitch($member)
            case element(gx:memberFile) | element(gx:memberFolder) return
                element {node-name($member)} {
                    $member/(@* except (@minOccurs, @maxOccurs, @occ)),
                    $member/@name/attribute regex {i:glob2regex(.)},
                    $minMaxOccurs($member)
                }
            case element(gx:memberFiles) | element(gx:memberFolders) return
                let $elemName := local-name($member) ! replace(., 's$', '')
                for $name in tokenize($member/@names, ',\s*')
                let $regex := i:glob2regex($name)
                return
                    element {concat('gx:', $elemName)} {
                        $member/(@* except (@names, @minOccurs, @maxOccurs, @occ)),
                        attribute name {$name},
                        attribute regex {$regex},
                        $minMaxOccurs($member)
                    }
            default return error()
    }</gx:folderContent>
    , '*** FOLDER_CONTENT: ')
};        

