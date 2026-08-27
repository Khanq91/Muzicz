# Muzicz technical audit — setup, architecture, performance và UI/UX

- Thời điểm audit: 2026-07-18 (Asia/Saigon)
- Commit baseline: `56cb5e1` (`main`)
- Phạm vi: source hiện tại, cấu hình Android/iOS, 11 screenshot trong `assets/screenshots/`, static analysis và test suite hiện có.
- Giới hạn: chưa chạy app/profile mode trên thiết bị thật; mọi tác động runtime chưa được đo được ghi là kỳ vọng hoặc `Likely`, không được trình bày như benchmark.

## Baseline

| Hạng mục | Kết quả |
|---|---|
| Flutter / Dart | Flutter 3.44.0 stable, Dart 3.12.0, DevTools 2.57.0 |
| Quy mô `lib/` | 64 Dart files, 20.542 dòng; `screens/` 8.524 dòng, downloader feature 7.149 dòng |
| State management | Provider/ChangeNotifier cho music; Riverpod cho downloader |
| Navigation | `Navigator` + `MaterialPageRoute`/`PageRouteBuilder`; named `/dl/*`; downloader có nested `MaterialApp` |
| DI | Provider composition ở root, constructor injection cho audio handler; nhiều service được `new` trực tiếp hoặc singleton |
| Networking | `http` đến LRCLIB; yt-dlp qua MethodChannel → Kotlin → Chaquopy/Python; `cached_network_image` |
| Local data | `SharedPreferences`, lyrics file cache, MediaStore/on_audio_query và filesystem ngoài |
| Auth/session | Không có flow authentication/session/token; phù hợp với phạm vi app local hiện tại |
| `flutter pub get` | Exit 0; lockfile không đổi; 48 package có bản mới không tương thích constraint hiện tại |
| Format check | Exit 1; 24/65 file sẽ bị formatter đổi; chạy với `--output=none`, không sửa source |
| Analyze | `scripts/flutter_analyze.bat` exit 0; 0 error, 0 warning, 0 info; log tại `audit/flutter_analyze.txt` |
| Test | `flutter test` pass 1/1; test duy nhất chỉ là `expect(true, isTrue)` |
| Integration test | Không có thư mục `integration_test/` |

Lần gọi Flutter đầu tiên trong sandbox timeout do SDK/cache ngoài workspace không ghi được. Chạy cùng lệnh ngoài sandbox hoàn tất bình thường; đây là giới hạn môi trường audit, không phải lỗi repository.

## 1. Executive summary

Analyzer sạch nhưng không phản ánh các lỗi orchestration chính. Các rủi ro lớn nhất nằm ở downloader và playback: playlist batch có thể khởi động cùng task nhiều lần; 10 download dùng chung một progress global; nút Cancel không dừng native download; và queue UI không được đồng bộ với audio source. Đây đều là lỗi có đường kích hoạt cụ thể và test hiện tại không phủ.

Cold start đang có chi phí chủ động: Chaquopy/Python được khởi tạo trước khi cần downloader; Splash chờ cố định 4,6 giây rồi mọi lần mở app sau first-run đều quét MediaStore vì danh sách bài không được hydrate từ storage. Chưa có benchmark thiết bị để định lượng thêm bao nhiêu mili-giây, nhưng thời gian chờ cố định và đường gọi scan đã được xác nhận trong code.

Dark-mode screenshot có hierarchy và purple accent khá nhất quán. Tuy vậy accessibility và light mode có lỗi xác nhận: text scale toàn app bị chặn ở 115%, nhiều control chính thiếu semantics/touch target, token text mờ không đủ contrast cho text thường, và một số chữ/icon trắng biến mất trên light background.

Client không chứa API key/token hardcode và không tắt SSL validation theo phép tìm kiếm source. Hai điểm release/security cần xử lý là release Android đang ký bằng debug key và app yêu cầu `MANAGE_EXTERNAL_STORAGE`, đồng thời log URL/path/lyrics response quá chi tiết.

## 2. Architecture map thực tế

### Music library và playback

```text
Screens / Widgets
  → Provider ChangeNotifier
      ThemeProvider → SharedPreferences
      MusicProvider → MusicScanner → on_audio_query → Android MediaStore / iOS plugin
                    → StorageService → SharedPreferences
      PlayerProvider → MuzicAudioHandler → just_audio / audio_service → local audio files
      LyricsProvider → LyricsService → LRCLIB HTTPS
                                     → application cache files
```

- Root composition nằm ở `lib/main.dart:42-67`.
- `SplashScreen` khởi tạo storage và scan tại `lib/screens/splash_screen.dart:78-89`.
- Không có repository/use-case layer; service hiện đóng vai adapter. Thiếu repository tự thân không phải lỗi ở quy mô hiện tại.

### Downloader

```text
Downloader screens
  → Riverpod AnalyzeNotifier / DownloadNotifier / networkStatusProvider
  → (một số screen gọi thẳng Connectivity, DownloaderStorageService)
  → YtdlpService / DownloaderStorageService singleton
  → MethodChannel("ytdlp_channel")
  → MainActivity Kotlin + IO coroutines
  → Chaquopy ytdlp_bridge.py / yt-dlp / MediaExtractor
  → Internet + shared external storage
```

- App đã có root `ProviderScope`, nhưng `AnalyzeScreenBridge` tạo thêm `ProviderScope` và `MaterialApp` (`lib/features/downloader/screens/analyze_screen_bridge.dart:12-27`).
- Native channel dispatch ở `android/app/src/main/kotlin/com/muziczz/muziczz/MainActivity.kt:47-169`; Python bridge ở `android/app/src/main/python/ytdlp_bridge.py`.
- Navigation và I/O orchestration còn nằm trực tiếp trong Widget; connectivity được kiểm tra theo ba đường khác nhau (gateway listener, analyze one-shot, Riverpod stream).

## 3. Danh sách phát hiện

### DL-01 — Playlist batch có thể khởi động cùng task nhiều lần

- **Nhóm:** State / async orchestration
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/features/downloader/screens/format/format_screen.dart:271-289`; `lib/features/downloader/providers/download_provider.dart:171-199`; `lib/features/downloader/services/ytdlp_service.dart:140-160`.
- **Bằng chứng:** UI gọi `enqueue` liên tiếp nhưng không `await`. `_processQueue` chọn task còn `queued`; `_startDownload` không reserve task sang `preparing` trước khi mở stream. Hai event `preparing/downloading` chỉ về subscriber bất đồng bộ, nên lần enqueue kế tiếp vẫn có thể chọn task cũ; `_subs[task.id]` sau đó bị overwrite.
- **Tác động:** cùng URL tải nhiều lần, vượt concurrency, subscription mồ côi và collision cùng output filename.
- **Tái hiện/đo:** chọn playlist từ 2 entry; gắn task ID vào log và đếm `[YTDLP_BRIDGE] download() called` theo URL.
- **Giải pháp:** đồng bộ chuyển task sang `preparing` ngay đầu `_startDownload`; guard `_subs.containsKey(task.id)`; batch enqueue xong mới gọi `_processQueue` một lần.
- **Rủi ro khi sửa:** nếu tạo stream ném lỗi đồng bộ phải đưa task sang `error`, không để kẹt `preparing`.
- **Effort:** S.

### DL-02 — Progress của tối đa 10 download dùng chung một biến global

- **Nhóm:** Correctness / performance
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/features/downloader/core/constants/app_constants.dart:10-12`; `lib/features/downloader/services/ytdlp_service.dart:162-188`; `android/app/src/main/python/ytdlp_bridge.py:7-29,119-159`; `MainActivity.kt:124-135`.
- **Bằng chứng:** `maxConcurrentDownloads = 10`; mỗi task poll `getProgress` mỗi 600 ms nhưng không truyền task ID. Python chỉ có `_progress` global và mỗi `download()` gọi `reset_progress()`.
- **Tác động:** card nhận progress/speed/ETA của task khác; download mới reset progress đang chạy. Trần lý thuyết là khoảng 16,7 platform poll/giây, chưa tính overlap khi call trước quá 600 ms.
- **Tái hiện/đo:** tải đồng thời hai file kích thước/tốc độ khác nhau, log `{taskId, url, progress.filename}` và đếm MethodChannel call trong DevTools/Perfetto.
- **Giải pháp:** containment trước mắt đặt concurrency = 1. Fix đầy đủ truyền `taskId` Dart → Kotlin → Python và dùng `Map<taskId, progress>`; tránh poll chồng bằng một poll loop tuần tự.
- **Rủi ro khi sửa:** containment giảm throughput; protocol task-scoped thay đổi ba layer.
- **Effort:** S (containment), L (fix đầy đủ).

### DL-03 — Cancel chỉ đổi UI, native/Python vẫn tải và ghi file

- **Nhóm:** Stability / resource lifecycle
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/features/downloader/providers/download_provider.dart:116-135`; `lib/features/downloader/models/download_task.dart:78-96`; `lib/features/downloader/services/ytdlp_service.dart:136-248`; `MainActivity.kt:49-169`.
- **Bằng chứng:** `task.process?.kill` không có tác dụng vì `process` không được gán. Cancel subscription không cancel `MethodChannel.invokeMethod`; `StreamController` không có `onCancel`; native channel không có method cancel.
- **Tác động:** UI báo “Đã hủy” nhưng network, CPU và storage vẫn chạy; queue còn khởi động task tiếp theo nên số native operation thực có thể vượt giới hạn.
- **Tái hiện/đo:** tải file lớn, nhấn Cancel, theo dõi network profiler và kích thước partial file trong 30–60 giây.
- **Giải pháp:** cooperative cancellation theo task ID xuyên ba layer; chỉ chuyển `cancelled` sau ACK; cleanup partial file theo chính sách rõ ràng.
- **Rủi ro khi sửa:** dừng yt-dlp giữa merge/post-process có thể để file hỏng; cần cleanup an toàn.
- **Effort:** M/L.

### PLAY-01 — Queue hiển thị và playlist của audio engine bị lệch

- **Nhóm:** Playback state
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/providers/player_provider.dart:351-372`; `lib/services/audio_handler.dart:23-64`; `lib/screens/now_playing_screen.dart:2155-2222`.
- **Bằng chứng:** `removeFromQueue`/`reorderQueue` chỉ sửa `_playQueue`; không remove/move `ConcatenatingAudioSource`. `skipToIndex` sau đó seek theo index UI trên playlist native cũ.
- **Tác động:** title/artwork có thể không khớp âm thanh; bài đã xóa vẫn phát hoặc tap bài C phát bài B.
- **Tái hiện/đo:** queue A/B/C, xóa B hoặc kéo C lên đầu, tap từng item và so audio thực với `currentSong`.
- **Giải pháp:** thêm API remove/move trong `MuzicAudioHandler`; thao tác provider thành async và chỉ commit state khi engine thành công; test index/current item.
- **Rủi ro khi sửa:** cần xử lý riêng remove/move bài đang phát và điều chỉnh current index.
- **Effort:** M.

### LIFE-01 — Nested ProviderScope dispose một singleton không thể tái sử dụng

- **Nhóm:** Architecture / lifecycle
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/main.dart:44-50`; `lib/features/downloader/screens/analyze_screen_bridge.dart:12-27`; `providers/network_provider.dart:7-11`; `services/network_service.dart:8-44`.
- **Bằng chứng:** bridge tạo Riverpod container ngắn hạn dù root đã có. Khi pop, provider gọi `NetworkService.instance.dispose()`, cancel sub và đóng final broadcast controller. Mở lại dùng cùng singleton/controller đã đóng; download state trong scope cũ cũng mất.
- **Tác động:** lần mở downloader sau có thể `StateError` khi connectivity add; download native đang chạy thành orphan khỏi UI.
- **Tái hiện/đo:** mở downloader → thoát → mở lại → bật/tắt airplane mode; lặp lại khi một download đang chạy.
- **Giải pháp:** dùng root ProviderScope/router; hoặc provider sở hữu instance `NetworkService` mới có lifecycle tương ứng, không đóng singleton dùng lại.
- **Rủi ro khi sửa:** regression back stack và hành vi “Về trang chủ”.
- **Effort:** M.

### START-01 — Splash có lower bound 4,6 giây rồi luôn await full scan ở cold start

- **Nhóm:** Startup performance / UX
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/screens/splash_screen.dart:68-89`; `lib/providers/music_provider.dart:16,78-81`; `lib/services/music_scanner.dart:50-69`.
- **Bằng chứng:** chuỗi delay 200 + 400 + 4.000 ms chạy trước `_navigate`. `MusicProvider` mới luôn có `_allSongs = []`; `init()` chỉ hydrate storage/playlists, nên non-first-run cold process luôn vào nhánh `await scanMusic()`, rồi scanner gọi `scanMedia('/storage/emulated/0')`.
- **Tác động:** time-to-Home theo code tối thiểu 4,6 giây cộng init/full scan; chưa có device benchmark để định lượng phần scan.
- **Tái hiện/đo:** profile build, timestamp process start/first Flutter frame/splash sequence/scan start-end/first Home frame; Perfetto MediaProvider/I/O.
- **Giải pháp:** khởi động `MusicProvider.init()` song song animation; dùng minimum splash duration thay vì delay nối tiếp; Home render loading/scan background; tách deep rescan thành action rõ ràng.
- **Rủi ro khi sửa:** Home cần loading state để tránh nháy empty; giữ đúng routing first-run.
- **Effort:** M.

### START-02 — Chaquopy/Python được khởi tạo đồng bộ dù downloader chưa dùng

- **Nhóm:** Android startup
- **Mức độ:** High
- **Độ tin cậy:** Confirmed về critical-path code; tác động thời gian chưa đo
- **File/vị trí:** `android/app/src/main/kotlin/com/muziczz/muziczz/MainActivity.kt:36-45`.
- **Bằng chứng:** `Python.start`, `Python.getInstance` và `getModule("ytdlp_bridge")` chạy trực tiếp trong `configureFlutterEngine` trên mọi Android app start.
- **Tác động:** Python runtime/module loading nằm trước khi app cần downloader và có khả năng tăng cold-start latency; chưa tuyên bố số mili-giây.
- **Tái hiện/đo:** Android Macrobenchmark `StartupTimingMetric` + Perfetto trước/sau lazy init trong profile/release build.
- **Giải pháp:** lazy-init ở method downloader đầu tiên, cache một shared init future/deferred để chống init trùng.
- **Rủi ro khi sửa:** đồng bộ coroutine và truyền init failure nhất quán về Dart.
- **Effort:** M.

### UI-01 — Permission/scanner failure vẫn được hiển thị như scan thành công

- **Nhóm:** Error recovery / permission UX
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/providers/music_provider.dart:91-134`; `lib/screens/onboarding_screen.dart:87-125`.
- **Bằng chứng:** provider có `permissionDenied` và `error`; onboarding không đọc status, luôn đặt `_scanDone = true`, hiện số lượng và redirect Home.
- **Tác động:** deny permission/exception biến thành “0 bài” thành công, không retry/Open Settings/rationale.
- **Tái hiện/đo:** deny một lần, deny permanently và inject scanner exception; quan sát screen/result/navigation.
- **Giải pháp:** render theo `LibraryStatus`; chỉ success/redirect khi `done`; thêm retry và CTA Settings cho permanently denied.
- **Rủi ro khi sửa:** permission lifecycle và tránh prompt lặp.
- **Effort:** M.

### UI-02 — Text scale accessibility bị chặn toàn app ở 115%

- **Nhóm:** Accessibility / typography
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/main.dart:82-88`.
- **Bằng chứng:** root `MediaQuery` clamp `maxScaleFactor: 1.15` cho mọi screen.
- **Tác động:** người dùng cấu hình font lớn không nhận scale hệ thống đầy đủ.
- **Tái hiện/đo:** Android Font size lớn nhất; widget/golden ở scale 1.0/1.3/2.0; chạy accessibility guideline.
- **Giải pháp:** sửa layout chịu text scale rồi bỏ clamp; nếu một widget đặc biệt cần bảo vệ thì giới hạn cục bộ và có semantics đầy đủ.
- **Rủi ro khi sửa:** sẽ lộ overflow hiện có, nhất là Now Playing và control hàng ngang.
- **Effort:** M.

### UI-03 — Light theme có text/icon trắng trên nền sáng và downloader dùng palette dark riêng

- **Nhóm:** Theme / design consistency
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/theme/app_colors_data.dart:492-512`; `lib/screens/welcome_screen.dart:96-103`; `lib/screens/library_screen.dart:450-459`; `lib/main.dart:31-38`; `lib/features/downloader/core/theme/app_colors.dart:17-28`.
- **Bằng chứng:** light background là `#F8F7FC`, nhưng Welcome title hardcode white; Library popup lấy static white `AppColors.textPrimary` trên light card; status icons root hardcode `Brightness.light`; downloader không dùng ThemeExtension của app.
- **Tác động:** nội dung/icon có thể biến mất trong light mode; chuyển feature tạo visual system khác.
- **Tái hiện/đo:** golden/manual tour Welcome, Home status bar, Library popup và toàn downloader trên dark/AMOLED/light.
- **Giải pháp:** dùng ThemeExtension/ColorScheme tại context; đồng bộ system overlay theo brightness; thêm golden ba preset.
- **Rủi ro khi sửa:** migrate downloader palette là thay đổi diện rộng, nên làm theo component.
- **Effort:** L.

### UI-04 — Playback/navigation controls thiếu semantics và trạng thái

- **Nhóm:** Accessibility semantics
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/screens/home_screen.dart:328-377`; `lib/widgets/mini_player.dart:302-341,394-403`; `lib/screens/now_playing_screen.dart:1910-1950,1992-2031,2077-2091`.
- **Bằng chứng:** nhiều `GestureDetector` bọc icon-only control không `Semantics`, `semanticLabel` hoặc `Tooltip`; bottom-nav inactive không có text label; shuffle/repeat/favorite không công bố selected/toggled.
- **Tác động:** TalkBack có thể bỏ qua hoặc đọc control không tên, người dùng không biết trạng thái.
- **Tái hiện/đo:** Semantics Debugger và TalkBack traversal Home → MiniPlayer → NowPlaying.
- **Giải pháp:** ưu tiên `NavigationBar`/`IconButton` có tooltip; hoặc bọc `Semantics(button: true, label, selected/toggled)`.
- **Rủi ro khi sửa:** thấp; cần tránh semantics trùng ở child icon/text.
- **Effort:** M.

### SEC-01 — Android release đang dùng debug signing key

- **Nhóm:** Release security
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `android/app/build.gradle.kts:46-51`.
- **Bằng chứng:** `release { signingConfig = signingConfigs.getByName("debug") }` cùng TODO release key.
- **Tác động:** artifact release không có quy trình khóa phát hành riêng; không phù hợp để publish/update an toàn.
- **Tái hiện/đo:** build release trong CI staging và chạy `apksigner verify --print-certs`, so fingerprint với debug keystore.
- **Giải pháp:** release signing từ CI secret/local untracked properties; fail release build nếu credential thiếu; lưu/backup key theo quy trình.
- **Rủi ro khi sửa:** mất/đổi key làm mất khả năng update app đã phát hành; cần chốt key ownership trước publish.
- **Effort:** S/M.

### PERF-01 — PlayerProvider không sở hữu đầy đủ timer/subscription/audio lifecycle

- **Nhóm:** Memory/resource lifecycle
- **Mức độ:** High
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/providers/player_provider.dart:67-85,99-123,406-410`; `lib/services/audio_handler.dart:8-120`.
- **Bằng chứng:** countdown `Timer.periodic` không giữ handle; set timer mới chỉ cancel one-shot nên periodic cũ tiếp tục với `_sleepEndTime` mới. Dispose chỉ cancel one-shot và không null end time. Ba stream `.listen()` không lưu subscription; wrapper không expose `AudioPlayer.dispose()`.
- **Tác động:** nhiều notify/giây sau khi reset timer; callback có thể chạy sau dispose và giữ resource lâu hơn vòng đời.
- **Tái hiện/đo:** fake-async set sleep timer nhiều lần rồi dispose, đếm notify/timer; DevTools retaining path và listener count.
- **Giải pháp:** field `_countdownTimer`; cancel/null trong set/cancel/dispose; lưu/cancel subscription; xác định owner của handler trước khi dispose AudioPlayer.
- **Rủi ro khi sửa:** không dispose handler nếu background playback phải sống lâu hơn provider.
- **Effort:** S/M.

### STATE-01 — Analyze result cũ vẫn gắn với URL mới và request không có revision guard

- **Nhóm:** Async state / duplicate submission
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/features/downloader/providers/analyze_provider.dart:34-90`; `lib/features/downloader/screens/analyze/analyze_screen.dart:176-215`.
- **Bằng chứng:** `onUrlChanged` chỉ đổi URL/platform, giữ `status/videoInfo`; success card cũ tiếp tục hiện. Hai analyze request không có generation/request ID nên response chậm hơn có thể overwrite request mới. `copyWith` dùng `??`, nên truyền null không clear nullable field.
- **Tác động:** URL field B có thể đi cùng video/format A; lỗi cũ/result cũ giữ trong state.
- **Tái hiện/đo:** analyze A, sửa thành B chưa submit; hoặc submit A/B với latency đảo ngược.
- **Giải pháp:** reset result khi URL thay đổi; disable duplicate submit; request revision token/cancellable operation; dùng sentinel cho nullable `copyWith`.
- **Rủi ro khi sửa:** card biến mất ngay khi user chỉnh typo; cần product behavior rõ.
- **Effort:** S/M.

### PERF-02 — Watch quá rộng làm rebuild màn hình/list theo state không liên quan

- **Nhóm:** Widget rebuild
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed về rebuild scope; mức jank chưa đo
- **File/vị trí:** `lib/widgets/music_list_tile.dart:38-39`; `lib/screens/library_screen.dart:219,892-899`; `lib/screens/album_detail_screen.dart:24-25`; `artist_detail_screen.dart:25-26`; `playlist_screen.dart:340-341`; `now_playing_screen.dart:168,186`.
- **Bằng chứng:** mỗi visible tile watch toàn `MusicProvider`; các root/detail watch cả Music và Player. Sleep countdown notify mỗi giây, favorite/search/scan notify toàn provider.
- **Tác động:** subtree lớn và nhiều tile rebuild dù chỉ một scalar đổi; khả năng jank tăng theo số item hiển thị.
- **Tái hiện/đo:** DevTools Track Widget Rebuilds khi toggle favorite, play/pause, search và bật sleep timer.
- **Giải pháp:** `context.select`/`Selector` theo record/scalar; `read` cho callback-only; tách current song/favorite/countdown consumer.
- **Rủi ro khi sửa:** selector thiếu field làm UI stale; cần widget tests.
- **Effort:** M.

### PERF-03 — Search/sort/smart lists và JSON storage được tính lại trên UI isolate

- **Nhóm:** CPU/allocation
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed về thuật toán; tác động theo library size chưa đo
- **File/vị trí:** `lib/providers/music_provider.dart:42-70,139-175,179`; `lib/screens/home_screen.dart:103-105,467-469,512-539,724-727`; `lib/screens/library_screen.dart:873-899`; `lib/services/storage_service.dart:48-82,129-167`; `lib/widgets/music_list_tile.dart:38-39`.
- **Bằng chứng:** mỗi phím notify ngay, filter toàn list và lowercase ba field; Library copy/sort O(N log N); smart getter copy/sort/shuffle mỗi build. `isFavorite` trong mỗi tile lại `jsonDecode` và tạo Set từ SharedPreferences string.
- **Tác động:** CPU/GC tăng theo N; Random Mix đổi ngoài ý muốn khi một notify không liên quan xảy ra.
- **Tái hiện/đo:** profile 1k/5k/10k bài; CPU sample `jsonDecode`, allocation và frame chart khi type/toggle favorite/play.
- **Giải pháp:** debounce 120–200 ms; cache normalized fields; memoize derived list theo `(query, sort, libraryRevision)`; hydrate typed collections một lần và persist từ cache.
- **Rủi ro khi sửa:** cache phải invalidate khi scan/sửa metadata; debounce tạo trễ nhỏ.
- **Effort:** M.

### PERF-04 — Scan lặp permission và deep `scanMedia` ở mọi refresh

- **Nhóm:** Platform I/O
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/providers/music_provider.dart:91-125`; `lib/services/music_scanner.dart:13-38,50-69,81-98`.
- **Bằng chứng:** provider gọi `requestPermission`, rồi `scanSongs` gọi lại; Android luôn `scanMedia('/storage/emulated/0')` trước `querySongs`. Group/filter/map là async signature nhưng vẫn chạy UI isolate.
- **Tác động:** platform call lặp và deep media scan có thể gây I/O đáng kể ở cold start/pull refresh; chưa đo latency thiết bị.
- **Tái hiện/đo:** timestamp permission/scanMedia/query/postprocess; Perfetto MediaProvider/I/O với library nhỏ/lớn.
- **Giải pháp:** một owner permission; refresh thường chỉ query MediaStore; deep rescan là action riêng hoặc scan file vừa download; gộp postprocess pass.
- **Rủi ro khi sửa:** file ngoài app có thể chưa xuất hiện ngay; giữ manual deep-rescan.
- **Effort:** M.

### PERF-05 — Download progress tick rebuild toàn danh sách task

- **Nhóm:** Riverpod rebuild
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/features/downloader/screens/download/download_screen.dart:49-100`; `providers/download_provider.dart:405-418`; `services/ytdlp_service.dart:165-188`.
- **Bằng chứng:** root screen watch toàn `DownloadState`; mỗi poll tạo list/state mới và rebuild stats + visible list, kể cả progress không đổi.
- **Tác động:** với nhiều task, update của một task rebuild mọi card theo nhịp 600 ms.
- **Tái hiện/đo:** Track Widget Rebuilds/frame chart với 1/5/10 task.
- **Giải pháp:** parent watch IDs/aggregate; card select đúng tuple field; suppress identical progress event. Sửa equality trước vì `DownloadTask ==` hiện chỉ so ID (`download_task.dart:145-150`).
- **Rủi ro khi sửa:** equality/selector sai có thể chặn update hợp lệ.
- **Effort:** M.

### PERF-06 — Lyrics path tạo work theo position stream và rebuild root theo line

- **Nhóm:** High-frequency stream
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed về code; tác động frame chưa đo
- **File/vị trí:** `lib/services/audio_handler.dart:107-113`; `lib/screens/now_playing_screen.dart:186,491-503,1811-1813`; `lib/providers/lyrics_provider.dart:119-143`.
- **Bằng chứng:** `positionDataStream` getter tạo combineLatest; mỗi event schedule post-frame, tìm active line tuyến tính từ đầu; khi index đổi, root NowPlaying đang watch `LyricsProvider` rebuild.
- **Tác động:** stream subscription/work dư khi lyrics synced; tăng theo số line/tần suất emission.
- **Tái hiện/đo:** CPU/rebuild trace khi mở lyrics; đếm emission, callback và list/root build.
- **Giải pháp:** share/replay một position stream; map + `distinct` theo line index; binary search/forward cursor; thu hẹp consumer tới line cần đổi.
- **Rủi ro khi sửa:** throttle quá mạnh làm highlight/scroll trễ.
- **Effort:** M.

### PERF-07 — Bulk hide parse/ghi toàn bộ hidden map N lần

- **Nhóm:** Storage write amplification
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/providers/music_provider.dart:273-280`; `lib/services/storage_service.dart:158-180`.
- **Bằng chứng:** bulk loop `await hideSong` từng bài; mỗi call decode toàn map, thêm một item, encode và `setString` lại.
- **Tác động:** N persistent writes và tổng parse/serialize gần bậc hai theo batch/payload.
- **Tái hiện/đo:** đếm `setString`, elapsed và bytes với batch 10/100/500 bài.
- **Giải pháp:** `hideSongs` parse/update một lần và persist một lần, trả success/failure typed.
- **Rủi ro khi sửa:** single write failure ảnh hưởng cả batch; cần rollback/in-memory consistency.
- **Effort:** S.

### DATA-01 — Play history/count nằm ngoài luồng chuyển bài

- **Nhóm:** Data consistency
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/providers/music_provider.dart:228-231`; `lib/providers/player_provider.dart:99-123`; caller rải rác tại `home_screen.dart:187-190`, `album_detail_screen.dart:215-218`, `library_screen.dart:1211-1214`, `playlist_screen.dart:383-417`.
- **Bằng chứng:** mỗi screen phải nhớ gọi `onSongPlayed`; auto-next/currentIndex trong PlayerProvider không báo MusicProvider, và một số đường play-all/shuffle/folder không track.
- **Tác động:** Recently Played/Most Played sai, auto-next không tăng count.
- **Tái hiện/đo:** play từ folder/playlist/shuffle và chờ auto-next, restart rồi kiểm tra smart list/count.
- **Giải pháp:** centralize track-change event sau engine xác nhận index; một coordinator ghi history có dedupe; bỏ manual calls dần.
- **Rủi ro khi sửa:** double-count trong giai đoạn chuyển đổi.
- **Effort:** M.

### DATA-02 — Playlist persist full SongItem snapshot, dễ stale và write lớn

- **Nhóm:** Persistence model
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/models/playlist_item.dart:3-17,39-59`; `lib/services/storage_service.dart:98-125`; `lib/providers/music_provider.dart:78-84,188-223,251-258`.
- **Bằng chứng:** mỗi playlist serialize toàn bộ song gồm absolute path; scan/update metadata tạo `_allSongs` mới nhưng playlist không reconcile; mutation persist toàn object graph.
- **Tác động:** title/path playlist stale, bài đã di chuyển/xóa còn tồn tại; JSON startup/write tăng theo tổng entry.
- **Tái hiện/đo:** thêm bài, sửa metadata/di chuyển file, rescan/restart; đo payload và encode/decode với 100/1k/5k entry.
- **Giải pháp:** trước mắt reconcile snapshot theo ID; hướng bền vững lưu playlist metadata + song IDs với schema version/migration.
- **Rủi ro khi sửa:** cần chính sách cho bài không còn trong library và migration rollback.
- **Effort:** M/L.

### ERR-01 — Exception/corrupt storage bị nuốt hoặc mất cause

- **Nhóm:** Reliability / observability
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/providers/music_provider.dart:104-134`; `lib/services/music_scanner.dart:56-61`; `lib/services/storage_service.dart:32-82,100-125,129-167`; `lib/providers/lyrics_provider.dart:91-112`; `download_provider.dart:256-270`.
- **Bằng chứng:** scan chỉ đặt generic `error`; scanMedia catch rỗng; playlist corrupt trả `[]`; save playlist swallow lỗi; lyrics bỏ `errorMessage`; download đổi mọi stream error thành `Stream error`. Nhiều getter SharedPreferences khác cast/decode không try/catch nên corrupt value có thể crash.
- **Tác động:** UI không phân biệt empty/corrupt/failure; mutation có vẻ thành công nhưng mất sau restart; khó support.
- **Tái hiện/đo:** inject invalid JSON/PlatformException/write failure và assert state/user message/debug cause.
- **Giải pháp:** typed failure `{category, safeMessage, debugCause}`; validate/migrate storage; persistence trả result và giữ last-known-good/backup khi phù hợp.
- **Rủi ro khi sửa:** không lộ raw exception/path/data nhạy cảm ra UI.
- **Effort:** M.

### UI-05 — Nhiều touch target nhỏ hơn 48 dp

- **Nhóm:** Accessibility / interaction
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/widgets/mini_player.dart:140-162,261-280,302-341,394-403`; `now_playing_screen.dart:1910-1950,2077-2091,2210-2220`; `features/downloader/widgets/primary_icon_button.dart:17-31`.
- **Bằng chứng:** play 36×36, prev/next khoảng 34, close 40, shuffle/repeat khoảng 40, queue remove khoảng 26, downloader icon default 44.
- **Tác động:** khó bấm trên màn nhỏ/di chuyển và với motor impairment.
- **Tái hiện/đo:** widget test `tester.getSize`, tap mép; Flutter accessibility guideline.
- **Giải pháp:** `ConstrainedBox` min 48 hoặc `IconButton`, giữ icon visual nhỏ nhưng mở hit area.
- **Rủi ro khi sửa:** spacing control row có thể cần điều chỉnh.
- **Effort:** S/M.

### UI-06 — `textDisabled` được dùng cho text thường với contrast thấp

- **Nhóm:** Color contrast
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/theme/app_colors_data.dart:341-350,503-512`; `home_screen.dart:406-430`; `library_screen.dart:319-324,378-383`; `onboarding_screen.dart:243-249`.
- **Bằng chứng:** token composite đo khoảng 2,71:1 ở dark surface và 2,02–2,12:1 ở light, nhưng dùng cho placeholder/info 11–15sp. Screenshot dark cũng cho thấy metadata/hint rất mờ.
- **Tác động:** không đạt ngưỡng 4,5:1 cho normal text.
- **Tái hiện/đo:** contrast audit trên ba preset và golden screenshot.
- **Giải pháp:** tách `textMuted/textPlaceholder` đạt contrast; giữ `textDisabled` cho control thật sự disabled/decorative.
- **Rủi ro khi sửa:** thấp, chủ yếu thay đổi visual emphasis.
- **Effort:** S.

### UI-07 — Now Playing có nguy cơ overflow trên màn hình thấp/text scale lớn

- **Nhóm:** Responsive
- **Mức độ:** Medium
- **Độ tin cậy:** Likely
- **File/vị trí:** `lib/screens/now_playing_screen.dart:214-266,373-393,595-597`; `lib/main.dart:26-29,82-88`.
- **Bằng chứng:** artwork theo `width * 0.70`, tiếp theo nhiều spacing/control cố định trong Column không scroll; app khóa portrait. Clamp text hiện đang che bớt overflow.
- **Tác động:** Dự kiến RenderFlex overflow ở 320×568/split-screen hoặc sau khi hỗ trợ text scale đúng; tablet có artwork quá lớn.
- **Tái hiện/đo:** render 320×568, 360×640, tablet, scale 1.15/1.3/2.0; bắt overflow log/golden.
- **Giải pháp:** LayoutBuilder tính theo cả width/height budget; flexible spacing và fallback scroll.
- **Rủi ro khi sửa:** gesture/flip/queue layout cần regression.
- **Effort:** M.

### UI-08 — Library search/sort hiển thị ở mọi tab nhưng chỉ tác động Songs

- **Nhóm:** UX consistency
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/screens/library_screen.dart:280-290,312-423,895-899,965-967,1065-1068,1158-1169`.
- **Bằng chứng:** search/sort control luôn hiện; chỉ Songs dùng query/sort, Album/Artist/Folder không đổi.
- **Tác động:** user thao tác mà không có kết quả/feedback trên bốn tab khác.
- **Tái hiện/đo:** ở từng tab, tìm item duy nhất và đổi sort.
- **Giải pháp:** lọc/sort theo tab hoặc chỉ hiện control trên tab Songs và ghi rõ scope.
- **Rủi ro khi sửa:** thấp đến trung bình tùy chọn product.
- **Effort:** M.

### SEC-02 — App yêu cầu all-files access và thao tác path shared storage trực tiếp

- **Nhóm:** Client security / privacy / platform policy
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed về cấu hình; policy impact cần xác nhận theo kênh phát hành
- **File/vị trí:** `android/app/src/main/AndroidManifest.xml:10-22,32-36`; `lib/features/downloader/services/downloader_storage_service.dart:110-145`; `android/app/src/main/res/xml/file_paths.xml:1-6`.
- **Bằng chứng:** manifest khai báo `MANAGE_EXTERNAL_STORAGE`; service chủ động request `manageExternalStorage` trên API 30+; FileProvider cho phép root external path `.` dù provider không exported.
- **Tác động:** quyền truy cập shared storage rộng hơn nhu cầu media/download thông thường, tăng blast radius và rủi ro bị từ chối bởi store/privacy review.
- **Tái hiện/đo:** kiểm tra permission screen/dumpsys trên API 30–35; rà kênh phát hành và manual test SAF/MediaStore.
- **Giải pháp:** ưu tiên MediaStore/SAF + persistable URI/app-specific directory; chỉ giữ all-files access nếu use case/kênh phân phối đáp ứng điều kiện rõ ràng.
- **Rủi ro khi sửa:** Python/yt-dlp hiện dùng absolute path, nên SAF URI cần bridge/copy strategy và migration đường dẫn đã lưu.
- **Effort:** L.

### SEC-03 — Production logs chứa URL, path, filename và lyrics response

- **Nhóm:** Privacy / logging
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/services/lyrics_service.dart:83-100,164-193`; `android/app/src/main/python/ytdlp_bridge.py:140-177,199-277`.
- **Bằng chứng:** Dart log title/artist, cache path, full GET query và tối đa 500 ký tự response; Python print URL, format, output path, filename, directory listing và bật yt-dlp verbose.
- **Tác động:** metadata nghe/tải và filesystem path có thể đi vào logcat/crash report/support log.
- **Tái hiện/đo:** release/profile build, chạy lyric/download rồi thu logcat; tìm URL/title/path.
- **Giải pháp:** structured logger có level/build guard; redact query/path; không log response body; yt-dlp `quiet/no_warnings` trong release.
- **Rủi ro khi sửa:** giảm dữ liệu chẩn đoán; giữ error category/correlation ID không chứa PII.
- **Effort:** S.

### TEST-01 — Flow rủi ro cao không có seam hoặc regression test

- **Nhóm:** Testability / maintainability
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/providers/music_provider.dart:9-12`; `lyrics_provider.dart:50-53`; `features/downloader/providers/analyze_provider.dart:69-76`; `download_provider.dart:194-197,307-309`; `test/widget_test.dart:1-7`.
- **Bằng chứng:** service được new/singleton trực tiếp nên khó override; test duy nhất không import app và chỉ assert `true`.
- **Tác động:** queue, cancel, stale response, corrupt storage, permission và lifecycle không có regression coverage; analyzer không phát hiện các lỗi này.
- **Tái hiện/đo:** inventory test name/import/coverage; mutation đơn giản ở queue sẽ không làm suite fail.
- **Giải pháp:** dependency seam nhỏ: optional constructor cho ChangeNotifier, Riverpod service provider override, fake audio/downloader/storage; thêm unit/widget/integration test theo Top 10.
- **Rủi ro khi sửa:** tránh tạo abstraction cho mọi class; chỉ seam ở external I/O và orchestration.
- **Effort:** M.

### PERF-08 — Thumbnail nhỏ chưa giới hạn decode/cache dimensions

- **Nhóm:** Image memory
- **Mức độ:** Medium
- **Độ tin cậy:** Likely
- **File/vị trí:** `lib/features/downloader/screens/download/download_screen.dart:334-340`; `format/format_screen.dart:1199-1204`; `playlist_picker/playlist_picker_screen.dart:362-369`; `lib/screens/playlist_screen.dart:154-162`.
- **Bằng chứng:** ảnh hiển thị 52–80 logical px nhưng `CachedNetworkImage` không có mem cache dimension và `Image.file` không có `cacheWidth/cacheHeight`. Kích thước ảnh nguồn thực tế chưa được đo.
- **Tác động:** Dự kiến decode/cache nhiều pixel hơn cần thiết khi thumbnail nguồn lớn và list dài.
- **Tái hiện/đo:** DevTools Memory/Image Cache với 720p/1080p thumbnail và DPR 1/2/3.
- **Giải pháp:** set decode dimensions theo logical size × DPR, có upper bound; giữ disk/original khi cần full preview.
- **Rủi ro khi sửa:** dimension quá thấp làm ảnh mờ trên DPR cao.
- **Effort:** S.

### UI-09 — Downloader init error không retry; playlist success rỗng không có empty state

- **Nhóm:** Error/empty state
- **Mức độ:** Medium
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `lib/features/downloader/screens/analyze/analyze_screen.dart:48-55,189-205,845-885`; `playlist_picker/playlist_picker_screen.dart:183-205,276-295`.
- **Bằng chứng:** `_initError` chỉ hiện card, button giữ loading/disabled và card không action. Playlist success với zero/search miss chỉ render `ListView` rỗng + CTA disabled.
- **Tác động:** lỗi tạm thời buộc vào lại screen; vùng trắng không giải thích playlist rỗng hay search miss.
- **Tái hiện/đo:** mock init fail-once; playlist zero entry; query không match.
- **Giải pháp:** Retry reset/init lại; empty state phân biệt source empty/search empty với Clear/Back/Retry.
- **Rủi ro khi sửa:** thấp; guard submit/retry trùng.
- **Effort:** S.

### UI-10 — Network badge overlay có thể chồng AppBar action

- **Nhóm:** Layout / hit testing
- **Mức độ:** Medium
- **Độ tin cậy:** Likely
- **File/vị trí:** `lib/features/downloader/widgets/app_shell.dart:45-61`; `screens/download/download_screen.dart:63-81`.
- **Bằng chứng:** badge `Positioned` top-right với SafeArea minimum top 52/right 24, đúng vùng AppBar “Xóa xong”; badge không `IgnorePointer`.
- **Tác động:** Dự kiến che/chặn action tùy kích thước badge/text.
- **Tái hiện/đo:** screenshot + hit-test DownloadScreen khi có finished task ở Online/Offline và text scale lớn.
- **Giải pháp:** reserve badge trong AppBar/layout; nếu chỉ hiển thị thì `IgnorePointer`.
- **Rủi ro khi sửa:** thấp.
- **Effort:** S.

### MAINT-01 — Baseline format lệch và code comment/dead branch dày

- **Nhóm:** Maintainability
- **Mức độ:** Low
- **Độ tin cậy:** Confirmed
- **File/vị trí:** formatter báo 24/65 file; ví dụ comment/dead implementation ở `download_provider.dart:182-397`, `app_shell.dart:21-42`, `download_screen.dart:52-61`.
- **Bằng chứng:** `dart format --output=none --set-exit-if-changed .` exit 1; nhiều implementation cũ comment dài làm code active khó đọc.
- **Tác động:** review/diff noise và tăng chi phí hiểu logic; không phải lỗi runtime.
- **Tái hiện/đo:** format check trong CI và code review active/comment ratio.
- **Giải pháp:** một commit mechanical format riêng; xóa code đã nằm trong Git; giữ comment giải thích “why”, không giữ implementation cũ.
- **Rủi ro khi sửa:** conflict với nhánh đang phát triển; tách commit và không trộn functional change.
- **Effort:** S.

### LOW-01 — Các UX/accessibility polish còn thiếu

- **Nhóm:** Optional UX polish
- **Mức độ:** Low
- **Độ tin cậy:** Confirmed cho form/content; Likely cho reduce motion
- **File/vị trí:** `online_screen.dart:120-127` + `profile_screen.dart:100-111` (feature availability mâu thuẫn); `playlist_screen.dart:265-317,674-728`, `add_to_playlist_sheet.dart:264-335`, `analyze_screen.dart:611-635` (validation/keyboard); `splash_screen.dart:56-63`, `onboarding_screen.dart:63-82`, `now_playing_screen.dart:47-66` (animation); `main.dart:69`, `welcome_screen.dart:96-103`, `profile_screen.dart:166-172,491-497` (brand/locale).
- **Bằng chứng:** Online báo downloader “Sớm” nhưng Profile mở được; whitespace submit im lặng và URL `TextInputAction.go` không `onSubmitted`; không tìm thấy `disableAnimations/accessibleNavigation`; brand/locale dùng nhiều tên và trộn “Home”/tiếng Việt.
- **Tác động:** discoverability/feedback/motion preference và cảm giác hoàn thiện chưa nhất quán.
- **Tái hiện/đo:** user journey Online/Profile; submit whitespace/Go; bật Remove animations; content inventory.
- **Giải pháp:** một source-of-truth feature flag/strings; inline validation; shared MotionSpec respect reduce motion; thống nhất brand/localization.
- **Rủi ro khi sửa:** thấp đến trung bình ở animation/navigation timing.
- **Effort:** S cho content/form, M cho motion/localization.

### PERF-09 — Eager list/controller hygiene còn một số điểm nhỏ

- **Nhóm:** Optional performance hygiene
- **Mức độ:** Low
- **Độ tin cậy:** Confirmed
- **File/vị trí:** `format_screen.dart:392-458`; `add_to_playlist_sheet.dart:178-243`; `playlist_picker_screen.dart:28-38`; dialog controller tại `add_to_playlist_sheet.dart:264-267`, `playlist_screen.dart:265-268,674-681`.
- **Bằng chứng:** format dùng `ListView(children: map.toList())`; shrinkWrap trong `Flexible` đã bounded; một số TextEditingController screen/dialog không dispose rõ ràng.
- **Tác động:** eager widget/layout work và resource nhỏ tích lũy; không phải bottleneck đã đo.
- **Tái hiện/đo:** nhiều formats/playlists, loop mở/đóng route/dialog và memory diff.
- **Giải pháp:** builder/separated, bỏ shrinkWrap không cần, dispose controller sau dialog/ở State.
- **Rủi ro khi sửa:** thấp.
- **Effort:** S.

### Điểm tích cực và kiểm tra không phát hiện vấn đề rộng

- `LyricsProvider` có song-ID stale-result guard (`lib/providers/lyrics_provider.dart:88-89`), Lyrics API có timeout và positive file cache.
- Danh sách lớn chính phần lớn dùng builder/sliver; không thấy `shrinkWrap`/nested-scroll đắt đỏ lan rộng.
- Phần lớn screen-level Animation/Tab/Scroll/Text controller có dispose; các thiếu sót cụ thể đã nêu ở finding.
- Không tìm thấy API key/token/password hardcode, SSL validation bypass hoặc service giữ `BuildContext` dài hạn bằng phép tìm source.
- Không thấy circular import được xác nhận. `SongItem` và `DownloadTask` phần lớn immutable.
- Dùng song song Provider và Riverpod theo ranh giới feature không tự thân là lỗi.

## 4. Top 10 ưu tiên

Điểm dưới đây chỉ dùng để triage tương đối, không phải metric runtime: `Impact (1–5) × Frequency (1–5) × Confidence (Confirmed=1; tác động Likely=0,8) ÷ Effort (S=1, M=2, L=3; khoảng giữa dùng 1,5/2,5)`.

| # | Finding | I | F | C | E | Điểm | Lý do ưu tiên |
|---:|---|---:|---:|---:|---:|---:|---|
| 1 | DL-01 duplicate batch task | 5 | 4 | 1,0 | 1 | 20,0 | Có thể tải trùng/collision ngay ở batch; fix containment nhỏ |
| 2 | DL-02 progress global + concurrency 10 | 4 | 4 | 1,0 | 1 | 16,0 | State sai theo thiết kế với từ 2 task; mitigation concurrency 1 rất nhỏ |
| 3 | START-01 forced splash + cold full scan | 4 | 5 | 1,0 | 2 | 10,0 | Kích hoạt mọi cold start sau first-run |
| 4 | UI-04 controls thiếu semantics | 4 | 5 | 1,0 | 2 | 10,0 | Ảnh hưởng toàn bộ core navigation/playback cho screen reader |
| 5 | START-02 eager Python init | 4 | 5 | 0,8 | 2 | 8,0 | Nằm trên mọi Android start dù feature không dùng; cần benchmark trước/sau |
| 6 | PLAY-01 queue UI/engine lệch | 5 | 3 | 1,0 | 2 | 7,5 | Có thể phát sai bài so với metadata hiển thị |
| 7 | SEC-01 debug release signing | 5 | 2 | 1,0 | 1,5 | Chặn quy trình phát hành/update an toàn |
| 8 | DL-03 cancel giả | 5 | 3 | 1,0 | 2,5 | Tốn network/storage sau khi UI báo hủy; cần native protocol |
| 9 | LIFE-01 scope/singleton lifecycle | 4 | 3 | 1,0 | 2 | 6,0 | Downloader lần hai/download khi thoát có thể hỏng/orphan |
| 10 | UI-02 global text-scale cap | 4 | 3 | 1,0 | 2 | 6,0 | Accessibility setting bị vô hiệu hóa trên toàn app |

Ngay sau Top 10: UI-01 false-success permission (4,0), UI-03 light theme (4,0), PERF-01 player lifecycle (khoảng 5,3 nhưng trigger ít hơn), STATE-01 stale analyze (4,0). Khi lập sprint thực tế, có thể ghép các finding cùng file để giảm context switching, nhưng không hạ ưu tiên correctness chỉ vì một UI quick win dễ hơn.

## 5. Kế hoạch refactor theo phase

### Phase 0 — Measurement và regression harness

- **Phạm vi:** thêm fake seam cho audio/downloader/storage; test tái hiện DL-01/02/03, PLAY-01, LIFE-01, STATE-01; timestamp startup; không đổi behavior.
- **Tiêu chí hoàn thành:** test hiện đỏ với bug và xanh với fixture đúng; lưu profile baseline cold start, scan, 1/2/10 download, search 1k/5k song.
- **Xác nhận:** `flutter analyze` qua batch, unit/widget test, Android profile trace/Macrobenchmark trên một thiết bị chuẩn.
- **Rollback:** revert riêng commit test seam/instrumentation; không thay data schema.

### Phase 1 — Downloader containment (không đổi native protocol)

- **Phạm vi:** reserve task đồng bộ + duplicate guard; batch process một lần; đặt concurrency = 1; suppress progress không đổi; dùng root ProviderScope và sửa NetworkService ownership. Nếu cancel native chưa có, UI phải ghi đúng là không thể hủy thật hoặc chờ Phase 2.
- **Tiêu chí hoàn thành:** mỗi task đúng một native call; progress card không cross-wire; mở/đóng downloader nhiều lần không lỗi; state download không mất ngoài ý muốn.
- **Xác nhận:** automated queue test; manual 20-entry playlist; open/close/airplane-mode loop; network/file observation.
- **Rollback:** feature flag/constant concurrency và các commit nhỏ theo guard/scope; không migrate model.

### Phase 2 — Task-scoped progress và cancellation xuyên native

- **Phạm vi:** task ID Dart → Kotlin → Python; keyed progress/event; cooperative cancel + partial-file cleanup/ACK.
- **Tiêu chí hoàn thành:** hai task độc lập về progress; cancel dừng traffic/file growth trong timeout đã định; task state phản ánh ACK thật.
- **Xác nhận:** integration test MethodChannel fake + Android device test 2 task tốc độ khác nhau, cancel ở download/merge; log không chứa PII.
- **Rollback:** giữ adapter protocol cũ sau flag và fallback concurrency 1 cho một release; migration không liên quan persisted data.

### Phase 3 — Playback correctness và lifecycle

- **Phạm vi:** engine API remove/move; atomic queue state; owner/dispose subscriptions/timers/audio handler; central track-change history.
- **Tiêu chí hoàn thành:** queue A/B/C reorder/remove/skip luôn khớp audio-metadata; timer reset/dispose không còn callback; history track mọi entry/auto-next đúng một lần.
- **Xác nhận:** fake audio unit test, widget queue test, manual background playback/headset/notification controls.
- **Rollback:** tách commit queue engine khỏi history/lifecycle; giữ old queue UI sau flag nếu native regression.

### Phase 4 — Startup, scan và derived library state

- **Phạm vi:** lazy Python; parallel/minimum splash; query MediaStore thay deep scan mặc định; one-owner permission; hydrate/cache SharedPreferences typed state; debounce/memoize search/sort/smart lists; batch storage writes.
- **Tiêu chí hoàn thành:** không còn fixed 4,6 s; downloader code không init khi không dùng; refresh thường không deep-scan; output search/smart list không đổi ngoài chủ ý.
- **Xác nhận:** Macrobenchmark/Perfetto trước-sau; library 1k/5k/10k; storage corruption/write-failure tests; cold/warm app tests.
- **Rollback:** feature flag lazy init/background scan; giữ manual deep scan; không xóa schema cũ trong cùng release.

### Phase 5 — Error states, accessibility và theme

- **Phạm vi:** LibraryStatus UI + retry/settings; bỏ root text clamp sau responsive fixes; semantics/touch target; contrast token; light/AMOLED theme; downloader retry/empty/layout.
- **Tiêu chí hoàn thành:** deny/error không báo success; TalkBack core journey đủ tên/trạng thái; target ≥48 dp; normal text đạt contrast; golden không overflow ở scale 1.0/1.3/2.0 và screen nhỏ.
- **Xác nhận:** widget/golden/accessibility guideline; manual TalkBack, Remove animations, keyboard, dark/AMOLED/light, 320×568/tablet.
- **Rollback:** chia theo component/token; có thể revert theme token/golden riêng, không re-enable global accessibility clamp như fix lâu dài.

### Phase 6 — Persistence, release hardening và maintenance

- **Phạm vi:** release signing/CI gate; redact logs; quyết định scoped storage; playlist ID schema + migration nếu số đo chứng minh cần; format/dead code cleanup; nâng test coverage.
- **Tiêu chí hoàn thành:** release cert đúng key quản lý; log không chứa URL/path/body; permission tối thiểu theo distribution; migration có version/backup; CI format/analyze/test xanh.
- **Xác nhận:** `apksigner`, release logcat audit, API 24/29/30/33/35 storage matrix, migration fixtures và rollback test.
- **Rollback:** dual-read old/new schema tối thiểu một release; signing key không đổi sau publish; storage migration có backup/version flag.

## 6. Quick wins ít rủi ro

1. Reserve task sang `preparing` và guard `_subs.containsKey` trước `_startDownload`; test số native call.
2. Tạm đặt downloader concurrency = 1 cho đến khi progress/cancel task-scoped; test hai item tuần tự.
3. Reset analyze result khi URL đổi và thêm request revision guard; test response đảo thứ tự.
4. Giữ handle/cancel countdown timer + stream subscriptions trong `PlayerProvider`; fake-async test dispose.
5. Thêm Retry cho downloader init và empty/search-empty cho playlist picker.
6. Mở hit area ≥48 dp và thêm semantics/tooltip cho các nút playback/navigation chính.
7. Tách `textMuted/textPlaceholder` đạt contrast thay vì dùng `textDisabled` cho info.
8. Guard/redact lyrics/Python verbose logs ở release.
9. Fail release build nếu đang dùng debug signing; cấu hình release key ngoài Git.
10. Tách một commit formatter/dead-comment cleanup, không trộn functional change.

## 7. Những việc không nên làm

- Không migrate toàn bộ Provider sang Riverpod chỉ để “thống nhất”; lỗi nằm ở lifecycle/orchestration, không nằm ở tên package.
- Không áp Clean Architecture/repository cho mọi plugin wrapper. Chỉ thêm seam/coordinator nơi external I/O đang cản test hoặc tạo duplicate flow.
- Không chia file chỉ dựa trên số dòng; ưu tiên tách responsibility đang gây lỗi như queue sync, download lifecycle và persistence/error state.
- Không bật concurrency >1 trước khi progress và cancel có task identity.
- Không tuyên bố startup/search/image nhanh hơn nếu chưa profile trước/sau trên cùng thiết bị/dataset.
- Không chuyển JSON/image sang isolate theo phản xạ; đo frame/CPU và giảm work/invalidations trước.
- Không chạy blanket `const` refactor như một phase performance.
- Không nâng đồng loạt 48 dependency chỉ vì `pub get` báo có bản mới; upgrade theo feature, changelog và platform matrix.
- Không đổi storage schema hoặc quyền Android trong cùng một big-bang release mà không dual-read/migration/rollback.
- Không sửa analyzer/formatter warning bằng cách disable lint hoặc format lẫn functional diff.

## Manual validation bắt buộc trước khi triển khai refactor

- Android device thật: cold start profile; library 1k/5k+ bài; deny/permanently-deny media/storage permission.
- Downloader: playlist ≥20 item, hai file tốc độ khác nhau, cancel file lớn, thoát/mở lại, airplane mode, kiểm tra partial file và traffic.
- Playback: queue reorder/remove/skip, background notification/headset, sleep timer đặt lại nhiều lần, auto-next/history.
- UI: TalkBack, font scale 1.3/2.0, Remove animations, light/AMOLED, 320×568, tablet/split-screen, keyboard/bottom inset.
- Release: release certificate, logcat privacy audit, storage API 24/29/30/33/35 và kênh phân phối dự kiến.
