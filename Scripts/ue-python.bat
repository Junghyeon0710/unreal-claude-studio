@echo off
rem Run one approved editor Python script in the running Unreal Editor.
rem Needs the editor open with Python Remote Execution enabled.
rem Usage: Scripts\ue-python.bat Scripts\Editor\001-example.py
setlocal
set "UE_ROOT=D:\Epic Games\UE_5.8"
set "PROJECT_DIR=%~dp0.."

"%UE_ROOT%\Engine\Binaries\ThirdParty\Python3\Win64\python.exe" -I "%~dp0ue_python.py" "%UE_ROOT%" "%PROJECT_DIR%" %*
exit /b %ERRORLEVEL%
