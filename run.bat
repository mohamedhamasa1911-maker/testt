@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo First-time setup is required.
  call setup.bat
)
if not exist ".venv\Scripts\python.exe" exit /b 1
set "ARCHIVE_HOST=127.0.0.1"
set "ARCHIVE_PORT=8787"
echo.
echo Qoyod Archive System
echo Open: http://127.0.0.1:8787
echo Close this window to stop the server.
echo.
".venv\Scripts\python.exe" start.py
pause
