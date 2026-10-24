$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $taskRoot 'local')) + [IO.Path]::DirectorySeparatorChar
$pointer = Join-Path $taskRoot 'local\long-test-current.json'
$state = Get-Content -LiteralPath $pointer -Raw | ConvertFrom-Json
$target = [IO.Path]::GetFullPath([string]$state.output)
if (-not $target.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetFileName($target)).StartsWith('long-test-')) { throw 'Invalid test output path.' }
Set-Content -LiteralPath (Join-Path $target 'STOP') -Value 'User requested stop' -Encoding UTF8
Write-Host 'Stop requested. The runner will stop its own test processes and write the report.'
