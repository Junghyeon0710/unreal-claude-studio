# Installs this Unreal Claude studio into an Unreal Engine project.
#
# Usage (from the folder you cloned this repository into):
#   powershell -ExecutionPolicy Bypass -File install.ps1 "D:\Unreal Projects\MyGame"
#
# What it does:
#   - copies .claude\ (agents, skills, rules, hooks, settings) and Scripts\
#   - writes CLAUDE.md, docs\, .gitignore, .gitattributes, .mcp.json and a smoke test from templates\,
#     with the project name and engine filled in
#   - turns on the ModelContextProtocol and AllToolsets plugins in the .uproject
# It never overwrites a file that already exists. Files that differ are listed so you can merge them.
param(
    [Parameter(Mandatory = $true)][string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Studio = Split-Path -Parent $MyInvocation.MyCommand.Path
$Utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) { Write-Output "프로젝트 폴더가 없습니다: $ProjectDir"; exit 1 }
$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path
$uprojects = @(Get-ChildItem -LiteralPath $ProjectDir -Filter *.uproject)
if ($uprojects.Count -ne 1) { Write-Output "프로젝트 폴더에 .uproject가 정확히 하나 있어야 합니다(지금 $($uprojects.Count)개)."; exit 1 }
$Uproject = $uprojects[0]
$Name = $Uproject.BaseName
$UprojectJson = Get-Content -LiteralPath $Uproject.FullName -Raw | ConvertFrom-Json
$EngineVersion = [string]$UprojectJson.EngineAssociation

$EngineRoot = & (Join-Path $Studio 'Scripts\ue-root.ps1') -ProjectDir $ProjectDir 2>$null
if ($LASTEXITCODE -ne 0 -or -not $EngineRoot) { $EngineRoot = '(엔진 폴더를 찾지 못함: 환경 변수 UE_ROOT를 넣어 주세요)' }
$IsCpp = Test-Path -LiteralPath (Join-Path $ProjectDir "Source\$Name")

$Created = New-Object System.Collections.Generic.List[string]
$Same = New-Object System.Collections.Generic.List[string]
$Skipped = New-Object System.Collections.Generic.List[string]

function Save-Bytes([string]$Relative, [byte[]]$Bytes) {
    $target = Join-Path $ProjectDir $Relative
    if (Test-Path -LiteralPath $target) {
        $old = [System.IO.File]::ReadAllBytes($target)
        if ([Convert]::ToBase64String($old) -eq [Convert]::ToBase64String($Bytes)) { $Same.Add($Relative) } else { $Skipped.Add($Relative) }
        return
    }
    $dir = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllBytes($target, $Bytes)
    $Created.Add($Relative)
}

function Copy-Tree([string]$Folder) {
    $root = Join-Path $Studio $Folder
    foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
        if ($f.FullName -match '\\__pycache__\\') { continue }
        $relative = $Folder + $f.FullName.Substring($root.Length)
        Save-Bytes $relative ([System.IO.File]::ReadAllBytes($f.FullName))
    }
}

function Write-Template([string]$Template, [string]$Relative) {
    $text = [System.IO.File]::ReadAllText((Join-Path $Studio "templates\$Template"), $Utf8)
    $text = $text.Replace('{{PROJECT}}', $Name).Replace('{{ENGINE_VERSION}}', $EngineVersion).
        Replace('{{ENGINE_ROOT}}', $EngineRoot).Replace('{{DATE}}', (Get-Date -Format 'yyyy-MM-dd'))
    Save-Bytes $Relative ($Utf8.GetBytes($text))
}

# 1. Studio files
Copy-Tree '.claude'
Copy-Tree 'Scripts'

# 2. Templates
Write-Template 'CLAUDE.md' 'CLAUDE.md'
Write-Template 'docs\progress.md' 'docs\progress.md'
Write-Template 'docs\design\.gitkeep' 'docs\design\.gitkeep'
Write-Template 'docs\tasks\.gitkeep' 'docs\tasks\.gitkeep'
Write-Template 'gitignore' '.gitignore'
Write-Template 'gitattributes' '.gitattributes'
Write-Template 'mcp.json' '.mcp.json'
if ($IsCpp) { Write-Template 'SmokeSpec.cpp' "Source\$Name\Tests\$($Name)SmokeSpec.cpp" }

# 3. Plugins in the .uproject
$pluginChanges = New-Object System.Collections.Generic.List[string]
if (-not $UprojectJson.PSObject.Properties['Plugins']) { $UprojectJson | Add-Member -NotePropertyName Plugins -NotePropertyValue @() }
$plugins = New-Object System.Collections.ArrayList
foreach ($p in @($UprojectJson.Plugins)) { [void]$plugins.Add($p) }
foreach ($needed in @('ModelContextProtocol', 'AllToolsets')) {
    $existing = $plugins | Where-Object { $_.Name -eq $needed } | Select-Object -First 1
    if (-not $existing) {
        [void]$plugins.Add([pscustomobject]@{ Name = $needed; Enabled = $true }); $pluginChanges.Add("$needed 켬")
    } elseif (-not $existing.Enabled) {
        $existing.Enabled = $true; $pluginChanges.Add("$needed 켬(꺼져 있었음)")
    }
}
if ($pluginChanges.Count -gt 0) {
    $UprojectJson.Plugins = @($plugins)
    [System.IO.File]::WriteAllText($Uproject.FullName, ($UprojectJson | ConvertTo-Json -Depth 20), $Utf8)
}

# 4. MCP server auto-start in the per-user editor settings (Saved\, not in Git), so the server also
#    starts when the editor is opened from the launcher. Scripts\editor.bat open passes the flag anyway.
$userIni = Join-Path $ProjectDir 'Saved\Config\WindowsEditor\EditorPerProjectUserSettings.ini'
$mcpSection = '[/Script/ModelContextProtocolEngine.ModelContextProtocolSettings]'
$iniText = if (Test-Path -LiteralPath $userIni) { [System.IO.File]::ReadAllText($userIni) } else { '' }
if ($iniText -match 'bAutoStartServer\s*=\s*True') {
    $mcpAutoStart = '이미 켜져 있음'
} elseif ($iniText.Contains($mcpSection)) {
    $mcpAutoStart = "직접 켜기: $userIni 의 $mcpSection 아래에 bAutoStartServer=True"
} else {
    $dir = Split-Path -Parent $userIni
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $add = "`r`n$mcpSection`r`nbAutoStartServer=True`r`n"
    [System.IO.File]::AppendAllText($userIni, $add, $Utf8)
    $mcpAutoStart = '켬 (개인 설정 파일)'
}

# 5. Report
Write-Output "스튜디오를 설치했습니다: $ProjectDir"
Write-Output "프로젝트: $Name, 엔진: $EngineVersion ($EngineRoot)"
Write-Output ("새로 만든 파일: {0}개, 이미 같은 파일: {1}개, 이미 있어서 건너뛴 파일: {2}개" -f $Created.Count, $Same.Count, $Skipped.Count)
if ($Skipped.Count -gt 0) {
    Write-Output '건너뛴 파일(내용이 달라서 덮어쓰지 않음, 직접 합치세요):'
    foreach ($s in $Skipped) { Write-Output "  - $s" }
}
if ($pluginChanges.Count -gt 0) { Write-Output ('.uproject 플러그인: ' + ($pluginChanges -join ', ')) } else { Write-Output '.uproject 플러그인: 이미 켜져 있음' }
Write-Output "MCP 서버 자동 시작: $mcpAutoStart"

Write-Output ''
Write-Output '남은 일:'
if (-not $IsCpp) {
    Write-Output "  - C++ 모듈(Source\$Name)이 없습니다. 에디터에서 C++ 클래스를 하나 추가해 C++ 프로젝트로 바꾼 뒤, 이 스크립트를 다시 실행하세요(최소 테스트가 그때 만들어집니다)."
} else {
    $buildCs = Join-Path $ProjectDir "Source\$Name\$Name.Build.cs"
    $cs = if (Test-Path -LiteralPath $buildCs) { [System.IO.File]::ReadAllText($buildCs) } else { '' }
    if ($cs -notmatch 'PublicIncludePaths\.Add\(ModuleDirectory\)') {
        Write-Output "  - $Name.Build.cs 생성자에 넣기: PublicIncludePaths.Add(ModuleDirectory);  (기능 폴더 헤더를 ""<기능>/<파일>.h""로 include)"
    }
    if ($cs -notmatch '"CQTest"') {
        Write-Output "  - $Name.Build.cs 생성자에 넣기: if (Target.bBuildEditor) { PrivateDependencyModuleNames.Add(""CQTest""); }  (월드가 필요한 테스트)"
    }
}
Write-Output '  - Claude Code 2.1.295 이상, Git for Windows(Git Bash), 에픽 플러그인 unreal-engine-skills-for-claude-code 설치'
Write-Output '  - 프로젝트 폴더에서 Claude Code를 열고 폴더를 신뢰한다고 승인(그래야 훅이 동작)'
Write-Output '  - 확인: Scripts\build.bat → Scripts\test.bat(최소 테스트 통과) → Scripts\editor.bat open → Scripts\editor.bat close'
Write-Output '  - Git: 저장소가 아니면 git init, 그리고 git lfs install(.gitattributes가 .uasset을 LFS로 보냄)'
Write-Output '  - 그다음 /design 게임'
exit 0
