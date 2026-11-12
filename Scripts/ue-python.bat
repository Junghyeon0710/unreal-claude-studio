@echo off
rem Run one approved editor Python script in the running Unreal Editor.
rem Needs the editor open with Python Remote Execution enabled.
rem Usage: Scripts\ue-python.bat Scripts\Editor\001-example.py
rem The engine folder is found by ue-root.ps1 (set UE_ROOT to override).
setlocal
set "PROJECT_DIR=%~dp0.."
set "ENGINE_ROOT="
for /f "usebackq delims=" %%R in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ue-root.ps1"`) do set "ENGINE_ROOT=%%R"
if not defined ENGINE_ROOT exit /b 1

"%ENGINE_ROOT%\Engine\Binaries\ThirdParty\Python3\Win64\python.exe" -I "%~dp0ue_python.py" "%ENGINE_ROOT%" "%PROJECT_DIR%" %*
exit /b %ERRORLEVEL%
