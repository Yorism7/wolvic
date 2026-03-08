# Capture logcat when reproducing Wolvic VR 180 crash
# 1. Clears logcat
# 2. You reproduce the crash (open app, open VR 180 page, enter immersive)
# 3. Press Enter when crash happened
# 4. Saves log to crash_log_YYYYMMDD_HHmmss.txt
# Usage: .\scripts\capture-crash-log.ps1

$ErrorActionPreference = "Stop"
$WolvicRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Error "adb not in PATH. Add Android SDK platform-tools to PATH."
    exit 1
}
$devices = adb devices | Where-Object { $_ -match "device$" }
if ($devices.Count -eq 0) {
    Write-Error "No device connected."
    exit 1
}

Write-Host "Clearing logcat ..." -ForegroundColor Cyan
adb logcat -c

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $WolvicRoot "crash_log_$ts.txt"

Write-Host ""
Write-Host "Now reproduce the crash:" -ForegroundColor Yellow
Write-Host "  1. Open Wolvic on the headset" -ForegroundColor White
Write-Host "  2. Open a VR 180 immersive page" -ForegroundColor White
Write-Host "  3. Enter immersive (trigger, etc.) until it crashes" -ForegroundColor White
Write-Host ""
Write-Host "When the app has crashed, press Enter here to save logcat to:" -ForegroundColor Yellow
Write-Host "  $logPath" -ForegroundColor Gray
Write-Host ""
Read-Host

Write-Host "Dumping logcat ..." -ForegroundColor Cyan
adb logcat -d > $logPath
Write-Host "Saved. Lines: $((Get-Content $logPath).Count)" -ForegroundColor Green

# Also save VRB-only snippet for quick check
$vrbPath = Join-Path $WolvicRoot "crash_log_${ts}_VRB_only.txt"
adb logcat -d | Select-String -Pattern "VRB|CreateLayerEquirect|Gecko|breakpad|minidump|Fatal|crash|Wolvic" | Set-Content $vrbPath -Encoding UTF8
Write-Host "VRB/relevant lines saved to: $vrbPath" -ForegroundColor Green
