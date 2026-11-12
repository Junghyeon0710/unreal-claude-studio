# Opens, closes or checks the Unreal Editor for this project.
#   open   - starts the editor (if it is not running) and waits until its MCP port answers
#   close  - asks the editor to close like the window's X button and waits until the process exits
#   status - prints whether the editor runs and whether its MCP port answers
# Never force-kills the editor. Save first with the official toolset (AssetTools.save_assets with an
# empty list saves all dirty assets); if something is still unsaved the editor shows its save dialog
# and this script stops waiting and says so.
# Exit codes: 0 done, 1 failed or timed out, 2 close is waiting on the editor (save dialog?).
param(
    [Parameter(Mandatory = $true)][ValidateSet('open', 'close', 'status')][string]$Action,
    [int]$TimeoutSec = 0,
    [string]$ProjectDir = ''
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 leaves $PSScriptRoot empty in param defaults, so resolve the project here.
if (-not $ProjectDir) { $ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# Engine folder: found by ue-root.ps1 next to this script (set UE_ROOT to override).
$UeRoot = & (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'ue-root.ps1') -ProjectDir $ProjectDir
if ($LASTEXITCODE -ne 0 -or -not $UeRoot) { exit 1 }
$EditorExe = Join-Path $UeRoot 'Engine\Binaries\Win64\UnrealEditor.exe'

$Uproject = Get-ChildItem -LiteralPath $ProjectDir -Filter *.uproject | Select-Object -First 1
if (-not $Uproject) { Write-Output "no .uproject in $ProjectDir"; exit 1 }
$LogFile = Join-Path $ProjectDir ("Saved\Logs\" + $Uproject.BaseName + ".log")

# MCP port: from .mcp.json (direct entry, or the upstream entry kept by Epic's proxy installer), else 8000.
$Port = 8000
try {
    $servers = (Get-Content -LiteralPath (Join-Path $ProjectDir '.mcp.json') -Raw | ConvertFrom-Json).mcpServers
    foreach ($s in $servers.PSObject.Properties.Value) {
        $url = if ($s.url) { $s.url } elseif ($s._upstreamEntry.url) { $s._upstreamEntry.url } else { $null }
        if ($url) { $Port = ([uri]$url).Port; break }
    }
} catch { }

function Get-ProjectEditor {
    # Only the editor that has this project open, not editors of other projects.
    Get-CimInstance Win32_Process -Filter "Name = 'UnrealEditor.exe'" |
        Where-Object { $_.CommandLine -and $_.CommandLine -like ('*' + $Uproject.Name + '*') }
}

function Test-McpPort {
    $client = New-Object System.Net.Sockets.TcpClient
    try { return ($client.ConnectAsync('127.0.0.1', $Port).Wait(500) -and $client.Connected) }
    catch { return $false }
    finally { $client.Dispose() }
}

function Show-Status {
    $editor = Get-ProjectEditor
    $running = if ($editor) { "켜짐 (pid $(@($editor)[0].ProcessId))" } else { '꺼짐' }
    $mcp = if (Test-McpPort) { "응답함 (포트 $Port)" } else { "응답 없음 (포트 $Port)" }
    Write-Output "에디터: $running, MCP: $mcp"
}

switch ($Action) {
    'status' { Show-Status; exit 0 }

    'open' {
        if ($TimeoutSec -le 0) { $TimeoutSec = 600 }   # the first start can compile shaders for minutes
        if (-not (Get-ProjectEditor)) {
            # Start the MCP server even if auto-start is off in the per-user settings (a new project has it off).
            $arguments = '"' + $Uproject.FullName + '" -ModelContextProtocolStartServer -ModelContextProtocolPort=' + $Port
            Start-Process -FilePath $EditorExe -ArgumentList $arguments | Out-Null
            Write-Output "에디터를 켰습니다. MCP 포트 $Port 를 기다립니다(최대 $TimeoutSec 초)."
        }
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while ($watch.Elapsed.TotalSeconds -lt $TimeoutSec) {
            if (Test-McpPort) { Write-Output ("준비됨: {0:N0}초. " -f $watch.Elapsed.TotalSeconds); Show-Status; exit 0 }
            if (-not (Get-ProjectEditor) -and $watch.Elapsed.TotalSeconds -gt 20) {
                Write-Output '에디터가 켜지다가 꺼졌습니다. 로그를 확인하세요:'; Write-Output $LogFile; exit 1
            }
            Start-Sleep -Seconds 2
        }
        Write-Output "시간 초과: $TimeoutSec 초 안에 MCP 포트가 응답하지 않았습니다."; Show-Status; exit 1
    }

    'close' {
        if ($TimeoutSec -le 0) { $TimeoutSec = 180 }
        $editors = @(Get-ProjectEditor)
        if ($editors.Count -eq 0) { Write-Output '에디터가 이미 꺼져 있습니다.'; exit 0 }
        $requested = Get-Date
        # Same as the window's X button; no force. A request is sometimes not picked up
        # (seen once: no dialog, editor responding), so it is sent again every 20 seconds.
        function Request-Close {
            foreach ($e in @(Get-ProjectEditor)) {
                $p = Get-Process -Id $e.ProcessId -ErrorAction SilentlyContinue
                if ($p) { [void]$p.CloseMainWindow() }
            }
        }
        Request-Close
        Write-Output "에디터에 닫기를 요청했습니다. 꺼질 때까지 기다립니다(최대 $TimeoutSec 초)."
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $nextRequest = 20
        while ($watch.Elapsed.TotalSeconds -lt $TimeoutSec) {
            if (-not (Get-ProjectEditor)) { Write-Output ("꺼짐: {0:N0}초." -f $watch.Elapsed.TotalSeconds); exit 0 }
            if ($watch.Elapsed.TotalSeconds -ge $nextRequest) { Request-Close; $nextRequest += 20 }
            Start-Sleep -Seconds 2
        }
        $logSaysExited = (Test-Path -LiteralPath $LogFile) -and
            ((Get-Item -LiteralPath $LogFile).LastWriteTime -ge $requested) -and
            (Select-String -LiteralPath $LogFile -Pattern 'LogExit: Exiting\.' -Quiet)
        if ($logSaysExited) {
            Write-Output '로그는 정상 종료(LogExit: Exiting.)인데 프로세스가 아직 남아 있습니다. 빌드 전에 조금 더 기다리세요.'
            exit 2
        }
        # Tell a save dialog apart from an ignored request: list the editor's visible windows.
        Add-Type -ErrorAction SilentlyContinue @'
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class EditorWindows {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  public static List<string> Titles(uint target) {
    var r = new List<string>();
    EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p);
      if (p == target && IsWindowVisible(h)) { var s = new StringBuilder(256); GetWindowText(h, s, 256); r.Add(s.ToString()); }
      return true; }, IntPtr.Zero);
    return r; } }
'@
        $titles = @()
        foreach ($e in @(Get-ProjectEditor)) { $titles += [EditorWindows]::Titles([uint32]$e.ProcessId) }
        if ($titles.Count -eq 0) {
            Write-Output '에디터 창은 닫혔고 프로세스가 끝나는 중입니다. 조금 더 기다린 뒤 status로 확인하세요.'
            exit 2
        } elseif ($titles.Count -gt 1) {
            Write-Output ('에디터가 아직 켜져 있습니다. 다른 창이 떠 있습니다(저장 창일 수 있음): ' + ($titles -join ' / '))
        } else {
            Write-Output ('에디터가 아직 켜져 있습니다. 다른 창은 없고, 닫기 요청이 처리되지 않았습니다. 창: ' + ($titles -join ' / '))
        }
        Write-Output '강제로 끄지 않았습니다.'
        exit 2
    }
}
