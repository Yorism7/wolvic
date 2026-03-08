# Extract Oculus/Meta OVR Platform SDK zip to third_party/OVRPlatformSDK
# Usage: .\setup-ovr-sdk.ps1 -ZipPath "C:\path\to\oculus-platform-sdk-android.zip"
# Or:    .\setup-ovr-sdk.ps1  (will prompt for path)

param(
    [Parameter(Mandatory=$false)]
    [string]$ZipPath
)

$ErrorActionPreference = "Stop"
$WolvicRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$TargetDir = Join-Path $WolvicRoot "third_party\OVRPlatformSDK"

if (-not $ZipPath) {
    $ZipPath = Read-Host "Enter full path to Oculus Platform SDK Android zip file"
}
$ZipPath = $ZipPath.Trim('"')
if (-not (Test-Path $ZipPath)) {
    Write-Error "File not found: $ZipPath"
    exit 1
}

$tempExtract = Join-Path $env:TEMP "ovr_sdk_extract_$(Get-Random)"
New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null
try {
    Write-Host "Extracting zip..."
    Expand-Archive -Path $ZipPath -DestinationPath $tempExtract -Force

    # Find Android and Include (zip may have root "Android"/"Include" or one top-level folder containing them)
    $androidSrc = $null
    $includeSrc = $null
    $root = Get-ChildItem $tempExtract -Directory | Select-Object -First 1
    $searchRoot = $tempExtract
    if ($root) { $searchRoot = $root.FullName }
    foreach ($item in Get-ChildItem $searchRoot -Recurse -Directory -Filter "Android" -ErrorAction SilentlyContinue) {
        if (Test-Path (Join-Path $item.FullName "libs")) {
            $androidSrc = $item.FullName
            $includeDir = Get-ChildItem $tempExtract -Recurse -Directory -Filter "Include" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($includeDir) { $includeSrc = $includeDir.FullName }
            break
        }
    }
    if (-not $androidSrc) {
        $androidSrc = Join-Path $tempExtract "Android"
        $includeSrc = Join-Path $tempExtract "Include"
    }
    if (-not (Test-Path $androidSrc)) {
        Write-Error "Zip does not contain 'Android' folder. Expected structure: .../Android/libs/arm64-v8a/libovrplatformloader.so"
        exit 1
    }

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Copy-Item -Path $androidSrc -Destination (Join-Path $TargetDir "Android") -Recurse -Force
    if (Test-Path $includeSrc) {
        Copy-Item -Path $includeSrc -Destination (Join-Path $TargetDir "Include") -Recurse -Force
    }
    $soPath = Join-Path $TargetDir "Android\libs\arm64-v8a\libovrplatformloader.so"
    if (-not (Test-Path $soPath)) {
        Write-Warning "libovrplatformloader.so not found at expected path. Check $TargetDir\Android\libs\arm64-v8a\"
    } else {
        Write-Host "OVR Platform SDK installed to $TargetDir"
        Write-Host "You can now run: .\scripts\build-quest3.ps1"
    }
} finally {
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
}
