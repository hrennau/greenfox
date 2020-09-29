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
 : Validates a folder against FolderContent constraints.
 :
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateFolderContent($constraintElem as element(gx:folderContent), 
                                         $context as map(*)) 
        as element()* {

    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    return

    (: write map mapping names patterns to regex values :)    
    let $nameRegexMap := f:getRegexMap(
        $constraintElem//@name,
        $constraintElem/(@ignoredMembers, .//@names))
        
    (: determine member file names, member folder names :)
    let $members := i:resourceChildResources($contextURI, '*') ! replace(., '[/\\]$', '')
    let $memberFiles := $members[i:fox-resource-is-file(concat($contextURI, '/', .))]
    let $memberFolders := $members[not(. = $memberFiles)]

    (: results: folder closed :)
    let $results_folderContentClosed := f:validateFolderContent_closed(
        $contextURI, $constraintElem, $nameRegexMap, $memberFiles, $memberFolders, $context)
    (: results: counts :)
    let $results_counts := f:validateFolderContentCounts(
        $contextURI, $constraintElem, $nameRegexMap, $memberFiles, $memberFolders, $context)
    (: results: hash keys :)        
    let $results_hash := f:validateFolderContent_hash(
        $contextURI, $constraintElem, $nameRegexMap, $memberFiles, $context)
    return ($results_folderContentClosed, $results_counts, $results_hash)
};

(:~
 : Validates FolderContentFolderClosed constraint.
 :
 : @param contextURI the file path of the folder
 : @param constraintElem the schema element representing the constraint
 : @param nameRegexMap a map associating all relevant glob names with their regex 
 : @param memberFiles names of the member files of the folder
 : @param memberFolders names of the member folders of the folder
 : @return validation results
 :)
 declare function f:validateFolderContent_closed($contextURI as xs:string,
                                                 $constraintElem as element(),
                                                 $nameRegexMap as map(xs:string, xs:string),
                                                 $memberFiles as xs:string*,
                                                 $memberFolders as xs:string*,
                                                 $context as map(xs:string, item()*))
        as element()* {
    if (not($constraintElem/@closed eq 'true')) then () else

    let $ignoredRegexs := $constraintElem/@ignoredMembers/tokenize(.) ! $nameRegexMap(.)
    let $unexpectedMembers :=
        for $member in ($memberFiles, $memberFolders)
            [not(some $regex in $ignoredRegexs satisfies matches(., $regex, 'i'))]
        let $names := $constraintElem/(
            gx:member/@name/string(), 
            gx:members/@name/tokenize(.),
            if ($member = $memberFiles) then (
                gx:memberFile/@name/string(),
                gx:memberFiles/@names/tokenize(.))
            else (
                gx:memberFolder/@name/string(),
                gx:memberFolders/@names/tokenize(.)
            )) => distinct-values()
        let $regexs := $names ! $nameRegexMap(.)            
        let $expected := some $r in $regexs satisfies matches($member, $r, 'i')
        where not($expected)
        return $member
    let $colour := if (exists($unexpectedMembers)) then 'red' else 'green'      
    return        
        result:constructError_folderContentClosed(
            $colour, $constraintElem, $constraintElem/@closed, $context, $unexpectedMembers, (), ())        
};        

(:~
 : Validates FolderContentCount constraints.
 :
 : @param contextURI the file path of the folder
 : @param constraintElem the schema element representing the constraint
 : @param nameRegexMap a map associating all relevant glob names with their regex  
 : @param memberFiles names of the member files of the folder
 : @param memberFolders names of the member folders of the folder
 : @return validation results
 :)
declare function f:validateFolderContentCounts($contextURI as xs:string,
                                               $constraintElem as element(),   
                                               $nameRegexMap as map(xs:string, xs:string),
                                               $memberFiles as xs:string*,
                                               $memberFolders as xs:string*,
                                               $context as map(xs:string, item()*))                                               
        as element()* {
    (: Loop over constraint components :)
    for $d in $constraintElem/(
        gx:member, gx:members, 
        gx:memberFile, gx:memberFiles, 
        gx:memberFolder, gx:memberFolders,
        gx:excludedMember, gx:excludedMembers, 
        gx:excludedMemberFile, gx:excludedMemberFiles,
        gx:excludedMemberFolder, gx:excludedMemberFolders)
    let $resourceNames := $d/(@name, @names/tokenize(.))
    
    (: Which members must be counted?
         Dependent on the element name it is files, folders, or both :)
    let $relevantMembers :=
        typeswitch($d)
        case element(gx:memberFile) | element(gx:memberFiles) |
             element(gx:excludedMemberFile) | element(gx:excludedMemberFiles)
             return $memberFiles
        case element(gx:memberFolder) | element(gx:memberFolders) |
             element(gx:excludedMemberFolder) | element(gx:excludedMemberFolders)
             return $memberFolders
        default return ($memberFiles, $memberFolders)
    
    (: Loop over resource names used by member nodes:
         count matching members and compare with constraints
     :)
    for $resourceName in $resourceNames    
    let $regex := $nameRegexMap($resourceName)
    let $found := $relevantMembers[matches(., $regex, 'i')]
    let $count := count($found)
    return
        (: member exclusion :)
        typeswitch($d)
        case element(gx:excludedMemberFile) | element(gx:excludedMemberFiles) |
             element(gx:excludedMemberFolder) | element(gx:excludedMemberFolders) |
             element(gx:excludedMember) | element(gx:excludedMembers) return

            let $colour := if ($count gt 0) then 'red' else 'green'
            return
                result:constructError_folderContentCount($colour, $constraintElem, $d, 
                    'FolderContentExcluded', $resourceName, $found, (), (), $context)
                    
        (: cardinality constraints :)            
        default return    
            let $countAtts := $d/(@count, @minCount, @maxCount) return
            
            (: explicit constraints :)
            if ($countAtts) then
                let $fn_check := function($att, $count) {
                    typeswitch($att)
                    case attribute(count) return $count = $att
                    case attribute(minCount) return $count >= $att
                    case attribute(maxCount) return $count <= $att
                    default return error()
                }
                for $att in $countAtts
                let $colour := if ($fn_check($att, $count)) then 'green' else 'red'
                return
                    result:constructError_folderContentCount(
                        $colour, $constraintElem, $att, (), $resourceName, $found, (), (), $context)
                        
            (: implicit constraints :)                        
            else
                let $colour := if ($count eq 1) then 'green' else 'red'
                return
                    result:constructError_folderContentCount($colour, $constraintElem, $d, 
                        'FolderContentCount', $resourceName, $found, 
                        attribute implicitCount {1}, (), $context) 
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
                                              $nameRegexMap as map(xs:string, xs:string),                                              
                                              $memberFiles as xs:string*,
                                              $context as map(xs:string, item()*))                                             
        as element()* {
        for $d in $constraintElem/*[@md5, @sha1, @sha256][self::gx:memberFile, self::gx:memberFolder]
        let $resourceName := $d/@name
        let $regex := $resourceName ! $nameRegexMap(.)
        let $found := $memberFiles[matches(., $regex, 'i')]
        let $foundPaths := $found ! concat($contextURI, '/', .)
        
        for $hashAtt at $pos in $d/(@md5, @sha1, @sha256)
        let $hashKind := $hashAtt/local-name(.)
        let $foundHashKeys := $foundPaths ! i:hashKey(., $hashKind)
        for $expectedHashKey in tokenize($hashAtt)
        let $colour := if ($expectedHashKey = $foundHashKeys) then 'green' else 'red'
        return        
            result:constructError_folderContentHash($colour, 
                                                    $constraintElem,
                                                    $hashAtt,
                                                    $expectedHashKey, 
                                                    $context,
                                                    $resourceName, 
                                                    $foundHashKeys, 
                                                    $found, (), ())

        (:
        (: for each matching file path a map entry: 
             hash key -> file path :)
        let $hashesMap := map:merge($foundPaths ! map:entry(i:hashKey(., $hashKind), .))
            
        (: all hash keys of the current kind (e.g. all md5 hash keys) found for this name pattern :)
        let $foundHashKeys := map:keys($hashesMap)
        
        (: write a result for every hash in the attribute value: green if a matching file is found :)
        for $expectedHashKey in tokenize($hashAtt)
        let $fileForExpectedHashKey := $hashesMap($expectedHashKey)
        let $colour := if ($fileForExpectedHashKey) then 'green' else 'red'
        return        
            result:constructError_folderContentHash($colour, 
                                                    $constraintElem,
                                                    $hashAtt,
                                                    $expectedHashKey, 
                                                    $resourceName, 
                                                    $foundHashKeys, 
                                                    $found, (), ())
        :)                                                    
};

(:~
 : Creates a map which associates glob values with the corresponding
 : regex values.
 :
 : @param nameValues glob values
 : @param namelistValues whitespace separated lists of glob values
 : @return a map associating each glob value with the corresponding regex
 :)
declare function f:getRegexMap($nameValues as xs:string*,
                               $namelistValues as xs:string*)
        as map(xs:string, xs:string) {
    let $names := ($nameValues, $namelistValues ! tokenize(.)) => distinct-values()
    return map:merge($names ! map:entry(., i:glob2regex(.)))
};        
