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
    (Join-Path $PSScriptRoot "src\FlyoutForm.cs"),
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

Write-Host "Compiling NetSpeedLite-arm.exe..." -ForegroundColor Cyan
& $csc /target:winexe /optimize+ /platform:arm "/win32icon:$icon" "/out:$bin\NetSpeedLite-arm.exe" $src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Copy-Item "$bin\NetSpeedLite-x64.exe" -Destination "$bin\NetSpeedLite.exe" -Force

# Create portable distribution zip
$zipPath = Join-Path $bin "NetSpeedLite-v1.1.0.zip"
$staging = Join-Path $env:TEMP "NetSpeedLite-staging"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging | Out-Null
Copy-Item (Join-Path $bin "*.exe") -Destination $staging
Copy-Item (Join-Path $PSScriptRoot "resources\app.ico") -Destination $staging
Copy-Item (Join-Path $PSScriptRoot "README.md") -Destination $staging
Copy-Item (Join-Path $PSScriptRoot "LICENSE") -Destination $staging
Compress-Archive -Path "$staging\*" -DestinationPath $zipPath -Force
Remove-Item $staging -Recurse -Force

# Generate SHA256SUMS.txt
$checksumPath = Join-Path $bin "SHA256SUMS.txt"
$hashTargets = @(
    "NetSpeedLite-x64.exe",
    "NetSpeedLite-x86.exe",
    "NetSpeedLite-AnyCpu.exe",
    "NetSpeedLite-arm.exe",
    "NetSpeedLite-v1.1.0.zip"
)
$lines = foreach ($name in $hashTargets) {
    $h = (Get-FileHash (Join-Path $bin $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    "$h  $name"
}
Set-Content -Path $checksumPath -Value $lines -Encoding ASCII

Write-Host "`n[SUCCESS] All architectures and distribution packages built successfully:" -ForegroundColor Green
Get-ChildItem $bin | Select-Object Name, Length
