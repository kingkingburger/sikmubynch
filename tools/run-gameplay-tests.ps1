param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoPath 'project'
$testPath = Join-Path $PSScriptRoot 'tests/gameplay_regression.gd'
$logDirectory = Join-Path $repoPath 'build'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$logPath = Join-Path $logDirectory ('regression-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')

$testOutput = & $GodotPath --headless --path $projectPath --fixed-fps 60 --script $testPath --log-file $logPath 2>&1
$testExitCode = $LASTEXITCODE
$testOutput | ForEach-Object { Write-Output $_ }
$resultText = $testOutput -join "`n"
if ($testExitCode -ne 0 -or $resultText -match 'SCRIPT ERROR|Parse Error|^FAIL:' -or
    $resultText -notmatch 'RESULT: \d+ checks, 0 failures') {
    throw "Gameplay regression failed (exit $testExitCode). Log: $logPath"
}
Write-Output "Gameplay regression passed. Log: $logPath"
