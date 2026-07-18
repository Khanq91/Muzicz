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
