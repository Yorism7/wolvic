# Build APK สำหรับ Meta Quest 3

> **ถ้าเห็น "This page isn't available"** บนเว็บ Meta = ยังไม่ได้ล็อกอิน  
> ให้ไป [developers.meta.com](https://developers.meta.com/) → **Sign in** ก่อน แล้วค่อยเปิดลิงก์ดาวน์โหลด SDK อีกครั้ง

## สิ่งที่ต้องมี

1. **Android Studio / JDK 11+** และ **Android NDK** (ผ่าน SDK Manager)
2. **OVR Platform SDK** (Oculus/Meta) – ใช้สำหรับ build variant `oculusvr`

## ขั้นตอน

### 1. ดาวน์โหลด OVR Platform SDK (ทำครั้งเดียว)

หน้าระบบ Meta มักแสดง **"This page isn't available"** ถ้ายัง**ไม่ได้ล็อกอิน** — ต้องใช้บัญชี Meta/Facebook Developer ก่อน

- **ล็อกอิน:** [Meta for Developers](https://developers.meta.com/) → Sign in
- **ศูนย์ดาวน์โหลด:** หลังล็อกอินแล้วไปที่  
  [Download SDKs | Meta Horizon](https://developers.meta.com/horizon/downloads/)  
  หรือ [Android apps downloads](https://developers.meta.com/horizon/downloads/android-apps/)  
  แล้วหา **Oculus Platform SDK** / **Android Platform SDK** (แบบ native ที่มีโฟลเดอร์ `Android` และ `Include`)
- ลิงก์เดิม (อาจต้องล็อกอิน): [Oculus Platform SDK – Android](https://developers.meta.com/horizon/downloads/package/oculus-platform-sdk-android/)
- ดาวน์โหลดไฟล์ **zip** ของ Oculus Platform SDK สำหรับ Android
- แตกไฟล์ไปที่โปรเจกต์ด้วยสคริปต์:

```powershell
cd F:\PROJECT_DEV\Wolvic\wolvic
.\scripts\setup-ovr-sdk.ps1 -ZipPath "C:\path\to\oculus-platform-sdk-android.zip"
```

หรือถ้ามีโฟลเดอร์ `Android` และ `Include` อยู่แล้ว ให้ copy ไปที่:

- `wolvic\third_party\OVRPlatformSDK\Android\` (ต้องมี `libs\arm64-v8a\libovrplatformloader.so`)
- `wolvic\third_party\OVRPlatformSDK\Include\`

### 2. Build APK

จากโฟลเดอร์ `wolvic`:

```powershell
.\scripts\build-quest3.ps1
```

หรือใช้ Gradle โดยตรง:

```powershell
.\gradlew.bat assembleOculusvrArm64GeckoGenericDebug
```

### 3. ตำแหน่ง APK

- **Debug:** `app\build\outputs\apk\oculusvrArm64GeckoGeneric\debug\Wolvic-*.apk`
- **Release:** ใช้ `assembleOculusvrArm64GeckoGenericRelease` (ต้องตั้งค่า signing)

## Debug crash (แอปเด้ง / VR 180)

### บันทึก log ตอน reproduce

1. เชื่อม Quest กับ PC แล้วรัน:

```powershell
.\scripts\capture-crash-log.ps1
```

2. ทำตามคำสั่งในสคริปต์: เล่นแอป → เปิดเว็บ VR 180 → เข้า immersive ให้เด้ง
3. พอแอปเด้งแล้วกลับมาที่เทอร์มินัล กด Enter
4. จะได้ไฟล์ `crash_log_YYYYMMDD_HHmmss.txt` และ `crash_log_*_VRB_only.txt` ในโฟลเดอร์ wolvic

### ดึง minidump จากเครื่อง

หลัง crash จะมีไฟล์ `.dmp` ใน app storage ของ Wolvic ดึงมาที่ PC ด้วย:

```powershell
.\scripts\pull-minidumps.ps1
```

ไฟล์จะไปที่ `wolvic\crash_dumps\` (หรือระบุ `-OutputDir " path "`)

ถ้าต้องการ stack trace จาก minidump ต้องใช้เครื่องมือ breakpad (เช่น `minidump_stackwalk`) กับ symbol ของ build เดียวกับ APK ที่ติดตั้ง — โปรเจกต์ Wolvic อาจอ้างอิงจาก Gecko build ที่มี breakpad อยู่แล้ว

## การแก้ไขสำหรับ VR video (immersive 180/360)

- **Equirect layer:** ถ้าไม่มี source layer ที่ใช้ได้ แอปจะไม่สร้าง OpenXR equirect และใช้โหมด geometry (sphere) แทน เพื่อลดโอกาส crash
- **CrashReporterService:** เรียก `startForeground()` ทันทีเมื่อ service ถูก start ด้วย `startForegroundService()` เพื่อไม่ให้เกิด `ForegroundServiceDidNotStartInTimeException` บน Quest
- **OffscreenDisplay:** บน API 34+ ถ้า Context ไม่ใช่ visual context จะ fallback ใช้ Display metrics แทน WindowManager
- **WAKE_LOCK:** Gecko เรียก `setWakeLockState` ตอนเล่นวิดีโอ (รวม VR) — ต้องไม่ลบ permission นี้ใน manifest มิฉะนั้นอาจ native crash

หมายเหตุ: ถ้า crash ยังเกิดใน Gecko (เช่น getScreenRefreshRate / non-visual Context) ต้องดู minidump หรืออัปเดต GeckoView ที่รองรับ Activity context / VR อย่างถูกต้อง

## ปัญหาที่พบบ่อย

- **ไม่มี OVR SDK:** ต้องดาวน์โหลดจาก Meta แล้วใช้ `setup-ovr-sdk.ps1` หรือวางโฟลเดอร์มือ
- **Gradle transform error (Windows):** ลองรันด้วย `--no-build-cache` หรือปิด antivirus ชั่วคราวที่โฟลเดอร์ `.gradle`
- **Submodules ไม่ครบ:** รัน `git submodule update --init --recursive`
