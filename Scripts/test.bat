@echo off
rem Run the project's automation tests from the command line. Close the Unreal Editor before running.
rem Usage: test.bat                  runs <Project>.* tests and functional tests in /Game/Tests/ maps
rem        test.bat <Project>.Dash   runs only tests whose name contains <Project>.Dash
rem Results: Saved\Automation\Report\index.json (the old report is deleted before each run)
setlocal
set "PROJECT="
for %%F in ("%~dp0..\*.uproject") do (
    set "PROJECT=%%~fF"
    set "NAME=%%~nF"
)
if not defined PROJECT (
    echo No .uproject found next to the Scripts folder.
    exit /b 1
)
set "ENGINE_ROOT="
for /f "usebackq delims=" %%R in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ue-root.ps1"`) do set "ENGINE_ROOT=%%R"
if not defined ENGINE_ROOT exit /b 1

set "REPORT=%~dp0..\Saved\Automation\Report"
set "FILTER=%~1"
if "%FILTER%"=="" set "FILTER=StartsWith:%NAME%.+StartsWith:Project.Functional Tests.Tests."

if exist "%REPORT%" rmdir /s /q "%REPORT%"

"%ENGINE_ROOT%\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "%PROJECT%" -ExecCmds="Automation RunTests %FILTER%;Quit" -TestExit="Automation Test Queue Empty" -ReportExportPath="%REPORT%" -unattended -nullrhi -nosplash -nosound -log
exit /b %ERRORLEVEL%
