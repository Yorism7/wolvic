# Capture logcat automatically: clear, wait 90s for you to reproduce crash, then save.
# Run: .\scripts\capture-crash-log-auto.ps1
# Then put on headset and reproduce the VR 180 crash within 90 seconds.

$ErrorActionPreference = "Stop"
$WolvicRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$WaitSeconds = 90

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Error "adb not in PATH."
    exit 1
}
if ((adb devices | Where-Object { $_ -match "device$" }).Count -eq 0) {
    Write-Error "No device connected."
    exit 1
}

Write-Host "Clearing logcat ..." -ForegroundColor Cyan
adb logcat -c

Write-Host ""
Write-Host "You have $WaitSeconds seconds to reproduce the crash:" -ForegroundColor Yellow
Write-Host "  1. Put on headset, open Wolvic" -ForegroundColor White
Write-Host "  2. Open a VR 180 immersive page, enter immersive until it crashes" -ForegroundColor White
Write-Host ""
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
for ($i = $WaitSeconds; $i -gt 0; $i--) {
    Write-Host "`r  Saving log in $i s... " -NoNewline -ForegroundColor Gray
    Start-Sleep -Seconds 1
}
Write-Host ""

$logPath = Join-Path $WolvicRoot "crash_log_${ts}.txt"
$vrbPath = Join-Path $WolvicRoot "crash_log_${ts}_VRB_only.txt"

Write-Host "Dumping logcat ..." -ForegroundColor Cyan
adb logcat -d | Out-File -FilePath $logPath -Encoding utf8
adb logcat -d | Select-String -Pattern "VRB|CreateLayerEquirect|Gecko|breakpad|minidump|Fatal|crash|Wolvic|igalia|Exiting due to|setWakeLockState|notifyWakeLock|google-breakpad" | Out-File -FilePath $vrbPath -Encoding utf8

Write-Host "Full log: $logPath" -ForegroundColor Green
Write-Host "VRB/relevant: $vrbPath" -ForegroundColor Green
