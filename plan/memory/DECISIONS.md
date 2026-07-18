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
