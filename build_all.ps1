$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$bin = "C:\Users\yakes\source\repos\NetSpeedLite\bin"
if (!(Test-Path $bin)) { New-Item -Path $bin -ItemType Directory -Force | Out-Null }

$src = @(
    "C:\Users\yakes\source\repos\NetSpeedLite\src\Program.cs",
    "C:\Users\yakes\source\repos\NetSpeedLite\src\MainForm.cs",
    "C:\Users\yakes\source\repos\NetSpeedLite\src\NetworkMonitor.cs",
    "C:\Users\yakes\source\repos\NetSpeedLite\src\TaskbarController.cs",
    "C:\Users\yakes\source\repos\NetSpeedLite\src\DarkMenuRenderer.cs",
    "C:\Users\yakes\source\repos\NetSpeedLite\src\Properties\AssemblyInfo.cs"
)
$icon = "C:\Users\yakes\source\repos\NetSpeedLite\resources\app.ico"

Write-Host "Compiling NetSpeedLite-x64.exe..." -ForegroundColor Cyan
& $csc /target:winexe /optimize+ /platform:x64 "/win32icon:$icon" "/out:$bin\NetSpeedLite-x64.exe" $src

Write-Host "Compiling NetSpeedLite-x86.exe..." -ForegroundColor Cyan
& $csc /target:winexe /optimize+ /platform:x86 "/win32icon:$icon" "/out:$bin\NetSpeedLite-x86.exe" $src

Write-Host "Compiling NetSpeedLite-AnyCpu.exe..." -ForegroundColor Cyan
& $csc /target:winexe /optimize+ /platform:anycpu "/win32icon:$icon" "/out:$bin\NetSpeedLite-AnyCpu.exe" $src

Copy-Item "$bin\NetSpeedLite-x64.exe" -Destination "$bin\NetSpeedLite.exe" -Force

Get-ChildItem $bin -Filter "*.exe" | Select-Object Name, Length
