# Music Visual cho Muzicz — Feasibility & Implementation Plan

## Metadata

- Đối tượng đánh giá: `Muzicz_` (Flutter, package name `muziczz`), player local-first dùng `just_audio` + `audio_service` + `on_audio_query`.
- Nguồn tham chiếu: 3 báo cáo đã có sẵn trong `docs/analysis/` của chính repo Muzicz —
  `FLUTTER_MOBILE_FEASIBILITY_REPORT.md`, `MUSIC_VISUAL_FORENSIC_REPORT.md`, `UPSTREAM_VISUAL_DIFF_REPORT.md`.
  Ba báo cáo này phân tích **Wavez** — một app Windows/Electron fork của
  [`XxHuberrr/Mineradio`](https://github.com/XxHuberrr/Mineradio) — không phải phân tích Muzicz.
- Việc của tài liệu này: đọc source Muzicz thật (không đoán), rồi bắc cầu giữa hai world:
  Wavez (Electron/Three.js/WebGL, streaming Zing/YouTube) ↔ Muzicz (Flutter mobile, local library).
- Phương pháp: đọc trực tiếp `pubspec.yaml`, `lib/providers/player_provider.dart`,
  `lib/services/audio_handler.dart`, `lib/services/lyrics_service.dart`, `lib/models/lyric_line.dart`,
  `lib/screens/now_playing_screen.dart`, `lib/screens/online_screen.dart`, `lib/services/music_scanner.dart`.
- Confidence: `CONFIRMED` = thấy trực tiếp trong source Muzicz. `INFERRED` = suy luận kỹ thuật hợp lý
  nhưng chưa chạy. `UNVERIFIED` = cần POC/đo runtime trên thiết bị.

## 1. Kết luận nhanh (executive verdict)

Tin tốt trước: **Muzicz ở vị trí thuận lợi hơn hẳn Wavez** để làm music-visual, vì lý do nền tảng
chứ không phải vì Flutter "mạnh hơn" JS — Muzicz phát **file nhạc local** (`on_audio_query`), còn
Wavez phát **stream CDN có thời hạn** (Zing/YouTube qua proxy). Toàn bộ phần rủi ro nặng nhất trong
`FLUTTER_MOBILE_FEASIBILITY_REPORT.md` — URL expiry, header, cache policy, ToS, HLS/DASH, integration
gate A1 — **không áp dụng cho luồng chính của Muzicz** (`CONFIRMED`, vì `music_scanner.dart` dùng
`OnAudioQuery` đọc file trên máy, không resolve URL streaming). `online_screen.dart` hiện chỉ là
placeholder "Trực tuyến — sắp ra mắt" (`CONFIRMED`), nên rủi ro streaming chỉ phát sinh **khi nào**
tính năng đó được build thật, không phải bây giờ.

Tin thứ hai: 90% kỹ thuật "hay" trong 3 báo cáo (Three.js particle shader, 3D lyric world, 3D shelf,
MediaPipe gesture, Electron overlay) đã được `UPSTREAM_VISUAL_DIFF_REPORT.md` xác nhận là
**kế thừa nguyên bản từ Mineradio, không phải Wavez tự viết** — tức là nó gắn chặt vào
DOM/WebGL/Three.js/GSAP, không có đường port 1:1 sang Flutter. Cái đáng mang qua Muzicz không phải
code, mà là **thuật toán và tư duy layering**: band mapping, attack/release, dynamic peak
normalization, beat cooldown, lyric line-lookup, adaptive quality theo hysteresis.

Muzicz hiện tại (`CONFIRMED` qua source): có `AnimationController` xoay ảnh bìa
(`_artRotateCtrl` trong `now_playing_screen.dart`), có blur background từ cover
(`_BlurredBackground`, `ImageFilter.blur`), có lyric line-sync đầy đủ qua LRCLIB
(`LyricsService.parseLrc`, model `LyricLine{text, time}`) — nhưng **chưa có bất kỳ audio-reactive
visual nào**: không `CustomPainter`, không waveform, không FFT/RMS, không particle, không shader.
Đây chính là baseline P0 mà `FLUTTER_MOBILE_FEASIBILITY_REPORT.md` gọi là "MVP A", và Muzicz đã có
sẵn phần lyric + cover pulse — chỉ thiếu phần audio feature thật.

**Khuyến nghị 1 câu:** làm visual theo đúng lộ trình A → B → C của feasibility report, nhưng bỏ hẳn
gate A1 (URL/cache/expiry) vì Muzicz local-first; bắt đầu bằng `just_waveform` (precompute từ file
local, không cần network) + `CustomPainter` progress bar phản ứng, sau đó mới cân nhắc
Android `Visualizer`/iOS tap cho realtime RMS nếu đo thấy đáng.

## 2. Ground truth Muzicz — cái gì đang có, cái gì chưa có

| Hạng mục | Trạng thái Muzicz | Bằng chứng |
| --- | --- | --- |
| Nguồn audio | File local trên thiết bị, quét bằng `on_audio_query` | `music_scanner.dart` dùng `OnAudioQuery().querySongs()` |
| Player | `just_audio` 0.9.36 + `audio_service` 0.18.12 qua `PlayerAudioGateway` | `pubspec.yaml`, `services/audio_handler.dart` |
| Streaming online | Chưa có, chỉ placeholder "Coming soon" | `screens/online_screen.dart` |
| Lyric | Line-level LRC từ LRCLIB API + cache file, model `LyricLine(text, time)` | `services/lyrics_service.dart`, `models/lyric_line.dart` |
| Lyric word-level | Không có `words[]`, không karaoke theo từ | `models/lyric_line.dart` chỉ có `text`/`time` |
| Animation hiện có | Xoay cover (`_artRotateCtrl`), flip card, appear transition, blur nền | `now_playing_screen.dart` (`TickerProviderStateMixin`, 3 `AnimationController`) |
| Audio-reactive visual | **Không có** — 0 `CustomPainter`, 0 FFT/RMS, 0 particle, 0 shader | grep toàn bộ `lib/` không ra kết quả |
| State management | `Provider`/`ChangeNotifier` cho player+lyrics, Riverpod riêng cho downloader | `providers/player_provider.dart` vs `features/downloader/providers/*` |
| UI style | `liquid_glass_widgets`, blur/glass theo sở thích đã ghi nhận trước đó | `pubspec.yaml`, `_BlurredBackground` |

Điểm quan trọng nhất cho phần kiến trúc: `PlayerProvider` là một `ChangeNotifier` lớn (467 dòng),
`notifyListeners()` mỗi lần position/state đổi. Nếu cắm thẳng audio feature 30–60 Hz vào provider này
và gọi `notifyListeners()` mỗi frame, cả `now_playing_screen.dart` (2241 dòng, rất nhiều widget con)
sẽ rebuild theo tần số đó — đúng cái `FLUTTER_MOBILE_FEASIBILITY_REPORT.md` cảnh báo ở mục 10.1
("packet audio 30–60 Hz không nên đi qua global app state"). Đây là rủi ro kiến trúc thật, cụ thể,
không phải lý thuyết.

## 3. Bắc cầu 3 báo cáo nguồn → Muzicz: cái gì dùng được, cái gì bỏ

### 3.1 Dùng được gần như nguyên thuật toán (port công thức, viết lại code)

| Kỹ thuật (từ Wavez/Mineradio) | Vai trò gốc | Áp dụng vào Muzicz | Vị trí gắn vào code hiện có |
| --- | --- | --- | --- |
| Band mapping theo sample rate (bass/mid/treble) | `beatBandRms()` | Native reducer hoặc Dart, dùng cho progress waveform tô màu theo dải tần (nếu có RMS) | `CustomPainter` mới, không đụng `PlayerProvider` |
| Dynamic peak normalization + attack/release | `processRealtimeBeatEngine()` | Làm mượt amplitude trước khi vẽ, tránh giật khi bài nhạc có đoạn to/nhỏ | Riêng một `ReactiveVisualController` (xem mục 4) |
| Beat impulse + cooldown | Realtime beat engine | Cover pulse phản ứng thật theo nhịp thay vì xoay đều như hiện tại | Thay/bổ sung cho `_artRotateCtrl` |
| Line-lookup nhị phân + cursor tuần tự | `tickLyricsParticles()` | Muzicz **đã có phần này về bản chất** qua `LyricsProvider`/`_LyricsView`; chỉ cần xác nhận có binary-search khi seek | `providers/lyrics_provider.dart` |
| Adaptive quality với hysteresis (giảm nhanh, tăng chậm) | `renderQualityProfile()`, `getRenderPixelRatio()` | Bắt buộc nếu làm particle/shader, để tránh máy yếu bị giật khi mở Now Playing | Controller mới, đọc `FrameTiming` |
| Repaint boundary tách biệt visual khỏi controls | Kiến trúc `animate()` | Bọc riêng waveform/particle bằng `RepaintBoundary`, không để trong cùng subtree với nút play/slider | `now_playing_screen.dart` |

### 3.2 Chỉ giữ ý tưởng, phải viết lại hoàn toàn hoặc bỏ

| Kỹ thuật gốc | Lý do không port | Khuyến nghị cho Muzicz |
| --- | --- | --- |
| Three.js particle shader cho cover (point cloud, depth texture) | Scene graph WebGL không tồn tại trong Flutter native | Nếu muốn hiệu ứng tương tự: `CustomPainter` particle 2D nhẹ hoặc `FragmentProgram` đơn giản, không cố port pixel-for-pixel |
| 3D playlist shelf, 3D lyric world-transform theo camera | Không có camera 3D scene trong app nhạc mobile-first | Bỏ hẳn — không phù hợp UX mobile một tay, và cũng không phải core value của Muzicz |
| MediaPipe hand gesture điều khiển particle | Cần camera permission + ML pipeline riêng, tốn pin/nhiệt | Không phù hợp cho music player nghe hằng ngày; bỏ khỏi roadmap |
| Electron desktop lyrics overlay (transparent window, IPC) | Mobile không có multi-window overlay kiểu đó | Nếu Muzicz sau này có bản Windows (đã có `windows/` trong repo), có thể cân nhắc riêng — không phải việc của mobile visual |
| Offline `analyzeAudioBeats()` full-track decode qua `OfflineAudioContext` + Worker | Không có API tương đương; tốn CPU/pin nếu làm full-track FFT trên mobile | Thay bằng `just_waveform` (precompute amplitude, không phải beat-map đầy đủ) — rẻ hơn nhiều và đã có sẵn plugin |

### 3.3 Khác biệt nền tảng quan trọng nhất: local file vs streaming

`FLUTTER_MOBILE_FEASIBILITY_REPORT.md` dành nguyên mục 13 và "integration gate A1" để lo về URL
expiry, Range header, cache policy, ToS khi nối Zing/YouTube. Với **luồng chính hiện tại của
Muzicz** (thư viện local), toàn bộ phần đó biến mất: file đã nằm sẵn trên máy, `just_waveform` đọc
thẳng path, không cần download/cache riêng, không có vấn đề pháp lý về lưu trữ audio của người khác.

Điều này chỉ đúng cho tới khi `online_screen.dart` được build thật. Nếu sau này Muzicz nối một
nguồn streaming (kể cả qua yt-dlp sẵn có trong `features/downloader/`), thì **toàn bộ gate A1 của
báo cáo feasibility áp dụng lại y nguyên** — cần treat riêng, không dùng chung pipeline waveform
với local file.

## 4. Kiến trúc đề xuất cho Muzicz cụ thể

Giữ đúng tinh thần mục 10 của `FLUTTER_MOBILE_FEASIBILITY_REPORT.md`, nhưng đặt tên theo convention
đang có trong Muzicz (`PlayerProvider`, `LyricsProvider`):

```
PlayerProvider (đã có — không đổi state-management)
├── vẫn low-frequency: position/duration/playing/currentSong/queue

VisualFeatureController  (MỚI — ChangeNotifier hoặc ValueNotifier riêng, KHÔNG nằm trong
│                          PlayerProvider, KHÔNG gọi notifyListeners() của PlayerProvider)
├── waveformData          (List<double> — precompute 1 lần/track qua just_waveform)
├── playheadFraction      (double — tính từ PlayerProvider.position, không cần stream riêng)
├── amplitudeSmoothed?    (chỉ nếu làm Cấp B/C — realtime RMS)
└── qualityProfile        (low/medium/high — theo device + rolling frame time)

NowPlayingScreen
└── RepaintBoundary
    └── CustomPainter(repaint: VisualFeatureController)   ← waveform/progress vẽ ở đây
        (tách hẳn khỏi _ControlsSection, _ProgressSection hiện có)
```

Lý do tách `VisualFeatureController` khỏi `PlayerProvider`: `PlayerProvider` hiện được inject xuyên
suốt app (mini player, now playing, queue sheet...) — nếu nhồi thêm state 30–60 Hz vào đó, mọi nơi
consume `PlayerProvider` đều có nguy cơ rebuild dư thừa. Tách riêng là thay đổi nhỏ, không đụng
`audio_service`/`just_audio` layer, đúng tinh thần "không đổi state-management toàn app" của báo cáo
gốc và cũng đúng cách Khang hay làm (sandbox diff nhỏ, tách seam rõ ràng).

### 4.1 Cơ chế bật/tắt cho người dùng — mục tiêu: cô lập hoàn toàn, gỡ dễ

Quyết định chốt: visual music là **1 feature module độc lập**, đi theo đúng tiền lệ đã có sẵn trong
repo (`lib/features/downloader/` — cũng tự quản `core/`, `models/`, `providers/`, `screens/`,
`services/`, `widgets/` riêng, gần như không đụng `Provider`/`ChangeNotifier` chính). Không tái sử
dụng cấu trúc mới; bắt chước cấu trúc cũ.

```
lib/features/music_visual/
├── core/
│   └── visual_feature_flag.dart      # const bool kMusicVisualFeatureEnabled — kill-switch build-time
├── models/
│   └── waveform_data.dart            # amplitudes[], songId, analysisVersion
├── services/
│   └── waveform_extract_service.dart # wrap just_waveform, cache RIÊNG thư mục, không chung StorageService
├── providers/
│   ├── visual_mode_provider.dart     # MusicVisualMode {normal, fancy}, persist SharedPreferences riêng key
│   └── visual_feature_controller.dart# amplitude/playhead/quality — không phải ChangeNotifier toàn app
├── painters/
│   └── waveform_painter.dart
└── widgets/
    ├── visual_mode_selector_sheet.dart # bắt chước BottomNavStyleSelectorSheet 1:1 (sheet, haptic, delay-apply)
    └── reactive_waveform_view.dart     # điểm gọi DUY NHẤT từ NowPlayingScreen
```

**Setting cho người dùng**, mirror đúng pattern `BottomNavStyle` đã có trong `theme_provider.dart`:

```dart
enum MusicVisualMode {
  normal('normal', 'Bình thường'),
  fancy('fancy', 'Xịn xò');

  const MusicVisualMode(this.key, this.label);
  final String key;
  final String label;

  bool get enablesReactiveVisual => this == MusicVisualMode.fancy;
}
```

- `normal` → không tạo `VisualFeatureController`, không extract waveform, không `Ticker` nào chạy
  thêm. App y hệt hiện tại — gate ở tầng khởi tạo controller, không phải ẩn/hiện widget trong
  `build()`, để tránh vừa tốn CPU/pin nền vừa phản lại lựa chọn của người dùng.
- `fancy` → mới khởi tạo `VisualFeatureController`, mới precompute waveform khi đổi bài, mới có
  `RepaintBoundary` + `CustomPainter` trong `NowPlayingScreen`.

**2 trục tách biệt, không gộp chung 1 switch:** `MusicVisualMode` là ý muốn người dùng; quality
profile (low/medium/high, mục 14.2 của feasibility report gốc) là runtime tự hạ theo máy/nhiệt độ.
Máy yếu + user chọn "fancy" → vẫn bật nhưng tự hạ xuống Low, không tự ý tắt hẳn lựa chọn của họ.

**Permission tách khỏi toggle chính:** giai đoạn đầu "fancy" chỉ mở Phase 1–2 (waveform local, không
cần quyền gì). Nếu sau này có Phase 3 (spectrum realtime, cần `RECORD_AUDIO`), đó là **sub-toggle
nằm bên trong** khi đã chọn "fancy", chỉ xin quyền đúng lúc bật sub-toggle kèm giải thích — không xin
mic permission chỉ vì người dùng chạm vào "Xịn xò".

**Default = `normal`.** Chưa có benchmark thiết bị thật, nên opt-in, không tự tin thay người dùng.

### 4.2 Điểm tích hợp — liệt kê hết, để biết chính xác cái gì phải revert khi gỡ

| # | File bị chạm | Mức độ thay đổi |
| --- | --- | --- |
| 1 | `main.dart` (nơi khai `MultiProvider`) | 1 dòng — đăng ký `VisualModeProvider` |
| 2 | `screens/profile_screen.dart` | 1 `ListTile` mới, gọi `VisualModeSelectorSheet.show(...)` |
| 3 | `screens/now_playing_screen.dart` | 1 chỗ chèn `ReactiveWaveformView(...)` cạnh `_ProgressSection` hiện có (không sửa bên trong `_ProgressSection`) |

Ngoài 3 điểm này, không file nào khác trong `lib/` được biết đến `music_visual/`. Test kiến trúc rẻ:
`grep -r "music_visual" lib/ --include="*.dart" -l` không được ra quá 3 file trên (cộng file trong
chính module).

**Cache/data cũng cô lập:** `WaveformExtractService` cache vào thư mục riêng
(`getApplicationDocumentsDirectory()/music_visual_cache/`), không dùng chung namespace với
`storage_service.dart` (file đó đang lo playlist/favorite/hidden songs, không nhồi thêm trách
nhiệm). `VisualModeProvider` tự quản key `SharedPreferences` riêng (`music_visual_mode`), không viết
chung getter/setter vào `ThemeProvider`/`StorageService`.

### 4.3 Kill-switch 2 lớp

- **Lớp 1 — user setting** (`MusicVisualMode`, per-device, qua sheet).
- **Lớp 2 — build-time flag** (`kMusicVisualFeatureEnabled` trong `core/visual_feature_flag.dart`):
  nếu phát hiện bug nghiêm trọng (crash, leak pin) cần tắt gấp cho toàn bộ user kể cả người đã lưu
  pref "fancy" — đổi `false`, build lại, ship. Không cần remote config cho quy mô 1 dev; 1 dòng const
  đủ, diff review 5 giây. `ReactiveWaveformView` check flag này **trước cả khi** đọc
  `VisualModeProvider`.

**Checklist gỡ khẩn cấp:**
1. Set `kMusicVisualFeatureEnabled = false` → tắt ngay, không cần đợi user tự đổi setting.
2. Gỡ hẳn: xoá `lib/features/music_visual/`, revert 3 điểm ở mục 4.2, xoá thư mục cache — build phải
   xanh ngay vì không có import ngược từ code còn lại vào thư mục đã xoá.

## 5. Bảng khả thi theo feature — áp cho đúng stack Muzicz

| Feature | Khả thi trên Muzicz | Cách làm | Cần gì mới | Độ khó | Ưu tiên |
| --- | --- | --- | --- | --- | --- |
| Waveform tiến độ (progress waveform) từ file local | CAO | `just_waveform` → cache theo `songId` (đã có sẵn trong `SongItem`/`on_audio_query`) → `CustomPainter` | Thêm 1 package | Thấp/Vừa | P0 |
| Cover pulse phản ứng biên độ thật (thay vì xoay đều) | CAO | Amplitude từ waveform đã precompute + `playheadFraction`, không cần realtime | Không | Thấp | P0 |
| Lyric line-sync mượt hơn khi seek | Đã có nền, cần audit | Kiểm tra `LyricsProvider` có binary-search khi seek lùi hay đang linear scan | Không, chỉ audit | Thấp | P0 |
| Spectrum/bar bass-mid-treble | TRUNG BÌNH | Cần RMS/FFT thật → Android `Visualizer` (cần `RECORD_AUDIO`) hoặc iOS tap; `just_audio` chưa có API ổn định public | Native plugin hoặc chấp nhận experimental | Vừa/Cao | P1 |
| Particle 2D nhẹ theo nhịp | CAO nếu chỉ dùng amplitude đã có, TRUNG BÌNH nếu cần beat thật | `CustomPainter`, pool object, không tạo `Paint` mỗi frame | Không bắt buộc | Vừa | P1 |
| Karaoke từng từ | THẤP hiện tại | LRCLIB không trả word-level; `LyricLine` model chưa có `words[]` | Cần nguồn lyric khác có word timestamp | Cao | Không phải V1 |
| Waveform cho nhạc streaming online (tương lai) | Áp dụng lại gate A1 nguyên vẹn | Download/cache có kiểm soát trước khi extract | Toàn bộ pipeline riêng | Cao | Sau khi `online_screen` thật |
| 3D shelf/particle kiểu Wavez, gesture tay | KHÔNG NÊN | Không phù hợp UX/mobile/pin | — | Rất cao | Loại khỏi roadmap |

## 6. Lộ trình đề xuất (POC → MVP A → MVP B, theo phase style quen thuộc)

**Phase 0 — Audit nhỏ, không code mới (0.5 ngày)**
Xem `LyricsProvider`/`_LyricsView` có đang binary-search khi seek hay linear scan; xem
`_artRotateCtrl` hiện chạy độc lập playback hay có nghe `position` không. Việc này rẻ và tránh
xây waveform mới trên một nền lyric-sync có bug tiềm ẩn.

**Phase 0.5 — Scaffold module + setting, chưa có visual thật**
Tạo khung `lib/features/music_visual/` theo mục 4.1–4.3 (rỗng phần logic), thêm
`kMusicVisualFeatureEnabled`, `MusicVisualMode` enum, `VisualModeProvider` (persist
`SharedPreferences`), `VisualModeSelectorSheet` (bắt chước `BottomNavStyleSelectorSheet`), 3 điểm
tích hợp ở mục 4.2. Chọn "Xịn xò" ở bước này chỉ nên hiện placeholder rỗng (ví dụ "Đang phát triển")
— mục đích là chốt xong cơ chế bật/tắt/gỡ **trước khi** có bất kỳ logic waveform nào, để Phase 1 trở
đi chỉ còn việc lấp nội dung vào trong ranh giới đã cô lập sẵn.

**Phase 1 — POC waveform local, trong `music_visual/`, sau `VisualModeProvider` (giống mục 17 của feasibility report)**
1. Thêm `just_waveform`, thử với 1–2 file local trong thư viện Muzicz thật (không phải MP3 giả).
2. Precompute 256–1024 cột amplitude, cache theo `songId + analysisVersion` (dùng
   `shared_preferences` hoặc file cache đã có sẵn pattern trong `storage_service.dart`).
3. Vẽ bằng `CustomPainter` trong `RepaintBoundary`, `playheadFraction` lấy từ `PlayerProvider.position`
   (không tạo stream mới, tái dùng cái đang có).
4. Xác nhận bằng DevTools: `_ControlsSection`/`_ProgressSection` hiện có không bị rebuild theo frame.

**Phase 2 — Tích hợp vào `NowPlayingScreen` thật, thay/bổ sung `_artRotateCtrl`**
Cover pulse dùng amplitude đã precompute thay vì animation xoay đều vô điều kiện — nhìn "thật" hơn
mà không cần realtime RMS. Đây chính là điểm dừng an toàn (MVP A) nếu quyết định không đầu tư native
plugin.

**Phase 3 — Chỉ làm nếu Phase 1–2 chứng minh đáng — Realtime RMS (MVP B)**
POC riêng Android `Visualizer` qua `just_audio`'s `androidAudioSessionIdStream` + iOS
`AVAudioEngine`/tap. Đây là phần duy nhất thật sự cần native code và permission
(`RECORD_AUDIO` trên Android — cần cân nhắc UX vì người dùng có thể e ngại app nhạc xin quyền mic).
Không cam kết trước khi đo được cả hai platform trả packet ổn định.

**Không làm trong V1 (đồng thuận với 2 báo cáo nguồn):** particle 3D, gesture, spectrum FFT đầy đủ,
bất kỳ thứ gì cần `OfflineAudioContext`-style full-track decode.

## 7. Rủi ro cụ thể cho Muzicz (không lặp lại rủi ro chung chung của Wavez)

| Rủi ro | Vì sao riêng cho Muzicz | Cách kiểm |
| --- | --- | --- |
| `notifyListeners()` của `PlayerProvider` bị dùng chung cho visual feature | `PlayerProvider` 467 dòng, được inject rộng | Code review + DevTools rebuild tracking trước khi merge |
| `now_playing_screen.dart` đã 2241 dòng — thêm painter vào sai chỗ dễ tăng rebuild scope | File lớn, nhiều `StatefulWidget` con lồng nhau | Đặt `CustomPainter` trong widget con riêng, `const` cho phần tĩnh |
| `just_waveform` cần license/maturity kiểm tra lại tại thời điểm implement (báo cáo ghi 0.0.7, "Trung bình") | Version có thể đã đổi từ 2026-07-23 | Check `pub.dev` version mới nhất trước khi thêm dependency |
| `RECORD_AUDIO` permission cho Android `Visualizer` (chỉ nếu làm Phase 3) | App nhạc xin quyền mic dễ gây nghi ngờ người dùng | Chỉ hỏi permission ngay trước khi bật tính năng, có giải thích rõ, và giữ MVP A hoạt động nếu user từ chối |
| Thiết bị yếu (đối tượng người dùng Việt Nam nhiều máy tầm trung/thấp) | Không có dữ liệu benchmark thiết bị cụ thể trong 3 báo cáo nguồn | Bắt buộc test trên ít nhất 1 máy Android tầm thấp thật trước khi để mặc định bật |
| Ranh giới `music_visual/` bị vi phạm dần theo thời gian (import ngược từ code chính vào module, hoặc ngược lại) | Dễ xảy ra nếu sau này thêm tính năng vội, không review lại boundary | `grep -r "music_visual" lib/ --include="*.dart" -l` định kỳ trước khi release; không quá 3 file tích hợp ở mục 4.2 |
| Cache waveform phình to theo thời gian nếu không giới hạn | Mỗi bài hát 1 file waveform cache, thư viện nhạc lớn cộng dồn | Giới hạn cache theo LRU hoặc dọn khi gỡ/khi user tắt "fancy" lâu ngày — thiết kế cùng lúc với `WaveformExtractService`, không để tồn đọng vô hạn |

## 8. Trả lời nhanh các câu hỏi cốt lõi (theo format mục 19 của feasibility report gốc)

1. **Áp dụng visual kiểu Wavez vào Muzicz có khả thi không?** Có, nhưng chỉ phần thuật toán
   (band mapping, normalization, easing, lyric timing) — không phải code hay kiến trúc render.
2. **Muzicz có lợi thế gì Wavez không có?** Local file, không phải lo URL expiry/cache/ToS — toàn bộ
   gate A1 của feasibility report biến mất cho luồng chính hiện tại.
3. **Bắt đầu từ đâu?** `just_waveform` + `CustomPainter` progress waveform, tách khỏi
   `PlayerProvider` bằng một `VisualFeatureController` riêng.
4. **Có cần native plugin ngay không?** Không. Chỉ cần nếu muốn realtime RMS/FFT thật (Phase 3),
   và chỉ sau khi Phase 1–2 đã chứng minh giá trị trải nghiệm đủ lớn.
5. **Phần nào của 3 báo cáo nguồn nên bỏ hẳn?** 3D shelf, 3D lyric world, MediaPipe gesture, Electron
   overlay — tất cả đều `upstream-inherited` từ Mineradio, gắn chặt Three.js/Electron, không có giá
   trị port sang mobile-first music player.
6. **Rủi ro kiến trúc lớn nhất riêng của Muzicz?** `PlayerProvider`/`now_playing_screen.dart` đã lớn;
   audio feature tần số cao cắm sai chỗ sẽ gây rebuild lan rộng — không phải rủi ro FFT/GPU như Wavez.

## 9. Việc tiếp theo cụ thể nếu muốn triển khai

- Audit nhanh `LyricsProvider` seek-behavior (Phase 0) trước khi build gì mới.
- Scaffold `lib/features/music_visual/` + `MusicVisualMode` setting + kill-switch (Phase 0.5) — chốt
  xong cơ chế bật/tắt/gỡ trước khi viết logic waveform, đúng thứ tự đã bàn.
- Xác nhận version `just_waveform` hiện tại trên pub.dev (báo cáo nguồn ghi nhận tại 2026-07-23).
- Chọn 1 bài hát thật trong thư viện để làm POC Phase 1, đo bằng DevTools trước khi merge vào
  `now_playing_screen.dart`.

## 10. Tóm tắt cơ chế cài đặt (đã thống nhất)

- Setting nằm trong `screens/profile_screen.dart`, dùng đúng UX pattern của
  `BottomNavStyleSelectorSheet` đã có: modal sheet, 2 lựa chọn, haptic feedback, delay trước khi áp
  dụng.
- 2 option: **Bình thường** (app như hiện tại, 0 chi phí thêm) / **Xịn xò** (bật
  `VisualFeatureController`, waveform + cover pulse phản ứng thật).
- Toàn bộ logic nằm trong `lib/features/music_visual/`, cô lập theo đúng tiền lệ
  `lib/features/downloader/` — chỉ 3 điểm tích hợp vào code chính (mục 4.2), có kill-switch build-time
  độc lập với setting của user (mục 4.3), cache riêng thư mục, `SharedPreferences` key riêng.
- Mục tiêu đã đạt: nếu sau này phát hiện lỗi, gỡ hoặc tắt gấp không cần đụng vào
  `PlayerProvider`, `audio_handler.dart`, `lyrics_service.dart` hay bất kỳ phần nào của luồng
  playback/lyric chính.

## 11. Gate và prompt cho từng phase — điều kiện để đi tiếp

Nguyên tắc chung: mỗi phase là 1 lượt agent riêng, phạm vi hẹp, dừng lại chờ review ở cuối. Không
gộp 2 phase vào 1 lượt kể cả khi phase trước "trông có vẻ ổn" — gate dưới đây là điều kiện khách quan
để quyết định, không phải cảm giác.

### 11.1 Gate Phase 0 → Phase 0.5

- Kết quả audit (`_LyricsView` seek binary-search hay linear scan; `_artRotateCtrl` có nghe
  `position` không) đã ghi vào `plan/memory/` kèm nhãn CONFIRMED/INFERRED.
- Nếu phát hiện bug thật ở seek/lyric (không chỉ "chưa tối ưu"): quyết định fix trước hay chấp nhận
  rủi ro đã biết rồi mới đi tiếp — không lờ đi.

### 11.2 Gate Phase 0.5 → Phase 1 (gate quan trọng nhất — trước khi đụng performance thật)

1. **Build sạch:** `flutter analyze` không thêm warning/error mới so với baseline.
2. **Ranh giới module đúng thiết kế:** `grep -r "music_visual" lib/ --include="*.dart" -l` chỉ ra các
   file trong `lib/features/music_visual/` + đúng 3 điểm tích hợp ở mục 4.2. Ra hơn 3 file ngoài
   module = fail.
3. **Setting hoạt động thật, không phải UI giả:** chọn "Xịn xò" → restart app → vẫn giữ; chọn "Bình
   thường" → không có `Ticker`/timer nào của module chạy nền.
4. **Kill-switch có tác dụng thật:** `kMusicVisualFeatureEnabled = false` → build lại → mục "Xịn xò"
   biến mất/disable hẳn, không chỉ ẩn UI còn logic chạy ngầm.
5. **Test rollback** (quan trọng nhất với mục tiêu "dễ gỡ"): xoá `lib/features/music_visual/` +
   revert 3 điểm tích hợp trên 1 branch/stash test → build phải xanh ngay, không lỗi import ngược.
   Fail ở đây thì sửa boundary trước, chưa cho viết thêm logic lên trên.
6. **Không regression luồng chính:** playback/lyric/mini player/queue hoạt động y hệt trước khi có
   `music_visual/`.
7. Đã ghi vào `plan/memory/PROGRESS.md` và Khang đã review.

### 11.3 Gate Phase 1 → Phase 2

- Waveform hiển thị đúng cho ít nhất 3 bài hát thật khác thể loại (nhạc động, nhạc chậm, có đoạn
  silence) — không chỉ 1 bài demo.
- `RepaintBoundary` xác nhận bằng DevTools: `_ControlsSection`/`_ProgressSection`/nút play không
  rebuild theo frame khi waveform đang vẽ.
- Cache waveform hoạt động đúng: mở lại bài đã phát không extract lại từ đầu; đổi bài liên tục 10
  lần không leak memory/isolate (theo dõi qua DevTools Memory).
- Seek liên tục, tắt/mở app giữa lúc đang phát không crash, `playheadFraction` đồng bộ đúng vị trí.
- Đo trên tối thiểu 1 máy Android tầm thấp/trung thật — không chỉ emulator.

### 11.4 Gate Phase 2 → Phase 3

- Cover pulse theo amplitude đã tích hợp vào `NowPlayingScreen` thật, không phải màn hình cô lập
  riêng nữa.
- Người dùng thật (kể cả chỉ là Khang) xác nhận trải nghiệm "đáng" so với `_artRotateCtrl` cũ — đây
  là gate mang tính sản phẩm, không chỉ kỹ thuật. Nếu không thấy đáng, dừng ở MVP A, không tự động
  đẩy sang Phase 3.
- Không có regression về pin/nhiệt so với trước khi có Phase 1–2 sau 20–30 phút nghe liên tục, theo
  đúng kế hoạch đo ở mục 14.3 của feasibility report gốc.
- Quyết định rõ ràng: có đầu tư native plugin (Android `Visualizer`/iOS tap) hay dừng ở đây. Đây là
  quyết định của Khang, không phải agent tự chọn tiếp.

### 11.5 Prompt mẫu cho từng phase

Bối cảnh:
- Đang triển khai tính năng "Music Visual" cho app Muzicz (Flutter, package `muziczz`).
- Tài liệu chính cần đọc và bám sát:  [MUZICZ_VISUAL_FEASIBILITY_PLAN.md](plan/visual-audio/MUZICZ_VISUAL_FEASIBILITY_PLAN.md) (kế hoạch đã chốt, 
  gồm cả cơ chế setting Bình thường/Xịn xò và yêu cầu cô lập module).
- Tài liệu tham khảo kỹ thuật chính khi cần đối chiếu công thức/thuật toán:
  `[FLUTTER_MOBILE_FEASIBILITY_REPORT.md](docs/analysis/FLUTTER_MOBILE_FEASIBILITY_REPORT.md) `. 
- Hai tài liệu sau CHỈ tham khảo thêm khi cần hiểu bối cảnh, không phải nguồn quyết định:
  ` [MUSIC_VISUAL_FORENSIC_REPORT.md](docs/analysis/MUSIC_VISUAL_FORENSIC_REPORT.md) `, `[UPSTREAM_VISUAL_DIFF_REPORT.md](docs/analysis/UPSTREAM_VISUAL_DIFF_REPORT.md) `. 
  Lưu ý cả 3 file này phân tích Wavez (Electron/Three.js), không phải Muzicz — không port code,
  chỉ port thuật toán/công thức đã được [MUZICZ_VISUAL_FEASIBILITY_PLAN.md](plan/visual-audio/MUZICZ_VISUAL_FEASIBILITY_PLAN.md)  chọn lọc sẵn. 

Prompt Phase 0/0.5 đã dùng ở lượt trước có thể tái sử dụng gần như nguyên văn cho Phase 1–3, chỉ đổi
phần "Phạm vi lượt này" và "Ràng buộc bắt buộc" theo đúng scope của phase đó, giữ nguyên khung:
bối cảnh → phạm vi hẹp → ràng buộc không sửa file cấm → constraint sandbox → yêu cầu tự verify gate
ở mục 11 tương ứng → dừng chờ review.

**Phase 1:**

```
Phạm vi lượt này: CHỈ Phase 1 (POC waveform local) trong lib/features/music_visual/.
Điều kiện bắt đầu: Gate Phase 0.5 → Phase 1 (mục 11.2 của plan) đã pass và đã được Khang review.

Việc cần làm:
- Thêm just_waveform (xác nhận version mới nhất trên pub.dev trước khi thêm vào pubspec.yaml).
- Implement WaveformExtractService: input là file path từ SongItem/on_audio_query, cache vào
  getApplicationDocumentsDirectory()/music_visual_cache/, key theo songId + analysisVersion.
- Implement WaveformPainter (CustomPainter) vẽ 256–1024 cột amplitude, playhead theo
  playheadFraction lấy từ PlayerProvider.position (đọc, không sửa PlayerProvider).
- Gắn vào ReactiveWaveformView đã scaffold ở Phase 0.5, trong RepaintBoundary riêng.

Ràng buộc bắt buộc:
- Không sửa providers/player_provider.dart, services/audio_handler.dart,
  services/lyrics_service.dart.
- Không mở rộng phạm vi tích hợp quá 3 điểm đã chốt ở mục 4.2 của plan.
- Sandbox không có Flutter SDK: xuất diff để mình áp tay, mình báo lại kết quả build/test.

Trước khi báo hoàn thành, tự kiểm tra và báo cáo kết quả theo đúng 5 tiêu chí ở mục 11.3 của
MUZICZ_VISUAL_FEASIBILITY_PLAN.md (waveform đúng cho 3+ bài khác thể loại, RepaintBoundary xác
nhận qua DevTools, cache hoạt động đúng, seek/lifecycle không crash, đã đo trên máy thật).
Dừng lại, không tự chuyển sang Phase 2.
```

**Phase 2:**

```
Phạm vi lượt này: CHỈ Phase 2 — tích hợp cover pulse theo amplitude vào NowPlayingScreen thật.
Điều kiện bắt đầu: Gate Phase 1 → Phase 2 (mục 11.3) đã pass và đã được Khang review.

Việc cần làm:
- Thay/bổ sung _artRotateCtrl trong now_playing_screen.dart bằng animation đọc amplitude đã
  precompute từ Phase 1 (qua VisualFeatureController), chỉ áp dụng khi MusicVisualMode = fancy.
- Khi MusicVisualMode = normal, giữ nguyên _artRotateCtrl cũ y hệt hiện tại — không đổi behavior
  mặc định của app.

Ràng buộc bắt buộc: giống Phase 1 (không sửa player_provider/audio_handler/lyrics_service, không
mở rộng phạm vi tích hợp, xuất diff cho sandbox không có SDK).

Trước khi báo hoàn thành, tự kiểm tra theo mục 11.4 của plan, đặc biệt là đo pin/nhiệt 20–30 phút
theo mục 14.3 của FLUTTER_MOBILE_FEASIBILITY_REPORT.md. Dừng lại chờ Khang quyết định có làm
Phase 3 (native RMS) hay dừng ở đây — đây là quyết định sản phẩm, agent không tự chọn.
```

**Phase 3 (chỉ tạo prompt này nếu Khang đã quyết định làm tiếp sau Phase 2):**

```
Phạm vi lượt này: CHỈ POC Android Visualizer (không làm iOS trong cùng lượt, tách riêng vì rủi ro/
API khác nhau — xem mục 8–9 của FLUTTER_MOBILE_FEASIBILITY_REPORT.md).
Điều kiện bắt đầu: Khang đã xác nhận muốn đầu tư native plugin sau Phase 2.

Việc cần làm:
- POC riêng, KHÔNG merge vào lib/features/music_visual/ chính cho tới khi packet ổn định trên
  thiết bị thật, theo đúng khuyến nghị "production/high-end sau POC" ở mục 6.3 của feasibility
  report.
- Dùng just_audio's androidAudioSessionIdStream để gắn android.media.audiofx.Visualizer.
- Chỉ request RECORD_AUDIO ngay trước khi bật sub-toggle riêng (không xin quyền khi user chỉ chọn
  "Xịn xò" ở mức Phase 1–2).

Ràng buộc bắt buộc: giống các phase trước. Đây là phần duy nhất được phép thêm native code
(Kotlin), nhưng vẫn phải nằm trong lib/features/music_visual/ + platform channel riêng, không
đụng cấu trúc audio_handler.dart hiện có.

Kết quả cần báo: packet RMS có ổn định qua ít nhất 3 lần seek/pause/resume/đổi track không, có
crash khi Bluetooth route đổi không. Nếu không ổn định, dừng ở MVP A/B (Phase 1–2), không cố ép
Phase 3 chạy bằng workaround.
```