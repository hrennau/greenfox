(:
 : -------------------------------------------------------------------------
 :
 : folderSimilarConstraint.xqm - validates a resource against a FolderSimilar constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFolderSimilar($filePath as xs:string,
                                         $constraintElem as element(gx:folderSimilar),
                                         $context as map(xs:string, item()*))
        as element()* {

    (: The "context info" gives access to the context file path and the focus path :)        
    let $contextInfo := map:merge((
        $filePath ! map:entry('filePath', .)
    ))

    (: Adhoc addition of $filePath and $fileName :)
    let $evaluationContext := $context?_evaluationContext
    let $evaluationContext := map:put($evaluationContext, QName((),'filePath'), $filePath)
    let $evaluationContext := map:put($evaluationContext, QName((), 'fileName'), replace($filePath, '.*[/\\]', ''))
    let $context := map:put($context, '_evaluationContext', $evaluationContext)
    
    let $otherFoxpath := $constraintElem/@otherFoxpath
 
    (: Determine items representing the folders with which to compare;
       each item should be a file path :) 
    let $otherFolders := f:validateFolderContentsSimilar_otherFolderReps($filePath, $constraintElem, $context)
    
    (: Check the number of items representing the documents with which to compare :)
    let $results_count := 
        f:validateFolderSimilarCount($otherFolders, $constraintElem, $contextInfo)
    
    let $results_comparison :=
        let $config := f:validateFolderSimilar_config($constraintElem)
        for $otherFolder in $otherFolders
        let $additionalAtts := attribute otherFolder {$otherFolder}
        (: compare 1 with 2 :)
        let $results12 := f:compareFolders($filePath, $otherFolder, $config, "12", $evaluationContext)
        let $results21 := f:compareFolders($otherFolder, $filePath, $config, "21", $evaluationContext)
        let $keys12 := map:keys($results12)
        let $keys21 := map:keys($results21)
        return
            if (empty($keys12) and empty($keys21)) then 
                f:validationResult_folderSimilar('green', $constraintElem, $constraintElem/@otherFoxpath, (), $additionalAtts, ())
            else
                let $values := (
                    if (not(map:contains($results12, 'files1Only'))) then ()
                    else
                        $results12?files1Only ! <gx:value kind="file" where="thisFolder">{.}</gx:value>
                    ,
                    if (not(map:contains($results12, 'dirs1Only'))) then ()
                    else
                        $results12?dirs1Only ! <gx:value kind="folder" where="thisFolder">{.}</gx:value>
                    ,
                    if (not(map:contains($results21, 'files1Only'))) then ()
                    else
                        $results21?files1Only ! <gx:value kind="file" where="otherFolder">{.}</gx:value>
                    ,
                    if (not(map:contains($results21, 'dirs1Only'))) then ()
                    else
                        $results21?dirs1Only ! <gx:value kind="folder" where="otherFolder">{.}</gx:value>
                )
                return
                    f:validationResult_folderSimilar('red', $constraintElem, $constraintElem/@otherFoxpath, (), $additionalAtts, $values)
                    
    return
        ($results_count, $results_comparison)
                   
};   

(:~
 : Validates a link count related constraint (LinkCountMinCount, LinkCountMaxCount, LinkCountCount).
 : It is not checked if the links can be resolved - only their number is considered.
 :
 : @param exprValue expression value producing the links
 : @param cmp link count related constraint
 : @param valueShape the value shape containing the constraint
 : @param contextInfo information about the resource context
 : @return a validation result, red or green
 :)
declare function f:validateFolderSimilarCount(
                                        $exprValue as item()*,
                                        $constraintElem as element(),
                                        $contextInfo as map(xs:string, item()*))
        as element()* {
    let $resultAdditionalAtts := ()
    let $resultOptions := ()
    
    let $valueCount := count($exprValue)
    let $countConstraints :=
        let $explicit := $constraintElem/(@count, @minCount, @maxCount)
        return
            if ($explicit) then $explicit else attribute count {1}
    for $cmp in $countConstraints
    let $cmpTrue :=
        typeswitch($cmp)
        case attribute(count) return function($count, $cmp) {$count = $cmp}        
        case attribute(minCount) return function($count, $cmp) {$count >= $cmp}        
        case attribute(maxCount) return function($count, $cmp) {$count <= $cmp}
        default return error(QName((), 'INVALID_SCHEMA'), concat('Unknown count comparison operator: ', $cmp))
    return        
        if ($cmpTrue($valueCount, $cmp)) then  
            f:validationResult_folderSimilarCount('green', $constraintElem, $cmp, $valueCount, 
                                                  $resultAdditionalAtts, (), $contextInfo, $resultOptions)
        else 
            let $values := $exprValue ! xs:string(.) ! <gx:value>{.}</gx:value>
            return
                f:validationResult_folderSimilarCount('red', $constraintElem, $cmp, $exprValue, 
                                                      $resultAdditionalAtts, $values, $contextInfo, $resultOptions)
};

(:~
 : Returns the items representing the other documents with which to compare.
 : The items may be nodes or URIs.
 :
 : @param filePath filePath of the context document
 : @param constraintElem the element representing the DocumentSimilar constraint
 : @param context the processing context
 :)
declare function f:validateFolderContentsSimilar_otherFolderReps(
                                                   $filePath as xs:string,
                                                   $constraintElem as element(),
                                                   $context as map(xs:string, item()*))
        as item()* {
    let $evaluationContext := $context?_evaluationContext
    let $otherFoxpath := $constraintElem/@otherFoxpath 
    return    
        if ($otherFoxpath) then 
            f:evaluateFoxpath($otherFoxpath, $filePath, $evaluationContext, true())
        else error()
};

declare function f:compareFolders($folder1 as xs:string, 
                                  $folder2 as xs:string, 
                                  $config as element(),
                                  $direction as xs:string,   (: '12' or '21' :)
                                  $evaluationContext as map(xs:QName, item()*))
        as item()* {
    let $files1 := i:resourceChildResources($folder1, ()) ! concat($folder1, '/', .)[i:fox-resource-is-file(.)]  
    let $files2 := i:resourceChildResources($folder2, ()) ! concat($folder2, '/', .)[i:fox-resource-is-file(.)]
    let $dirs1 := i:resourceChildResources($folder1, ()) ! concat($folder1, '/', .)[i:fox-resource-is-dir(.)]  
    let $dirs2 := i:resourceChildResources($folder2, ()) ! concat($folder2, '/', .)[i:fox-resource-is-dir(.)]
    (:
    let $files1 := f:evaluateFoxpath('*[is-file(.)]', $folder1, $evaluationContext, true())        
    let $files2 := f:evaluateFoxpath('*[is-file(.)]', $folder2, $evaluationContext, true())
    let $dirs1 := f:evaluateFoxpath('*[is-dir(.)]', $folder1, $evaluationContext, true())
    let $dirs2 := f:evaluateFoxpath('*[is-dir(.)]', $folder2, $evaluationContext, true())    
    :)
    
    let $fileNames1 := $files1 ! replace(., '^.*[/\\]', '')
    let $fileNames2 := $files2 ! replace(., '^.*[/\\]', '')
    let $fileNames1Only := $fileNames1[not(. = $fileNames2)]
         [$direction eq '12' and not(
            some $ignoredFile in $config/ignoredFiles1/ignoredFile1 satisfies matches(., $ignoredFile/@regex, 'i'))
          or $direction eq '21' and not(            
            some $ignoredFile in $config/ignoredFiles2/ignoredFile2 satisfies matches(., $ignoredFile/@regex, 'i'))          
         ]
    
    let $dirNames1 := $dirs1 ! replace(., '^.*[/\\]', '')
    let $dirNames2 := $dirs2 ! replace(., '^.*[/\\]', '')
    let $dirNames1Only := $dirNames1[not(. = $dirNames2)]
         [$direction eq '12' and not(
            some $ignoredFolder in $config/ignoredFolders1/ignoredFolder1 satisfies matches(., $ignoredFolder/@regex, 'i'))
          or $direction eq '21' and not(            
            some $ignoredFolder in $config/ignoredFolders2/ignoredFolder2 satisfies matches(., $ignoredFolder/@regex, 'i'))          
         ]
    return
        map:merge((
            if (empty($fileNames1Only)) then () else map{'files1Only': $fileNames1Only},
            if (empty($dirNames1Only)) then () else map{'dirs1Only': $dirNames1Only}
        ))
};

declare function f:validateFolderSimilar_config($folderSimilar as element(gx:folderSimilar))
        as element() {
    let $ignoredFiles :=
        for $name in string-join($folderSimilar/gx:skipFiles/@names, ' ') ! tokenize(.)
        let $regex := $name ! i:glob2regex(.)
        return <ignoredFile1 name="{$name}" regex="{$regex}"/>
        
    let $ignoredFolders :=
        for $name in string-join($folderSimilar/gx:skipFolders/@names, ' ') ! tokenize(.)
        let $regex := $name ! i:glob2regex(.)
        return <ignoredFolder1 name="{$name}" regex="{$regex}"/>

    let $ignoredOtherFiles :=
        for $name in string-join($folderSimilar/gx:skipForeignFiles/@names, ' ') ! tokenize(.)
        let $regex := $name ! i:glob2regex(.)
        return <ignoredFile2 name="{$name}" regex="{$regex}"/>
        
    let $ignoredOtherFolders :=
        for $name in string-join($folderSimilar/gx:skipForeignFolders/@names, ' ') ! tokenize(.)
        let $regex := $name ! i:glob2regex(.)
        return <ignoredFolder2 name="{$name}" regex="{$regex}"/>
        
    return
        <config>{
            <ignoredFiles1>{$ignoredFiles}</ignoredFiles1>,
            <ignoredFolders1>{$ignoredFolders}</ignoredFolders1>,            
            <ignoredFiles2>{$ignoredOtherFiles}</ignoredFiles2>,
            <ignoredFolders2>{$ignoredOtherFolders}</ignoredFolders2>
        }</config>
        

};

(: ============================================================================
 :
 :     f u n c t i o n s    c r e a t i n g    v a l i d a t i o n    r e s u l t s
 :
 : ============================================================================ :)

(:~
 : Writes a validation result for a DeepSimilar constraint.
 :
 : @param colour indicates success or error
 : @param constraintElem the element representing the constraint
 : @param constraint an attribute representing the main properties of the constraint
 : @param reasons strings identifying reasons of violation
 : @param additionalAtts additional attributes to be included in the validation result
 :) 
declare function f:validationResult_folderSimilar(
                                          $colour as xs:string,
                                          $constraintElem as element(gx:folderSimilar),
                                          $constraint as attribute(),
                                          $reasonCodes as xs:string*,
                                          $additionalAtts as attribute()*,
                                          $additionalElems as element()*)
        as element() {
    let $elemName := 'gx:' || $colour
    let $constraintComponent :=
        $constraintElem/f:firstCharToUpperCase(local-name(.)) ||
        $constraint/f:firstCharToUpperCase(local-name(.))
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintId := $constraintElem/@constraintID
    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraint/local-name(.), ())
        
    return
        element {$elemName}{
            $msg ! attribute msg {$msg},
            attribute constraintComp {$constraintComponent},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            if (empty($reasonCodes)) then () else attribute reasonCodes {$reasonCodes},
            $additionalAtts,
            $constraintElem/*,
            $additionalElems
        }        
};

(:~
 : Creates a validation result for a LinkCount related constraint (LinkMinCount,
 : LinkMaxCount, LinkCount.
 :
 : @param colour 'green' or 'red', indicating violation or conformance
 : @param valueShape the shape declaring the constraint
 : @param exprValue expression value producing the links
 : @param additionalAtts additional attributes to be included in the validation result
 : @param additionalElems additional elements to be included in the validation result 
 : @param contextInfo information about the resource context
 : @param options options controling details of the validation result
 : @return a validation result, red or green
 :)
declare function f:validationResult_folderSimilarCount(
                                          $colour as xs:string,
                                          $constraintElem as element(),
                                          $constraint as attribute(),
                                          $exprValue as item()*,
                                          $additionalAtts as attribute()*,
                                          $additionalElems as element()*,
                                          $contextInfo as map(xs:string, item()*),
                                          $options as map(*)?)
        as element() {
    let $exprAtt := $constraintElem/(@otherFoxpath, @otherXPath)        
    let $expr := $exprAtt/normalize-space(.)
    let $exprLang := $exprAtt ! local-name(.) ! replace(., '^other', '') ! lower-case(.)     
    let $constraintConfig :=
        typeswitch($constraint)
        case attribute(count) return map{'constraintComp': 'FolderSimilarCount', 'atts': ('count')}
        case attribute(minCount) return map{'constraintComp': 'FolderSimilarMinCount', 'atts': ('minCount')}
        case attribute(maxCount) return map{'constraintComp': 'FolderSimilarMaxCount', 'atts': ('maxCount')}
        default return error()
    
    let $standardAttNames := $constraintConfig?atts
    let $standardAtts := 
        let $explicit := $constraintElem/@*[local-name(.) = $standardAttNames]
        return
            (: make sure the constraint attribute is included, even if it is a default constraint :)
            ($explicit, $constraint[not(. intersect $explicit)])
    let $useAdditionalAtts := $additionalAtts[not(local-name(.) = ('valueCount', $standardAttNames))]
    let $valueCountAtt := attribute valueCount {count($exprValue)} 
    
    let $resourceShapeId := $constraintElem/@resourceShapeID
    let $constraintElemId := $constraintElem/@id
    let $constraintId := concat($constraintElemId, '-', $constraint/local-name(.))
    let $filePath := $contextInfo?filePath ! attribute filePath {.}

    let $msg := 
        if ($colour eq 'green') then i:getOkMsg($constraintElem, $constraint/local-name(.), ())
        else i:getErrorMsg($constraintElem, $constraint/local-name(.), ())
    let $elemName := 'gx:' || $colour
    return
        element {$elemName} {
            $msg ! attribute msg {.},
            attribute constraintComp {$constraintConfig?constraintComp},
            attribute constraintID {$constraintId},
            attribute resourceShapeID {$resourceShapeId},            
            $filePath,
            $standardAtts,
            $useAdditionalAtts,
            $valueCountAtt,            
            attribute exprLang {$exprLang},
            attribute expr {$expr},
            $additionalElems
        }       
};


