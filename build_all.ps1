$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (!(Test-Path $csc)) {
    Write-Error "C# Compiler not found at $csc"
    exit 1
}

$bin = Join-Path $PSScriptRoot "bin"
if (!(Test-Path $bin)) { 
    New-Item -Path $bin -ItemType Directory -Force | Out-Null 
}

$src = @(
    (Join-Path $PSScriptRoot "src\Program.cs"),
    (Join-Path $PSScriptRoot "src\MainForm.cs"),
    (Join-Path $PSScriptRoot "src\NetworkMonitor.cs"),
    (Join-Path $PSScriptRoot "src\TaskbarController.cs"),
    (Join-Path $PSScriptRoot "src\DarkMenuRenderer.cs"),
    (Join-Path $PSScriptRoot "src\Properties\AssemblyInfo.cs")
)
$icon = Join-Path $PSScriptRoot "resources\app.ico"

Write-Host "Compiling NetSpeedLite-x64.exe..." -ForegroundColor Cyan
& $csc /target:winexe /optimize+ /platform:x64 "/win32icon:$icon" "/out:$bin\NetSpeedLite-x64.exe" $src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Compiling NetSpeedLite-x86.exe..." -ForegroundColor Cyan
& $csc /target:winexe /optimize+ /platform:x86 "/win32icon:$icon" "/out:$bin\NetSpeedLite-x86.exe" $src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Compiling NetSpeedLite-AnyCpu.exe..." -ForegroundColor Cyan
& $csc /target:winexe /optimize+ /platform:anycpu "/win32icon:$icon" "/out:$bin\NetSpeedLite-AnyCpu.exe" $src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Copy-Item "$bin\NetSpeedLite-x64.exe" -Destination "$bin\NetSpeedLite.exe" -Force

Write-Host "`n[SUCCESS] All architectures built successfully:" -ForegroundColor Green
Get-ChildItem $bin -Filter "*.exe" | Select-Object Name, Length
