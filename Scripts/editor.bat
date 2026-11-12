@echo off
rem Open, close or check the Unreal Editor for this project. Never force-kills.
rem Usage: Scripts\editor.bat open ^| close ^| status
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0editor.ps1" %*
exit /b %ERRORLEVEL%
