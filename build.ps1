$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (!(Test-Path $csc)) {
    Write-Error "C# Compiler not found at $csc"
    exit 1
}

$binDir = Join-Path $PSScriptRoot "bin"
if (!(Test-Path $binDir)) {
    New-Item -Path $binDir -ItemType Directory -Force | Out-Null
}

$outExe = Join-Path $binDir "NetSpeedLite.exe"
$iconPath = Join-Path $PSScriptRoot "resources\app.ico"
$srcFiles = @(
    (Join-Path $PSScriptRoot "src\Program.cs"),
    (Join-Path $PSScriptRoot "src\MainForm.cs"),
    (Join-Path $PSScriptRoot "src\NetworkMonitor.cs"),
    (Join-Path $PSScriptRoot "src\TaskbarController.cs"),
    (Join-Path $PSScriptRoot "src\DarkMenuRenderer.cs"),
    (Join-Path $PSScriptRoot "src\Properties\AssemblyInfo.cs")
)

Write-Host "Compiling NetSpeedLite..." -ForegroundColor Cyan
& $csc /target:winexe /optimize+ /platform:x64 "/win32icon:$iconPath" "/out:$outExe" $srcFiles

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Compiled cleanly to $outExe" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Build failed with code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
