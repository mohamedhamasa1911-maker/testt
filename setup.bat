@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py -3"
) else (
  set "PY=python"
)

echo [1/4] Creating Python environment...
if not exist ".venv\Scripts\python.exe" %PY% -m venv .venv
if not exist ".venv\Scripts\python.exe" (
  echo Could not create .venv. Install Python 3.11 or newer.
  pause
  exit /b 1
)

echo [2/4] Installing local requirements...
".venv\Scripts\python.exe" -m pip install --upgrade pip
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 (
  echo Dependency installation failed.
  pause
  exit /b 1
)

echo [3/4] Checking local OCR engine...
if exist "C:\Program Files\Tesseract-OCR\tesseract.exe" (
  echo Tesseract is already installed.
) else (
  where winget >nul 2>nul
  if %errorlevel%==0 (
    echo Installing Tesseract OCR...
    winget install --id UB-Mannheim.TesseractOCR --exact --silent --accept-package-agreements --accept-source-agreements
  ) else (
    echo Tesseract was not found and Winget is unavailable.
    echo The system will still work with manual review.
  )
)

echo [4/4] Preparing configuration...
if not exist ".env" copy /Y ".env.example" ".env" >nul

echo.
echo Setup complete.
echo Add optional API keys to: %CD%\.env
echo Local OCR path: C:\Program Files\Tesseract-OCR\tesseract.exe
echo Then run: run.bat
pause
