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

declare function f:validateFolderContent($folderPath as xs:string, 
                                         $constraint as element(gx:folderContent), 
                                         $context as map(*)) 
        as element()* {
        
    let $D_DEBUG := trace($folderPath, '__FOLDER_PATH: ')        
    
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
                $_constraint/@id/attribute constraintID {.},
                $_constraint/@label/attribute constraintLabel {.},
                attribute constraintFacet {'unexpectedMember'},
                attribute member {$member}
            }</gx:error>
            
            
    let $errors_missingMembers :=
        for $d in $_constraint/*
        let $candMembers := if ($d/self::gx:memberFile) then $memberFiles 
                            else if ($d/self::gx:memberFolder) then $memberFolders 
                            else $members                                 
        let $found := $candMembers[matches(., $d/@regex, 'i')]
        let $facet :=
            if (empty($found)) then 
                if ($d/@minOccurs eq '0') then ()
                else 'missingMember'
            else if ($d/@minOccurs/xs:integer(.) > count($found)) then 'tooFewMembers'                
            else if ($d/@maxOccurs/xs:integer(.) = -1) then ()
            else if ($d/@maxOccurs/xs:integer(.) < count($found)) then 'tooManyMembers'            
            else ()
               
        where $facet
        let $facetEdited :=
            if ($facet eq 'tooManyMembers' and $d/@maxOccurs eq '0') then 'excludedMember'
            else $facet
        let $memberName :=
            if (count($found) eq 1) then $found
            else $_constraint/@name
        return
            <gx:error>{
                $_constraint/@msg,
                attribute constraintComponent {'folderContent'},
                $_constraint/@id/attribute constraintID {.},
                $_constraint/@label/attribute constraintLabel {.},
                attribute constraintFacet {$facetEdited},
                $d/@minOccurs[not(. eq '1')]/attribute minOccurs {.},
                $d/@maxOccurs[not(. eq '1')]/attribute maxOccurs {.},
                attribute member {$memberName}
            }</gx:error>

    let $errors_hash :=
        for $d in $_constraint/*[@md5, @sha1, @sha256][self::gx:memberFile, self::gx:memberFolder]
        let $candMembers := $memberFiles 
        let $found := $candMembers[matches(., $d/@regex, 'i')]
        for $file in $found
        let $file := concat($folderPath, '/', $file) ! replace(., '\\', '/')
        let $fileContent := file:read-binary($file)
        for $hashExp in $d/(@md5, @sha1, @sha256)
        let $hashKind := $hashExp/local-name(.)
        let $rawHash :=
            typeswitch($hashExp)
            case attribute(md5) return hash:md5($fileContent)
            case attribute(sha1) return hash:sha1($fileContent)
            case attribute(sha256) return hash:sha256($fileContent)
            default return error()
        let $hash := string(xs:hexBinary($rawHash))
        where ($hash ne $hashExp)
        let $msg := (concat('Not expected ', $hashKind), $_constraint/@msg)[1]
        let $actValueAtt := attribute {concat($hashKind, 'Found')} {$hash}
        return
            <gx:error>{
                attribute msg {$msg},
                attribute constraintComponent {'folderContent'},
                $_constraint/@id/attribute constraintID {.},
                $_constraint/@label/attribute constraintLabel {.},
                attribute constraintFacet {$hashExp/local-name(.)},
                $hashExp,
                $actValueAtt,
                attribute member {$file}
            }</gx:error>

    let $errors := ($errors_missingMembers, $errors_unexpectedMembers, $errors_hash)
    return
        if ($errors) then $errors
        else $_constraint/
            <gx:green>{
                attribute constraintComponent {local-name()},
                @id/attribute constraintID {.},
                @label/attribute constraintLabel {.},
                attribute folderPath {$folderPath}
            }</gx:green>
        
    
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
    return
    
    <gx:folderContent>{
        $folderContent/@*,
        if ($folderContent/@closed) then () else attribute closed {'false'},
        
        for $member in $folderContent/*
        return
            typeswitch($member)
            case element(gx:memberFile) 
                 | element(gx:memberFolder) 
                 | element(gx:excludedMemberFile) 
                 | element(gx:excludedMemberFolder) return
                let $member :=
                    if ($member/self::gx:excludedMemberFile, $member/self::gx:excludedMemberFolder) then
                        let $lname := $member/local-name(.) ! replace(., 'excludedM', 'm')
                        return
                            element {concat('gx:', $lname)} {
                                $member/(@* except @occ),
                                attribute occ {0}
                            }
                    else $member
                return
                        element {node-name($member)} {
                            $member/(@* except (@minOccurs, @maxOccurs, @occ)),
                            $member/@name/attribute regex {i:glob2regex(.)},
                            $minMaxOccurs($member)
                        }
            case element(gx:memberFiles) 
                 | element(gx:memberFolders)
                 | element(gx:excludedMemberFiles)
                 | element(gx:excludedMemberFolders) return
                let $member :=
                    if ($member/self::gx:excludedMemberFiles, $member/self::gx:excludedMemberFolders) then
                        let $lname := $member/local-name(.) ! replace(., 'excludedM', 'm')
                        return
                            element {concat('gx:', $lname)} {
                                $member/(@* except @occ),
                                attribute occ {0}
                            }
                    else $member
                 
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
};        

