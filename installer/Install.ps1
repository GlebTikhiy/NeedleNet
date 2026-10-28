param([string]$GamePath = '')
$ErrorActionPreference = 'Stop'
$payloadRoot = $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $payloadRoot 'mods\multiplayer'))) { $payloadRoot = Split-Path -Parent $PSScriptRoot }
function Find-NeedleGame {
    $steamRoots = @()
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($null -ne $entry) {
            foreach ($field in @('SteamPath', 'InstallPath')) {
                if ($entry.$field) { $steamRoots += [string]$entry.$field }
            }
        }
    }
    $libraries = @($steamRoots)
    foreach ($steamRoot in $steamRoots) {
        $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($match in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
                $libraries += $match.Groups[1].Value.Replace('\\', '\')
            }
        }
    }
    foreach ($library in ($libraries | Select-Object -Unique)) {
        $candidate = Join-Path $library 'steamapps\common\Find The Needle Demo'
        if (Test-Path -LiteralPath (Join-Path $candidate 'FindTheNeedle.exe')) { return $candidate }
    }
    return ''
}
if ([string]::IsNullOrWhiteSpace($GamePath)) { $GamePath = Find-NeedleGame }
if ([string]::IsNullOrWhiteSpace($GamePath)) {
    $GamePath = (Read-Host 'Game folder containing FindTheNeedle.exe').Trim().Trim('"')
}
if ([string]::IsNullOrWhiteSpace($GamePath)) { throw 'No game folder selected.' }
$GamePath = (Resolve-Path -LiteralPath $GamePath).Path
$exe = Join-Path $GamePath 'FindTheNeedle.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'FindTheNeedle.exe not found.' }
if (Get-Process FindTheNeedle -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }) { throw 'Close the game first.' }
$expected = '0304F7CDD9D2A30510F43A45E6D7CE96F201E69CED4A7334D08A7BFD01073742'
if ((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne $expected) { throw 'This game build has not been tested. Expected Steam build 25963876.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$backup = Join-Path $GamePath "NeedleNet-backups\$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
$config = Join-Path $GamePath 'override.cfg'
$target = Join-Path $GamePath 'mods\multiplayer'
if (Test-Path -LiteralPath $config) { Copy-Item -LiteralPath $config -Destination (Join-Path $backup 'override.cfg') }
if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'multiplayer') -Recurse }
$text = if (Test-Path -LiteralPath $config) { [IO.File]::ReadAllText($config) } else { '' }
# Remove an earlier MPMod entry, preserving every other setting.
$text = [regex]::Replace($text, '(?m)^MPMod\s*=.*\r?\n?', '')
if ($text -match '(?m)^\[autoload\]\s*$') {
    $text = [regex]::Replace($text, '(?m)^\[autoload\]\s*$', "[autoload]`r`nMPMod=`"*mods/multiplayer/mp.gd`"", 1)
} else { $text += "`r`n[autoload]`r`nMPMod=`"*mods/multiplayer/mp.gd`"`r`n" }
New-Item -ItemType Directory -Path (Join-Path $GamePath 'mods') -Force | Out-Null
Copy-Item -Path (Join-Path $payloadRoot 'mods\multiplayer') -Destination (Join-Path $GamePath 'mods') -Recurse -Force
[IO.File]::WriteAllText($config, $text, (New-Object Text.UTF8Encoding($false)))
Write-Host "NeedleNet installed. Backup: $backup"
Write-Host 'Launch the game through Steam. F2 opens multiplayer.'
