(:
 : -------------------------------------------------------------------------
 :
 : folderContentSimilarConstraint.xqm - validates a resource against a FolderContentSimilar constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateFolderContentSimilar($filePath as xs:string,
                                                $constraintElem as element(gx:folderContentSimilar),
                                                $context as map(xs:string, item()*))
        as element()* {

    (: Adhoc addition of $filePath and $fileName :)
    let $evaluationContext := $context?_evaluationContext
    let $evaluationContext := map:put($evaluationContext, QName((),'filePath'), $filePath)
    let $evaluationContext := map:put($evaluationContext, QName((), 'fileName'), replace($filePath, '.*[/\\]', ''))
    let $context := map:put($context, '_evaluationContext', $evaluationContext)
    
    let $otherFoxpath := $constraintElem/@otherFoxpath
 
    let $otherDoc :=
        if ($otherFoxpath) then f:evaluateFoxpath($otherFoxpath, $filePath, $evaluationContext, true())
        else ()
    let $otherDocExists := 
        if (1 ne count($otherDoc)) then false()
        else $otherDoc ! i:resourceExists(.)
    return
        if (not($otherDoc)) then
            f:validationResult_folderContentSimilar('red', $constraintElem, $constraintElem/@otherFoxpath, 'no-other-doc', (), ())
        else
            let $additionalAtts := attribute otherFolder {$otherDoc}
            (: compare 1 with 2 :)
            let $results12 := f:compareFolders($filePath, $otherDoc, $evaluationContext)
            let $results21 := f:compareFolders($otherDoc, $filePath, $evaluationContext)
            let $keys12 := map:keys($results12)
            let $keys21 := map:keys($results21)
            return
                if (empty($keys12) and empty($keys21)) then 
                    f:validationResult_folderContentSimilar('green', $constraintElem, $constraintElem/@otherFoxpath, (), $additionalAtts, ())
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
                        f:validationResult_folderContentSimilar('red', $constraintElem, $constraintElem/@otherFoxpath, (), $additionalAtts, $values)
};   

declare function f:compareFolders($folder1 as xs:string, 
                                  $folder2 as xs:string, 
                                  $evaluationContext as map(xs:QName, item()*))
        as item()* {
    let $files1 := f:evaluateFoxpath('*[is-file(.)]', $folder1, $evaluationContext, true())        
    let $files2 := f:evaluateFoxpath('*[is-file(.)]', $folder2, $evaluationContext, true())
    let $dirs1 := f:evaluateFoxpath('*[is-dir(.)]', $folder1, $evaluationContext, true())
    let $dirs2 := f:evaluateFoxpath('*[is-dir(.)]', $folder2, $evaluationContext, true())
    
    let $fileNames1 := $files1 ! replace(., '^.*[/\\]', '')
    let $fileNames2 := $files2 ! replace(., '^.*[/\\]', '')
    let $fileNames1Only := $fileNames1[not(. = $fileNames2)]
    
    let $dirNames1 := $dirs1 ! replace(., '^.*[/\\]', '')
    let $dirNames2 := $dirs2 ! replace(., '^.*[/\\]', '')
    let $dirNames1Only := $dirNames1[not(. = $dirNames2)]
    return
        map:merge((
            if (empty($fileNames1Only)) then () else map{'files1Only': $fileNames1Only},
            if (empty($dirNames1Only)) then () else map{'dirs1Only': $dirNames1Only}
        ))
};


(:~
 : Writes a validation result for a DeepSimilar constraint.
 :
 : @param colour indicates success or error
 : @param constraintElem the element representing the constraint
 : @param constraint an attribute representing the main properties of the constraint
 : @param reasons strings identifying reasons of violation
 : @param additionalAtts additional attributes to be included in the validation result
 :) 
declare function f:validationResult_folderContentSimilar(
                                                 $colour as xs:string,
                                                 $constraintElem as element(gx:folderContentSimilar),
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

