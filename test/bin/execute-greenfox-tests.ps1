Param(
    $greenfoxDir = "$PSScriptRoot\..\..",
    $testDir = "$greenfoxDir/test/testcases",
    $outDir = "$greenfoxDir/test/testcases-output",
    $resultDir = "$greenfoxDir/test/testcases-output-validation-result",
    $greenfoxCheckOutput = "$greenfoxDir/test/schema-testcases-output/testcases-output.gfox.xml",
    $testcase = $null
)

# Set variables
$greenfoxDir = (Get-Item $greenfoxDir).FullName -replace '\\', '/'
$testDir = (Get-Item $testDir).FullName -replace '\\', '/'
$outDir = (Get-Item $outDir).FullName -replace '\\', '/'
$resultDir = (Get-Item $resultDir).FullName -replace '\\', '/'
$greenfoxCheckOutput = (Get-Item $greenfoxCheckOutput).FullName -replace '\\', '/'
$timestamp = Get-Date -format "yyyyMMdd-hhmm"
$fnameVresultXml = "$resultDir/validation-result.$timestamp.xml"
$fnameVresultTxt = "$resultDir/validation-result.$timestamp.txt"

# Execute testcases
Write-Host "Execute testcases ..."
Write-Host "====================="
$schemas = Get-ChildItem $testDir/*.gfox.xml -Recurse
foreach ($schema in $schemas) {
    $schemaFS = $schema -replace '\\', '/'
    $fname = $schema.Name
    if ($testcase) {if (-not($fname -like $testcase)) {continue}}
    $fnameOutput = "output-$fname"
    Write-Host "Execute test: $fname"    
    gfox $schemaFS -r | Out-File "$outDir/$fnameOutput"
}

# Validate output
Write-Host "Validate output ..."
Write-Host "==================="
cmd.exe /c "$greenfoxDir/bin/gfox" $greenfoxCheckOutput -r | Out-File "$fnameVresultXml"
cmd.exe /c "$greenfoxDir/bin/gfox" $greenfoxCheckOutput -3 | Out-File "$fnameVresultTxt"

# Summarize result
$countRed = basex -i $fnameVresultXml "/*/@countRed/string()"
$countGreen = basex -i $fnameVresultXml "/*/@countGreen/string()"
Write-Host "Testcases executed; count red/green: $countRed/$countGreen"
exit 0

