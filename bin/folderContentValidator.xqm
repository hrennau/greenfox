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
        
    (: let $D_DEBUG := trace($folderPath, '__FOLDER_PATH: ') :)        
    let $folderPathDisplay := replace($folderPath, '\\', '/')
    
    (: determine expectations :)
    let $_constraint := f:validateFolderContent_compile($constraint)
    (: let $_DEBUG := trace($_constraint, '_COMPILED: ') :)
    let $closed := $_constraint/@closed
    let $msgFolderContent := $_constraint/@msg

    (: determine member files and folders :)
    (: let $members := file:list($folderPath, false(), '*') ! replace(., '[/\\]$', '') :)
    let $members := i:resourceChildResources($folderPath, '*') ! replace(., '[/\\]$', '')
    (: let $memberFiles := $members[file:is-file(concat($folderPath, '/', .))] :)
    let $memberFiles := $members[i:resourceIsFile(concat($folderPath, '/', .))]
    let $memberFolders := $members[not(. = $memberFiles)]

    let $results_folderContentClosed :=
        if (not($_constraint/@closed eq 'true')) then () else
        
        let $unexpectedMembers :=
            for $member in $members
            let $descriptors := $_constraint/(
                gx:member, 
                gx:ignoreMember,
                if ($member = $memberFiles) then gx:memberFile else gx:memberFolder)
            let $expected := 
                some $d in $descriptors satisfies matches($member, $d/@regex, 'i')
            where not($expected)
            return $folderPath || '/' || $member
        let $colour := if (exists($unexpectedMembers)) then 'red' else 'green'      
        let $additionalAtts := ()
        let $additionalElems := ()
        return        
            f:constructError_folderContentClosed(
                $colour, $_constraint, $unexpectedMembers, $additionalAtts, $additionalElems) 
(:        
            if (exists($unexpectedMembers)) then
                let $msg := i:getErrorMsg($constraint, 'closed', 'Unexpected folder contents.')
                return                            
                    <gx:red>{
                        $msg ! attribute msg {.},
                        attribute constraintComp {'FolderContentClosed'},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        $constraint/@resourceShapeID,
                        attribute filePath {$folderPathDisplay},

                        for $name in $unexpectedMembers
                        let $path := concat($folderPath, '/', $name)
                        let $kind := if (file:is-dir($path)) then 'folder' else 'file'
                        return
                            <gx:value resoureKind="{$kind}">{$path}</gx:value>

                    }</gx:red>
            else            
                let $msg := i:getOkMsg($constraint, 'closed', ())
                return                            
                    <gx:green>{
                        $msg ! attribute msg {.},
                        attribute constraintComp {'FolderContentClosed'},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        $constraint/@resourceShapeID,
                        attribute filePath {$folderPathDisplay}
                    }</gx:green>
:)            
    let $results_cardinality :=
        for $d in $_constraint/(* except gx:ignoreMember)
        let $minCount := $d/@minCount/number(.)
        let $maxCount := 
            let $raw := $d/@maxCount/number(.)
            return
                if ($raw ne -1 and $raw lt $minCount) then $minCount else $raw
        let $resourceName := $d/@name
        let $candMembers := 
            if ($d/self::gx:memberFile) then $memberFiles 
            else if ($d/self::gx:memberFolder) then $memberFolders 
            else $members   
        let $resourceKind :=            
            if ($d/self::gx:memberFile) then 'file' 
            else if ($d/self::gx:memberFolder) then 'folder' 
            else ()
        let $found := $candMembers[matches(., $d/@regex, 'i')]
        let $foundPaths := $found ! concat($folderPath, '/', .)
        let $count := count($found)
        let $result_minCount :=
            if ($minCount eq 0) then () 
            else
                let $ok := $count ge $minCount
                let $colour := if ($ok) then 'green' else 'red'            
                let $additionalAtts := ()
                let $additionalElems := ()
                return
                    f:constructError_folderContentCount(
                        $colour, $_constraint, $d/@minCount, $resourceName, $foundPaths, $additionalAtts, $additionalElems)
(:        

                let $ok := $count ge $minCount
                let $elemName := if ($ok) then 'gx:green' else 'gx:red'
                let $msg := if ($ok) then $d/i:getOkMsg((., ..), 'minCount', ())
                            else $d/i:getErrorMsg((., ..), 'minCount', ())
                return
                    element {$elemName} {
                        $msg ! attribute msg {.},
                        attribute constraintComp {'FolderContentMinCount'},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        attribute minCount {$d/@minCount},
                        attribute valueCount {$count},
                        attribute resourceName {$d/@name},
                        $resourceKind ! attribute resourceKind {.}
                    }
:)                    
        let $result_maxCount :=
            if ($maxCount eq -1) then () 
            else
                let $ok := $count le $maxCount
                let $colour := if ($ok) then 'green' else 'red'            
                let $additionalAtts := ()
                let $additionalElems := ()
                return
                    f:constructError_folderContentCount(
                        $colour, $_constraint, $d/@maxCount, $resourceName, $foundPaths, $additionalAtts, $additionalElems)
(:                
                let $elemName := if ($ok) then 'gx:green' else 'gx:red'
                let $msg := if ($ok) then $d/i:getOkMsg((., ..), 'maxCount', ())
                            else $d/i:getErrorMsg((., ..), 'maxCount', ())
                return
                    element {$elemName} {
                        $msg ! attribute msg {.},
                        attribute constraintComp {'FolderContentMaxCount'},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        attribute maxCount {$d/@maxCount},
                        attribute valueCount {$count},
                        attribute resourceName {$d/@name},
                        $resourceKind ! attribute resourceKind {.}
                    }
:)                    
        return ($result_minCount, $result_maxCount)
        
    let $results_hash :=
        for $d in $_constraint/*[@md5, @sha1, @sha256][self::gx:memberFile, self::gx:memberFolder]
        let $resourceName := $d/@name
        let $candMembers := $memberFiles 
        let $found := $candMembers[matches(., $d/@regex, 'i')]
        let $foundPaths := $found ! concat($folderPath, '/', .)
        
        for $expectedHashKeys in $d/(@md5, @sha1, @sha256)
        let $hashKind := $expectedHashKeys/local-name(.)
        let $hashesMap := 
            map:merge($foundPaths ! map:entry(i:hashKey(., $expectedHashKeys/local-name(.)), .))
(:                
                let $fileContent := file:read-binary($path)
                let $rawHash :=
                    typeswitch($hashExp)
                    case attribute(md5) return hash:md5($fileContent)
                    case attribute(sha1) return hash:sha1($fileContent)
                    case attribute(sha256) return hash:sha256($fileContent)
                    default return error()
                return
                    map:entry(string(xs:hexBinary($rawHash)), $path)
            )
:)            
        (: the hash keys found for this name pattern :)
        let $foundHashKeys := map:keys($hashesMap)
        
        (: OK, if for every hash in the attribute value a matching file is found :)
        for $expectedHashKey in tokenize($expectedHashKeys)
        let $constraintComponent := concat('FolderContent-', $expectedHashKeys/local-name(.))
        let $fileForExpectedHashKey := $hashesMap($expectedHashKey)
        let $colour := if ($fileForExpectedHashKey) then 'green' else 'red'
        return        
            f:constructError_folderContentHash($colour, 
                                               $_constraint, 
                                               $expectedHashKeys, 
                                               $expectedHashKey, 
                                               $resourceName, 
                                               $foundHashKeys, 
                                               $foundPaths, (), ())

(:        
        return
            if ($file) then
                let $msg := i:getOkMsg(($d, $d/..), $hashKind, 
                            concat('Expected ', $hashKind, ' value found.'))
                return
                    <gx:green>{
                        $msg ! attribute msg {.},
                        attribute constraintComp {$constraintComponent},
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
                    <gx:red>{
                        $msg ! attribute msg {.},
                        attribute constraintComp {$constraintComponent},
                        $_constraint/@id/attribute constraintID {.},
                        $_constraint/@label/attribute constraintLabel {.},
                        attribute {$hashExp/name()} {$hashExpItem},
                        $actValueAtt,
                        attribute resourceName {$name}
                    }</gx:red>
:)
    let $errors := ($results_folderContentClosed, $results_cardinality, $results_hash)
    return
        if ($errors) then $errors
        else $_constraint/
            <gx:green>{
                attribute constraintComp {local-name()},
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
                    ($elem/@maxCount/replace(., '\*', '-1'), 1)[1] ! xs:integer(.) 
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
        for $ign in $folderContent/@ignoredMembers/tokenize(., ',\s*')
        return
            <gx:ignoreMember name="{$ign}" regex="{i:glob2regex($ign)}"/>
        ,
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

(:~
 : Writes a validation result for constraint component FolderContentClosed.
 :
 : @param colour the colour of the result
 : @param constraintElem the element containing the attributes and child elements declaring the constraint
 : @param paths the file paths of violating resources 
 : @param additionalAtts additional attributes to be included in the result
 : @param additionalElems additional elements to be included in the result 
 : @return an element representing a 'red' or 'green' validation result
 :)
declare function f:constructError_folderContentClosed($colour as xs:string,
                                                      $constraintElem as element(),
                                                      $paths as xs:string*,
                                                      $additionalAtts as attribute()*,
                                                      $additionalElems as element()*                                                    
                                                     ) 
        as element() {
    let $constraintComp := 'FolderContentClosed'
    let $elemName := 'gx:' || $colour
    let $msg := 
        if ($colour eq 'red') then i:getErrorMsg($constraintElem, 'closed', 'Unexpected folder contents.')
        else i:getOkMsg($constraintElem, 'closed', ())
    let $constraintId := $constraintElem/@id
    let $resourceShapeId := $constraintElem/@resourceShapeID
    
    let $valueElems :=
        for $path in $paths
        let $kind := if (i:resourceIsDir($path)) then 'folder' else 'file'
        return
            <gx:value resoureKind="{$kind}">{$path}</gx:value>
    
    return
        element {$elemName} {
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            $additionalAtts,
            $additionalElems,
            $valueElems
        }
};

(:~
 : Writes a validation result for constraint components FolderContentMinCount and FolderContentMaxCount.
 :
 : @param colour the colour of the result
 : @param constraintElem the element containing the attributes and child elements declaring the constraint
 : @param constraint attribute representing the maximum or minimum count allowed
 : @param resourceName the resource name or name pattern used by the constraint declaration
 : @param paths the file paths of resources matching the name or name pattern 
 : @param additionalAtts additional attributes to be included in the result
 : @param additionalElems additional elements to be included in the result 
 : @return an element representing a 'red' or 'green' validation result
 :)
declare function f:constructError_folderContentCount($colour as xs:string,
                                                     $constraintElem as element(),
                                                     $constraint as attribute(),
                                                     $resourceName as xs:string,
                                                     $paths as xs:string*,
                                                     $additionalAtts as attribute()*,
                                                     $additionalElems as element()*                                                    
                                                     ) 
        as element() {
    let $elemName := 'gx:' || $colour        
    let $constraintComp :=
        $constraintElem/f:firstCharToUpperCase(local-name(.)) ||
        $constraint/f:firstCharToUpperCase(local-name(.))    
    let $msg := 
        if ($colour eq 'red') then i:getErrorMsg($constraintElem, 'minCount', ())
        else i:getOkMsg($constraintElem, 'minCount', ())
    let $constraintId := $constraintElem/@id
    let $resourceShapeId := $constraintElem/@resourceShapeID
    
    let $valueElems :=
        for $path in $paths
        let $kind := if (i:resourceIsDir($path)) then 'folder' else 'file'
        return
            <gx:value resoureKind="{$kind}">{$path}</gx:value>
    let $actCount := count($paths)            
    
    return
        element {$elemName} {
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},    
            attribute resourceName {$resourceName},
            $constraint,
            attribute actCount {$actCount},
            $additionalAtts,
            $additionalElems,
            $valueElems[$colour eq 'red']
        }
};



(:~
 : Writes a validation result for constraint components FolderContentMinCount and FolderContentMaxCount.
 :
 : @param colour the colour of the result
 : @param constraintElem the element containing the attributes and child elements declaring the constraint
 : @param constraint attribute representing the maximum or minimum count allowed
 : @param resourceName the resource name or name pattern used by the constraint declaration
 : @param paths the file paths of resources matching the name or name pattern 
 : @param additionalAtts additional attributes to be included in the result
 : @param additionalElems additional elements to be included in the result 
 : @return an element representing a 'red' or 'green' validation result
 :)
declare function f:constructError_folderContentHash($colour as xs:string,
                                                    $constraintElem as element(),
                                                    $constraint as attribute(),
                                                    $constraintValue as xs:string,
                                                    $resourceName as xs:string,
                                                    $foundHashKeys as xs:string*,                                                   
                                                    $paths as xs:string*,
                                                    $additionalAtts as attribute()*,
                                                    $additionalElems as element()*                                                    
                                                    ) 
        as element() {

    let $elemName := 'gx:' || $colour
    let $constraintComp :=
        $constraintElem/f:firstCharToUpperCase(local-name(.)) ||
        $constraint/f:firstCharToUpperCase(local-name(.))
    let $constraintId := $constraintElem/@id
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $hashKind := $constraint/local-name(.)
    let $actValueAtt := 
        if (count($paths) gt 1) then () else attribute {concat($hashKind, 'Found')} {$foundHashKeys}

    let $msg := 
        if ($colour eq 'green') then 
            i:getOkMsg(($constraint/.., $constraint/../..), $hashKind, concat('Expected ', $hashKind, ' value found.'))
        else
            i:getErrorMsg(($constraint/.., $constraint/../..), $hashKind, concat('Not expected  ', $hashKind, ' value.'))
    let $constraintId := $constraintElem/@id
    let $resourceShapeId := $constraintElem/@resourceShapeID
            
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            attribute resourceName {$resourceName},
            $actValueAtt,
            attribute {$constraint/name()} {$constraintValue}
        }
};        