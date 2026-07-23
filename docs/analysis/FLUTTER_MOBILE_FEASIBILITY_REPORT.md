# Flutter Mobile Feasibility Report for Wavez Music Visuals

## Document Metadata

- Nhiệm vụ nguồn: `promt-v2.md` — Bước 14, đánh giá khả năng tái dựng visual trên Flutter mobile.
- Ngày phân tích: 2026-07-23.
- Phạm vi: phân tích tĩnh source Wavez hiện tại và kiểm tra tài liệu/package công khai hiện hành.
- Kết quả liên quan trước đó: `docs/analysis/MUSIC_VISUAL_FORENSIC_REPORT.md`.
- Loại công việc: feasibility study và kế hoạch; không triển khai Flutter, không sửa source.
- Confidence:
  - `CONFIRMED`: có bằng chứng trực tiếp trong source hoặc tài liệu chính thức.
  - `INFERRED`: suy luận kỹ thuật có căn cứ nhưng chưa chạy trên thiết bị.
  - `UNVERIFIED`: cần proof-of-concept hoặc runtime/network measurement.

## Executive Verdict

Các visual ưu tiên của Wavez **có thể tái dựng tốt trên Flutter mobile**, nhưng phải xem đây là một **reimplementation**, không phải port trực tiếp JavaScript/DOM/Web Audio/Three.js/GSAP.

Phạm vi phù hợp nhất cho mobile là waveform theo tiến độ, spectrum/band bars, particle 2D nhẹ, shader gradient/glow, album-cover motion, lyric đồng bộ theo dòng và adaptive quality. Công thức FFT band, normalization, attack/release, lyric timing và easing có thể giữ gần 1:1 về thuật toán; lớp render và audio capture phải viết lại theo Flutter/native.

Khuyến nghị:

1. POC đầu tiên dùng **file audio local cố định** + playback position + waveform precompute + lyric theo dòng. Không nối Zing/YouTube ở bước này.
2. Production audio-reactive dùng native feature extractor khi cần RMS/FFT ổn định trên cả Android và iOS.
3. Chỉ gửi feature đã rút gọn (`rms`, `peak`, `bass`, `mid`, `treble`, `beatImpulse`) về Dart; không đẩy PCM hoặc hàng nghìn FFT bin qua platform channel mỗi frame.
4. Không đưa 3D shelf, cinematic camera đầy đủ, webcam gesture hay desktop overlay vào mobile V1.
5. Không thay state-management toàn app chỉ để phục vụ visual tần suất cao.
6. Chỉ gọi precomputed waveform là “MVP an toàn” sau khi URL/header/expiry/cache/storage của nguồn thật vượt qua một integration gate riêng.

## 1. Scope and Non-goals

### 1.1 Phạm vi ưu tiên

- Waveform hoặc đường sóng chạy theo nhạc.
- Spectrum bars/curve.
- Bass/mid/treble reactive motion.
- Particle 2D nhẹ.
- Gradient, glow và fragment shader phản ứng theo feature.
- Album-cover pulse/tilt/parallax nhẹ.
- Lyric theo dòng và chuyển cảnh dòng trước/hiện tại/sắp tới.
- Karaoke theo từ chỉ khi normalized lyric thật sự có word timestamp.
- Seek lyric và waveform.
- Preset nhẹ và adaptive quality theo thiết bị/lifecycle.

### 1.2 Không ưu tiên

- Port nguyên WebGL scene.
- 3D playlist shelf hoàn chỉnh.
- Cinematic 3D camera nhiều channel.
- Webcam/MediaPipe gesture.
- Hover-centric interaction.
- Electron desktop lyrics overlay.
- Giữ hai UI stack Flutter + web lâu dài.

### 1.3 Ranh giới bằng chứng

Repo hiện tại không có `pubspec.yaml`, file `.dart`, thư mục Flutter `android/` hoặc `ios/`. Vì vậy không có “audio player hiện tại của Flutter project” để kiểm tra. Mọi đề xuất Flutter dưới đây là architecture option; package chưa được cài và chưa được chạy trong Wavez.

## 2. Direct Port Versus Reimplementation

| Hạng mục | Port trực tiếp | Reimplementation phù hợp |
| --- | --- | --- |
| DOM/CSS | Không có runtime tương đương trong Flutter native | Viết Widget/CustomPainter |
| GSAP timeline | Không chạy trực tiếp | Chuyển keyframe/easing sang `AnimationController`, Tween, `TweenSequence` |
| Web Audio graph | Không có `AnalyserNode` trong Flutter SDK | Player/native tap sinh normalized audio features |
| Three.js/GLSL | Scene graph và shader API khác | Giữ visual behavior; viết lại Canvas/Flutter fragment shader |
| `requestAnimationFrame` | Không dùng trực tiếp | `Ticker`, `AnimationController` hoặc repaint `Listenable` |
| Electron IPC | Không tồn tại trên mobile | Dart service, isolate, platform channel |
| Lyrics timing | Có thể giữ gần nguyên model/timestamp math | Parser/model Dart + Flutter render |
| Band mapping/smoothing | Có thể giữ công thức | Chạy trên feature packet native hoặc Dart |

Kết luận: chỉ timing, toán mapping, smoothing, easing và state transition có tính “gần 1:1”. Render tree, audio capture, lifecycle và input đều phải viết lại.

## 3. Ground Truth from Current Wavez

### 3.1 Visual/audio techniques làm nguồn tham chiếu

Source desktop hiện dùng hai `AnalyserNode` với FFT size 2048 (`public/index.html:2732-2737`, `17745-17765`), tính band RMS ở `4431-4455`, chạy realtime beat engine ở `4444-4633`, render trong main animation loop ở `26759-27015`, và giới hạn DPR theo pixel budget ở `3789-3803`.

Những phần có giá trị tái sử dụng về thuật toán:

- Chia dải tần theo sample rate/FFT size.
- Dynamic peak normalization.
- Attack/release smoothing.
- Confidence/cooldown cho beat impulse.
- Playback-position lyric lookup.
- Current/outgoing/upcoming lyric state.
- Performance quality profile và giảm DPR/effect.

Những phần chỉ nên giữ ý tưởng:

- Cover point cloud shader.
- 3D lyric world transform.
- Camera beat choreography.
- Shelf raycast/layout.

### 3.2 Music stream hiện tại

`zing-proxy.js:getSongStream()` chọn URL HTTPS thật từ mức `320`, `128` hoặc `64`. `server.js:handleSongUrl()` trả URL đó cho renderer; nếu Zing thất bại, URL Google/YouTube được resolve bằng `yt-dlp`.

`/api/audio` ở `server.js:4378+`:

- Forward header `Range`.
- Forward `Content-Length` và `Content-Range` nếu upstream trả.
- Công bố `Accept-Ranges: bytes`.
- Stream body về client.

Do đó:

- **Direct file URL:** `CONFIRMED` ở mức code: đường chính nhận URL CDN trực tiếp, không phải một ID trừu tượng. Container/codec cụ thể thay đổi theo upstream.
- **Range request:** `CONFIRMED` proxy có hỗ trợ/forward; việc từng CDN URL luôn đáp ứng range vẫn cần runtime matrix.
- **URL hết hạn:** YouTube URL được code ghi rõ phải re-resolve khi phát vì có expiry. Zing URL có dấu hiệu là URL resolve theo phiên, nhưng source không lưu `expiresAt`; thời hạn cụ thể là `UNVERIFIED`.
- **HLS/DASH:** current Wavez path không xây hoặc parse manifest HLS/DASH. Không được kết luận upstream không bao giờ trả manifest nếu chưa đo runtime.
- **Cache:** không có durable audio cache/waveform cache trong đường phát hiện tại.
- **Offline analysis:** khả thi nếu tải đủ bytes trước khi URL hết hạn và decoder hỗ trợ format; chưa phải capability hiện có.

### 3.3 Lyric hiện tại

`zing-proxy.js:getLyric()` trả `lyricFile`, `lyricText`, `sentences`. `server.js:handleZingLyric()` tải file LRC khi cần và trả:

```text
lyric: LRC text
yrc: ""
sentences: upstream sentences
```

Frontend `fetchLyric()` chỉ parse `r.yrc` và `r.lyric`; `sentences` chưa được dùng. `parseLyricText()` hỗ trợ timestamp theo dòng. `parseYrcText()` hỗ trợ timestamp theo từ cho nguồn legacy có YRC, nhưng Zing route hiện đặt `yrc` rỗng.

Kết luận:

- Zing hiện có line-level LRC: `CONFIRMED`.
- Word timestamp có thể tồn tại trong `sentences`, nhưng chưa normalize, chưa parse và chưa xác minh độ phủ: `UNVERIFIED`.
- Mobile MVP phải coi line-level là baseline.
- Nguồn lyric cần normalized model vì Wavez có LRC, YRC legacy, custom lyric và `sentences` schema chưa tiêu thụ.

## 4. Web/Electron-to-Flutter Mapping

| Mineradio/Web technique | Current role | Flutter equivalent | Portability | Required adaptation | Main risk |
| --- | --- | --- | --- | --- | --- |
| DOM element | UI, lyric, controls | Flutter Widget | HIGH về ý tưởng | Viết lại layout/state | Rebuild quá rộng |
| CSS transition | Hover/fade/scale | Implicit animation hoặc explicit Animation | HIGH | Chuyển duration/easing | Chồng animation khi input dồn |
| GSAP timeline | Choreography, interruption | `AnimationController`, `TweenSequence`, custom timeline | MEDIUM | Tự quản cancel/retarget | Mất interruption semantics |
| Canvas 2D | Text/texture phụ | `CustomPainter`/Canvas | HIGH | Viết lại paint/text metrics | Allocation trong `paint()` |
| WebGL fragment shader | Cover/depth/glow | `FragmentProgram`/`FragmentShader` | MEDIUM | Rewrite shader contract/uniform | Backend/device variation |
| Three.js particle | Particle cover/scene | `CustomPainter`, fragment shader, hoặc engine khi thật cần | MEDIUM/LOW | Bỏ scene graph hoặc viết renderer mới | Fill-rate, particle count |
| Web Audio `AnalyserNode` | Waveform/FFT/bands | Player FFT experimental, native tap, hoặc precompute | LOW trực tiếp | Thay nguồn feature | Platform parity |
| `requestAnimationFrame` | Main loop | `Ticker`, `AnimationController`, repaint `Listenable` | HIGH | Lifecycle-aware scheduling | Ticker leak/background work |
| Browser event | Pointer/wheel/key | `GestureDetector`, `Listener`, `RawGestureDetector` | HIGH | Redesign cho touch | Gesture conflict |
| CSS blur/glow | Depth/readability | `ImageFilter`, `MaskFilter`, `ShaderMask`, shader | MEDIUM | Giới hạn vùng/layer | `saveLayer` và overdraw |
| DOM lyrics | Line/stage lyric | `Text`, `RichText`, `TextPainter`, `CustomPainter` | HIGH | Text measurement/font fallback | Dòng dài, dấu tiếng Việt |
| `localStorage` | Preset/settings | SharedPreferences/database/file cache | HIGH | Version/migration schema | Cache invalidation |
| Electron IPC | Overlay/control bridge | Dart service/isolate/platform channel | MEDIUM | Thiết kế message/lifecycle mới | Traffic và resource cleanup |
| Browser webcam | Hand landmarks | Camera plugin + native/ML pipeline | LOW | Viết pipeline riêng | Permission, thermal, latency |
| Adaptive DPR | Pixel budget | quality profile + painter/shader resolution scale | HIGH về ý tưởng | Đo frame timing thực | Chất lượng nhảy liên tục |

### Bảng bắt buộc: Current Technique Mapping

| Current technique | Flutter equivalent | Preserve algorithm | Rewrite required | Native dependency | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| FFT band aggregation | Native/Dart feature reducer | Có | Có lớp input | Có thể | Giữ Hz boundaries, scale theo sample rate |
| Attack/release | Dart math | Có | Ít | Không | Nên time-based thay vì frame-dependent |
| Dynamic peak normalization | Dart/native reducer | Có | Ít | Không bắt buộc | Reset/decay khi đổi track và silence |
| Beat impulse/cooldown | Dart/native reducer | Có | Vừa | Không bắt buộc | Cần timestamp audio |
| Particle visual | `CustomPainter`/shader | Một phần | Có | Không | Giảm số lượng và overdraw |
| 3D cover point cloud | Shader/engine | Chỉ ý tưởng | Nhiều | Không bắt buộc | Không thuộc MVP |
| CanvasTexture lyric | Widget/TextPainter | Timing/layering | Có | Không | Không cần texture nếu dùng widget |
| LRC/YRC parser | Dart parser | Có | Có | Không | Normalize thành line/word model |
| Preset serialization | JSON + local storage | Có | Có | Không | Version schema rõ |
| Desktop IPC overlay | Không port | Không | Không nên làm | — | Mobile background không render UI |

## 5. Current Flutter Audio Stack

Không có Flutter app trong repository. Không có package/version/player implementation để xác nhận cho Wavez mobile.

Architecture option hợp lý nhất để khảo sát đầu tiên là `just_audio` + `audio_session`; thêm `audio_service` khi cần background/notification phức tạp. Không được coi lựa chọn này là đã chốt trước POC.

### Package assessment snapshot — 2026-07-23

| Package | Version | Role | Android | iOS | Waveform | FFT | PCM access | Maturity | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `just_audio` | 0.10.6 | URL/file/stream playback, playlist, position/duration/index/seek | Có | Có | Experimental theo README | Experimental theo README | Không thấy stable public PCM API | Cao cho playback; visualizer experimental | Ứng viên player, không cam kết FFT production |
| `audio_service` | 0.18.19 | Background audio, media notification/control center | Có | Có | Không | Không | Không | Cao | Dùng cho background orchestration, không phải analyzer |
| `audio_session` | 0.2.4 | Focus, interruption, route/session | Có | Có | Không | Không | Không | Cao | Dùng quản lý session; không sinh feature |
| `just_audio_background` | 0.0.1-beta.17 | Background add-on đơn giản | Có | Có | Không | Không | Không | Beta | Chỉ khi nhu cầu đơn giản; ghi rõ prerelease |
| `just_waveform` | 0.0.7 | Extract waveform từ **audio file** | Có | Có | Precomputed file | Không | Nội bộ extractor, không stream PCM ra app | Trung bình | POC waveform sau khi cache file |
| `media_kit` | 1.2.6 | Cross-platform playback qua native libs | Có | Có | Không xác nhận API built-in | Không xác nhận API built-in | Không xác nhận public API | Khá, nhưng issue tracker ghi “Limited Maintenance” | Chỉ benchmark như phương án player thay thế |
| `flutter_sound` | 9.30.0 | Record/play, PCM stream do app cấp/nhận | Có | Có | Không phải mục tiêu chính | Không built-in được xác nhận | Có PCM stream cho luồng do app quản lý | Lâu năm, API rộng | Không đổi player chỉ để lấy visualizer |

#### Chi tiết bằng chứng và giới hạn

**just_audio 0.10.6**

- Phát URL/file/asset/byte stream, có position/duration/current-index/seek, headers và playlist.
- Có `androidAudioSessionIdStream`, hữu ích để gắn Android `Visualizer`.
- `LockCachingAudioSource` được tài liệu đánh dấu experimental.
- README hiện liệt kê waveform/FFT visualizer trong mục **Experimental features**; issue [#97](https://github.com/ryanheise/just_audio/issues/97) về visualizer vẫn mở. Không dựa vào API này cho production trước POC trên bản package cụ thể.
- Không tìm thấy stable public PCM callback trong tài liệu package.
- License Apache-2.0/MIT.

**audio_service 0.18.19**

- Bọc audio code hiện có để chạy background và tích hợp notification, lock screen, headset, Android Auto/CarPlay.
- Không đảm nhận decode, waveform, FFT hay PCM.
- License MIT.

**audio_session 0.2.4**

- Quản lý audio focus, mixing/ducking, interruptions và hardware/session configuration.
- Không phải analyzer.
- License MIT.

**just_waveform 0.0.7**

- API nhận đường dẫn `audioInFile` và ghi `waveOutFile`.
- Hỗ trợ Android/iOS/macOS, không ghi nhận URL/HLS trực tiếp.
- Muốn dùng với Wavez phải tải/cache thành file ổn định trước.
- License MIT.

**media_kit 1.2.6**

- Playback đa nền tảng; tài liệu package được kiểm tra không chứng minh waveform/FFT/PCM callback phù hợp yêu cầu.
- Issue tracker công khai hiện gắn trạng thái “Limited Maintenance”; không nên đổi stack chỉ vì kỳ vọng analyzer chưa xác minh.
- License MIT.

**flutter_sound 9.30.0**

- Có remote URL, recording, và PCM Int16/Float32 Dart stream cho các luồng app chủ động feed/record.
- Điều đó không đồng nghĩa tự động tap decoded PCM của một stream đang phát bởi player khác.
- License MPL-2.0.

## 6. Three Levels of Audio Visualization

### 6.1 Cấp A — Precomputed waveform

```text
PlayableTrack
→ resolve stream URL + headers
→ download/cache file
→ native/file waveform extractor
→ downsample + serialize
→ CustomPainter
→ playhead từ playback position
```

Đánh giá:

- Với `just_waveform`, cần file local; thông thường phải có toàn bộ file hoặc ít nhất file đã tải đủ cho extractor.
- URL có thời hạn làm cache key theo URL không ổn định. Dùng key theo `provider + trackId + quality + analysisVersion`.
- Zing/YouTube headers và expiry phải được giữ trong download service; cache không được mặc định hợp pháp hoặc vô hạn.
- HLS/DASH cần tải/merge segment hoặc analyzer streaming riêng; current Wavez chưa dùng manifest nên chưa cần đưa vào MVP, nhưng interface phải cho phép từ chối precompute.
- Chạy extraction native/background hoặc isolate tùy package. Isolate giúp Dart CPU work, nhưng native plugin có thread model riêng.
- Waveform đã phân tích chỉ mô tả biên độ toàn track; nó không phải capture realtime và không tách bass/mid/treble.
- Có thể tái sử dụng lần sau nếu file/analysis version còn hợp lệ.

Verdict: **dễ nhất cho POC render bằng file local và phù hợp thiết bị yếu**, nhưng **không mặc định là MVP toàn hệ thống dễ nhất**. Khi nối Zing/YouTube, download, header, URL expiry, cache policy, dung lượng và điều khoản sử dụng có thể làm phương án này phức tạp hơn amplitude realtime hoặc waveform do backend chuẩn bị.

### 6.2 Cấp B — Real-time amplitude

```text
Player/native tap
→ peak + RMS
→ silence/clipping guard
→ rolling reference
→ attack/release
→ visual state 30–60 Hz
```

Đánh giá:

- Player Flutter chưa tồn tại; không có bằng chứng package được chọn sẽ expose amplitude ổn định.
- Android có `Visualizer` measurement peak/RMS; cần audio session ID và `RECORD_AUDIO`.
- iOS cần PCM tap trong cùng playback graph hoặc audio processing tap phù hợp AVPlayer.
- Capture feature 30–60 Hz là đủ cho visual; không cần gửi sample-rate audio về Dart.
- Dùng pre-volume PCM/feature để visual không biến mất khi volume thiết bị giảm; behavior cụ thể phải test với Bluetooth/headphone.
- Silence: noise floor + hold/release về 0.
- Clipping: clamp và dùng rolling percentile/peak decay thay vì scale tuyệt đối.
- Latency: packet phải kèm monotonic/audio timestamp; visual có thể interpolate giữa packet.

Verdict: **phù hợp MVP B/production nếu native path được chứng minh**.

### 6.3 Cấp C — Real-time FFT

```text
Decoded PCM hoặc platform Visualizer
→ FFT
→ band aggregation native
→ {bass, lowMid, highMid, treble, rms, peak, centroid, beatImpulse, timestamp}
→ EventChannel/FFI
→ interpolation + CustomPainter/shader
```

Đánh giá:

- FFT có thể chạy native, Dart isolate hoặc API package experimental. Production cross-platform ưu tiên native vì PCM ownership gắn với player.
- FFT size khởi điểm để benchmark: 1024 hoặc 2048; không chốt trước measurement.
- Feature update 30–60 Hz; render có thể 60/90/120 Hz bằng interpolation, không cần FFT cùng tần số màn hình.
- Không gửi toàn bộ FFT bins qua EventChannel mỗi frame. Native reducer gửi 4–8 band/feature.
- Band edge phải tính từ sample rate thực, không hard-code bin index.
- Android và iOS không có API đối xứng; cùng normalized packet nhưng implementation khác.
- Background/screen-off: tiếp tục playback nhưng tắt visual capture nếu không có consumer. Không cần visual khi không có màn hình.
- Bluetooth/headphone phải test route changes, audio session recreation, latency và session ID changes.

Verdict: **production/high-end sau POC**, không phải điều kiện để ship MVP.

### 6.4 Khuyến nghị theo mục tiêu

| Mục tiêu | Cấp phù hợp |
| --- | --- |
| POC đầu tiên | A với file local cố định; chưa nối provider |
| MVP nối nguồn thật | Chọn A chỉ khi cache/download gate pass; nếu không dùng progress-only hoặc B |
| Production phổ thông | A + B; C nếu native parity pass |
| Thiết bị yếu | A, render 30/60 tùy benchmark |
| Thiết bị tầm trung | B hoặc C với ít band và particle |
| Thiết bị cao cấp | C + fragment shader, 60/120 chỉ sau profiling |

## 7. Pure Dart, Existing Package, or Native Plugin

| Phương án | Làm tốt | Ưu điểm | Hạn chế | Verdict |
| --- | --- | --- | --- | --- |
| Pure Flutter/Dart | Lyric, progress waveform, precomputed data, easing, `CustomPainter`, shader nhận feature | Một codebase, test dễ | Không tự tap decoded PCM của native player | MVP A |
| Package có sẵn | Playback, background, file waveform; có thể visualizer experimental | Giảm native code | Capability không đồng đều, API experimental/maintenance risk | POC trước khi chốt |
| Native plugin riêng | RMS/FFT đồng bộ player, reduced packets | Kiểm soát latency/lifecycle/parity contract | Hai implementation, permission, QA cao | Production MVP B/C khi package không đạt |

Native plugin trở thành bắt buộc khi cả ba điều kiện cùng đúng:

1. Cần realtime RMS/FFT thật, không chấp nhận precompute/synthetic.
2. Player/package đã chọn không expose feature ổn định trên cả Android và iOS.
3. POC xác nhận UX đáng giá so với chi phí permission, lifecycle và bảo trì.

## 8. Android Implementation Options

### 8.1 `android.media.audiofx.Visualizer`

Tài liệu Android xác nhận:

- Gắn theo audio session ID cụ thể.
- Capture waveform mono 8-bit và FFT magnitude 8-bit.
- Có callback hoặc polling.
- Có measurement peak/RMS.
- Cần `android.permission.RECORD_AUDIO`.
- Phải disable/release khi không dùng.
- Session 0 còn cần `MODIFY_AUDIO_SETTINGS`; không nên dùng global mix nếu chỉ cần player của app.

Với `just_audio`, `androidAudioSessionIdStream` là cầu nối khả thi. Plugin phải:

- Reattach khi session ID đổi.
- Clamp capture rate theo khả năng platform.
- Aggregate band/RMS ở native.
- Dừng khi pause/background/no visual consumer.
- Release khi player dispose, route/session đổi hoặc app detach.

Rủi ro:

- `Visualizer` trả dữ liệu chất lượng thấp phục vụ visualization, không phải PCM studio.
- Permission microphone có thể làm người dùng e ngại dù app không record mic.
- Device/OEM và audio offload có thể tạo khác biệt; cần matrix thiết bị.

### 8.2 Native PCM tap khác

Nếu `Visualizer` không ổn định, giải pháp sâu hơn là giữ playback trong native graph/Media3 audio processor rồi rút feature trước output. Đây là mức tích hợp cao và có thể phụ thuộc chặt vào player; chỉ cân nhắc sau khi POC `Visualizer` thất bại.

## 9. iOS Implementation Options

### 9.1 `AVAudioEngine`

`AVAudioEngine` quản lý graph audio node và hỗ trợ tap trên node khi app sở hữu playback graph. Đây là đường sạch cho PCM/FFT nếu dùng `AVAudioPlayerNode`, nhưng không phải drop-in tap cho mọi `AVPlayer` stream.

### 9.2 `MTAudioProcessingTap`

`MTAudioProcessingTap` có thể truy cập source audio qua audio mix track của AVFoundation. Nó phù hợp hơn khi playback dựa trên `AVPlayerItem`, nhưng implementation phức tạp, C callback/lifecycle nhạy cảm và cần kiểm tra compatibility với stream/protected media.

### 9.3 Kiến trúc iOS đề xuất

```text
AVPlayer/owned audio graph
→ processing tap
→ Accelerate/vDSP FFT + RMS
→ reduced packet
→ EventChannel
→ Dart interpolator
```

Rủi ro:

- Player/package có thể không expose hook cần thiết.
- Audio session interruption và route change có thể rebuild graph.
- Background execution không phải lý do để tiếp tục gửi visual packet khi UI không hiển thị.
- AVPlayer compatibility phải chứng minh theo URL Zing/YouTube thực tế; không suy từ local file.

## 10. Recommended Flutter Architecture

```text
AudioPlayerService
├── PlaybackState (low frequency/business state)
│   ├── position
│   ├── duration
│   ├── playing
│   └── currentTrack
├── AudioAnalysisSource (high frequency)
│   ├── waveform
│   ├── rms / peak
│   ├── bass / mid / treble
│   └── beatImpulse + timestamp
├── LyricsSynchronizer
│   ├── previous/current/next
│   └── wordProgress?
└── ReactiveVisualController
    ├── smoothing/interpolation
    ├── preset
    └── qualityProfile

ReactiveVisualController (Listenable)
→ RepaintBoundary
→ CustomPainter / FragmentShader
→ foreground lyric widgets
→ independent player controls
```

### 10.1 State strategy

- Business state như track, playing, duration, playlist có thể đi qua state-management hiện có.
- Packet audio 30–60 Hz **không** nên đi qua global app state nếu làm rebuild widget tree.
- Dùng `ValueNotifier`/custom `ChangeNotifier` hoặc stream được adapter thành một `Listenable` cục bộ.
- `CustomPainter(repaint: visualController)` có thể repaint trực tiếp mà không gọi `setState` cả màn hình.
- Position stream của player thường không đủ dày cho lyric/visual frame; giữ clock nội suy từ position sample + monotonic time.
- Không đổi state-management toàn app.

### 10.2 Repaint boundaries

- Một `RepaintBoundary` quanh visual canvas/shader.
- Một boundary riêng cho lyric nếu lyric dùng painter/effect nặng.
- Controls tách khỏi high-frequency repaint.
- Không bọc quá nhiều boundary nhỏ trước khi đo memory/layer cost.

### 10.3 Cleanup

- Dispose `Ticker`/controllers.
- Cancel position/analysis subscriptions.
- Detach EventChannel consumer.
- Disable/release Android `Visualizer`.
- Remove iOS taps trước khi destroy graph/item.
- Xóa reference waveform/texture của track cũ.
- Stop analysis khi background, screen off hoặc visual tab không hiển thị.

## 11. Lyrics Feasibility

### 11.1 Normalized lyric model

```text
LyricDocument
- offsetMs
- lines[]

LyricLine
- startMs
- endMs
- text
- words[]?

LyricWord
- startMs
- endMs
- text
- characterRange?
```

Adapter riêng chuyển LRC, YRC, Zing `sentences` và custom text về model này. Visual không đọc schema provider trực tiếp.

### 11.2 Line-synced lyrics

- `HIGH` feasibility.
- Sort line theo timestamp một lần.
- Lookup bằng binary search khi seek/track load; khi playback tiến bình thường, tăng cursor tuần tự O(1).
- Khi seek lùi hoặc position discontinuity, binary search lại.
- Hỗ trợ offset người dùng/provider.
- Dòng không timestamp: hiển thị static/scroll thủ công hoặc fallback title; không giả timestamp.

### 11.3 Multi-line stage

Widget stack phù hợp:

- `AnimatedSwitcher`/custom transition cho đổi current line.
- `FadeTransition`, `SlideTransition`, `ScaleTransition`.
- `Text`/`RichText` cho accessibility; `TextPainter` khi cần đo/clip chính xác.
- Blur/glow có giới hạn và giảm ở Low profile.

Phải xử lý:

- Font có glyph tiếng Việt đầy đủ.
- `TextScaler`/accessibility.
- Dòng dài: wrap tối đa hợp lý, fit/ellipsis chỉ khi UX chấp nhận.
- Portrait/landscape layout.
- `MediaQuery.disableAnimations` hoặc accessibility reduce motion: bỏ blur/scale lớn, giữ fade ngắn hoặc chuyển tức thời.

### 11.4 Word-level karaoke

- Chỉ bật khi `words` có timestamp hợp lệ và coverage đủ.
- Render bằng hai lớp text giống nhau: base + highlighted, clip theo measured progress; hoặc `TextPainter`/`ShaderMask`.
- Không suy word timing bằng chia đều ký tự cho production nếu muốn gọi là karaoke đồng bộ.
- Zing path hiện chưa normalize `sentences`, nên word karaoke là `UNVERIFIED`.

Verdict: ship line-level trước; làm spike schema `sentences` riêng rồi mới quyết định word-level.

## 12. Rendering Options

### 12.1 Widget animation

Tốt cho lyrics, cover pulse, controls và transition ít phần tử. Không dùng hàng trăm Widget làm particle.

### 12.2 CustomPainter

Lựa chọn mặc định cho waveform, spectrum, curve và particle 2D:

- Preallocate arrays/objects.
- Không tạo `Paint`, path list hoặc random object hàng loạt mỗi frame.
- Giới hạn draw calls và vùng repaint.
- Downsample waveform theo pixel width.
- Interpolate feature packet trong controller.

### 12.3 Fragment shader

Phù hợp gradient distortion, noise, color shift, glow và displacement. Flutter hỗ trợ custom shader qua `FragmentProgram`; shader được khai báo asset và tạo `FragmentShader`.

Lưu ý:

- Preload/precache program trước animation.
- Tái sử dụng `FragmentShader` giữa frame.
- `ImageFilter.shader` chỉ được tài liệu Flutter hỗ trợ trên Impeller; cần fallback.
- Giảm uniform/texture update và tránh full-screen shader đắt trên thiết bị yếu.

### 12.4 Game/render engine

Không đề xuất cho MVP. Chỉ cân nhắc khi benchmark cho thấy `CustomPainter`/shader không đáp ứng một yêu cầu particle/scene graph đã được chứng minh có giá trị.

### 12.5 Embedded WebView

Có thể chạy prototype visual web, nhưng production có rủi ro:

- Bridge native player → JavaScript audio feature.
- Hai lifecycle và hai UI stack.
- Memory/GPU surface cao hơn.
- Khó đồng bộ seek/background.
- Touch/accessibility khác Flutter.
- Giữ Web Audio graph riêng có nguy cơ double playback hoặc CORS.

Verdict: dùng cho demo ngắn hạn nếu cần so sánh fidelity, **không khuyến nghị** làm kiến trúc production.

## 13. Vietnamese Music-source Constraints

### 13.1 Trả lời 10 câu hỏi bắt buộc

1. **Audio URL là file trực tiếp?** Code nhận HTTPS CDN URL trực tiếp; format cụ thể cần probe từng mẫu.
2. **Range request?** Proxy forward `Range` và response range headers; upstream coverage cần runtime test.
3. **URL hết hạn?** YouTube chắc chắn được re-resolve; Zing expiry duration chưa được biểu diễn/xác minh.
4. **HLS/DASH?** Không thấy current route sử dụng manifest; không kết luận cho mọi nguồn tương lai.
5. **Có thể cache?** Kỹ thuật có, nhưng cần policy theo expiry/header/ToS và storage budget.
6. **Có thể offline analyze?** Có nếu lấy đủ bytes và decoder hỗ trợ; không bảo đảm cho mọi stream.
7. **Có LRC timestamp?** Có ở Zing route hiện tại.
8. **Có word timestamp?** `sentences` có tiềm năng nhưng chưa normalize/consume; chưa đủ bằng chứng.
9. **Nhiều lyric schema?** Có: LRC, YRC legacy, custom text, Zing `sentences`.
10. **Visual phụ thuộc provider?** Không; phải phụ thuộc normalized `PlayableTrack` và `LyricDocument`.

### 13.2 Normalized provider boundary

```text
PlayableTrack
- id
- provider
- title
- artist
- duration
- streamUrl
- streamHeaders
- expiresAt
- artworkUrl
- lyric
- lyricFormat
- waveformCacheKey
```

Thêm capability flags ở implementation sau này (`seekable`, `cacheable`, `analysisMode`) sẽ an toàn hơn việc suy từ provider name. Không triển khai interface trong nhiệm vụ này.

## 14. Mobile Performance Budget

Flutter hướng đến 60 FPS và có thể 120 FPS trên thiết bị hỗ trợ; frame 60 Hz khoảng 16.7 ms, 90 Hz khoảng 11.1 ms, 120 Hz khoảng 8.3 ms. Đây là budget toàn frame, không phải toàn bộ dành cho visual.

### 14.1 Risk checklist

- UI thread: parser, allocation, state propagation, rebuild.
- Raster/GPU: blur, shadow, opacity overlap, `saveLayer`, full-screen shader, overdraw.
- Platform thread/native: FFT callback, channel serialization.
- Thermal/battery: continuous 60/120 Hz, camera, FFT, blur.
- Memory: cached audio, waveform, artwork texture, shader resource.
- Lifecycle: background/foreground, screen off, interruption, route change.
- Shader warm-up và first-frame jank.

### 14.2 Quality profiles

| Profile | Target device | FPS target | Particle count | FFT bands | Effects |
| --- | --- | ---: | --- | ---: | --- |
| Low | Android yếu/thermal cao | 30 hoặc 60 sau đo | Thấp | Ít | Không blur nặng; waveform/progress |
| Medium | Thiết bị tầm trung | 60 | Trung bình | Vừa | Glow giới hạn; shader đơn giản |
| High | Thiết bị cao cấp | 60; 90/120 chỉ khi pass | Cao hơn | Nhiều hơn | Shader nâng cao có fallback |

Không chốt số particle/band trước benchmark. Quality controller nên:

- Dùng rolling frame-time window, không phản ứng theo một frame.
- Downgrade nhanh khi jank/thermal/lifecycle; upgrade chậm có hysteresis.
- Giảm theo thứ tự: blur → shader resolution → particle → FFT packet rate → FPS.
- Không thay đổi lyric timing/playback.

### 14.3 Kế hoạch đo

Chạy profile mode trên ít nhất một Android yếu, một Android tầm trung, một iPhone còn được hỗ trợ:

- Flutter DevTools Performance view.
- UI/raster frame chart.
- CPU profiler và memory allocation.
- Widget rebuild tracking.
- Shader compilation/warm-up.
- Platform-channel packet rate/size.
- Battery và thermal sau 20–30 phút.
- Seek liên tục, đổi track, Bluetooth route, app background/foreground.

Không tuyên bố đạt 60/120 FPS trước test thiết bị thật.

## 15. Flutter Feature Feasibility Matrix

| Feature | Flutter feasibility | Recommended technique | Pure Dart possible | Native required | Expected difficulty | Main limitation |
| --- | --- | --- | --- | --- | --- | --- |
| Static waveform trang trí | HIGH | `CustomPainter` | Có | Không | Thấp | Không phản ánh audio thật |
| Precomputed real waveform | HIGH | Cache file + extractor + painter | Phần render có | Thường plugin native | Vừa | Download/expiry/storage |
| Playback-progress waveform | HIGH | Waveform data + clipped progress | Có | Không sau extraction | Thấp | Chỉ theo position |
| Real-time amplitude | MEDIUM | Native RMS/peak packet | Feature math có | Có thể cần | Vừa/Cao | Player/platform parity |
| Real-time FFT | MEDIUM | Native FFT + reduced bands | Có thể, nếu có PCM | Khả năng cao | Cao | PCM access, lifecycle |
| Bass/mid/treble bars | MEDIUM/HIGH | Painter từ reduced bands | Có ở render | Analyzer có thể native | Vừa | Chất lượng input |
| Particle 2D | HIGH | `CustomPainter`/shader | Có | Không | Vừa | Overdraw/thermal |
| Fragment-shader wave | HIGH | `FragmentProgram` | Dart điều khiển | Không | Vừa | GPU variation/fallback |
| Album cover pulse | HIGH | Scale/rotation/filter animation | Có | Không | Thấp | Có thể trông “giả” nếu không có amplitude |
| Line-level lyrics | HIGH | Normalized LRC + widgets | Có | Không | Vừa | Lyric quality/offset |
| Word-level karaoke | MEDIUM | Timed words + clip/TextPainter | Có | Không | Cao | Zing word timing chưa xác minh |
| Lyric glow | HIGH | Shadow/MaskFilter/shader nhẹ | Có | Không | Thấp/Vừa | Blur cost |
| Lyric auto-scroll | HIGH | ScrollController/animated layout | Có | Không | Vừa | Seek/dòng dài/accessibility |
| Beat-reactive camera-like movement | HIGH | Transform cover/background | Có | Analyzer có thể native | Vừa | Motion sickness; reduce motion |
| 3D scene | LOW | Engine/custom scene | Một phần | Không bắt buộc | Rất cao | Thermal, complexity |
| 3D playlist shelf | NOT RECOMMENDED | Mobile-native list/carousel | Có thể | Không | Rất cao | Touch/UX/perf không đáng |
| Webcam interaction | NOT RECOMMENDED V1 | Camera + ML/native | Không hoàn toàn | Có | Rất cao | Permission, thermal, latency |
| Background visualization | NOT RECOMMENDED | Tắt render, giữ playback | — | — | — | Không có màn hình; hao pin |

### Bảng ưu tiên MVP

| Feature | Feasibility | Implementation path | Performance risk | Native requirement | MVP priority |
| --- | --- | --- | --- | --- | --- |
| Line lyrics | HIGH | LRC parser + Widget transitions | Thấp | Không | P0 |
| Progress waveform | HIGH | Cached waveform + painter | Thấp | Extraction plugin | P0 |
| Cover pulse | HIGH | AnimationController | Thấp | Không | P0 |
| RMS glow | MEDIUM | Native/experimental amplitude | Thấp/Vừa | Có thể | P1 |
| Spectrum bands | MEDIUM | Native reduced FFT | Vừa | Có thể cao | P1 |
| Particle 2D | HIGH | Painter, pooled state | Vừa | Không | P1 |
| Fragment shader | HIGH | Feature uniforms + fallback | Vừa/Cao | Không | P2 |
| Word karaoke | MEDIUM | Normalize `sentences`/YRC | Vừa | Không | P2 |
| 3D/webcam | LOW | Separate research | Cao | Có thể | Không thuộc V1 |

## 16. MVP Options

| MVP | Scope | Giá trị trải nghiệm | Độ khó | Rủi ro | Native dependency | Khuyến nghị |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| A — Local-first | Progress waveform, LRC line lyrics, cover pulse, gradient nhẹ | Khá | Thấp/Vừa với file local; cao hơn khi nối stream | Expiry/cache/header/storage | Chỉ waveform extractor | **Bắt đầu bằng POC local** |
| B — Reactive thật | RMS + bass/mid/treble, spectrum/painter, lyrics | Cao | Cao | Native/player parity | Có khả năng | POC sau A |
| C — Shader | Feature từ B, fragment shader, glow/noise/displacement | Rất cao trên máy phù hợp | Cao | GPU/thermal | Phụ thuộc B | Sau benchmark B |

### 16.1 MVP A

- Giữ player được dự án mobile chọn.
- Giai đoạn A0 chỉ dùng file audio local cố định, được phép sử dụng; chưa resolve Zing/YouTube.
- Precompute waveform local theo file/version để kiểm chứng extractor, painter, seek và performance.
- LRC line sync bằng position clock.
- Một `CustomPainter` cho waveform/progress.
- Album-cover pulse tổng hợp rất nhẹ; không tuyên bố “reactive FFT”.
- 30/60 FPS adaptive; dừng ticker khi background.
- Giai đoạn A1 mới thử một adapter nguồn thật và chỉ tiến tiếp nếu download/header/range/expiry/cache policy/storage đều đạt.
- Nếu A1 không đạt, MVP production giữ lyric + playback progress/cover pulse và hoãn waveform thật; không ép tải toàn bộ stream.

### 16.2 MVP B

- Native/plugin POC gửi `rms`, `peak`, `bass`, `mid`, `treble`, `timestamp`.
- Painter spectrum/curve và particle nhỏ.
- Giữ lyric pipeline của A.
- Test Android permission UX và iOS AVPlayer tap trước khi cam kết.

### 16.3 MVP C

- Shader nhận feature packet đã smoothing.
- Preload shader, reuse object, có fallback painter.
- Chỉ bật High profile sau device benchmark.

## 17. Smallest Proof-of-concept After Analysis

Không triển khai trong nhiệm vụ này. POC nhỏ nhất nên là một màn hình Flutter độc lập:

1. Phát một file MP3 local được phép sử dụng bằng candidate player.
2. Hiển thị position/duration/seek.
3. Parse một LRC tiếng Việt và chuyển previous/current/next đúng khi seek.
4. Precompute 256–1024 amplitude columns rồi vẽ bằng một `CustomPainter`.
5. Có `RepaintBoundary`; DevTools xác nhận controls không rebuild theo frame.
6. Tắt ticker khi app background.

Gate tiếp theo:

- Nếu POC A ổn, thử Android `Visualizer` theo audio session ID và iOS processing tap trên cùng sample.
- Chỉ khi cả hai trả packet ổn định mới làm spectrum/particle thật.

## 18. Risks and Verification Plan

| Risk | Mức | Cách xác minh | Điều kiện pass |
| --- | --- | --- | --- |
| Package FFT chỉ experimental | Cao | Build exact version, test API/device | API ổn định hoặc chấp nhận plugin riêng |
| iOS không tap được PCM của player | Cao | AVPlayer remote URL POC | RMS/FFT đúng, seek/route/background không crash |
| Android permission làm giảm trust | Cao UX | Permission flow/user test | Lý do rõ, từ chối vẫn có MVP A |
| Zing URL expiry/cache | Cao | Log TTL/status/range trên sample matrix | Refresh và cache invalidation đúng |
| Word timing không đủ coverage | Trung bình | Sample tối thiểu nhiều thể loại | Coverage/accuracy đạt ngưỡng sản phẩm |
| Blur/shader gây raster jank | Trung bình/Cao | DevTools trên 3 tier | Frame budget và thermal pass |
| Platform-channel flood | Trung bình | Trace packet rate/size | Reduced packet, không backlog |
| Bluetooth/route session đổi | Trung bình | Route-change test | Analyzer reattach và audio không gián đoạn |
| Background hao pin | Cao | 30 phút screen-off | Visual capture/ticker dừng hoàn toàn |
| Provider coupling | Trung bình | Contract tests adapters | Painter/controller không import provider schema |

## 19. Final Mobile Verdict

1. **Có dựng được trên Flutter mobile không?** Có. Waveform, spectrum, particle 2D, shader nhẹ và lyrics đều khả thi.
2. **Phần tái dựng tốt nhất?** Timing, normalization, smoothing, line lyrics, waveform/painter, cover motion và adaptive quality.
3. **Phần không nên mang sang?** Full 3D shelf/camera scene, webcam gesture, desktop overlay và hover-centric behavior trong V1.
4. **Thuần Dart đến đâu?** Toàn bộ UI/render, lyrics, progress waveform, easing, presets và feature smoothing; precomputed extraction có thể qua plugin. Dart không tự giải quyết PCM tap của native player.
5. **Khi nào cần native plugin?** Khi cần RMS/FFT realtime production mà player/package không expose API ổn định trên Android+iOS.
6. **Waveform precompute hay realtime?** Precompute bằng file local cho POC. Với MVP nối nguồn thật, chỉ chọn precompute sau integration gate về download/header/range/expiry/cache/storage; nếu gate không đạt, dùng progress-only hoặc realtime feature.
7. **Lyrics theo dòng hay theo từ?** Theo dòng trước. Theo từ chỉ sau khi Zing `sentences` được normalize và đo coverage/accuracy.
8. **MVP thực tế nhất?** MVP A: player + progress waveform + LRC line sync + cover pulse + gradient nhẹ + lifecycle/adaptive FPS.
9. **Rủi ro lớn nhất?** Không phải vẽ Flutter, mà là lấy decoded audio feature đồng bộ và ổn định qua hai platform/player.
10. **POC nhỏ nhất?** Local MP3 + seekable waveform + LRC tiếng Việt + isolated repaint; sau đó mới thêm native RMS/FFT.

## 20. Evidence and Sources

### 20.1 Source files inspected

- `promt-v2.md`
- `promt.md`
- `docs/analysis/MUSIC_VISUAL_FORENSIC_REPORT.md`
- `docs/memory/CODE_MAP.md`
- `docs/memory/RISKS.md`
- `package.json`
- `zing-proxy.js`
- Targeted ranges/symbols in `server.js` and `public/index.html`

### 20.2 External primary sources

- [Flutter: Writing and using fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
- [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)
- [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices)
- [Android `Visualizer` API](https://developer.android.com/reference/android/media/audiofx/Visualizer)
- [Apple `AVAudioEngine`](https://developer.apple.com/documentation/AVFAudio/AVAudioEngine)
- [Apple `MTAudioProcessingTap`](https://developer.apple.com/documentation/MediaToolbox/MTAudioProcessingTap)
- [Apple `audioTapProcessor`](https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters/audiotapprocessor)
- [`just_audio` 0.10.6](https://pub.dev/packages/just_audio)
- [`just_audio` visualizer issue #97](https://github.com/ryanheise/just_audio/issues/97)
- [`audio_service` 0.18.19](https://pub.dev/packages/audio_service)
- [`audio_session` 0.2.4](https://pub.dev/packages/audio_session)
- [`just_audio_background` 0.0.1-beta.17](https://pub.dev/packages/just_audio_background)
- [`just_waveform` 0.0.7](https://pub.dev/packages/just_waveform)
- [`media_kit` 1.2.6](https://pub.dev/packages/media_kit)
- [`flutter_sound` 9.30.0](https://pub.dev/packages/flutter_sound)

### 20.3 Items intentionally not claimed

- Không khẳng định Wavez đã có Flutter implementation.
- Không khẳng định package experimental đạt production quality.
- Không khẳng định mọi Zing URL có cùng TTL/range/container.
- Không khẳng định Zing `sentences` luôn có word timestamp chính xác.
- Không khẳng định 60/90/120 FPS trước benchmark thiết bị.
- Không khẳng định native capture hoạt động khi background/offload/Bluetooth trước POC.
