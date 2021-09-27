Param(
    $rootSchemaDir = "../../../../projects/greenfox/work/example-schemas",
    [Parameter(Mandatory=$true)]$odir,
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

$rootDir = Join-Path $PSScriptRoot $rootSchemaDir | Resolve-Path
$binDir = Join-Path $PSScriptRoot ../../bin | Resolve-Path
$odir = Resolve-Path $odir
$gfox = Join-Path $binDir "/gfox.bat"
foreach ($schema in Get-ChildItem $rootDir/*.gfox.xml -Recurse) {
    $fname = $schema.Name
    $ofile = "output-$fname"
    $opath = "$odir/$ofile"
    $schemaFOX = filename_fox $schema
    Write-Host "Process file: $fname"
    cmd.exe /c $gfox $schemaFOX -r | Out-File $opath
}
Write-Host "rootSchemaDir: $rootDir"
Write-Host "binDir: $binDir"
Write-Host "odir: $odir"

exit 0    