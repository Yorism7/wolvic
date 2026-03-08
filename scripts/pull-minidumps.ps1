# Pull Wolvic crash minidumps from device (Quest/Android)
# Requires: device connected, adb in PATH, debug build of Wolvic installed
# Usage: .\scripts\pull-minidumps.ps1  [-OutputDir ".\crash_dumps"]

param(
    [string]$OutputDir = (Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "crash_dumps")
)

$ErrorActionPreference = "Stop"
$Package = "com.igalia.wolvic"

# Check adb
$null = Get-Command adb -ErrorAction Stop
$devices = adb devices | Where-Object { $_ -match "device$" }
if ($devices.Count -eq 0) {
    Write-Error "No device connected. Connect Quest and enable USB debugging."
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDir = (Resolve-Path $OutputDir).Path
Write-Host "Output directory: $OutputDir" -ForegroundColor Cyan

# List profile dirs: run-as can only see app's files/ under package
$profilesLine = (adb shell "run-as $Package ls files/mozilla 2>/dev/null || true") -replace "`r", ""
$profileDirs = $profilesLine -split "[\s\r\n]+" | Where-Object { $_ -match "\.default$" }
if (-not $profileDirs) {
    Write-Host "No mozilla profile found (no *.default in files/mozilla). No minidumps pulled." -ForegroundColor Yellow
    exit 0
}

foreach ($profile in $profileDirs) {
    $minidumpDir = "files/mozilla/$profile/minidumps"
    $listLine = (adb shell "run-as $Package ls $minidumpDir 2>/dev/null || true") -replace "`r", ""
    $dmpFiles = $listLine -split "[\s\r\n]+" | Where-Object { $_ -match "\.dmp$" }
    if (-not $dmpFiles) {
        Write-Host "No .dmp files in $minidumpDir" -ForegroundColor Gray
        continue
    }
    foreach ($dmp in $dmpFiles) {
        $remotePath = "$minidumpDir/$dmp"
        $localPath = Join-Path $OutputDir $dmp
        Write-Host "Pulling $dmp ..." -ForegroundColor Green
        # Binary: use Start-Process -RedirectStandardOutput so PowerShell does not corrupt bytes
        $psi = @{
            FilePath               = "adb"
            ArgumentList           = "exec-out", "run-as", $Package, "cat", $remotePath
            RedirectStandardOutput = $localPath
            NoNewWindow            = $true
            Wait                   = $true
        }
        & Start-Process @psi
    }
}

# Fallback: try direct pull if run-as path differs (e.g. some devices expose path)
$directPath = "/data/user/0/$Package/files/mozilla"
$directList = adb shell "ls $directPath 2>/dev/null" 2>$null
if ($directList -match "\.default") {
    $profiles = ($directList -split "[\r\n\s]+") | Where-Object { $_ -match "\.default" }
    foreach ($p in $profiles) {
        $full = "$directPath/$p/minidumps"
        $files = (adb shell "ls $full 2>/dev/null") -split "[\r\n\s]+" | Where-Object { $_ -match "\.dmp$" }
        foreach ($f in $files) {
            $localPath = Join-Path $OutputDir $f
            Write-Host "Pulling (direct) $f ..." -ForegroundColor Green
            adb pull "$full/$f" $localPath 2>$null
        }
    }
}

Write-Host "Done. Minidumps (if any) saved to: $OutputDir" -ForegroundColor Green
Write-Host "To get a readable stack you need symbols from your Wolvic native build (e.g. breakpad minidump_stackwalk + .sym files)." -ForegroundColor Cyan
