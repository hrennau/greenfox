(:
 : -------------------------------------------------------------------------
 :
 : folderSimilarConstraint.xqm - validates a resource against a FolderSimilar constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at
    "log.xqm",
    "greenfoxUtil.xqm";
    
import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at
    "linkDefinition.xqm",
    "linkResolution.xqm",
    "linkValidation.xqm";
    
import module namespace vr="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at
    "validationResult.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a Folder Similar constraint.
 :
 : @param contextURI the file path of the context folder 
 : @param constraintElem the element declaring the constraint
 : @param context the processing context
 : @return a set of validation results
 :)
declare function f:validateFolderSimilar($contextURI as xs:string,
                                         $constraintElem as element(gx:folderSimilar),
                                         $context as map(xs:string, item()*))
        as element()* {

    let $evaluationContext := $context?_evaluationContext
    
    (: Link resolution :)
    let $ldo := link:getLinkDefObject($constraintElem, $context)
    let $lros := link:resolveLinkDef($ldo, 'lro', $contextURI, (), $context, ())
                 [not(?targetURI ! i:fox-resource-is-file(.))] (: ignore files :)
    let $targetFolders := $lros?targetURI    

    (: Check the number of items representing the folders with which to compare :)
    let $results_count := f:validateFolderSimilar_count(
        $constraintElem, $ldo, $targetFolders, $context)
    
    (: Check similarity :)
    let $results_comparison := f:validateFolderSimilar_similarity(
        $contextURI, $constraintElem, $ldo, $targetFolders, $evaluationContext)
    return
        ($results_count, $results_comparison)
                   
};   

(:~
 : Validates the target count of a resource shape or a focus node.
 :
 : @param constraintElem element declaring the constraints
 : @param targetItems the target resources obtained by resolving the target declaration
 : @param context the processing context
 : @return validation results obtained for the target count constraints
 :) 
declare function f:validateFolderSimilar_count($constraintElem as element(), 
                                               $ldo as map(*)?,
                                               $targetItems as item()*,
                                               $context as map(xs:string, item()*))
        as element()* {
    let $contextPath := $context?_contextPath        
    let $targetCount := count($targetItems)    
    let $countConstraints := $constraintElem/(@count, @minCount, @maxCount)
    return if (empty($countConstraints)) then () else
    
    for $cmp in $countConstraints
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        default return error(QName((), 'INVALID_SCHEMA'), 
            concat('Unknown count comparison operator: ', $cmp))
    let $colour := if ($cmpTrue($targetCount, $cmp)) then 'green' else 'red'
    return        
        vr:validationResult_folderSimilar_count(
            $colour, $ldo, $constraintElem, $cmp, $targetItems, $contextPath)
};

(:~
 : Validates the similarity between a folder and other folders.
 :
 : @param contextURI the file path of the folder to be checked
 : @param constraintElem element declaring the constraints
 : @param targetFolders the target folders with which to compare
 : @param evaluationContext the evaluation context
 : @return validation results obtained for the target count constraints
 :) 
declare function f:validateFolderSimilar_similarity(
                                $contextURI as xs:string,
                                $constraintElem as element(gx:folderSimilar),
                                $ldo as map(*)?,                                
                                $targetFolders as xs:string*,
                                $evaluationContext as map(*))
        as element()* {
    let $config := f:getFolderSimilarityConfig($constraintElem)
    
    for $targetFolder in $targetFolders
    let $results12 := f:compareFolders($contextURI, $targetFolder, $config, "12", $evaluationContext)
    let $results21 := f:compareFolders($targetFolder, $contextURI, $config, "21", $evaluationContext)
    let $keys12 := map:keys($results12)
    let $keys21 := map:keys($results21)
    return
        if (empty($keys12) and empty($keys21)) then 
            vr:validationResult_folderSimilar('green', $targetFolder, $ldo, $constraintElem, ())
        else
            let $values := (
                if (not(map:contains($results12, 'files1Only'))) then () else
                    $results12?files1Only ! <gx:value kind="file" where="thisFolder">{.}</gx:value>
                ,
                if (not(map:contains($results12, 'dirs1Only'))) then () else
                    $results12?dirs1Only ! <gx:value kind="folder" where="thisFolder">{.}</gx:value>
                ,
                if (not(map:contains($results21, 'files1Only'))) then () else
                    $results21?files1Only ! <gx:value kind="file" where="otherFolder">{.}</gx:value>
                ,
                if (not(map:contains($results21, 'dirs1Only'))) then () else
                    $results21?dirs1Only ! <gx:value kind="folder" where="otherFolder">{.}</gx:value>
            )
            return
                vr:validationResult_folderSimilar('red', $targetFolder, $ldo, $constraintElem, $values)
};

(:~
 : Compares two folders, returning files and folders occurring in the first one.
 : 
 : @param folder1 the first folder
 : @param folder2 the second folder
 : @param config configuration of the comparison, specifying files and folders to be ignored
 : @param direction specifies if $folder1 is the local folder (12) or the target folder (21)
 : @return a map with possible entries 'files1Only' and 'drs1Only'
 :)
declare function f:compareFolders($folder1 as xs:string, 
                                  $folder2 as xs:string, 
                                  $config as element(),
                                  $direction as xs:string,   (: '12' or '21' :)
                                  $evaluationContext as map(xs:QName, item()*))
        as item()* {
    let $ignoredFiles :=
        $config/(ignoredFiles, if ($direction eq '12') then ignoredFilesHere else ignoredFilesThere)/*
    let $ignoredFolders := 
        $config/(ignoredFolders, if ($direction eq '12') then ignoredFoldersHere else ignoredFoldersThere)/*

    let $files1 := i:resourceChildResources($folder1, ()) ! concat($folder1, '/', .)[i:fox-resource-is-file(.)]  
    let $files2 := i:resourceChildResources($folder2, ()) ! concat($folder2, '/', .)[i:fox-resource-is-file(.)]
    let $dirs1 := i:resourceChildResources($folder1, ()) ! concat($folder1, '/', .)[i:fox-resource-is-dir(.)]  
    let $dirs2 := i:resourceChildResources($folder2, ()) ! concat($folder2, '/', .)[i:fox-resource-is-dir(.)]
    
    let $fileNames1 := $files1 ! replace(., '^.*[/\\]', '')
    let $fileNames2 := $files2 ! replace(., '^.*[/\\]', '')
    let $fileNames1Only := $fileNames1[not(. = $fileNames2)]
        [   
            not(some $ignoredFile in $ignoredFiles satisfies 
                matches(., $ignoredFile/@regex, 'i'))
        ]
    let $dirNames1 := $dirs1 ! replace(., '^.*[/\\]', '')
    let $dirNames2 := $dirs2 ! replace(., '^.*[/\\]', '')
    let $dirNames1Only := $dirNames1[not(. = $dirNames2)]
       [
            not(some $ignoredFile in $ignoredFolders satisfies 
                matches(., $ignoredFile/@regex, 'i'))]    
    return
        map:merge((
            if (empty($fileNames1Only)) then () else map{'files1Only': $fileNames1Only},
            if (empty($dirNames1Only)) then () else map{'dirs1Only': $dirNames1Only}
        ))
};

(:~
 : Writes a configuration capturing details of a FolderSimilar constraint.
 : The configuration contains regular expressions matched by the names of
 : files and folders to be ignored.
 :
 : @param folderSimilar an element declaring a Folder Similar constraint
 : @return a configuration
 :) 
declare function f:getFolderSimilarityConfig($folderSimilar as element(gx:folderSimilar))
        as element() {
    let $ignoredFiles :=
        for $elem in $folderSimilar/gx:skipFiles    
        for $name in $elem/@names/tokenize(.)
        let $regex := $name ! i:glob2regex(.)
        return 
            <ignoredFile name="{$name}" regex="{$regex}">{
                $elem/@where
            }</ignoredFile>
    let $ignoredFolders :=
        for $elem in $folderSimilar/gx:skipFolders    
        for $name in $elem/@names/tokenize(.)
        let $regex := $name ! i:glob2regex(.)
        return 
            <ignoredFolder name="{$name}" regex="{$regex}">{
                $elem/@where
            }</ignoredFolder>
            
    let $ignoredFilesAny := $ignoredFiles[not(@where)]            
    let $ignoredFilesHere := $ignoredFiles[@where eq 'here']
    let $ignoredFilesThere := $ignoredFiles[@where eq 'there']
    let $ignoredFoldersAny := $ignoredFolders[not(@where)]            
    let $ignoredFoldersHere := $ignoredFolders[@where eq 'here']
    let $ignoredFoldersThere := $ignoredFolders[@where eq 'there']
            
    return
        <config>{
            <ignoredFiles>{$ignoredFilesAny}</ignoredFiles>[$ignoredFilesAny],
            <ignoredFilesHere>{$ignoredFilesHere}</ignoredFilesHere>[$ignoredFilesHere],
            <ignoredFilesThere>{$ignoredFilesThere}</ignoredFilesThere>[$ignoredFilesThere],

            <ignoredFolders>{$ignoredFoldersAny}</ignoredFolders>[$ignoredFoldersAny],
            <ignoredFoldersHere>{$ignoredFoldersHere}</ignoredFoldersHere>[$ignoredFoldersHere],
            <ignoredFoldersThere>{$ignoredFoldersThere}</ignoredFoldersThere>[$ignoredFoldersThere]
        }</config>
};

