(:
 : -------------------------------------------------------------------------
 :
 : folderContentValidator.xqm - functions for validating folder content
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at 
    "tt/_request.xqm",
    "tt/_foxpath.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at
    "expressionEvaluator.xqm",
    "expressionValueConstraint.xqm",
    "fileValidator.xqm",
    "greenfoxUtil.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at
    "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a FolderContent constraint.
 :
 : @param contextURI the file path of the file containing the initial context item 
 : @param contextDoc the XML document containing the initial context item
 : @param contextItem the initial context item to be used in expressions
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateFolderContent($contextURI as xs:string, 
                                         $constraintElem as element(gx:folderContent), 
                                         $context as map(*)) 
        as element()* {
        
    (: determine expectations :)
    let $_constraintElem := f:validateFolderContent_compile($constraintElem)
    let $closed := $_constraintElem/@closed
    let $msgFolderContent := $_constraintElem/@msg

    (: determine member file names, member folder names :)
    let $members := i:resourceChildResources($contextURI, '*') ! replace(., '[/\\]$', '')
    let $memberFiles := $members[i:fox-resource-is-file(concat($contextURI, '/', .))]
    let $memberFolders := $members[not(. = $memberFiles)]

    (: results: folder closed :)
    let $results_folderContentClosed := f:validateFolderContent_closed(
        $contextURI, $_constraintElem, $memberFiles, $memberFolders)
    (: results: counts :)
    let $results_counts := f:validateFolderContentCounts(
        $contextURI, $_constraintElem, $memberFiles, $memberFolders)
    (: results: hash keys :)        
    let $results_hash := f:validateFolderContent_hash(
        $contextURI, $_constraintElem, $memberFiles)
    let $errors := ($results_folderContentClosed, $results_counts, $results_hash)
    
    return
        if ($errors) then $errors
        else $_constraintElem/
            <gx:green>{
                attribute constraintComp {local-name()},
                @id/attribute constraintID {.},
                @label/attribute constraintLabel {.},
                attribute folderPath {$contextURI}
            }</gx:green>
        
    
};

(:~
 : Validates FolderContentFolderClosed constraint.
 :
 : @param contextURI the file path of the folder
 : @param constraintElem the schema element representing the constraint
 : @param memberFiles names of the member files of the folder
 : @param memberFolders names of the member folders of the folder
 : @return validation results
 :)
 declare function f:validateFolderContent_closed($contextURI as xs:string,
                                                 $constraintElem as element(),
                                                 $memberFiles as xs:string*,
                                                 $memberFolders as xs:string*)
        as element()* {
    if (not($constraintElem/@closed eq 'true')) then () else
        
    let $unexpectedMembers :=
        for $member in ($memberFiles, $memberFolders)
        let $descriptors := $constraintElem/(
            gx:member, gx:ignoreMember,
            if ($member = $memberFiles) then gx:memberFile else gx:memberFolder)
        let $expected := 
            some $d in $descriptors satisfies matches($member, $d/@regex, 'i')
        where not($expected)
        return $contextURI || '/' || $member
    let $colour := if (exists($unexpectedMembers)) then 'red' else 'green'      
    return        
        result:constructError_folderContentClosed($colour, $constraintElem, $unexpectedMembers, (), ())        
};        

(:~
 : Validates FolderContentMinCount and FolderContentMaxCount constraints.
 :
 : @param contextURI the file path of the folder
 : @param constraintElem the schema element representing the constraint
 : @param memberFiles names of the member files of the folder
 : @param memberFolders names of the member folders of the folder
 : @return validation results
 :)
declare function f:validateFolderContentCounts($contextURI as xs:string,
                                               $constraintElem as element(),                                               
                                               $memberFiles as xs:string*,
                                               $memberFolders as xs:string*)
        as element()* {
    for $d in $constraintElem/(* except gx:ignoreMember)
    let $minCount := $d/@minCount/number(.)
    let $maxCount := 
        let $raw := $d/@maxCount/number(.)
        return if ($raw ne -1 and $raw lt $minCount) then $minCount else $raw
    let $resourceName := $d/@name
    let $relevantMembers := 
        if ($d/self::gx:memberFile) then $memberFiles 
        else if ($d/self::gx:memberFolder) then $memberFolders 
        else ($memberFiles, $memberFolders)   
    let $found := $relevantMembers[matches(., $d/@regex, 'i')]
    let $foundPaths := $found ! concat($contextURI, '/', .)
    let $count := count($found)
    return (        
        (: results: minCount :)
        if ($minCount eq 0) then () else 
            let $ok := $count ge $minCount
            let $colour := if ($ok) then 'green' else 'red'            
            return
                result:constructError_folderContentCount(
                    $colour, $constraintElem, $d/@minCount, $resourceName, $foundPaths, (), ())
        ,                        
        (: results: maxCount :)                        
        if ($maxCount eq -1) then () else
            let $ok := $count le $maxCount
            let $colour := if ($ok) then 'green' else 'red'            
            return
                result:constructError_folderContentCount(
                    $colour, $constraintElem, $d/@maxCount, $resourceName, $foundPaths, (), ())
    )        
};

(:~
 : Validates FolderContentHash constraints.
 :
 : @param contextURI the file path of the folder
 : @param constraintElem the schema element representing the constraint
 : @param memberFiles names of the member files of the folder
 : @return validation results
 :)
declare function f:validateFolderContent_hash($contextURI as xs:string,
                                              $constraintElem as element(), 
                                              $memberFiles as xs:string*)
        as element()* {
        for $d in $constraintElem/*[@md5, @sha1, @sha256][self::gx:memberFile, self::gx:memberFolder]
        let $resourceName := $d/@name
        let $relevantMembers := $memberFiles 
        let $found := $relevantMembers[matches(., $d/@regex, 'i')]
        let $foundPaths := $found ! concat($contextURI, '/', .)
        
        for $expectedHashKeys in $d/(@md5, @sha1, @sha256)
        let $hashKind := $expectedHashKeys/local-name(.)
        
        (: map: hashkey -> file path :)
        let $hashesMap := 
            map:merge($foundPaths ! map:entry(i:hashKey(., $expectedHashKeys/local-name(.)), .))
            
        (: all hash keys of the current kind (md5|sha1|sha256) found for this name pattern :)
        let $foundHashKeys := map:keys($hashesMap)
        
        (: write a result for every hash in the attribute value: green if a matching file is found :)
        for $expectedHashKey in tokenize($expectedHashKeys)
        let $fileForExpectedHashKey := $hashesMap($expectedHashKey)
        let $colour := if ($fileForExpectedHashKey) then 'green' else 'red'
        return        
            result:constructError_folderContentHash($colour, 
                                                    $constraintElem, 
                                                    $expectedHashKeys, 
                                                    $expectedHashKey, 
                                                    $resourceName, 
                                                    $foundHashKeys, 
                                                    $foundPaths, (), ())
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

(:
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
        let $kind := if (i:fox-resource-is-dir($path)) then 'folder' else 'file'
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
        let $kind := if (i:fox-resource-is-dir($path)) then 'folder' else 'file'
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
:)