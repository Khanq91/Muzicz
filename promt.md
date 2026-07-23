# NHIỆM VỤ: PHÂN TÍCH APP FLUTTER ANDROID HIỆN TẠI VÀ LẬP KẾ HOẠCH TÍCH HỢP MUSIC VISUAL

Bạn đóng vai trò:

* Senior Flutter Engineer.
* Android Audio Engineer.
* Mobile Graphics/Animation Engineer.
* Software Architect.
* Technical Investigator.

Project hiện tại là một ứng dụng nghe nhạc Flutter dành cho Android đã tồn tại và đang hoạt động.

Mục tiêu là phân tích toàn bộ kiến trúc liên quan, đánh giá mức độ phù hợp, sau đó tạo một **implementation plan có bằng chứng** để bổ sung các tính năng:

* Lyrics đồng bộ theo nhạc.
* Waveform hoặc progress waveform.
* Album-cover motion nhẹ.
* Spectrum hoặc bass/mid/treble reactive visual nếu khả thi.
* Particle 2D nhẹ.
* Glow/gradient/fragment shader tùy hiệu năng.
* Adaptive visual quality.

Đây là nhiệm vụ **phân tích và lập kế hoạch**, chưa phải nhiệm vụ triển khai.

---

# NGUỒN THAM CHIẾU

Trước khi phân tích Flutter project, tìm và đọc các báo cáo sau nếu chúng tồn tại trong repository:

```text
docs/analysis/MUSIC_VISUAL_FORENSIC_REPORT.md
docs/analysis/FLUTTER_MOBILE_FEASIBILITY_REPORT.md
docs/analysis/UPSTREAM_VISUAL_DIFF_REPORT.md
```

Nếu tên hoặc vị trí hơi khác, tìm bằng:

```bash
find . -iname "*VISUAL*REPORT*.md" -o -iname "*FLUTTER*FEASIBILITY*.md"
```

Vai trò của các báo cáo:

* `MUSIC_VISUAL_FORENSIC_REPORT.md`: mô tả kỹ thuật visual/audio/lyrics của Wavez/Mineradio.
* `FLUTTER_MOBILE_FEASIBILITY_REPORT.md`: đánh giá các phần có thể tái dựng trên Flutter.
* `UPSTREAM_VISUAL_DIFF_REPORT.md`: xác định visual core được kế thừa từ Mineradio upstream.

Không được coi các báo cáo là nguồn sự thật về app Flutter hiện tại.

Thứ tự nguồn sự thật:

1. Source code Flutter hiện tại.
2. Android native code hiện tại.
3. Runtime/test/log thực tế.
4. `pubspec.lock` và dependency resolution thực tế.
5. Documentation của project Flutter.
6. Các báo cáo visual đã cung cấp.
7. Tài liệu package hoặc platform chính thức.
8. Suy luận.

---

# OUTPUT DUY NHẤT

Tạo hoặc cập nhật duy nhất file:

```text
docs/analysis/FLUTTER_ANDROID_MUSIC_VISUAL_IMPLEMENTATION_PLAN.md
```

Nếu thư mục chưa tồn tại, được phép tạo `docs/analysis/`.

Ngoài file báo cáo trên, không được thay đổi source hoặc configuration.

Không được:

* Sửa file Dart.
* Sửa Kotlin/Java.
* Sửa Gradle.
* Sửa Manifest.
* Sửa `pubspec.yaml`.
* Sửa `pubspec.lock`.
* Cài package.
* Chạy `flutter pub add`.
* Chạy formatter/autofix làm thay đổi file.
* Tạo implementation POC.
* Tạo test mới.
* Refactor player.
* Thay state management.
* Tạo platform channel.
* Tạo shader.
* Tạo commit hoặc pull request.
* “Tiện tay sửa” lỗi phát hiện được.

Được phép chạy các lệnh read-only hoặc validation nếu môi trường đã sẵn sàng:

```bash
git status --short
git diff --stat
git log -5 --oneline
flutter --version
dart --version
flutter doctor -v
flutter pub deps
flutter analyze
flutter test
rg
find
grep
```

Không chạy `flutter pub get` nếu có khả năng thay đổi lockfile hoặc dependency resolution.

Nếu dependency chưa được resolve và không thể chạy analyze/test mà không thay đổi project, ghi rõ giới hạn đó.

---

# NGUYÊN TẮC PHÂN TÍCH

Mỗi kết luận quan trọng phải có một trạng thái:

* `CONFIRMED`
* `STRONG INFERENCE`
* `UNVERIFIED`
* `NOT FOUND`

Mỗi nhận định phải chỉ ra bằng chứng:

```text
File:
Symbol/Class:
Line range:
Finding:
Confidence:
```

Không được:

* Mặc định project dùng `just_audio`.
* Mặc định project dùng Provider/Riverpod/BLoC.
* Mặc định app có background playback.
* Mặc định audio URL có thể cache.
* Mặc định player expose PCM, RMS hoặc FFT.
* Mặc định có thể dùng Android `Visualizer`.
* Mặc định đổi package audio là giải pháp tốt.
* Mặc định 60 FPS vì code trông nhẹ.
* Mặc định lyric có word-level timestamp.
* Đưa ra estimate ngày công giả khi chưa hiểu project.

Estimate nên dùng:

* `S`, `M`, `L`, `XL`.
* Điều kiện phụ thuộc.
* Gate cần vượt qua.

---

# PHẦN 1 — BASELINE REPOSITORY

Ghi nhận:

```bash
git status --short
git diff --stat
git branch --show-current
git rev-parse HEAD
git log -5 --oneline
```

Phải phân biệt:

* Thay đổi đã tồn tại trước phiên phân tích.
* File do quá trình phân tích tạo.
* Generated files không được track.
* Source file tuyệt đối không được chạm vào.

Ghi vào report:

* Commit.
* Branch.
* Flutter version.
* Dart version.
* Android Gradle Plugin.
* Kotlin version.
* compileSdk.
* targetSdk.
* minSdk.
* Java/JDK version nếu xác định được.

---

# PHẦN 2 — LẬP BẢN ĐỒ PROJECT FLUTTER

Phân tích cấu trúc project:

* Entry point.
* App bootstrap.
* Dependency injection.
* Routing/navigation.
* State management.
* Domain/data/presentation layers.
* Feature-first hay layer-first.
* Service locator.
* Repository pattern.
* Models/DTO.
* API client.
* Persistence.
* Error handling.
* Logging.
* Build flavors.
* Environment config.
* Code generation.
* Isolates.
* Existing platform channels.
* Existing shaders/CustomPainter.
* Existing animations.
* Testing structure.

Tạo bảng:

| Khu vực | File/Class chính | Vai trò | Mức coupling | Liên quan music visual |
| ------- | ---------------- | ------- | ------------ | ---------------------- |

Tạo sơ đồ kiến trúc hiện tại bằng Mermaid.

Không áp đặt Clean Architecture nếu project không dùng nó.

---

# PHẦN 3 — AUDIO PLAYER FORENSIC AUDIT

Đây là phần quan trọng nhất.

Xác định chính xác:

## 3.1 Player package

* Package nào phát nhạc.
* Version chính xác từ `pubspec.lock`.
* Có nhiều audio package đồng thời không.
* Package nào thật sự được gọi runtime.
* Có wrapper nội bộ hay gọi trực tiếp package.
* Player instance được tạo ở đâu.
* Singleton, service hay per-screen.
* Ai sở hữu lifecycle của player.
* Player được dispose ở đâu.
* Có nguy cơ tạo nhiều player không.

## 3.2 Playback architecture

Lần theo:

```text
UI action
→ state/controller
→ audio service
→ source resolver
→ player
→ playback stream
→ UI update
```

Xác định:

* Play.
* Pause.
* Resume.
* Seek.
* Next/previous.
* Queue.
* Playlist.
* Current track.
* Duration.
* Position.
* Buffered position.
* Processing state.
* Error state.
* Playback speed.
* Loop/shuffle.
* Volume.
* Audio focus.
* Headset/Bluetooth.
* Notification/lock screen.
* Background playback.

## 3.3 Audio source

Kiểm tra:

* Local file.
* Remote URL.
* HLS/DASH.
* Progressive file.
* Custom HTTP headers.
* Cookies/token.
* Range request.
* Redirect.
* Expiring URL.
* Retry.
* Fallback source.
* Cache.
* Download.
* Offline mode.

Tạo normalized source map:

| Source type | Resolver | Headers | Expiry | Seekable | Cacheable | Analyzer feasibility |
| ----------- | -------- | ------- | ------ | -------- | --------- | -------------------- |

## 3.4 Audio-analysis capability

Kiểm tra player hiện tại có expose:

* Android audio session ID.
* PCM.
* Waveform.
* RMS.
* Peak.
* FFT.
* Equalizer data.
* Audio processor hook.
* Native player reference.
* Custom ExoPlayer/Media3 integration.

Mỗi capability phải ghi:

```text
Capability:
Current support:
Evidence:
Stable/experimental:
Android support:
Blocker:
```

Không đề xuất đổi player trước khi hoàn thành audit này.

---

# PHẦN 4 — ANDROID NATIVE READINESS

Phân tích:

* `android/app/src/main/AndroidManifest.xml`
* `MainActivity`
* Kotlin hay Java.
* Existing MethodChannel/EventChannel.
* Existing foreground service.
* MediaSession.
* Audio focus.
* Notification channel.
* ProGuard/R8.
* minSdk.
* compileSdk.
* Android embedding version.
* Plugin registration.
* App lifecycle hooks.

Đánh giá khả năng sử dụng:

```text
android.media.audiofx.Visualizer
```

Phải kiểm tra:

* Player có audio session ID không.
* Session ID có thay đổi khi đổi bài không.
* Có thể attach/detach analyzer không.
* Có cần `RECORD_AUDIO` không.
* Permission hiện tại của app.
* UX khi người dùng từ chối permission.
* OEM/audio offload/Bluetooth risk.
* Lifecycle release.
* Background behavior.
* Capture rate.
* Waveform/FFT/RMS availability.

Không coi Android `Visualizer` là phương án mặc định.

Tạo bảng:

| Android option | Tương thích player hiện tại | Native work | Permission | Risk | Verdict |
| -------------- | --------------------------- | ----------- | ---------- | ---- | ------- |

Các option cần đánh giá:

1. Capability có sẵn từ Flutter package.
2. Android `Visualizer` gắn audio session.
3. Media3/ExoPlayer audio processor.
4. Native PCM tap khác.
5. Không realtime, chỉ precomputed waveform.

---

# PHẦN 5 — LYRIC PIPELINE AUDIT

Xác định:

* Lyric được lấy từ API nào.
* Model hiện tại.
* LRC/YRC/plain text/word timing.
* Parser hiện tại.
* Offset.
* Translation/romanization nếu có.
* Current-line lookup.
* Seek behavior.
* Auto-scroll.
* Empty/error state.
* Cache.
* Lyric screen hiện tại.
* Mini-player lyrics.
* Full-player lyrics.
* Dòng trước/hiện tại/tiếp theo.
* Word-level data có thật không.

Tạo flow:

```text
Provider response
→ DTO
→ normalized lyric model
→ parser
→ synchronizer
→ current line
→ UI renderer
```

Đánh giá khả năng tái sử dụng code hiện tại:

| Thành phần lyric | Giữ nguyên | Mở rộng | Thay thế | Lý do |
| ---------------- | ---------: | ------: | -------: | ----- |

Không triển khai karaoke theo từ nếu source chỉ có timestamp theo dòng.

---

# PHẦN 6 — UI, ANIMATION VÀ RENDERING AUDIT

Tìm:

* Full-player screen.
* Now-playing screen.
* Mini player.
* Album cover.
* Background.
* Lyrics screen.
* Existing waveform.
* Existing equalizer.
* Existing `CustomPainter`.
* Existing fragment shader.
* Existing `AnimationController`.
* Existing `Ticker`.
* Existing `RepaintBoundary`.
* Existing blur/glow.
* Hero animations.
* Gesture interactions.
* Theme/dynamic colors.

Đánh giá:

* Visual nên nằm ở màn nào.
* Có che player controls không.
* Có ảnh hưởng lyrics readability không.
* Vùng nào được repaint.
* Widget nào rebuild theo position stream.
* Có global rebuild không.
* Có animation controller bị tạo trong build không.
* Có nested blur/saveLayer không.
* Có memory leak controller/subscription không.

Tạo rendering map:

```text
ReactiveVisualController
→ painter/shader layer
→ lyrics layer
→ controls layer
```

Tạo bảng:

| Screen/Widget | Hiện trạng | Điểm chèn visual | Risk | Recommended treatment |
| ------------- | ---------- | ---------------- | ---- | --------------------- |

---

# PHẦN 7 — STATE MANAGEMENT VÀ HIGH-FREQUENCY DATA

Xác định state management hiện tại.

Phân loại state:

## Low-frequency business state

* Current track.
* Queue.
* Playing.
* Duration.
* Source.
* Error.
* Playlist.

## Medium-frequency state

* Position.
* Buffered position.
* Current lyric line.

## High-frequency visual state

* RMS.
* Peak.
* Bass.
* Mid.
* Treble.
* Beat impulse.
* Particle phase.
* Shader uniforms.

Đánh giá:

* State nào đang đi qua global provider/store.
* State nào nên giữ cục bộ.
* Có selector/listenWhen/fine-grained listener không.
* Có thể dùng `Listenable` trực tiếp cho painter không.
* Cách tránh `setState` cả screen 30–60 lần/giây.

Không tự động đổi toàn bộ state management.

Đưa ra architecture phù hợp với chính project hiện tại.

---

# PHẦN 8 — PERFORMANCE BASELINE

Trước khi thêm visual, lập baseline nếu có thể chạy app.

Thu thập hoặc đề xuất thu thập:

* UI frame time.
* Raster frame time.
* Rebuild count.
* Memory.
* CPU.
* Battery.
* App startup.
* Track switch.
* Seek.
* Background/foreground.
* Bluetooth route.
* 20–30 phút playback.

Phân biệt:

* Baseline đo được.
* Baseline chưa đo.
* Target cần đạt.
* Điều kiện pass/fail.

Không tuyên bố app đủ 60 FPS nếu chưa profile.

Phân tích thiết bị mục tiêu:

* Android yếu.
* Android tầm trung.
* Android cao cấp.
* 60/90/120 Hz.

---

# PHẦN 9 — FIT ASSESSMENT

Đánh giá từng feature với project hiện tại:

| Feature | Fit với kiến trúc hiện tại | Tái sử dụng được gì | Cần thêm gì | Risk | Verdict |
| ------- | -------------------------- | ------------------- | ----------- | ---- | ------- |

Tối thiểu gồm:

* Line lyrics.
* Previous/current/next lyrics.
* Word karaoke.
* Progress waveform.
* Precomputed waveform.
* Realtime RMS.
* Realtime FFT.
* Bass/mid/treble bars.
* Cover pulse.
* Particle 2D.
* Gradient/glow.
* Fragment shader.
* Adaptive quality.
* Background visualization.
* 3D scene.
* Webcam gesture.

Verdict được phép:

* `GO`
* `GO WITH CONDITIONS`
* `POC REQUIRED`
* `DEFER`
* `NO-GO`

Mỗi verdict phải có bằng chứng từ project.

---

# PHẦN 10 — KHÔNG ĐƯỢC ĐỔI PLAYER TÙY TIỆN

Tạo một decision record riêng:

## Giữ player hiện tại

Đánh giá:

* Playback stability.
* Background support.
* Streaming.
* Headers.
* Queue.
* Audio session.
* Native extensibility.
* Existing integration cost.

## Mở rộng player hiện tại

Ví dụ:

* Plugin phụ.
* Native EventChannel.
* Android audio session hook.
* Custom analyzer adapter.

## Thay player

Chỉ đề xuất khi có blocker đã chứng minh:

* Không thể lấy session ID hoặc PCM.
* Không thể giữ background behavior.
* Không thể xử lý URL/header.
* Package bị abandon hoặc incompatible.
* Native integration bị khóa hoàn toàn.

Tạo bảng:

| Option | Playback regression risk | Visual capability | Migration cost | Verdict |
| ------ | ------------------------ | ----------------- | -------------- | ------- |

Không chọn package mới chỉ vì package đó quảng cáo có waveform/FFT.

---

# PHẦN 11 — DECISION GATES

Kế hoạch phải có các gate rõ ràng.

## Gate 0 — Project baseline

Pass khi:

* Playback hiện tại được hiểu.
* File ownership rõ.
* Existing tests/analyze status được ghi nhận.
* Không còn nghi ngờ player instance chính nằm ở đâu.

## Gate 1 — Lyrics fit

Pass khi:

* Có normalized lyric model.
* Seek đúng.
* Line lookup đúng.
* UI hiện tại có vị trí tích hợp phù hợp.

## Gate 2 — Local visual POC

Pass khi:

* Local audio hoạt động.
* Waveform local được render.
* Controls không rebuild theo frame.
* Visual dừng khi background.
* Không làm playback regression.

## Gate 3 — Real provider integration

Pass khi:

* URL/header/range/expiry được hiểu.
* Cache/download policy rõ.
* Waveform extraction với nguồn thật khả thi hoặc có fallback.

## Gate 4 — Android realtime feature

Pass khi:

* Player/session hook hoạt động.
* RMS/FFT packet ổn định.
* Permission UX chấp nhận được.
* Bluetooth/seek/track switch không làm crash.
* Analyzer release đúng.

## Gate 5 — Production visual

Pass khi:

* Frame budget đạt.
* Battery/thermal đạt.
* Feature flag và fallback hoạt động.
* Không ảnh hưởng background playback.

Không được chuyển phase nếu gate trước chưa pass.

---

# PHẦN 12 — KIẾN TRÚC ĐỀ XUẤT

Sau audit, đề xuất kiến trúc phù hợp với project.

Architecture tham khảo, không được áp dụng máy móc:

```text
Existing Audio Player
├── Playback State Adapter
├── Audio Source Capability Adapter
├── Lyrics Repository
├── Lyrics Synchronizer
└── Audio Analysis Source
      ├── None/Progress-only
      ├── Precomputed Waveform
      └── Android Realtime Features

Audio Analysis Source
→ ReactiveVisualController
→ CustomPainter / FragmentShader
```

`ReactiveVisualController` nên chỉ nhận normalized data:

```text
timestamp
rms
peak
bass
mid
treble
beatImpulse
```

Không gửi toàn bộ PCM hoặc hàng nghìn FFT bin sang Dart nếu không có benchmark chứng minh cần thiết.

Đề xuất interface/data contract ở mức pseudocode hoặc UML.

Không viết implementation hoàn chỉnh.

---

# PHẦN 13 — PHASED IMPLEMENTATION PLAN

Kế hoạch phải được điều chỉnh sau khi hiểu project, nhưng tối thiểu phải xem xét các phase sau.

## Phase 0 — Baseline và instrumentation

* Chốt player ownership.
* Chốt playback lifecycle.
* Chốt current performance.
* Ghi regression checklist.
* Chưa thêm visual.

## Phase 1 — Normalized contracts

* `PlayableTrack` hoặc adapter tương đương.
* `LyricDocument`.
* `LyricLine`.
* `AudioVisualFrame`.
* `AudioAnalysisSource`.
* Không phụ thuộc trực tiếp provider schema.

## Phase 2 — Lyrics integration

* Line sync.
* Previous/current/next.
* Seek.
* Offset.
* UI transition nhẹ.
* Accessibility/reduce motion.

## Phase 3 — Local-first visual POC

* Local audio fixture.
* Waveform precompute.
* `CustomPainter`.
* Playback progress.
* Cover pulse.
* Repaint isolation.
* Lifecycle.

## Phase 4 — Tích hợp vào player/screen hiện tại

* Giữ UI hiện có.
* Feature flag.
* Không phá mini player/full player.
* Visual off fallback.
* Không đổi player nếu chưa cần.

## Phase 5 — Provider integration gate

* Remote URL.
* Header.
* Range.
* Expiry.
* Cache.
* Storage.
* Failure fallback.

## Phase 6 — Android realtime RMS/FFT POC

* Chọn option sau audit.
* Reduced feature packet.
* Timestamp/interpolation.
* Session recreation.
* Permission.
* Bluetooth.
* Lifecycle.

## Phase 7 — Reactive visual production

* Spectrum.
* Particle 2D.
* Glow.
* Attack/release.
* Adaptive profile.
* Preset.

## Phase 8 — Optional fragment shader

* Chỉ sau benchmark.
* Preload.
* Fallback painter.
* Low profile disable.

## Phase 9 — Hardening và release

* Tests.
* Device matrix.
* Battery/thermal.
* Error telemetry.
* Rollback.
* Documentation.
* Attribution.

Mỗi phase phải có:

```text
Goal
Preconditions
Files likely affected
New files likely needed
Detailed tasks
Technical decisions
Risks
Tests
Acceptance criteria
Rollback
Complexity
Gate to next phase
```

---

# PHẦN 14 — FILE-LEVEL IMPACT MAP

Tạo bảng cụ thể theo source thật:

| File hiện tại | Vai trò | Dự kiến thay đổi | Mức rủi ro | Phase |
| ------------- | ------- | ---------------- | ---------- | ----- |

Và bảng file mới dự kiến:

| File đề xuất | Trách nhiệm | Lý do cần | Không nên chứa gì |
| ------------ | ----------- | --------- | ----------------- |

Không được dùng tên file giả chung chung nếu đã có thể suy ra convention từ project.

Ví dụ, nếu project dùng feature-first:

```text
lib/features/player/...
```

thì plan phải theo convention đó.

Nếu project dùng layer-first:

```text
lib/services/
lib/providers/
lib/screens/
```

thì plan phải tôn trọng cấu trúc hiện tại.

---

# PHẦN 15 — DEPENDENCY DECISION MATRIX

Kiểm tra dependency hiện tại trước.

Với mỗi dependency có thể cần thêm:

| Package/native API | Mục đích | Có thật sự cần | Trùng capability hiện tại | Maturity | Risk | Verdict |
| ------------------ | -------- | -------------- | ------------------------- | -------- | ---- | ------- |

Không đề xuất package chỉ dựa trên tên.

Nếu internet khả dụng, kiểm tra:

* Official documentation.
* Pub.dev.
* Repository chính thức.
* Version hiện tại.
* Open issues quan trọng.
* License.
* Android support.
* minSdk.
* Maintenance status.

Nếu internet không khả dụng, đánh dấu `UNVERIFIED`.

---

# PHẦN 16 — FEATURE FLAG VÀ ROLLBACK

Plan phải có:

* Master visual enable/disable.
* Disable realtime analyzer riêng.
* Disable shader riêng.
* Quality profile.
* Permission-denied fallback.
* Analyzer initialization failure fallback.
* Device blacklist chỉ khi có evidence.
* Remote kill switch nếu project đã có config system.
* Rollback không yêu cầu đổi audio player.

Fallback tối thiểu:

```text
FFT unavailable
→ RMS unavailable
→ precomputed/progress waveform
→ cover pulse + line lyrics
→ visual off
```

Playback không được phụ thuộc vào visual.

Nếu visual lỗi, nhạc vẫn phải phát bình thường.

---

# PHẦN 17 — TEST MATRIX

## Unit tests

* LRC parser.
* Offset.
* Binary search.
* Seek backward.
* Seek forward.
* Track switch.
* Feature smoothing.
* Peak normalization.
* Silence decay.
* Quality-profile decision.

## Widget tests

* Current lyric transition.
* Long Vietnamese line.
* No lyric.
* Reduce motion.
* Text scaling.
* Visual disabled.
* Permission denied.

## Integration tests

* Play/pause.
* Seek.
* Next.
* Previous.
* Queue switch.
* Background/foreground.
* Screen off/on.
* Bluetooth connect/disconnect.
* Incoming call/audio focus.
* Permission denied/allowed.
* Analyzer unavailable.
* Expiring URL.
* Network failure.

## Performance tests

* Android yếu.
* Android tầm trung.
* Android cao cấp.
* 20–30 phút playback.
* Fullscreen visual.
* Rapid track switching.
* Repeated seek.
* Lyrics + waveform + particle.
* Shader on/off.

Tạo bảng:

| Scenario | Device tier | Metric | Pass condition | Tool |
| -------- | ----------- | ------ | -------------- | ---- |

Không tự đặt threshold tùy tiện nếu chưa có baseline.

---

# PHẦN 18 — ACCEPTANCE CRITERIA TOÀN HỆ THỐNG

Tối thiểu:

* Không tạo player thứ hai.
* Không phát audio hai lần.
* Không làm hỏng background playback.
* Không làm hỏng notification/lock screen.
* Seek lyric chính xác.
* Track switch không giữ state bài cũ.
* Visual không block UI thread.
* Player controls không rebuild 30–60 lần/giây.
* Visual dừng khi app background hoặc không hiển thị.
* Analyzer được release.
* Permission denied vẫn nghe nhạc bình thường.
* FFT unavailable có fallback.
* Shader unavailable có fallback.
* Playback không phụ thuộc visual.
* Có feature flag.
* Có attribution phù hợp với Mineradio upstream.
* Có baseline và profiler evidence trước khi tuyên bố 60 FPS.

---

# PHẦN 19 — OUTPUT STRUCTURE

File:

```text
docs/analysis/FLUTTER_ANDROID_MUSIC_VISUAL_IMPLEMENTATION_PLAN.md
```

phải có cấu trúc:

```markdown
# Flutter Android Music Visual Implementation Plan

## Document Metadata
## Executive Recommendation
## Ground Truth and Limitations
## Existing Project Architecture
## Existing Audio Playback Architecture
## Existing Android Native Architecture
## Existing Lyrics Pipeline
## Existing UI and Rendering Architecture
## Existing State-management Analysis
## Existing Performance Baseline
## Fit Assessment
## Player Compatibility Decision
## Audio-analysis Options
## Recommended Architecture
## Data Contracts
## Decision Gates
## Phased Implementation Plan
## File-level Impact Map
## Dependency Decision Matrix
## Feature Flags and Fallbacks
## Permission and Privacy Strategy
## Test Strategy
## Device Performance Matrix
## Acceptance Criteria
## Risks
## Open Questions
## Deferred Features
## Attribution Requirements
## Final Go/No-go Recommendation
```

---

# PHẦN 20 — FINAL GO/NO-GO

Báo cáo phải trả lời rõ:

1. Kiến trúc hiện tại có phù hợp để thêm visual không?
2. Điểm tích hợp tốt nhất là đâu?
3. Có cần sửa player không?
4. Có cần đổi player không?
5. Lyrics hiện tại tái sử dụng được bao nhiêu?
6. Waveform precompute có phù hợp với nguồn hiện tại không?
7. Realtime RMS có khả thi không?
8. Realtime FFT có khả thi không?
9. Android native work cần tới mức nào?
10. State management hiện tại có chịu được visual data không?
11. Screen nào nên chứa visual?
12. Feature nào nên làm trước?
13. Feature nào phải hoãn?
14. Rủi ro lớn nhất là gì?
15. POC nhỏ nhất là gì?
16. Điều kiện nào khiến toàn bộ hướng realtime analyzer bị `NO-GO`?
17. Có thể triển khai mà không regression playback không?
18. Phase đầu tiên sau khi plan được duyệt là gì?

Không được kết luận `GO` chỉ vì Flutter có `CustomPainter`.

Kết luận phải dựa trên source project hiện tại.

---

# HOÀN THÀNH NHIỆM VỤ

Sau khi viết report:

```bash
git status --short
git diff --stat
git diff -- docs/analysis/FLUTTER_ANDROID_MUSIC_VISUAL_IMPLEMENTATION_PLAN.md
```

Xác nhận:

* Chỉ file plan được tạo hoặc cập nhật bởi phiên này.
* Không source file nào bị thay đổi.
* Không lockfile nào bị thay đổi.
* Không package nào được cài.
* Không implementation nào được tạo.

Câu trả lời chat cuối cùng chỉ cần:

```text
Đã hoàn thành implementation plan.

- File:
- Project commit:
- Audio player hiện tại:
- Kiến trúc phù hợp:
- Recommended first POC:
- Player replacement:
- Realtime FFT verdict:
- Main blockers:
- Files changed: chỉ file plan
```

**Không triển khai code trong nhiệm vụ này.**
