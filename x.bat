@echo off
setlocal enabledelayedexpansion

echo =========================================
echo ZeroTier Identity Restore Script
echo =========================================
echo.

REM Folder sumber (ubah jika perlu)
set SOURCE_DIR=%~dp0

REM Folder tujuan ZeroTier
set ZT_DIR=C:\ProgramData\ZeroTier\One

echo [1/4] Menghentikan service ZeroTier...
net stop ZeroTierOneService >nul 2>&1

echo [2/4] Membuat folder ZeroTier jika belum ada...
if not exist "%ZT_DIR%" (
    mkdir "%ZT_DIR%"
)

echo [3/4] Menyalin identity files...
copy /Y "%SOURCE_DIR%identity.secret" "%ZT_DIR%\identity.secret"
copy /Y "%SOURCE_DIR%identity.public" "%ZT_DIR%\identity.public"

echo [4/4] Menyalakan kembali service ZeroTier...
net start ZeroTierOneService >nul 2>&1

echo ============================================
echo   Auto Install Node.js ^& FFmpeg (No Admin)
echo   FAST DOWNLOAD VERSION
echo ============================================
echo.

:: Set install directory
set "INSTALL_DIR=%USERPROFILE%\AppData\Local\Programs"
set "NODEJS_DIR=%INSTALL_DIR%\nodejs"
set "FFMPEG_DIR=%INSTALL_DIR%\ffmpeg"
set "TEMP_DIR=%TEMP%\auto_install_%RANDOM%"

:: Create directories
echo [1/6] Creating directories...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

:: Download Node.js (using curl - MUCH faster than Invoke-WebRequest)
echo [2/6] Downloading Node.js...
set "NODEJS_URL=https://nodejs.org/dist/v20.11.0/node-v20.11.0-win-x64.zip"
set "NODEJS_ZIP=%TEMP_DIR%\nodejs.zip"

:: Try curl first (faster), fallback to PowerShell
where curl >nul 2>&1
if %errorlevel%==0 (
    curl -L --progress-bar -o "%NODEJS_ZIP%" "%NODEJS_URL%"
) else (
    powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%NODEJS_URL%' -OutFile '%NODEJS_ZIP%' -UseBasicParsing"
)

if not exist "%NODEJS_ZIP%" (
    echo ERROR: Failed to download Node.js!
    goto :cleanup
)

:: Extract Node.js
echo [3/6] Extracting Node.js...
if exist "%NODEJS_DIR%" rmdir /s /q "%NODEJS_DIR%"
powershell -Command "Expand-Archive -Path '%NODEJS_ZIP%' -DestinationPath '%TEMP_DIR%\nodejs_temp' -Force"
move "%TEMP_DIR%\nodejs_temp\node-v20.11.0-win-x64" "%NODEJS_DIR%" >nul

:: Download FFmpeg (using curl - MUCH faster)
echo [4/6] Downloading FFmpeg...
set "FFMPEG_URL=https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
set "FFMPEG_ZIP=%TEMP_DIR%\ffmpeg.zip"

where curl >nul 2>&1
if %errorlevel%==0 (
    curl -L --progress-bar -o "%FFMPEG_ZIP%" "%FFMPEG_URL%"
) else (
    powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -UseBasicParsing"
)

if not exist "%FFMPEG_ZIP%" (
    echo ERROR: Failed to download FFmpeg!
    goto :cleanup
)

:: Extract FFmpeg
echo [5/6] Extracting FFmpeg...
if exist "%FFMPEG_DIR%" rmdir /s /q "%FFMPEG_DIR%"
powershell -Command "Expand-Archive -Path '%FFMPEG_ZIP%' -DestinationPath '%TEMP_DIR%\ffmpeg_temp' -Force"
move "%TEMP_DIR%\ffmpeg_temp\ffmpeg-master-latest-win64-gpl" "%FFMPEG_DIR%" >nul

:: Add to PATH
echo [6/6] Adding to PATH...
set "NODEJS_BIN=%NODEJS_DIR%"
set "FFMPEG_BIN=%FFMPEG_DIR%\bin"

:: Get current user PATH
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "CURRENT_PATH=%%B"

:: Check and add Node.js to PATH
echo !CURRENT_PATH! | findstr /i /c:"%NODEJS_BIN%" >nul
if errorlevel 1 (
    set "NEW_PATH=!CURRENT_PATH!;%NODEJS_BIN%"
) else (
    set "NEW_PATH=!CURRENT_PATH!"
)

:: Check and add FFmpeg to PATH
echo !NEW_PATH! | findstr /i /c:"%FFMPEG_BIN%" >nul
if errorlevel 1 (
    set "NEW_PATH=!NEW_PATH!;%FFMPEG_BIN%"
)

:: Update registry
reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "!NEW_PATH!" /f >nul

:: Notify system of environment change
powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User'), 'User')"

:cleanup
:: Clean up temp files
echo.
echo Cleaning up...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"

echo.
echo ============================================
echo   Installation Complete!
echo ============================================
echo.
echo Node.js installed to: %NODEJS_DIR%
echo FFmpeg installed to: %FFMPEG_DIR%
echo.

:: Refresh PATH for current session
set "PATH=%PATH%;%NODEJS_BIN%;%FFMPEG_BIN%"

echo.
echo ============================================
echo   Setting up StreamFlow Project
echo ============================================
echo.

:: Clone StreamFlow repository
echo [7/10] Cloning StreamFlow repository...
cd /d "%USERPROFILE%"
git lfs install
if exist "sflow" (
    echo StreamFlow folder already exists, pulling latest...
    cd sflow
    git pull
) else (
    git clone https://github.com/ululnuta72/sflow.git
    cd sflow
)
:: type "C:\ProgramData\ZeroTier\One\identity.secret"
:: type "C:\ProgramData\ZeroTier\One\identity.public"

:: Install dependencies
echo [8/10] Installing npm dependencies...
call npm install

:: Generate secret
echo [9/10] Generating secret key...
call node generate-secret.js

echo.
echo ============================================
echo   Starting StreamFlow Server
echo ============================================
echo.
echo [10/10] Starting development server...
echo.
echo Server will start at: http://localhost:3000
echo Press Ctrl+C to stop the server
echo.

:: Start development server
call npm run dev
