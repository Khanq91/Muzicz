## [Phase 1] - 2026-07-18 20:42
- [x] Đọc đầy đủ `plan/01-setup-performance-plan.md`; xác nhận phạm vi hiện tại là audit có bằng chứng, chưa chỉnh sửa source app.
- [x] Kiểm tra hướng dẫn agent: repository không có `AGENT.MD` hoặc `AGENTS.md`.
- [ ] Đang thu thập baseline: metadata dự án, cấu trúc source/test, cấu hình nền tảng và kết quả toolchain.
- [ ] Bước tiếp theo: đọc các file cấu hình/tài liệu, lập bản đồ dependency và chạy các lệnh baseline được kế hoạch yêu cầu.

## [Phase 1] - 2026-07-18 20:47
- [x] Đọc `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `README.md`, test hiện có và cấu hình Android/iOS liên quan.
- [x] Ghi nhận SDK từ metadata cache: Flutter 3.44.0 stable, Dart 3.12.0; gọi trực tiếp Dart executable xác nhận Dart 3.12.0.
- [ ] `flutter --version`/`flutter pub get` chưa chạy xong do Flutter SDK đang bị lock bởi các tiến trình có sẵn; chưa chạy formatter/analyzer/test để tránh xếp thêm tiến trình chờ lock.
- [ ] Đang lập bản đồ source và audit song song kiến trúc, performance, UI/UX, ổn định/bảo mật; bước tiếp theo là đọc sâu các service/provider/model và retry toolchain khi an toàn.

## [Phase 1] - 2026-07-18 20:53
- [x] Hoàn tất baseline toolchain ngoài sandbox: Flutter 3.44.0 stable, Dart 3.12.0, DevTools 2.57.0; `flutter pub get` exit 0 và không đổi `pubspec.lock`.
- [x] Chạy `dart format --output=none --set-exit-if-changed .`: kiểm tra 65 file, 24 file chưa đúng formatter, exit 1; lệnh không ghi source.
- [x] Chạy `scripts/flutter_analyze.bat`, đọc lại `audit/flutter_analyze.txt`: exit 0, 0 errors, 0 warnings, 0 infos, analyzer 1.4 giây.
- [x] Chạy `flutter test`: pass 1/1; suite chỉ có smoke assertion cấu hình, chưa kiểm tra hành vi app. Phase 1 hoàn tất.
- [ ] Đang ở Phase 2–5: tổng hợp finding có line evidence và xếp hạng; bước tiếp theo là hoàn thiện báo cáo audit/refactor plan.

## [Phase 2] - 2026-07-18 21:08
- [x] Hoàn tất architecture map cho music/playback và downloader; xác định ranh giới Provider, Riverpod, service, MethodChannel, Kotlin và Python.
- [x] Ghi nhận 6 finding kiến trúc/correctness ưu tiên cao quanh queue, task orchestration, ProviderScope và startup lifecycle.
- [x] Phase 2 hoàn tất; chuyển sang đối chiếu performance path và cách đo, không sửa source app.

## [Phase 3] - 2026-07-18 21:08
- [x] Hoàn tất audit startup, rebuild, list/image, lyrics, scan, persistence, timer/subscription và downloader polling/concurrency.
- [x] Mỗi nhận định runtime chưa có profile thiết bị được đánh dấu `Likely` hoặc nêu rõ tác động chưa đo; không tuyên bố app đã nhanh hơn.
- [x] Phase 3 hoàn tất; chuyển sang UI/UX/accessibility dựa trên source và 11 screenshot hiện có.

## [Phase 4] - 2026-07-18 21:08
- [x] Hoàn tất audit dark/light theme, hierarchy, responsive risk, semantics, touch target, contrast, empty/error state và consistency.
- [x] Tách lỗi đã xác nhận khỏi rủi ro layout cần chạy trên màn hình nhỏ/font scale lớn; lập danh sách manual validation tương ứng.
- [x] Phase 4 hoàn tất; chuyển sang stability/security, ranking và refactor plan.

## [Phase 5] - 2026-07-18 21:08
- [x] Hoàn tất audit error handling, lifecycle, release signing, Android storage permission, privacy logging và testability.
- [x] Tạo `audit/01-setup-performance-audit.md` gồm 36 finding, Top 10 theo công thức của plan, Phase 0–6, quick wins, việc không nên làm và manual validation.
- [x] Kiểm tra cuối: đủ các trường bắt buộc cho từng finding; Git chỉ có report/memory/analyze log của lượt này ngoài thay đổi ` D git` có sẵn từ trước.
- [x] Trạng thái hiện tại: Phase 1–5 của audit hoàn tất và dừng trước khi refactor source theo yêu cầu plan; bước tiếp theo là user duyệt ưu tiên rồi mới triển khai Phase 0/1.

## [Phase 0] - 2026-07-18 21:54
- [x] Đọc lại audit, toàn bộ code/test liên quan DL-01 và ghi baseline: analyzer 0 issue; test cũ pass 1/1.
- [x] Thêm seam tối thiểu `DownloadGateway` cùng Riverpod override cho gateway/output directory; không thay package hoặc public protocol native.
- [x] Thêm regression test tái hiện DL-01: hai lần enqueue liên tiếp tạo 3 download start và lặp task ID đầu trước khi sửa.
- [ ] Phase 0 còn dang dở: chưa có harness cho DL-02/03, PLAY-01, LIFE-01, STATE-01; chưa có profile baseline trên thiết bị thật.

## [Phase 1] - 2026-07-18 21:54
- [x] Hoàn tất DL-01: reserve task sang `preparing` đồng bộ, guard subscription/trạng thái, bắt lỗi start đồng bộ và enqueue selected playlist theo batch trước khi process queue.
- [x] Regression test sau sửa pass 2/2; toàn suite pass 3/3; `scripts/flutter_analyze.bat` exit 0 với 0 error/warning/info.
- [ ] Chưa xác nhận manual playlist 20 item/native call trên thiết bị; bước tiếp theo là quay lại Phase 0 tạo harness cho DL-02 rồi triển khai containment concurrency = 1 của Phase 1 trong một issue riêng.

## [Phase 6] - 2026-07-18 22:09
- [x] Chẩn đoán CI release build: Flutter 3.44 tự thêm `armeabi-v7a`, còn cấu hình `abiFilters +=` chỉ bổ sung chứ không xóa ABI; Chaquopy Python 3.13 không hỗ trợ ABI 32-bit này.
- [x] Sửa `defaultConfig.ndk` bằng `abiFilters.clear()` rồi chỉ thêm `arm64-v8a` và `x86_64`; không đổi Python/package hoặc nâng Gradle toolchain.
- [x] `flutter build apk --release --no-pub` exit 0, tạo APK 80.706.719 byte; kiểm tra archive chỉ có `arm64-v8a`, `x86_64`. Analyzer 0 issue và test pass 3/3.
- [ ] Chưa rerun GitHub Actions trên Linux; bước tiếp theo là push/rerun workflow và xử lý nâng Gradle/AGP/Kotlin ở issue độc lập trước khi Flutter bỏ hỗ trợ phiên bản hiện tại.

## [Phase 0] - 2026-07-18 22:30
- [x] Đọc lại code Dart/Kotlin/Python liên quan DL-02 và xác nhận 10 download cùng poll một `_progress` global, mỗi download mới còn reset state này.
- [x] Thêm regression harness điều khiển completion của fake gateway; test trước sửa fail vì hai task cùng start khi protocol progress chưa có task ID.
- [ ] Phase 0 còn thiếu harness DL-03, PLAY-01, LIFE-01 và STATE-01; chưa có profile/device baseline 1/2/10 download.

## [Phase 1] - 2026-07-18 22:30
- [x] Hoàn tất containment DL-02: đặt `maxConcurrentDownloads = 1`; task tiếp theo chỉ start sau event finished của task hiện tại.
- [x] Cập nhật DL-01 regression để vẫn chứng minh mỗi task start đúng một lần trong queue tuần tự; targeted test pass 3/3, full suite pass 4/4, analyzer 0 issue.
- [ ] Chưa triển khai progress/cancellation task-scoped; throughput bị giới hạn có chủ đích. Bước tiếp theo: tạo harness DL-03 trong Phase 0 trước khi thiết kế cancellation xuyên native ở Phase 2.

## [Phase 6] - 2026-07-18 22:52
- [x] Chẩn đoán CI release fail mới: runner Ubuntu không có build-host Python 3.13 mà Chaquopy runtime 3.13 yêu cầu; lỗi ABI trước đó không còn xuất hiện.
- [x] Thêm `actions/setup-python@v6` với Python 3.13 trước bước Flutter build; giữ nguyên Chaquopy/Python/package và Gradle toolchain.
- [x] `flutter build apk --release --no-pub` local pass, tạo APK 77,0 MB; analyzer sạch và full test pass 8/8.
- [ ] Chưa rerun workflow trên Ubuntu; bước tiếp theo là push/rerun CI để xác nhận `installReleasePythonRequirements` dùng interpreter do `setup-python` cung cấp.

## [Phase 0] - 2026-07-18 22:52
- [x] Thêm regression harness DL-03; test trước sửa fail vì `DownloadNotifier.cancel` trả `void` và không có native acknowledgement để chờ.
- [x] Bổ sung MethodChannel contract test cho task ID và điều kiện ACK `accepted && stopped`.
- [ ] Chưa có Android device measurement cho traffic và tăng trưởng partial file sau cancel.

## [Phase 2] - 2026-07-18 22:52
- [x] Triển khai cooperative cancellation theo task ID qua Dart → Kotlin → Python; Kotlin giữ download `Job`, Python dùng cancellation event trong progress/postprocessor hook.
- [x] Task active chỉ chuyển `cancelled` từ response của download sau khi native dừng; cancel thất bại/timeout giữ task active và không cho queue chạy tiếp.
- [x] Cleanup chỉ nhắm file tạm `.part`, `.ytdl` và fragment cùng basename đã quan sát; không xóa output hoàn chỉnh hoặc quét cả thư mục.
- [x] Targeted test pass 5/5, MethodChannel test pass 2/2, full suite pass 8/8, analyzer 0 issue và release APK build pass.
- [ ] Phase 2 còn task-scoped progress; cần device test cancel khi download/merge và xác nhận traffic/file growth dừng trong timeout trước khi tuyên bố runtime hoàn tất.

## [Phase 2] - 2026-07-18 23:09
- [x] Đọc lại toàn bộ Dart/Kotlin/Python và test liên quan DL-02; baseline analyzer 0 issue, full suite pass 8/8.
- [x] Thêm regression test hai stream có progress 25%/75%; test đỏ trước sửa vì `getProgress` không có arguments/task ID và xanh sau sửa.
- [x] Truyền `taskId` qua Dart → Kotlin → Python; thay `_progress` global bằng map task-scoped có lock và cleanup khi task kết thúc.
- [x] Targeted service test pass 3/3, full suite pass 9/9, analyzer 0 issue, Python compile check pass và debug APK build pass.
- [ ] Concurrency production tiếp tục giữ ở 1; chưa đo hai native download đồng thời, polling rate, traffic hoặc progress card trên Android device. Bước tiếp theo: device validation Phase 2 trước khi cân nhắc mở lại concurrency, hoặc quay về Phase 0 tạo harness cho PLAY-01 theo thứ tự kế hoạch.

## [Phase 0] - 2026-07-18 23:22
- [x] Đọc lại toàn bộ `player_provider.dart`, `audio_handler.dart`, queue UI, model và test hiện có; baseline analyzer 0 issue, full suite pass 9/9, format-check giữ lỗi có sẵn 26/67 file.
- [x] Thêm `PlayerAudioGateway` làm fake seam tối thiểu và regression harness A/B/C cho PLAY-01; trước fix hai test đỏ vì provider đã remove/reorder nhưng engine vẫn giữ `[1, 2, 3]`.
- [ ] Phase 0 đã có harness PLAY-01 nhưng vẫn thiếu LIFE-01, STATE-01 và profile/device baseline; chưa chạy playback trên thiết bị thật.

## [Phase 3] - 2026-07-18 23:22
- [x] Hoàn tất PLAY-01: thêm engine API remove/move, chuyển queue mutation thành async và chỉ commit provider state sau khi engine thành công.
- [x] Đồng bộ current index/current song khi remove hoặc move bài đang phát; clear history index cũ và chặn queue mutation chồng trong lúc engine đang cập nhật.
- [x] Thêm 6 regression test cho remove, reorder, failure atomicity và current-song behavior; targeted pass 6/6, full suite pass 15/15, analyzer 0 issue.
- [x] Tăng app version từ `1.0.0+1` lên `1.0.0+2`; format-check cuối trở về baseline 26/68 file sau khi format riêng test mới.
- [ ] Chưa xác nhận manual background playback/headset/notification hoặc queue sheet trên Android device. Bước tiếp theo: device-check A/B/C remove/reorder/skip, rồi xử lý timer/subscription/history của Phase 3 như issue độc lập.

## [Phase 3] - 2026-07-19 00:08
- [x] Đọc lại finding PERF-01, toàn bộ `PlayerProvider`, audio gateway/composition và test playback; xác nhận periodic timer không có handle, ba stream subscription không được cancel và history có hai writer cạnh tranh.
- [x] Giữ/cancel riêng one-shot timer và countdown timer; lưu/cancel ba audio subscription khi dispose; tập trung cập nhật current track/history qua một helper chống ghi trùng giữa lệnh seek và `currentIndexStream`.
- [x] Thêm 4 regression test cho reset countdown, dispose subscription, manual seek và auto-next history; targeted pass 10/10, full suite pass 19/19, analyzer 0 issue.
- [x] Tăng app version từ `1.0.0+2` lên `1.0.0+3`; format-check cuối vẫn fail đúng baseline 26/68 file và không format hàng loạt ngoài phạm vi.
- [ ] Chưa đo retaining path/timer callback bằng DevTools hoặc kiểm tra background playback/headset/notification trên thiết bị thật. Bước tiếp theo: manual validation toàn Phase 3, sau đó quay về Phase 0 tạo harness LIFE-01 hoặc STATE-01 theo kế hoạch.

## [Phase 0] - 2026-07-19 00:27
- [x] Đọc lại toàn bộ root composition, downloader bridge/router, network provider/service và test hiện có; baseline analyzer 0 issue và full suite pass 19/19.
- [x] Thêm regression harness LIFE-01 cho ownership service theo Riverpod container, recreate service sau dispose và contract giữ `RouteSettings.name` của downloader.
- [ ] Phase 0 vẫn thiếu harness STATE-01 và profile/device baseline; chưa có automated widget test cho toàn bộ back stack thật.

## [Phase 1] - 2026-07-19 00:27
- [x] Hoàn tất LIFE-01: xóa nested `ProviderScope`/`MaterialApp`, mở `/dl/analyze` qua navigator gốc và giữ tên route cho `pushNamedAndRemoveUntil`.
- [x] Thay singleton `NetworkService.instance` bằng instance do `networkServiceProvider` sở hữu; init idempotent, dispose idempotent và chờ cancel subscription trước khi đóng controller.
- [x] Targeted LIFE-01 test pass 3/3, full suite pass 22/22, analyzer 0 issue; tăng app version từ `1.0.0+3` lên `1.0.0+4`.
- [x] Final format-check không ghi file vẫn exit 1 do baseline 25/68 file; giảm một file so với session trước và không format hàng loạt.
- [ ] Chưa manual open/close downloader + airplane-mode loop hoặc thoát khi download đang chạy trên Android device. Bước tiếp theo: xác nhận manual LIFE-01, sau đó tạo harness STATE-01 như issue độc lập.

## [Phase 0] - 2026-07-19 00:38
- [x] Đọc lại finding STATE-01, toàn bộ notifier, analyze screen, gateway/model và test liên quan; baseline analyzer 0 issue, full suite pass 22/22.
- [x] Thêm `AnalyzeGateway` seam và 3 regression test; trước sửa test đỏ đúng ở stale result, response đảo thứ tự và duplicate submit.
- [x] Hoàn tất STATE-01: URL thay đổi xóa result/error, nullable `copyWith` dùng sentinel, duplicate loading request bị chặn và revision token loại response cũ.
- [x] Targeted test sau sửa pass 3/3; full suite pass 25/25; analyzer cuối 0 issue; tăng app version từ `1.0.0+4` lên `1.0.0+5`.
- [x] Final format-check không ghi file exit 1 với baseline 24/69 file sẽ đổi; không format hàng loạt ngoài phạm vi.
- [ ] Chưa manual analyze A/B với mạng thật. Bước tiếp theo: chuyển sang Phase 4 theo kế hoạch, bắt đầu bằng measurement START-01/START-02 trong issue riêng.

## [Phase 4] - 2026-07-19 00:47
- [x] Đọc lại finding/kế hoạch START-02, toàn bộ `MainActivity.kt`, Python bridge, Android build config và test hiện có; baseline analyzer 0 issue, full suite pass 25/25.
- [x] Thêm regression test bảo vệ cold-start path; test đỏ trước sửa vì `configureFlutterEngine` gọi `Python.start/getModule` và xanh sau sửa.
- [x] Hoàn tất START-02 về mặt code: chuyển Chaquopy/module sang lazy init đồng bộ ở downloader call đầu tiên; debug APK build pass và tăng app version từ `1.0.0+5` lên `1.0.0+6`.
- [x] Kiểm chứng cuối: targeted test pass 1/1, full suite pass 26/26, analyzer 0 issue; format-check giữ baseline 24/70 file sẽ đổi và không ghi source.
- [ ] Chưa có Macrobenchmark/Perfetto hoặc device test cold start/downloader-first-use, nên chưa định lượng latency. Bước tiếp theo: đo START-02 trên Android device hoặc xử lý START-01 parallel/minimum splash như issue Phase 4 độc lập.

## [Phase 1] - 2026-07-19 01:16
- [x] Đọc plan Liquid Glass, memory, skill Flutter UI và toàn bộ code/test liên quan bottom navigation, settings, theme persistence, root initialization và Android manifest; baseline analyzer 0 issue, full suite pass 26/26.
- [x] Thêm lựa chọn `Đồ họa` gồm `Bình thường` và `Xịn xò`; lưu `bottom_nav_style` bằng `SharedPreferences` và áp dụng ngay qua loading transition hiện có.
- [x] Tách bottom navigation khỏi `home_screen.dart`: bản thường giữ nguyên presentation/behavior, bản xịn dùng `GlassTabBar.bottom` với `GlassQuality.premium` và `MaskingQuality.high`; cả hai giữ 3 tab và chỉ tab focus hiện text.
- [x] Khởi tạo/wrap `liquid_glass_widgets` 0.22.1, bật Impeller trong Android manifest, thêm 4 regression test và tăng version `1.0.0+6` → `1.0.0+7`.
- [x] Kiểm chứng cuối: targeted test pass 4/4, full suite pass 30/30, analyzer 0 issue và debug APK build thành công; format-check không ghi source còn 22/74 file baseline lệch formatter.
- [ ] Chưa kiểm tra shader Premium, animation kéo tab và frame timing trên thiết bị Android thật. Bước tiếp theo: manual switch Bình thường ↔ Xịn xò ở dark/AMOLED/light và profile raster frame trong lúc scroll/chuyển tab.

## [Phase 2] - 2026-07-19 14:21
- [x] Chuyển download/queue/audio extraction khỏi `MainActivity` sang Android `dataSync` foreground service; task được persist, resume sau process recreation và hydrate lại vào Riverpod khi mở app.
- [x] Thêm notification tiến trình với số đang tải/hoàn thành/chờ/lỗi; xin notification permission best-effort và giữ download chạy khi Flutter route/activity detach.
- [x] Thêm auto retry tối đa 2 lần cho lỗi transient với backoff 2/4 giây, chờ đến khi có mạng; user cancel và lỗi terminal không retry.
- [x] Mở native concurrency từ 1 lên 2 sau khi progress/cancel đã task-scoped; reserve queue dưới lock và thêm media ID vào output filename để tránh collision.
- [x] Targeted regression pass 15/15, full suite pass 37/37, analyzer 0 issue và debug APK build pass; tăng version `1.0.0+7` → `1.0.0+8`.
- [ ] Chưa có Android device để kiểm tra Home/screen-off/process recreation, notification permission, traffic sau cancel/retry và throughput hai task. Bước tiếp theo: manual device matrix rồi mới cân nhắc concurrency >2.

## [Phase 4] - 2026-07-19 14:21
- [x] Xác nhận whitelist Dart đã có WebM nhưng `MediaStore.Audio` có thể không trả file; thêm fallback query `MediaStore.Files` chỉ cho ứng viên WebM và xác nhận audio/duration bằng `MediaMetadataRetriever`.
- [x] Merge theo path không phân biệt hoa thường, ưu tiên metadata từ `on_audio_query`, dùng synthetic ID ổn định cho fallback và giữ scan audio thường khi quyền video bị từ chối.
- [x] Thêm MethodChannel mapping/merge regression test; native scanner compile trong debug APK.
- [ ] Chưa quét file WebM thật trên API 24/29/33/35 hoặc SD card; bước tiếp theo sau device validation downloader là kiểm tra audio-only và video+audio WebM, duplicate và permission denied.

## [Phase 4] - 2026-07-19 15:06
- [x] Đọc lại START-01, toàn bộ splash/provider/scanner/storage/Home/onboarding và test liên quan; baseline analyzer 0 issue, full suite pass 37/37.
- [x] Bỏ chuỗi chờ cố định 4,6 giây: storage init và minimum splash 1,3 giây chạy song song; returning user bắt đầu scan sau init nhưng navigation Home không chờ scan hoàn tất, first-run vẫn đi Welcome và không tự scan.
- [x] Home hiển thị loading state có live-region semantics khi initial scan chưa có bài; permission/request exception được map về `LibraryStatus.error` thay vì thành unhandled background future.
- [x] Thêm 3 regression test cho first-run, background scan và slow init; targeted pass 3/3, full suite pass 40/40, analyzer 0 issue; tăng version `1.0.0+8` → `1.0.0+9`.
- [ ] Chưa có Android device/Macrobenchmark/Perfetto để đo process start → first Home frame hoặc scan duration. Bước tiếp theo: đo cold/warm startup và kiểm tra loading/error/permission flow thực, sau đó xử lý deep scan mặc định/permission ownership như issue Phase 4 riêng.

## [Phase 4] - 2026-07-19 15:22
- [x] Đọc lại PERF-04, toàn bộ provider/scanner/storage/startup và các call site scan liên quan; baseline analyzer 0 issue, full suite pass 40/40.
- [x] Thêm seam inject `MusicScanner`/`StorageService`; regression test trước sửa đỏ với 2 permission request cho một refresh và xanh sau sửa với đúng 1 request.
- [x] Refresh thường chỉ query MediaStore: provider sở hữu permission request và `scanSongs` không còn gọi deep `scanMedia('/storage/emulated/0')`; giữ tham số mặc định để caller độc lập vẫn có thể tự bảo đảm quyền.
- [x] Thêm guard test bảo vệ normal refresh khỏi deep scan; targeted pass 2/2, full suite pass 42/42, analyzer 0 issue; tăng version `1.0.0+9` → `1.0.0+10`.
- [ ] Chưa có Android device/Perfetto để đo permission/platform-call count và scan I/O thực; file ngoài app chưa được MediaStore index có thể chưa xuất hiện ngay. Bước tiếp theo: device validation API 24/29/33/35 và thiết kế manual deep-rescan hoặc scan đúng file vừa tạo như issue riêng.

## [Phase 4] - 2026-07-19 15:53
- [x] Đọc lại PERF-07, toàn bộ `MusicProvider`, `StorageService`, model và test scan hiện có; baseline analyzer 0 issue, full suite pass 42/42.
- [x] Thêm regression metric cho batch 100 bài; trước sửa test đỏ vì tạo 100 single storage calls thay vì một batch operation.
- [x] Thêm `StorageService.hideSongs`: hydrate hidden map một lần, merge cả batch và persist một lần; provider chỉ cập nhật library/playlist sau khi storage hoàn tất.
- [x] Thêm test giữ hidden entries cũ khi merge; targeted test pass 4/4; tăng version `1.0.1+10` → `1.0.1+11`.
- [x] Final analyzer 0 issue và full suite pass 44/44; format-check không ghi source giữ baseline 17/80 file legacy sẽ đổi.
- [ ] Đang ở Phase 4; bước tiếp theo là xử lý hydrate/cache typed collections hoặc debounce/memoize derived lists như issue độc lập.

## [Phase 4] - 2026-07-19 16:07
- [x] Đọc lại PERF-03, toàn bộ `StorageService`, `MusicProvider`, model và test/call site liên quan; xác nhận mỗi getter typed collection vẫn đọc và `jsonDecode` lại từ SharedPreferences.
- [x] Thêm regression test hydrate-once và corrupt-storage; trước sửa cả hai đỏ bằng `FormatException` khi getter decode raw JSON.
- [x] Hydrate/cache `recentlyPlayedIds`, `playCounts`, `favoriteIds`, `metaOverrides` và `hiddenSongs` trong `init`; mọi mutation persist thành công rồi mới commit cache typed.
- [x] Targeted test pass 6/6; tăng version `1.0.1+11` → `1.0.1+12`.
- [x] Final analyzer 0 issue và full suite pass 46/46; format-check không ghi source giữ baseline 17/81 file legacy sẽ đổi.
- [ ] Đang ở Phase 4; bước tiếp theo là debounce/memoize search/sort/smart lists như issue độc lập, kèm dataset 1k/5k/10k nếu có thiết bị/profile harness.

## [Phase 4] - 2026-07-19 16:50
- [x] Đọc lại PERF-03, toàn bộ `MusicProvider`, `StorageService`, `SongItem`, Home/Library call site, tile và test liên quan; baseline analyzer 0 issue, full suite pass 46/46.
- [x] Thêm regression trên dataset giả 5.000 bài; trước sửa test đỏ vì query commit ngay và smart getter cấp phát snapshot mới ở mỗi lần đọc.
- [x] Debounce Home/Library search 160 ms, cache normalized search text, memoize filter/sort/smart snapshots và invalidate chọn lọc khi library, metadata, favorite hoặc play tracking đổi; Random Mix ổn định qua notify không liên quan.
- [x] Targeted test pass 6/6; tăng version `1.0.1+12` → `1.0.1+13`; final analyzer 0 issue và full suite pass 48/48.
- [ ] Format-check không ghi source còn 16/81 file legacy sẽ đổi; chưa có DevTools/device profile 1k/5k/10k nên chỉ xác nhận loại recomputation/allocation theo contract test. Bước tiếp theo: đo search/frame/allocation trên thiết bị hoặc xử lý derived album/artist/folder rebuild như issue Phase 4 riêng.
