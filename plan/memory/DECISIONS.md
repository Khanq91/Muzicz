## [Phase 1] - 2026-07-18 20:42
- Giữ lượt này ở chế độ audit-only theo yêu cầu của kế hoạch; chỉ tạo/cập nhật báo cáo và memory, không sửa code ứng dụng trước khi có danh sách ưu tiên rõ ràng.
- Tách rõ `Confirmed`, `Likely` và `Optional` trong báo cáo; không quy kết tác động hiệu năng nếu chưa có phép đo runtime trước/sau.

## [Phase 1] - 2026-07-18 20:47
- Không kill các tiến trình Dart/Flutter tồn tại trước lượt audit và không sửa cấu hình Git global của Flutter SDK; đây là state ngoài phạm vi repo, có thể thuộc phiên làm việc khác của user.
- Dùng `flutter.version.json` chỉ như bằng chứng metadata SDK khi wrapper bị lock; báo cáo vẫn tách rõ lệnh `flutter --version` đã timeout và không coi metadata thay thế cho exit code của lệnh.

## [Phase 1] - 2026-07-18 20:53
- Chạy toolchain ngoài sandbox sau khi xác định wrapper cần quyền SDK/cache; giữ nguyên source khi formatter báo 24 file lệch chuẩn để bảo toàn baseline audit-only.
- Không coi `flutter analyze` sạch và một placeholder test pass là bằng chứng các flow runtime đúng; các lỗi queue/download/lifecycle cần test hành vi riêng.

## [Phase 2] - 2026-07-18 21:08
- Không đề xuất migrate toàn bộ Provider sang Riverpod hoặc áp Clean Architecture đại trà; hai state stack có ranh giới feature chấp nhận được, còn lỗi thực tế nằm ở ownership/lifecycle và async orchestration.
- Ưu tiên đồng bộ queue/task state và dùng root ProviderScope trước khi chia nhỏ file hoặc tạo thêm abstraction.

## [Phase 3] - 2026-07-18 21:08
- Chọn containment downloader `concurrency = 1` làm bước ngắn hạn trước khi thiết kế progress/cancel theo task ID; tradeoff là giảm throughput nhưng ngăn state cross-wire với thay đổi nhỏ, dễ rollback.
- Yêu cầu profile cùng thiết bị/dataset trước và sau cho startup, scan, search, JSON và image decode; static code chỉ đủ xác nhận đường gọi, không đủ định lượng lợi ích.

## [Phase 4] - 2026-07-18 21:08
- Phân loại overflow thumbnail/badge là `Likely` vì screenshot chỉ phủ dark portrait cỡ lớn; các lỗi text-scale clamp, semantics, light color và contrast có bằng chứng trực tiếp nên giữ `Confirmed`.
- Bỏ clamp accessibility chỉ sau khi responsive layout có regression test ở font scale 1.3/2.0; tránh đổi một lỗi accessibility thành overflow chưa kiểm soát.

## [Phase 5] - 2026-07-18 21:08
- Xếp correctness và release safety trước micro-optimization: duplicate download, global progress, cancel giả, queue lệch và debug signing nằm trước các chỉnh sửa `const`, builder hoặc image cache.
- Giữ lượt này audit-only theo điểm dừng của plan: chỉ thay report/memory/analyze log, không tự triển khai quick win hay refactor source khi user chưa duyệt thứ tự.

## [Phase 0] - 2026-07-18 21:54
- Chỉ tạo seam tại biên I/O cần fake: `DownloadGateway` và provider output directory. Không abstract toàn bộ downloader/storage vì DL-01 chỉ cần quan sát số lần start và không cần thay kiến trúc feature.
- Theo xác nhận của user, ghép regression harness DL-01 với fix Phase 1 trong cùng session để chứng minh test đỏ trước sửa và giữ suite xanh khi kết thúc.

## [Phase 1] - 2026-07-18 21:54
- Reserve task trong state trước khi tạo/listen stream, thay vì chờ event `preparing`; state đồng bộ là source-of-truth khiến lần `_processQueue` kế tiếp không chọn lại task cũ.
- Giữ thêm guard `_subs.containsKey` và kiểm tra trạng thái `queued` như defense-in-depth; nếu gateway ném đồng bộ, chuyển task sang `error` rồi tiếp tục queue để tránh kẹt `preparing`.
- Thêm `enqueueBatch` cho selected playlist để tạo toàn bộ task rồi process một lần; giữ `enqueue`/`enqueuePlaylist` cũ để không phá public API hoặc behavior caller khác.

## [Phase 6] - 2026-07-18 22:09
- Giữ Python 3.13 và ABI intent hiện có (`arm64-v8a`, `x86_64`), dùng `clear()` + `addAll()` theo migration của Flutter 3.35+; không hạ Python để giữ `armeabi-v7a` vì cấu hình repo đã chủ động loại ABI này.
- Không nâng Gradle 8.10.2, AGP 8.7.0 hoặc Kotlin trong cùng fix build; đây là migration dependency có matrix/rủi ro riêng và các phiên bản hiện tại vẫn build thành công.
- Loại hai flag `android.builtInKotlin=false`/`android.newDsl=false` mà Flutter migrator tự thêm khi build local để không trộn mutation generated ngoài phạm vi vào diff.

## [Phase 1] - 2026-07-18 22:30
- Chọn containment `maxConcurrentDownloads = 1` vì protocol hiện không truyền task ID và Python chỉ có một progress state; giảm throughput là tradeoff có chủ đích để ngăn progress cross-wire mà không đổi ba layer trong cùng issue.
- Giữ full task-scoped progress/cancellation cho Phase 2; không thêm task ID nửa vời ở Dart khi Kotlin/Python chưa cùng hỗ trợ.
- Dùng fake gateway có completion điều khiển được để test cả giới hạn concurrency lẫn việc queue tự start task kế tiếp, thay vì chỉ assert một constant.

## [Phase 6] - 2026-07-18 22:52
- Setup Python 3.13 rõ ràng trong GitHub Actions thay vì hạ runtime Python hoặc thêm fallback mơ hồ; Chaquopy yêu cầu build-host Python cùng major/minor với app và local runtime 3.13 đã build thành công.
- Không nâng Gradle/AGP/Kotlin trong fix này; các cảnh báo deprecation không gây failure `installReleasePythonRequirements` và cần migration riêng.

## [Phase 2] - 2026-07-18 22:52
- Dùng response stream của native download làm source-of-truth cho trạng thái terminal; API cancel chỉ yêu cầu dừng và chờ ACK, không tự sửa UI state trước native.
- Dedupe cancel lặp theo task ID và giữ concurrency = 1; nếu native không dừng trong 15 giây hoặc Dart không nhận ACK trong 20 giây, task vẫn active để tránh khởi động task kế tiếp khi operation cũ còn chạy.
- Chọn cooperative flag trong yt-dlp progress/postprocessor hook thay vì chỉ cancel Kotlin coroutine, vì cancel coroutine không ngắt lời gọi Python blocking.
- Cleanup giới hạn theo filename đã được hook ghi nhận và chỉ xóa artifact tạm; chấp nhận có thể còn artifact không được hook quan sát để tránh xóa nhầm file hoàn chỉnh của user.
