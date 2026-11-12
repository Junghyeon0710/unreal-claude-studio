# Prints the Unreal Engine folder for this project (the folder that contains Engine\).
# Looks in this order:
#   1. the UE_ROOT environment variable (set it to override)
#   2. the Epic launcher's install list, for the .uproject's EngineAssociation (e.g. "5.8" -> UE_5.8)
#   3. the registry: launcher installs (HKLM) and source builds (HKCU, by GUID)
# Exit code 1 with a message on stderr if nothing is found.
param([string]$ProjectDir = '')

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if (-not $ProjectDir) { $ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }

function Test-EngineRoot([string]$Path) {
    return [bool]($Path -and (Test-Path -LiteralPath (Join-Path $Path 'Engine\Binaries\Win64\UnrealEditor.exe')))
}

if (Test-EngineRoot $env:UE_ROOT) { Write-Output $env:UE_ROOT; exit 0 }

$uproject = Get-ChildItem -LiteralPath $ProjectDir -Filter *.uproject | Select-Object -First 1
if (-not $uproject) { [Console]::Error.WriteLine("No .uproject in $ProjectDir"); exit 1 }
$assoc = (Get-Content -LiteralPath $uproject.FullName -Raw | ConvertFrom-Json).EngineAssociation

$launcher = Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
if ($assoc -and (Test-Path -LiteralPath $launcher)) {
    $hit = (Get-Content -LiteralPath $launcher -Raw | ConvertFrom-Json).InstallationList |
        Where-Object { $_.AppName -eq "UE_$assoc" } | Select-Object -First 1
    if ($hit -and (Test-EngineRoot $hit.InstallLocation)) { Write-Output $hit.InstallLocation; exit 0 }
}

try {
    $p = (Get-ItemProperty -Path "HKLM:\SOFTWARE\EpicGames\Unreal Engine\$assoc" -ErrorAction Stop).InstalledDirectory
    if (Test-EngineRoot $p) { Write-Output $p; exit 0 }
} catch { }

try {
    $p = (Get-ItemProperty -Path 'HKCU:\Software\Epic Games\Unreal Engine\Builds' -ErrorAction Stop).$assoc
    if (Test-EngineRoot $p) { Write-Output $p; exit 0 }
} catch { }

[Console]::Error.WriteLine("엔진 '$assoc' 위치를 찾지 못했습니다. 환경 변수 UE_ROOT에 엔진 폴더(Engine 폴더가 들어 있는 곳)를 넣어 주세요.")
exit 1
