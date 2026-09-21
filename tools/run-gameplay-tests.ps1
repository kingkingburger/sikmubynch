param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoPath 'project'
# logs go to build/logs/<suite>.log and are overwritten on every run, so build/ stays clean
$logDirectory = Join-Path $repoPath 'build\logs'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

# headless simulation regression + headless scene smoke
$suites = @(
    @{ Name = 'regression'; Script = 'tests/gameplay_regression.gd' },
    @{ Name = 'smoke'; Script = 'tests/play_smoke.gd' }
)
foreach ($suite in $suites) {
    $testPath = Join-Path $PSScriptRoot $suite.Script
    $logPath = Join-Path $logDirectory ($suite.Name + '.log')
    if (Test-Path $logPath) { Remove-Item $logPath -Force }
    # Godot prints warnings to stderr at exit; do not let PowerShell turn those into a thrown error.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $testOutput = & $GodotPath --headless --path $projectPath --fixed-fps 60 --script $testPath --log-file $logPath 2>&1 | ForEach-Object { "$_" }
    $testExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    $testOutput | ForEach-Object { Write-Output $_ }
    $resultText = $testOutput -join "`n"
    if ($testExitCode -ne 0 -or $resultText -match 'SCRIPT ERROR|Parse Error|^FAIL:' -or
        $resultText -notmatch 'RESULT: \d+ checks, 0 failures') {
        throw "$($suite.Name) failed (exit $testExitCode). Log: $logPath"
    }
    Write-Output "$($suite.Name) passed. Log: $logPath"
}
