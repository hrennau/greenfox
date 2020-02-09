(:
 : -------------------------------------------------------------------------
 :
 : greenfoxTarget.xqm - functions for determining the target and Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="template" type="node()" func="templateOp">     
         <param name="domain" type="xs:string?" pgroup="input"/>
         <param name="folder" type="xs:string?" pgroup="input"/>
         <param name="folder2" type="xs:string?"/>
         <param name="file" type="xs:string?" pgroup="input"/>         
         <param name="file2" type="xs:string?" pgroup="input"/>
         <param name="empty" type="xs:string*" fct_values="folder, folder2, file, file2"/>
         <param name="mfolder" type="xs:string?"/>
         <param name="mfolder2" type="xs:string?"/>
         <param name="mfile" type="xs:string?"/>
         <param name="mfile2" type="xs:string?"/>
         <pgroup name="input" minOccurs="1"/>         
      </operation>
    </operations>  
:)  
 
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm";

import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "constants.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns a greenfox templates.
 :
 : The target is identified either by a path (@path)
 : or by a foxpath expression (@foxpath). The path is
 : appended to the context path. The foxpath is
 : evaluated.
 :
 : @param resourceShape a file or folder shape
 : @param context a map of variable bindings
 : @return the target paths :)
declare function f:templateOp($request as element())
        as element() {
    let $template := map:merge((
        tt:getParams($request, 'domain') ! map:entry('domain', .),
        tt:getParams($request, 'folder') ! map:entry('folder', .),
        tt:getParams($request, 'folder2') ! map:entry('folder2', .),
        tt:getParams($request, 'file') ! map:entry('file', .),
        tt:getParams($request, 'file2') ! map:entry('file2', .),
        tt:getParams($request, 'mfolder') ! map:entry('mfolder', .),
        tt:getParams($request, 'mfolder2') ! map:entry('mfolder2', .),
        tt:getParams($request, 'mfile') ! map:entry('mfile', .),        
        tt:getParams($request, 'mfile2') ! map:entry('mfile2', .),
        let $empty := tt:getParams($request, 'empty') 
        return if (empty($empty)) then () else map:entry('empty', $empty)
    ))
    return
        f:instantiateGreenfoxTemplate($template)
(:        
    let $domainPath := 
        let $raw := tt:getParams($request, 'domain')
        return ($raw, $folderPath, $filePath)[1]
        
    let $mfolder := tt:getParams($request, 'mfolder')        
    let $mfolder2 := tt:getParams($request, 'mfolder2')
    let $mfile := tt:getParams($request, 'mfile')    
    let $mfile2 := tt:getParams($request, 'mfile2')
    
    (: Set resource names :)
    let $domainName := $domainPath ! replace(., '.*[/\\](.*)$', '$1')
    let $folderName := $folderPath ! replace(., '.*[/\\](.*)$', '$1')
    let $folder2Name := $folder2Path ! replace(., '.*[/\\](.*)$', '$1')
    let $fileName := $filePath ! replace(., '.*[/\\](.*)$', '$1')
    let $file2Name := $file2Path ! replace(., '.*[/\\](.*)$', '$1')

    (: Read parameters :)   
    let $folderPath := tt:getParams($request, 'folder')
    let $folder2Path := tt:getParams($request, 'folder2')
    let $filePath := tt:getParams($request, 'file')
    let $file2Path := tt:getParams($request, 'file2')
    let $empty := tt:getParams($request, 'empty')
    let $domainPath := 
        let $raw := tt:getParams($request, 'domain')
        return ($raw, $folderPath, $filePath)[1]
        
    let $mfolder := tt:getParams($request, 'mfolder')        
    let $mfolder2 := tt:getParams($request, 'mfolder2')
    let $mfile := tt:getParams($request, 'mfile')    
    let $mfile2 := tt:getParams($request, 'mfile2')
    
    (: Set resource names :)
    let $domainName := $domainPath ! replace(., '.*[/\\](.*)$', '$1')
    let $folderName := $folderPath ! replace(., '.*[/\\](.*)$', '$1')
    let $folder2Name := $folder2Path ! replace(., '.*[/\\](.*)$', '$1')
    let $fileName := $filePath ! replace(., '.*[/\\](.*)$', '$1')
    let $file2Name := $file2Path ! replace(., '.*[/\\](.*)$', '$1')
    
    (: Construct shapes :)
    let $file2Shape :=
        if (not($file2Path)) then () else
        
        let $targetSizeAtts :=
            if ($empty = 'file2') then (
                attribute maxCount {0},
                attribute maxCountMsg {($mfile2, "'"||$file2Name||' file not expected.')[1]}
            ) else (
                attribute minCount {1},
                attribute minCountMsg {($mfile2, "File not found: '"||$file2Name||"'.")[1]}
            )
        return
            <gx:file foxpath="{$file2Path}">{
                <gx:targetSize>{$targetSizeAtts}</gx:targetSize>
            }</gx:file>
    let $fileShape :=
        if (not($filePath)) then () else
        
        let $targetSizeAtts :=
            if ($empty = 'file') then (
                attribute maxCount {0},
                attribute maxCountMsg {($mfile, "'"||$fileName||' file not expected.')[1]}
            ) else (
                attribute minCount {1},
                attribute minCountMsg {($mfile2, "File not found: '"||$file2Name||"'.")[1]}
            )
        return
            <gx:file foxpath="{$filePath}">{
                <gx:targetSize>{$targetSizeAtts}</gx:targetSize>
            }</gx:file>
    let $folder2Shape :=
        if (not($folder2Path)) then () else
        
        let $targetSizeAtts :=
            if ($empty = 'folder2') then (
                attribute maxCount {0},
                attribute maxCountMsg {($mfolder2, "'"||$folder2Name||' file not expected.')[1]}
            ) else (
                attribute minCount {1},
                attribute minCountMsg {($mfolder2, "Folder not found: '"||$folder2Name||"'.")[1]}
            )
        return
            <gx:folder foxpath="{$folder2Path}">{
                <gx:targetSize>{$targetSizeAtts}</gx:targetSize>,
                $file2Shape                
            }</gx:folder>
    let $folderShape :=
        if (not($folderPath)) then () else
        
        let $targetSizeAtts :=
            if ($empty = 'folder') then (
                attribute maxCount {0},
                attribute maxCountMsg {($mfolder, "'"||$folderName||' file not expected.')[1]}
            ) else (
                attribute minCount {1},
                attribute minCountMsg {($mfolder, "Folder not found: '"||$folderName||"'.")[1]}
            )
        return        
            <gx:folder foxpath="{$folderPath}">{
                <gx:targetSize>{$targetSizeAtts}</gx:targetSize>,
                $folder2Shape,
                $fileShape                
             }</gx:folder>
             
    (: Construct greenfox :)             
    let $greenfox :=
        <gx:greenfox greenfoxURI="http://www.greenfox.org/ns/schema-examples/EDITME"
                  xmlns="http://www.greenfox.org/ns/schema">{
            <gx:domain path="{$domainPath}" name="{$domainName}">{
                $folderShape,
                $fileShape[not($folderShape)]
            }</gx:domain>
        }</gx:greenfox>
        
    return
        $greenfox/i:addDefaultNamespace(., $i:URI_GX, ())
:)        
};

declare function f:instantiateGreenfoxTemplate($template as map(*))
        as element() {
    (: Read parameters :)   
    let $folderPath := $template?folder
    let $folder2Path := $template?folder2
    let $filePath := $template?file
    let $file2Path := $template?file2
    let $empty := $template?empty
    let $mfolder := $template?mfolder        
    let $mfolder2 := $template?mfolder2
    let $mfile := $template?mfile    
    let $mfile2 := $template?mfile2

    let $domainPath := 
        let $raw := $template?domain
        return ($raw, $folderPath, $filePath)[1]
        
    (: Set resource names :)
    let $domainName := $domainPath ! replace(., '.*[/\\](.*)$', '$1')
    let $folderName := $folderPath ! replace(., '.*[/\\](.*)$', '$1')
    let $folder2Name := $folder2Path ! replace(., '.*[/\\](.*)$', '$1')
    let $fileName := $filePath ! replace(., '.*[/\\](.*)$', '$1')
    let $file2Name := $file2Path ! replace(., '.*[/\\](.*)$', '$1')
    
    (: Construct shapes :)
    let $file2Shape :=
        if (not($file2Path)) then () else
        
        let $targetSizeAtts :=
            if ($empty = 'file2') then (
                attribute maxCount {0},
                attribute maxCountMsg {($mfile2, "'"||$file2Name||' file not expected.')[1]}
            ) else (
                attribute minCount {1},
                attribute minCountMsg {($mfile2, "File not found: '"||$file2Name||"'.")[1]}
            )
        return
            <gx:file foxpath="{$file2Path}">{
                <gx:targetSize>{$targetSizeAtts}</gx:targetSize>
            }</gx:file>
    let $fileShape :=
        if (not($filePath)) then () else
        
        let $targetSizeAtts :=
            if ($empty = 'file') then (
                attribute maxCount {0},
                attribute maxCountMsg {($mfile, "'"||$fileName||' file not expected.')[1]}
            ) else (
                attribute minCount {1},
                attribute minCountMsg {($mfile, "File not found: '"||$fileName||"'.")[1]}
            )
        return
            <gx:file foxpath="{$filePath}">{
                <gx:targetSize>{$targetSizeAtts}</gx:targetSize>
            }</gx:file>
    let $folder2Shape :=
        if (not($folder2Path)) then () else
        
        let $targetSizeAtts :=
            if ($empty = 'folder2') then (
                attribute maxCount {0},
                attribute maxCountMsg {($mfolder2, "'"||$folder2Name||' folder not expected.')[1]}
            ) else (
                attribute minCount {1},
                attribute minCountMsg {($mfolder2, "Folder not found: '"||$folder2Name||"'.")[1]}
            )
        return
            <gx:folder foxpath="{$folder2Path}">{
                <gx:targetSize>{$targetSizeAtts}</gx:targetSize>,
                $file2Shape                
            }</gx:folder>
    let $folderShape :=
        if (not($folderPath)) then () else
        
        let $targetSizeAtts :=
            if ($empty = 'folder') then (
                attribute maxCount {0},
                attribute maxCountMsg {($mfolder, "'"||$folderName||' file not expected.')[1]}
            ) else (
                attribute minCount {1},
                attribute minCountMsg {($mfolder, "Folder not found: '"||$folderName||"'.")[1]}
            )
        return        
            <gx:folder foxpath="{$folderPath}">{
                <gx:targetSize>{$targetSizeAtts}</gx:targetSize>,
                $fileShape,
                $folder2Shape                
             }</gx:folder>
             
    (: Construct greenfox :)             
    let $greenfox :=
        <gx:greenfox greenfoxURI="http://www.greenfox.org/ns/schema-examples/EDITME"
                  xmlns="http://www.greenfox.org/ns/schema">{
            <gx:domain path="{$domainPath}" name="{$domainName}">{
                $folderShape,
                $fileShape[not($folderShape)]
            }</gx:domain>
        }</gx:greenfox>
        
    return
        $greenfox/i:addDefaultNamespace(., $i:URI_GX, ())
};
