$ErrorActionPreference = 'Stop'

# Ensure JAVA_HOME points to a valid JDK
if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $JavaExe = (Get-Command java -ErrorAction Stop).Source
    $env:JAVA_HOME = Split-Path -Parent (Split-Path -Parent $JavaExe)
}

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildDir = Join-Path $RootDir 'build'
$ObjDir = Join-Path $BuildDir 'obj'
$ResFlatDir = Join-Path $BuildDir 'res_flat'
$GenDir = Join-Path $BuildDir 'gen'
$ClassesDir = Join-Path $BuildDir 'classes'
$DexDir = Join-Path $BuildDir 'dex'

# Locate Android SDK
$SdkCandidates = @('C:\Android\Sdk', "$env:LOCALAPPDATA\Android\Sdk", $env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
$SdkDir = $SdkCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $SdkDir) {
    throw "Android SDK not found."
}

$BuildTools = Join-Path $SdkDir 'build-tools\34.0.0'
$AndroidJar = Join-Path $SdkDir 'platforms\android-34\android.jar'
$Aapt2 = Join-Path $BuildTools 'aapt2.exe'
$D8 = Join-Path $BuildTools 'd8.bat'
$ZipAlign = Join-Path $BuildTools 'zipalign.exe'
$ApkSigner = Join-Path $BuildTools 'apksigner.bat'

foreach ($tool in @($AndroidJar, $Aapt2, $D8, $ZipAlign, $ApkSigner)) {
    if (-not (Test-Path $tool)) {
        throw "Required tool missing: $tool"
    }
}

# Clean intermediate dirs (preserve keystore)
foreach ($d in @($ObjDir, $ResFlatDir, $GenDir, $ClassesDir, $DexDir)) {
    if (Test-Path $d) { Remove-Item -Recurse -Force $d }
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

Write-Host "[1/6] Compiling resources with aapt2..."
& $Aapt2 compile --dir (Join-Path $RootDir 'res') -o $ResFlatDir
if ($LASTEXITCODE -ne 0) { throw "aapt2 compile failed ($LASTEXITCODE)" }

$FlatFiles = Get-ChildItem -Path $ResFlatDir -Filter '*.flat' | ForEach-Object { $_.FullName }
$UnalignedApk = Join-Path $ObjDir 'unaligned.apk'

Write-Host "[2/6] Linking resources and manifest with aapt2..."
& $Aapt2 link `
    -I $AndroidJar `
    --manifest (Join-Path $RootDir 'AndroidManifest.xml') `
    --java $GenDir `
    --min-sdk-version 26 `
    --target-sdk-version 34 `
    -o $UnalignedApk `
    @FlatFiles
if ($LASTEXITCODE -ne 0) { throw "aapt2 link failed ($LASTEXITCODE)" }

Write-Host "[3/6] Compiling Java sources with javac..."
$JavaFiles = @()
$JavaFiles += Get-ChildItem -Path (Join-Path $RootDir 'src') -Recurse -Filter '*.java' | ForEach-Object { $_.FullName }
$JavaFiles += Get-ChildItem -Path $GenDir -Recurse -Filter '*.java' | ForEach-Object { $_.FullName }

& javac `
    -encoding UTF-8 `
    -source 11 -target 11 `
    -classpath $AndroidJar `
    -Xlint:all,-serial,-options `
    -d $ClassesDir `
    @JavaFiles
if ($LASTEXITCODE -ne 0) { throw "javac failed ($LASTEXITCODE)" }

Write-Host "[4/6] Converting bytecode to DEX with d8..."
$ClassFiles = Get-ChildItem -Path $ClassesDir -Recurse -Filter '*.class' | ForEach-Object { $_.FullName }
& $D8 `
    --min-api 26 `
    --lib $AndroidJar `
    --output $DexDir `
    @ClassFiles
if ($LASTEXITCODE -ne 0) { throw "d8 failed ($LASTEXITCODE)" }

Write-Host "[5/6] Packaging classes.dex and aligning APK..."
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$DexFile = Join-Path $DexDir 'classes.dex'
$Zip = [System.IO.Compression.ZipFile]::Open($UnalignedApk, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Zip, $DexFile, 'classes.dex', [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
} finally {
    $Zip.Dispose()
}

$AlignedApk = Join-Path $ObjDir 'aligned.apk'
& $ZipAlign -f -p 4 $UnalignedApk $AlignedApk
if ($LASTEXITCODE -ne 0) { throw "zipalign failed ($LASTEXITCODE)" }

Write-Host "[6/6] Signing and verifying APK..."
$Keystore = Join-Path $BuildDir 'netspeedlite.keystore'
$KeyAlias = 'netspeedlite'
$StorePass = 'netspeedlite123'

if (-not (Test-Path $Keystore)) {
    & keytool -genkeypair `
        -v `
        -keystore $Keystore `
        -alias $KeyAlias `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -storepass $StorePass `
        -keypass $StorePass `
        -dname 'CN=NetSpeedLite, OU=Mobile, O=NetSpeedLite, L=Local, S=NA, C=US'
    if ($LASTEXITCODE -ne 0) { throw "keytool failed ($LASTEXITCODE)" }
}

$FinalApk = Join-Path $BuildDir 'NetSpeedLite-Android.apk'
& $ApkSigner sign `
    --ks $Keystore `
    --ks-key-alias $KeyAlias `
    --ks-pass "pass:$StorePass" `
    --key-pass "pass:$StorePass" `
    --out $FinalApk `
    $AlignedApk
if ($LASTEXITCODE -ne 0) { throw "apksigner sign failed ($LASTEXITCODE)" }

& $ApkSigner verify --verbose $FinalApk
if ($LASTEXITCODE -ne 0) { throw "apksigner verify failed ($LASTEXITCODE)" }

$ApkInfo = Get-Item $FinalApk
Write-Host ("BUILD SUCCEEDED: {0} ({1:N0} bytes)" -f $ApkInfo.FullName, $ApkInfo.Length)
