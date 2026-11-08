@echo off
setlocal
echo ========================================================
echo   NetSpeedLite - Automated Build Script
echo ========================================================

set CSC_PATH=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe

if not exist "%CSC_PATH%" (
    echo [ERROR] C# Compiler not found at: %CSC_PATH%
    pause
    exit /b 1
)

if not exist "bin" mkdir "bin"

echo Compiling NetSpeedLite with optimization...
"%CSC_PATH%" /target:winexe /optimize+ /platform:x64 /win32icon:"resources\app.ico" /out:"bin\NetSpeedLite.exe" "src\Program.cs" "src\MainForm.cs" "src\NetworkMonitor.cs" "src\TaskbarController.cs" "src\DarkMenuRenderer.cs" "src\Properties\AssemblyInfo.cs"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] NetSpeedLite compiled successfully!
    echo Binary: bin\NetSpeedLite.exe
) else (
    echo.
    echo [FAILED] Compilation failed with error code %ERRORLEVEL%
)

echo ========================================================
