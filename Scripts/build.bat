@echo off
rem Build the project's editor target. Close the Unreal Editor before running.
rem The project is the .uproject next to Scripts\, and the engine folder is found by ue-root.ps1
rem (set UE_ROOT to override).
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

call "%ENGINE_ROOT%\Engine\Build\BatchFiles\Build.bat" %NAME%Editor Win64 Development -Project="%PROJECT%" -WaitMutex
exit /b %ERRORLEVEL%
