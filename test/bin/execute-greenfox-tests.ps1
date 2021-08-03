Param(
    $greenfoxDir = "/tt/greenfox",
    $testDir = "$greenfoxDir/test/testcases",
    $outDir = "$greenfoxDir/test/testcases-output"
)

$schemas = Get-ChildItem $testDir/*.gfox.xml -Recurse

foreach ($schema in $schemas) {
    $schemaFS = $schema -replace '\\', '/'
    $fname = $schema.Name
    $fnameOutput = "output-$fname"
    Write-Host "Execute test: $fname"    
    gfox $schemaFS -r | Out-File "$outDir/$fnameOutput"
}

