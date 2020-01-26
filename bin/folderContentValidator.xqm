(:
 : -------------------------------------------------------------------------
 :
 : folderContentValidator.xqm - functions for validating folder content
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
    let $folderPathDisplay := replace($folderPath, '\\', '/')
    
    (: determine expectations :)
    let $_constraint := trace(f:validateFolderContent_compile($constraint) , '_COMPILED: ')
    let $closed := $_constraint/@closed
    let $msgFolderContent := $_constraint/@msg

    (: determine member files and folders :)
    let $members := file:list($folderPath, false(), '*') ! replace(., '[/\\]$', '')
    let $memberFiles := $members[file:is-file(concat($folderPath, '/', .))]
    let $memberFolders := $members[not(. = $memberFiles)]

    let $results_folderContentClosed :=
        if (not($_constraint/@closed eq 'true')) then () else
        
        let $unexpectedMembers :=
            for $member in $members
            let $descriptors := $_constraint/(gx:member, 
                if ($member = $memberFiles) then gx:memberFile else gx:memberFolder)
            let $expected := 
                some $d in $descriptors satisfies matches($member, $d/@regex, 'i')
            where not($expected)
            return $member
        return
            if (exists($unexpectedMembers)) then
                let $msg := i:getErrorMsg($constraint, 'closed', 'Unexpected folder contents.')
                return                            
                    <gx:error>{
                        $msg ! attribute msg {.},
                        attribute constraintComp {'folderContentClosed'},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        $constraint/@resourceShapeID,
                        attribute filePath {$folderPathDisplay},
                        <gx:resources>{
                            for $name in $unexpectedMembers
                            let $path := concat($folderPath, '/', $name)
                            let $kind := if (file:is-dir($path)) then 'folder' else 'file'
                            return
                                <gx:resource name="{$name}" kind="{$kind}"/>
                        }</gx:resources>
                    }</gx:error>
            else            
                let $msg := i:getOkMsg($constraint, 'closed', 'No unexpected folder contents.')
                return                            
                    <gx:green>{
                        $msg ! attribute msg {.},
                        attribute constraintComp {'folderContentClosed'},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        $constraint/@resourceShapeID,
                        attribute filePath {$folderPathDisplay}
                    }</gx:green>
            
    let $results_cardinality :=
        for $d in $_constraint/*
        let $minCount := $d/@minCount/number(.)
        let $maxCount := $d/@maxCount/number(.)
        let $candMembers := 
            if ($d/self::gx:memberFile) then $memberFiles 
            else if ($d/self::gx:memberFolder) then $memberFolders 
            else $members   
        let $resourceKind :=            
            if ($d/self::gx:memberFile) then 'file' 
            else if ($d/self::gx:memberFolder) then 'folder' 
            else ()
        let $found := $candMembers[matches(., $d/@regex, 'i')]
        let $count := count($found)
        let $result_minCount :=
            if ($minCount eq 0) then () 
            else
                let $ok := $count ge $minCount
                let $elemName := if ($ok) then 'gx:green' else 'gx:error'
                let $msg := if ($ok) then $d/i:getOkMsg((., ..), 'minCount', ())
                            else $d/i:getErrorMsg((., ..), 'minCount', ())
                return
                    element {$elemName} {
                        $msg ! attribute msg {.},
                        attribute constraintComponent {'folderContentMinCount'},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        attribute minCount {$d/@minCount},
                        attribute actCount {$count},
                        attribute resourceName {$d/@name},
                        $resourceKind ! attribute resourceKind {.}
                    }                            
        let $result_maxCount :=
            if ($maxCount eq -1) then () 
            else
                let $ok := $count le $maxCount
                let $elemName := if ($ok) then 'gx:green' else 'gx:error'
                let $msg := if ($ok) then $d/i:getOkMsg((., ..), 'maxCount', ())
                            else $d/i:getErrorMsg((., ..), 'maxCount', ())
                return
                    element {$elemName} {
                        $msg ! attribute msg {.},
                        attribute constraintComponent {'folderContentMaxCount'},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        attribute maxCount {$d/@maxCount},
                        attribute actCount {$count},
                        attribute resourceName {$d/@name},
                        $resourceKind ! attribute resourceKind {.}
                    }                            
        return ($result_minCount, $result_maxCount)
        
    let $results_hash :=
        for $d in $_constraint/*[@md5, @sha1, @sha256][self::gx:memberFile, self::gx:memberFolder]
        let $name := $d/@name
        let $candMembers := $memberFiles 
        let $found := $candMembers[matches(., $d/@regex, 'i')]
        
        for $hashExp in $d/(@md5, @sha1, @sha256)
        let $hashKind := $hashExp/local-name(.)

        let $hashesMap := 
            map:merge(
                for $file in $found
                let $filePath := concat($folderPath, '/', $file) ! replace(., '\\', '/')
                let $fileContent := file:read-binary($filePath)
                let $rawHash :=
                    typeswitch($hashExp)
                    case attribute(md5) return hash:md5($fileContent)
                    case attribute(sha1) return hash:sha1($fileContent)
                    case attribute(sha256) return hash:sha256($fileContent)
                    default return error()
                return
                    map:entry(string(xs:hexBinary($rawHash)), $filePath)
            )
        let $hashes := map:keys($hashesMap)
        
        (: OK, if for every hash in the attribute value a matching file is found :)
        for $hashExpItem in tokenize($hashExp)
        let $constraintComponent := concat('folderContent-', $hashExp/local-name(.))
        let $file := $hashesMap($hashExpItem)
        return
            if ($file) then
                let $msg := i:getOkMsg(($d, $d/..), $hashKind, 
                            concat('Expected ', $hashKind, ' value found.'))
                return
                    <gx:green>{
                        $msg ! attribute msg {.},
                        attribute constraintComponent {$constraintComponent},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        attribute {$hashExp/name()} {$hashExpItem}
                    }</gx:green>
            else            
                let $msg := i:getErrorMsg(($d, $d/..), $hashKind, 
                            concat('Not expected  ', $hashKind, ' value.'))
                let $actValueAtt := 
                    if (count($found) gt 1) then () else attribute {concat($hashKind, 'Found')} {$hashes[1]}
                return
                    <gx:error>{
                        $msg ! attribute msg {.},
                        attribute constraintComponent {$constraintComponent},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        attribute {$hashExp/name()} {$hashExpItem},
                        $actValueAtt,
                        attribute resourceName {$name}
                    }</gx:error>

    let $errors := ($results_folderContentClosed, $results_cardinality, $results_hash)
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
        
    let $minMaxCount :=
        function($elem) {
            let $limits :=
                if ($elem/@count) then $elem/@count/i:occ2minMax(.)
                else (
                    ($elem/@minCount, 1)[1] ! xs:integer(.),
                    ($elem/@maxCount, 1)[1] ! xs:integer(.) 
                )
            return (
                attribute minCount {$limits[1]},
                attribute maxCount {$limits[2]}
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
                                $member/(@* except (@count, @minCount, @maxCount)),
                                attribute count {0}
                            }
                    else $member
                return
                        element {node-name($member)} {
                            $member/(@* except (@count, @minCount, @maxCount)),
                            $member/@name/attribute regex {i:glob2regex(.)},
                            $minMaxCount($member)
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
                                $member/(@* except (@count, @minCount, @maxCount)),
                                attribute count {0}
                            }
                    else $member
                 
                let $elemName := local-name($member) ! replace(., 's$', '')
                for $name in tokenize($member/@names, ',\s*')
                let $regex := i:glob2regex($name)
                return
                    element {concat('gx:', $elemName)} {
                        $member/(@* except (@names, @minCount, @maxCount, @count)),
                        attribute name {$name},
                        attribute regex {$regex},
                        $minMaxCount($member)
                    }
            default return error()
    }</gx:folderContent>
};        

