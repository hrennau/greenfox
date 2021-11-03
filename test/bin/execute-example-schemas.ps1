Param(
    $rootSchemaDir = "../../../../projects/greenfox/work/greenfox/example-schemas",
    [Parameter(Mandatory=$true)]$odir = '../../../../projects/greenfox/work/validation-output3',
    $pathFilter = $null
)

Function filename_fox {
    Param(
        [Parameter(Position=0)][string] $name
    )
    $name_fox = $name
    $name_fox = $name_fox -Replace "\\", "/"
    $name_fox = $name_fox -Replace "\s", "~ "
    $name_fox = $name_fox -Replace "\(", "~("
    $name_fox = $name_fox -Replace "\)", "~)"
    $name_fox = $name_fox -Replace '/(\d)', '/~$1'
    $name_fox
}

Write-Host "PSScriptRoot: $PSScriptRoot"
$rootDir = Join-Path $PSScriptRoot $rootSchemaDir | Resolve-Path
$binDir = Join-Path $PSScriptRoot ../../bin | Resolve-Path
$odir = Resolve-Path $odir
$gfox = Join-Path $binDir "/gfox.bat"
foreach ($schema in Get-ChildItem $rootDir/*.gfox.xml -Recurse) {
    if ($pathFilter) {if (-not($schema -like $pathFilter)) {continue}}
    $fname = $schema.Name

    # Some examples require an explicit domain
    $domain = 
        if ($fname -ceq 'cc-links-href.niem.gfox.xml') {"/projects/xsdbase"}
        elseif ($fname -ceq 'link-targets.recursive.niem.gfox.xml') {"/projects/xsdbase"}
        elseif ($fname -ceq 'link-targets.recursive.niem.archive.gfox.xml') {"/projects/xsdbase"}
        elseif ($fname -ceq 'link-targets.recursive.opentravel.gfox.xml') {"/projects/xsdbase"}
        elseif ($fname -ceq 'link-targets.recursive.opentravel.archive.gfox.xml') {"/projects/xsdbase"}
        else {""}

    $ofile = "output-$fname"
    $opath = "$odir/$ofile"
    $schemaFOX = filename_fox $schema
    Write-Host "Process file: $fname"
    cmd.exe /c $gfox $schemaFOX $domain -r | Out-File $opath
}
Write-Host "rootSchemaDir: $rootDir"
Write-Host "binDir: $binDir"
Write-Host "odir: $odir"

exit 0    