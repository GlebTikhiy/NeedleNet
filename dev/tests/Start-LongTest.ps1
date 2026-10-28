param([double]$Minutes = 90, [switch]$Smoke)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $taskRoot
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$pythonPath = 'C:\Python314\python.exe'
if (-not (Test-Path -LiteralPath $pythonPath)) { $pythonPath = (Get-Command python -ErrorAction Stop).Source }
$logDirectory = Join-Path $taskRoot 'local'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$consoleLog = Join-Path $logDirectory ('long-test-console-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
$Host.UI.RawUI.WindowTitle = 'NeedleNet - RUNNING - silent test'
Write-Host 'NeedleNet: silent isolated test. Keep this console open; you may minimize it.'
Write-Host 'At the end copy BEGIN_NEEDLENET_LONG_TEST_RESULT ... END_NEEDLENET_LONG_TEST_RESULT.'
Write-Host "Console log: $consoleLog"
$testArguments = @('-u', (Join-Path $PSScriptRoot 'run_long_test.py'), '--minutes', [string]$Minutes)
if ($Smoke) { $testArguments += '--smoke' }
try {
    & $pythonPath @testArguments 2>&1 | Tee-Object -FilePath $consoleLog
    $testExitCode = $LASTEXITCODE
    Write-Host "Test process exit code: $testExitCode"
} catch {
    Write-Host "Launcher error: $_"
    Write-Host "Inspect $consoleLog and local/long-test-current.json."
}
$Host.UI.RawUI.WindowTitle = 'NeedleNet - FINISHED - copy result'
Read-Host 'Finished. Press Enter to close the console'
