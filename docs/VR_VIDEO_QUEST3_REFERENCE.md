# VR Video บน Quest 3 – อ้างอิงจาก GitHub / Meta / OpenXR / Gecko

เอกสารนี้สรุปจากหลายแหล่ง (ไม่เฉพาะ Wolvic) ว่าการทำวิดีโอ immersive (180/360) บน Quest 3 ควรทำอย่างไร

---

## 1. Meta Horizon Browser (Oculus Browser) – วิธีที่เป็นทางการ

**ที่มา:** [Meta – Browser Video](https://developers.meta.com/horizon/documentation/web/browser-video/), [WebXR Layers](https://developers.meta.com/horizon/documentation/web/webxr-layers/)

### 2D เว็บเพจ (วิดีโอในหน้าเว็บธรรมดา)

- ผู้ใช้ **ใส่วิดีโอเต็มจอ (fullscreen)** ก่อน
- จากนั้นเบราว์เซอร์ให้เลือก **reproject** เป็น spherical 360 หรือ 180 equirect
- รองรับโหมด mono หรือ stereo (ซ้าย-ขวา / บน-ล่าง)
- ขนาดสูงสุดที่แสดง: Quest 3 = **3840×2160**

ดังนั้น flow ที่ Meta ออกแบบ: **fullscreen ก่อน → แล้วค่อยเลือก projection**

### WebXR (แอป/เว็บ XR)

- ใช้ **WebXR Media Layers**: `XRMediaBinding.createEquirectLayer(video, options)` โดยส่ง **HTMLVideoElement**
- เบราว์เซอร์จัดขนาด layer และวาดให้เหมาะสม ไม่ต้องใช้ `requestFullscreen()` ในกรณีนี้
- รองรับวิดีโอ cross-origin / สตรีม
- บน Oculus Browser 16.1+ รองรับถึง 8K @ 90fps โดยไม่หลุดเฟรม

```javascript
let xrMediaFactory = new XRMediaBinding(session);
let video = document.createElement('video');
video.src = '...';
let layer = xrMediaFactory.createEquirectLayer(video, { space: refSpace, layout: "stereo-top-bottom" });
session.updateRenderState({ layers: [ layer ] });
```

---

## 2. OpenXR Native (Quest / ทุกแพลตฟอร์ม)

**ที่มา:** [Khronos XrCompositionLayerEquirectKHR](https://registry.khronos.org/OpenXR/specs/1.1/man/html/XrCompositionLayerEquirectKHR.html), [Meta OpenXR Swapchains](https://developers.meta.com/horizon/documentation/native/android/mobile-openxr-swapchains/)

- ใช้ extension **XR_KHR_composition_layer_equirect**
- โครงสร้าง **XrCompositionLayerEquirectKHR** มี:
  - **subImage** = `XrSwapchainSubImage` (ชี้ไปที่ swapchain ที่เป็น texture ของภาพ/วิดีโอ)
  - pose, radius, scale, bias สำหรับ mapping equirect ลง sphere
- Swapchain ต้องเป็น **ภาพที่ compositor วาดได้** (เช่น จาก Surface/SurfaceTexture ที่ engine วาดลงไป)
- บน Quest ใช้ format เช่น OpenGL `GL_RGB10_A2` หรือ Vulkan `VK_FORMAT_B8G8R8A8_SRGB`

ความหมาย: **ภาพที่ส่งเข้า equirect layer ต้องเป็น “ภาพที่ต้องการแสดง” เท่านั้น** (เช่น เฉพาะวิดีโอ) ไม่ใช่ทั้งหน้าต่างเบราว์เซอร์

---

## 3. Firefox Reality / Wolvic (GeckoView) – พายพล์ไลน์กราฟิก

**ที่มา:** [Firefox Reality – graphics pipeline (Wiki)](https://github.com/MozillaReality/FirefoxReality/wiki/Firefox-Reality-internals:-graphics-pipeline)

- GeckoView **วาดทุกอย่างลง Surface เดียว** (แท็บเดียว = หนึ่ง Surface)
- **วิดีโอก็วาดลง Surface เดียวกัน** ทั้งตอนเป็น “iframe” ในหน้า และตอน **fullscreen**
- ความต่างคือ: **เมื่อวิดีโอ fullscreen แล้ว Gecko compositor จะวาดเฉพาะวิดีโอลง Surface นั้น** (ไม่วาด address bar / UI อื่น)
- บน Oculus: ใช้ **Equirect Timewarp Layer** โดยส่ง surface/swapchain นี้ไปให้ VR compositor โดยตรง → texture ถูก sample แค่ครั้งเดียว

สรุปสำหรับ Wolvic/Gecko:

- ถ้าต้องการให้ layer ที่ส่งไป equirect เป็น **เฉพาะวิดีโอ (ไม่มี UI)** ต้องให้ **วิดีโอเข้า fullscreen ก่อน** (หน้าเว็บเรียก `requestFullscreen()` ที่ element วิดีโอ)
- หลังจากนั้น Surface/swapchain ที่ได้จะ “มีแต่วิดีโอ” จึงเหมาะกับ **XrCompositionLayerEquirectKHR**

---

## 4. Wolvic – การ implement ที่สอดคล้องกับเอกสาร

**ที่มา:** โค้ด Wolvic, [issue #150](https://github.com/Igalia/wolvic/issues/150) (Wait for media full screen availability before entering video VR mode)

- `getFullScreenVideo()` จะไม่เป็น null ก็ต่อเมื่อ **media (วิดีโอ) อยู่โหมด fullscreen** แล้ว
- ถ้าเข้า VR ก่อนวิดีโอ fullscreen → จะได้ layer ของ **ทั้งหน้าต่าง** (มี UI) หรือไม่มีวิดีโอ → จอดำ / เห็น UI แทนวิดีโอ
- ทางแก้ที่ issue #150: **รอ event fullscreen จาก Media** (ไม่ใช่แค่ content fullscreen) ก่อนเข้า VR

ดังนั้น flow ที่ถูกต้องบน Wolvic:

1. ผู้ใช้กดเล่น (หรือแอปสั่งให้วิดีโอเล่น)
2. **ให้ element วิดีโอเข้า fullscreen** (เช่น เรียก `document.querySelector('video').requestFullscreen()` ผ่าน JS)
3. รอ **onMediaFullScreen** (และ `getFullScreenVideo() != null`)
4. จากนั้นค่อย **เข้า VR** (สร้าง equirect จาก layer/swapchain ของหน้าต่างนั้น)
5. ตอนนี้ swapchain = เนื้อหาเฉพาะวิดีโอ → แสดงใน equirect ได้ถูกต้อง (มีภาพ, ไม่มี UI)

---

## 5. สรุปสั้นๆ – ต้องทำยังไงบน Quest 3

| แหล่ง | วิธีที่ต้องทำ |
|--------|------------------|
| **Meta Browser (2D page)** | ผู้ใช้กด fullscreen วิดีโอก่อน → เบราว์เซอร์ให้เลือก projection (360/180) |
| **Meta Browser (WebXR)** | ใช้ `XRMediaBinding.createEquirectLayer(video)` ไม่จำเป็นต้อง fullscreen แยก |
| **OpenXR native** | สร้าง swapchain จาก texture ที่เป็น “เฉพาะวิดีโอ” แล้วส่งเข้า `XrCompositionLayerEquirectKHR` |
| **Wolvic / GeckoView** | ให้วิดีโอ fullscreen ก่อน (requestFullscreen ที่ &lt;video&gt;) → รอ onMediaFullScreen → ค่อยเข้า VR และใช้ layer นั้นทำ equirect |

สำหรับ Wolvic บน Quest 3 การทำที่สอดคล้องกับทั้ง Meta, OpenXR และ Gecko คือ:

- **ไม่เข้า immersive ทันทีโดยใช้ layer ทั้งหน้าต่าง**
- **สั่ง `requestFullscreen()` ที่ element วิดีโอ** (จากแอปหรือจากเว็บ) แล้วรอ **onMediaFullScreen** และ **getFullScreenVideo()**
- **แล้วค่อยสร้าง equirect layer** จาก swapchain ของหน้าต่างนั้น (ซึ่งตอนนี้เป็น “เฉพาะวิดีโอ”)

เอกสารนี้ใช้เป็นอ้างอิงสำหรับการ implement / แก้บั๊ก “จอดำ” หรือ “เห็น UI แทนวิดีโอ” ในโหมด immersive บน Quest 3
