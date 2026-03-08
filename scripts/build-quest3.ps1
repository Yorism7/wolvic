# Build Wolvic APK for Meta Quest 3
# Requires: OVR Platform SDK in third_party/OVRPlatformSDK (see QUEST3-BUILD.md)
# Run from repo root: .\scripts\build-quest3.ps1

$ErrorActionPreference = "Stop"
# Wolvic repo root = parent of folder containing this script (scripts/)
$WolvicRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $WolvicRoot "app\build.gradle"))) {
    Write-Error "Repo root not found (expected app\build.gradle in $WolvicRoot). Run from wolvic folder."
    exit 1
}
Set-Location $WolvicRoot

# 1. Git submodules (vrb, KTX-Software, tinygltf)
Write-Host "Checking git submodules..."
$vrbSrc = Join-Path $WolvicRoot "app\src\main\cpp\vrb\src"
if (-not (Test-Path $vrbSrc)) {
    $gitDir = Join-Path $WolvicRoot ".git"
    if (Test-Path $gitDir) {
        Write-Host "Initializing submodules..."
        git submodule update --init --recursive
    } else {
        Write-Warning "Not a git repo or submodules missing. Ensure app\src\main\cpp\vrb\src and KTX-Software exist."
    }
}

# 2. OVR Platform SDK required for Quest
$ovrSo = Join-Path $WolvicRoot "third_party\OVRPlatformSDK\Android\libs\arm64-v8a\libovrplatformloader.so"
$ovrInclude = Join-Path $WolvicRoot "third_party\OVRPlatformSDK\Include"
if (-not (Test-Path $ovrSo)) {
    Write-Host ""
    Write-Host "OVR Platform SDK not found. Quest 3 build requires it." -ForegroundColor Yellow
    Write-Host "  Expected: third_party\OVRPlatformSDK\Android\libs\arm64-v8a\libovrplatformloader.so" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  A) Download from Meta (you MUST sign in first; otherwise page shows 'not available'):" -ForegroundColor White
    Write-Host "     https://developers.meta.com/horizon/downloads/" -ForegroundColor Gray
    Write-Host "     or https://developers.meta.com/horizon/downloads/package/oculus-platform-sdk-android/" -ForegroundColor Gray
    Write-Host "     Then run: .\scripts\setup-ovr-sdk.ps1 -ZipPath `"C:\path\to\downloaded.zip`"" -ForegroundColor Gray
    Write-Host "  B) If you have wolvic-third-parties repo access:" -ForegroundColor White
    Write-Host "     git clone git@github.com:Igalia/wolvic-third-parties.git third_party" -ForegroundColor Gray
    Write-Host ""
    Write-Host "See scripts\QUEST3-BUILD.md for full steps." -ForegroundColor Cyan
    exit 1
}

# 3. Build
Write-Host "Building Quest 3 debug APK (oculusvrArm64GeckoGenericDebug)..."
& .\gradlew.bat assembleOculusvrArm64GeckoGenericDebug --no-build-cache
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apkDir = Join-Path $WolvicRoot "app\build\outputs\apk\oculusvrArm64GeckoGeneric\debug"
$apk = Get-ChildItem $apkDir -Filter "*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($apk) {
    Write-Host ""
    Write-Host "Build succeeded. APK: $($apk.FullName)" -ForegroundColor Green
} else {
    Write-Host "Build finished. Check $apkDir for APK." -ForegroundColor Green
}
