# ดึง logcat เฉพาะ Wolvic (tag VRB) ตอน reproduce ปัญหา VR video (มีเสียงไม่มีภาพ / ไม่เข้า immersive)
# ใช้: .\scripts\capture-vr-video-log.ps1
# 1. รันสคริปต์ แล้วใส่หัว เปิด Wolvic เล่น VR video (180/360) จนมีเสียงแต่ไม่มีภาพ
# 2. กด Enter ในเทอร์มินัล
# 3. ดูไฟล์ vr_video_log_*_VRB.txt ว่ามี CreateLayerEquirect / VRVideo หรือไม่

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
$vrbPath = Join-Path $WolvicRoot "vr_video_log_${ts}_VRB.txt"

Write-Host ""
Write-Host "Reproduce VR video issue:" -ForegroundColor Yellow
Write-Host "  1. Put on headset, open Wolvic" -ForegroundColor White
Write-Host "  2. Open a page with VR 180/360 video, play it" -ForegroundColor White
Write-Host "  3. Select Watch in VR / 180 or 360 (so you get sound but no image)" -ForegroundColor White
Write-Host "  4. Wait a few seconds then take off headset" -ForegroundColor White
Write-Host ""
Write-Host "When done, press Enter here to save VRB log to:" -ForegroundColor Yellow
Write-Host "  $vrbPath" -ForegroundColor Gray
Write-Host ""
Read-Host

Write-Host "Dumping logcat (VRB tag only) ..." -ForegroundColor Cyan
adb logcat -d -s VRB:V | Set-Content $vrbPath -Encoding UTF8
$lines = (Get-Content $vrbPath).Count
Write-Host "Saved $lines lines to: $vrbPath" -ForegroundColor Green

# Also show lines that mention our VR video debug strings
$relevant = Get-Content $vrbPath | Select-String -Pattern "CreateLayerEquirect|VRVideo|equirect|geometry fallback|SurfaceTexture"
if ($relevant) {
    Write-Host ""
    Write-Host "VR video related lines:" -ForegroundColor Cyan
    $relevant | ForEach-Object { Write-Host $_.Line }
} else {
    Write-Host ""
    Write-Host "No CreateLayerEquirect/VRVideo lines found. Make sure Wolvic was in foreground when you reproduced." -ForegroundColor Yellow
}
