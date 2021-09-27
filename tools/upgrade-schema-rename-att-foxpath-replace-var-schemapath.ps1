# Copies a file system tree and upgrades all Greenfox schemas contained
Param(
    [Parameter(Mandatory=$true, Position=0)]$dirInput,
    [Parameter(Mandatory=$true, Position=1)]$dirOutput
)

Write-Host "input folder: $dirInput"
Write-Host "output output: $dirOutput"
$xslt = "$PSScriptRoot/upgrade-schema-rename-att-foxpath-replace-var-schemapath.xsl"
Write-Host "xslt: $xslt"

if (Test-Path $dirOutput) {
    Write-Warning "Output folder already exists: $dirOutput"
    Write-Warning "Aborted"
    exit 1    
}

New-Item $dirOutput -ItemType Directory

$folders = Get-ChildItem $dirInput -Recurse -Directory
$files = Get-ChildItem $dirInput -Recurse -File

Write-Host "Folders:"
Write-Host $folders

$dirInputBase = (Get-Item $dirInput).FullName
$dirOutputBase = (Get-Item $dirOutput).FullName
$dirInputBaseReplace = $dirInputBase -replace '\\', '\\'
Write-Host "inDirBase: $dirInputBase"
Write-Host "outDirBase: $dirOutputBase"

foreach ($folder in $folders) {
    $fullname = $folder.FullName
    $relName = $fullname -replace "^$dirInputBaseReplace", ''
    $newname = "$dirOutputBase$relName"
    New-Item $newname -ItemType Directory
}
foreach ($file in $files) {
    $fullname = $file.FullName
    $relName = $fullname -replace "^$dirInputBaseReplace", ''
    $newname = "$dirOutputBase$relName"
    $mustUpgrade = basex "try {exists(doc('$fullname')[//@foxpath or *:gfox/*:context/*:field/@value[contains(., '${schemaPath}')]])} catch * {false()}"
    if ($mustUpgrade -ceq 'true') {
        Write-Host "Upgrade: $fullname"
        xsltx $fullname $xslt -o:$newname
    } else {Copy-Item $fullname $newname}
}
exit 0

$rootPath = (Get-Item $dirTestRoot).FullName -replace '\\', '/'
$files_mag = Get-ChildItem "$dirTestRoot/mag.xml", "$dirTestRoot/*imag.xml", "$dirTestRoot/mag.json" -Recurse
#$files_mag = Get-Item /nestor/com.sap.it.spc.smarti.ica.exporter.mag.xslt/src/test/resources/com/sap/it/spc/smarti/ica/exporter/mag/xslt/regression/iogoa-4812/fullstack/flow_b/mag.json
#$files_mag = Get-ChildItem /nestor/com.sap.it.spc.smarti.ica.exporter.mag.xslt/src/test/resources/com/sap/it/spc/smarti/ica/exporter/mag/xslt/regression/iogoa-4812/fullstack/mag.json -Recurse
foreach ($file_mag in $files_mag) {
    $parent = Split-Path $file_mag -Parent    
    $dirName = $parent -replace '\\', '/'
    $imagFromSrc = if ($file_mag -like "*xml") {$file_mag} else {$null}
    $imagFromTarget = 
        if ($imagFromSrc) {
            $null
        } else {
            $dirName2 = $dirName -replace '/src/test/resources/', '/target/test-classes/'
            Write-Host "dirName2: $dirName2"
            $imagPath = "$dirName2/imag.xml"
            if (Test-Path "$imagPath") {$imagPath} else {
                Write-Host "Cannot find imag for mag: $file_mag"
                $null
            }
        }
    
    $accept = (Test-Path "$parent/*in.*") -and ((Test-Path "$parent/*out.*") -or (Test-Path "$parent/*expected*.xml") -or (Test-Path "$parent/*messages*/*.xml")) -and ($imagFromSrc -or $imagFromTarget)
    if ($accept) {        
        $relPath = $dirName -replace "^$rootPath/", ''
        $srcPath = "$dirSrc/$relPath"
        if (-not(Test-Path $srcPath)) {
            New-Item $srcPath -ItemType Directory
        } else {
            Remove-Item "$srcPath/*.xml"
            Write-Host "Copy folder: $relPath"            
        }        
        Copy-Item "$dirName/*" -R $srcPath -Force | Out-Null  
        if ($imagFromTarget) {Copy-Item $imagFromTarget $srcPath}      

        if (Test-Path "$parent/*messages*/*out*.xml") {
            Write-Host "*** Copy files from messages sub folder ***"        
            Copy-Item $parent/*messages*/*.xml $srcPath
        }
    }
}
