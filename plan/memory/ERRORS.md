## [Phase 1] - 2026-07-18 20:42
- Baseline Git đã có thay đổi từ trước: mục tracked `git` đang ở trạng thái deleted (` D git`). Không khôi phục hoặc tác động tới thay đổi này trong lượt audit.
- Lệnh dò `AGENT.MD`/`AGENTS.md` trả exit code 1 vì không tìm thấy file; đây là kết quả “không có match”, không phải lỗi source.

## [Phase 1] - 2026-07-18 20:47
- Chuỗi `flutter --version` → `dart --version` → `flutter pub get` timeout sau 120 giây ngay tại `flutter --version`; không có exit code cho ba baseline command từ wrapper.
- Có nhiều tiến trình `dart.exe`/`dartvm.exe` bắt đầu khoảng 19:42–19:44 và các file lock SDK `bin/cache/flutter.bat.lock`, `bin/cache/lockfile`; sandbox không cho đọc command line qua CIM (`Access denied`). Tránh kill vì không xác định được owner/workload.
- `git -C D:/program/data/flutterDev/flutter ...` bị Git chặn do `dubious ownership` giữa user thật và sandbox. Không dùng workaround `safe.directory` toàn cục vì sẽ thay đổi cấu hình ngoài repo.

## [Phase 1] - 2026-07-18 20:53
- Workaround xác nhận: chạy Flutter/Dart ngoài sandbox hoàn tất bình thường; blocker trước đó là quyền truy cập SDK/cache trong sandbox, không phải lỗi toolchain của repo.
- Formatter baseline exit 1 vì 24/65 file sẽ bị đổi nếu format. Không chạy format ghi file trong lượt audit; danh sách file nằm trong log lệnh của lượt làm.

## [Phase 3] - 2026-07-18 21:08
- Chưa có phép đo profile/release trên thiết bị thật, library lớn hoặc tải đồng thời; tránh dùng các con số suy đoán làm benchmark. Báo cáo chỉ dùng con số được suy ra trực tiếp như fixed delay 4,6 giây và trần polling lý thuyết.
- Analyzer sạch nhưng suite hiện chỉ có một `expect(true, isTrue)`; không dùng kết quả pass này để phủ nhận finding runtime và không coi đây là lỗi của analyzer.

## [Phase 4] - 2026-07-18 21:08
- 11 screenshot hiện có chỉ đại diện dark mode, portrait và độ phân giải lớn; chưa thể xác nhận light mode, 320×568, tablet/split-screen, font scale 1.3/2.0, TalkBack hoặc Remove animations nếu không test thủ công/runtime.

## [Phase 5] - 2026-07-18 21:08
- Không phát sinh conflict khi tạo report/memory. Thay đổi tracked `git` ở trạng thái deleted đã có trước lượt audit và vẫn được giữ nguyên, không khôi phục hay chỉnh sửa.
- `audit/flutter_analyze.txt` bị replace là hành vi được yêu cầu của `scripts/flutter_analyze.bat`; run cuối có 0 error, 0 warning, 0 info.

## [Phase 0] - 2026-07-18 21:54
- `scripts/analyze_codex.bat` được user dẫn không tồn tại; repo thực tế có `scripts/flutter_analyze.bat`, nên dùng script này và đọc `audit/flutter_analyze.txt`.
- Analyzer baseline trong sandbox timeout 120 giây do Flutter SDK/cache; chạy lại ngoài sandbox theo workaround audit trước thành công, 0 issue. Không kill process hoặc sửa SDK ngoài repo.
- Regression test trước fix fail đúng dự kiến: expected 2 start nhưng ghi nhận 3 ID, task đầu xuất hiện hai lần. Đây là bằng chứng tự động của DL-01, không phải lỗi môi trường.

## [Phase 1] - 2026-07-18 21:54
- Analyzer lần đầu sau sửa báo `use_build_context_synchronously` tại navigation vì batch enqueue có `await`; thêm `if (!mounted) return` ngay trước `Navigator`, run kế tiếp sạch.
- `dart format --output=none --set-exit-if-changed .` exit 1 và báo 26 file sẽ đổi; lệnh không ghi source. Không chạy formatter hàng loạt vì baseline đã lệch và yêu cầu cấm trộn mechanical diff với functional change.
- Chưa chạy app/device thật, playlist 20 item hoặc đếm native log; chỉ xác nhận nguyên nhân và số lần gateway start bằng fake. Không tuyên bố throughput/runtime đã được tối ưu.
- Giữ nguyên thay đổi có sẵn ngoài phạm vi: `audit/01-setup-performance-audit.md` đang deleted và `plan/02-report-from-01-performance-audit.md` đang untracked; không khôi phục, xóa hoặc stage.

## [Phase 6] - 2026-07-18 22:09
- CI failure gốc: `Variant 'debug': Python 3.13 is not available for ABI 'armeabi-v7a'`; dòng `evaluationDependsOn(":app")` chỉ là nơi Gradle báo lỗi cấu hình, không phải root cause.
- Release build local exit 0 sau 342,6 giây và tạo `build/app/outputs/flutter-apk/app-release.apk`; SHA-256 `EB59A8B31AAA8373135DD3C9DECD6CC1E9393E4CA333820295507835B75A02C2`.
- Kotlin daemon local báo lỗi incremental cache do source pub cache ở ổ `C:` và project ở ổ `D:`; Gradle fallback vẫn hoàn tất APK. Nếu tái diễn/chặn build, tránh xóa rộng và ưu tiên clean cache build cục bộ hoặc tắt incremental trong bước chẩn đoán riêng.
- Build vẫn cảnh báo Flutter sắp bỏ Gradle 8.10.2, AGP 8.7.0 và Kotlin hiện dụng; ngoài ra app/plugin cần migration Built-in Kotlin. Không dùng flag skip validation để che cảnh báo.
- Formatter cuối vẫn exit 1 với 26 Dart file baseline sẽ đổi; chạy `--output=none` nên không ghi source và không format hàng loạt trong fix Gradle này.
- APK được xác minh local trên Windows, chưa xác nhận workflow Ubuntu/GitHub Actions đã xanh cho đến khi rerun CI.

## [Phase 0] - 2026-07-18 22:30
- Analyzer/test gọi trong sandbox timeout 120 giây trước khi tạo output; analyzer user chạy thủ công và các lệnh chạy ngoài sandbox hoàn tất bình thường. Không kill tiến trình Dart/Java của IDE; workaround là chạy Flutter/Dart ngoài sandbox.
- Regression test DL-02 trước sửa fail đúng dự kiến: expected một native start nhưng ghi nhận hai task start đồng thời. Đây là bằng chứng orchestration, chưa phải phép đo runtime/device.

## [Phase 1] - 2026-07-18 22:30
- `dart format --output=none --set-exit-if-changed .` vẫn exit 1 với 26 file baseline sẽ đổi; giữ diff constant chỉ ở dòng containment và không format hàng loạt ngoài phạm vi.
- Chưa chạy app/device thật, chưa quan sát hai download có tốc độ khác nhau và chưa đo throughput trước/sau. Chỉ xác nhận containment bằng fake gateway; không tuyên bố downloader đã được tối ưu runtime.
- Full test pass 4/4 và analyzer run cuối tại `audit/flutter_analyze.txt` exit 0 với 0 error/warning/info.
