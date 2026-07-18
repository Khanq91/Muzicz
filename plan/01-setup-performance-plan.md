Bạn đang đóng vai trò Senior Flutter Engineer, Mobile Performance Engineer và UI/UX Reviewer.

Hãy thực hiện một cuộc audit kỹ thuật có bằng chứng cho repository Flutter hiện tại.

## Mục tiêu

Đánh giá và đề xuất cải thiện cho:

1. Kiến trúc và cấu trúc source code.
2. State management và luồng dữ liệu.
3. Hiệu năng runtime và thời gian khởi động.
4. UI/UX, responsive và accessibility.
5. API, local storage, cache và xử lý bất đồng bộ.
6. Độ ổn định, testability, maintainability và bảo mật phía client.

Không mặc định rằng dự án cần Clean Architecture, BLoC, Riverpod hoặc bất kỳ pattern nào. Chỉ đề xuất thay đổi khi có vấn đề thực tế và chứng minh được lợi ích.

## Nguyên tắc bắt buộc

* Không bịa đặt file, class, metric hoặc lỗi không tồn tại.
* Mọi nhận xét phải chỉ rõ file, class, function hoặc đoạn code liên quan.
* Phân biệt rõ:

  * Vấn đề đã xác nhận.
  * Rủi ro có khả năng xảy ra.
  * Gợi ý tùy chọn.
* Không tuyên bố app nhanh hơn nếu chưa đo trước và sau.
* Không rewrite toàn bộ dự án nếu có thể cải thiện từng phần.
* Không thay package hoặc state management chỉ vì sở thích cá nhân.
* Giữ nguyên hành vi hiện tại trừ khi hành vi đó là lỗi đã xác nhận.
* Không chỉnh sửa code trong giai đoạn audit đầu tiên.

## Giai đoạn 1 — Thu thập baseline

Trước tiên:

1. Đọc:

   * pubspec.yaml
   * pubspec.lock
   * analysis_options.yaml
   * README và tài liệu kiến trúc nếu có
   * toàn bộ cấu trúc lib/
   * test/, integration_test/
   * cấu hình Android và iOS có liên quan

2. Xác định:

   * Phiên bản Flutter và Dart thực tế.
   * State management đang sử dụng.
   * Navigation.
   * Dependency injection.
   * Networking.
   * Local database hoặc storage.
   * Cấu trúc module/feature.
   * Cách xử lý authentication và session.

3. Chạy các lệnh phù hợp nếu môi trường cho phép:

   * flutter --version
   * dart --version
   * flutter pub get
   * dart format --output=none --set-exit-if-changed .
   * flutter analyze
   * flutter test

Không tự ý sửa lỗi chỉ để các lệnh trên chạy thành công. Hãy ghi lại baseline ban đầu.

Nếu một lệnh không thể chạy, ghi rõ nguyên nhân thay vì suy đoán kết quả.

## Giai đoạn 2 — Audit kiến trúc

Kiểm tra:

* Business logic nằm trong Widget hoặc BuildContext.
* UI gọi trực tiếp API/database.
* Model API, domain model và view model bị trộn lẫn.
* Dependency hướng sai hoặc module phụ thuộc vòng.
* Singleton/global state không kiểm soát.
* Provider/BLoC/controller có phạm vi quá rộng.
* Một class đảm nhiệm quá nhiều trách nhiệm.
* Duplicate logic giữa các màn hình.
* Navigation chứa business logic.
* Error handling không thống nhất.
* Khả năng test từng layer.
* Feature coupling và khả năng mở rộng.

Không đánh giá kiến trúc dựa trên số lượng folder. Đánh giá dựa trên dependency, trách nhiệm và mức độ thay đổi lan truyền.

## Giai đoạn 3 — Audit performance

Tìm bằng chứng về:

* Widget rebuild không cần thiết.
* watch/listen/select được đặt ở phạm vi quá rộng.
* Tạo object, controller, future hoặc stream trong build().
* ListView/Column render số lượng phần tử lớn không hợp lý.
* Nested scroll hoặc shrinkWrap gây chi phí cao.
* Xử lý JSON, ảnh hoặc tính toán nặng trên UI isolate.
* Request API bị gọi nhiều lần.
* Không debounce search.
* Không cache hoặc cache sai.
* Image decode quá lớn so với kích thước hiển thị.
* Animation hoặc opacity gây repaint không cần thiết.
* StreamSubscription, AnimationController, TextEditingController hoặc listener không dispose.
* Timer/request tiếp tục chạy sau khi màn hình bị hủy.
* Truy cập database lặp lại.
* Startup thực hiện quá nhiều tác vụ đồng bộ.
* Memory leak hoặc giữ BuildContext quá lâu.

Với mỗi vấn đề performance, mô tả:

1. Bằng chứng trong code.
2. Tình huống kích hoạt.
3. Ảnh hưởng dự kiến.
4. Cách đo để xác nhận.
5. Cách sửa ít rủi ro nhất.

Không dùng const một cách máy móc và không coi thiếu const là vấn đề nghiêm trọng nếu không có ảnh hưởng đáng kể.

## Giai đoạn 4 — Audit UI/UX

Kiểm tra:

* Visual hierarchy.
* Spacing và alignment.
* Typography.
* Màu sắc và contrast.
* Design consistency.
* Loading, error, empty, offline và retry state.
* Form validation và thông báo lỗi.
* Touch target.
* Text scaling.
* Responsive trên nhiều kích thước màn hình.
* SafeArea, keyboard và bottom inset.
* Accessibility semantics.
* Navigation feedback.
* Skeleton/loading indicator.
* Animation có hỗ trợ trải nghiệm hay chỉ trang trí.
* Dark mode nếu dự án có yêu cầu.
* Tính nhất quán giữa các component giống nhau.

Nếu không có screenshot, video hoặc khả năng chạy app, hãy ghi rõ rằng đánh giá UI/UX chỉ dựa trên code và không được kết luận về chất lượng giao diện đã render.

## Giai đoạn 5 — Audit độ ổn định và bảo mật

Kiểm tra:

* setState hoặc cập nhật state sau khi dispose.
* Sử dụng BuildContext sau async gap.
* Race condition và duplicate submission.
* Request thiếu timeout, retry hoặc cancellation.
* Token, API key hoặc secret nằm trong source.
* Log dữ liệu nhạy cảm.
* Lưu token bằng storage không phù hợp.
* SSL validation bị tắt.
* Phân quyền chỉ kiểm tra ở UI.
* Exception bị nuốt hoặc catch quá rộng.
* Null handling và parsing dữ liệu API.
* Refresh token và logout flow.
* Offline/error recovery.

## Đầu ra bắt buộc

Tạo báo cáo theo cấu trúc:

### 1. Executive summary

Tóm tắt ngắn tình trạng dự án, không dùng nhận xét chung chung.

### 2. Architecture map

Mô tả luồng:

UI → State → Use case/Service → Repository → API/Database

Chỉ ra luồng thực tế của dự án, không vẽ kiến trúc giả định.

### 3. Danh sách phát hiện

Mỗi phát hiện phải có:

* ID.
* Nhóm vấn đề.
* Mức độ: Critical / High / Medium / Low.
* Độ tin cậy: Confirmed / Likely / Optional.
* File và vị trí liên quan.
* Bằng chứng.
* Tác động.
* Cách tái hiện hoặc đo.
* Giải pháp đề xuất.
* Rủi ro khi sửa.
* Effort: S / M / L.

### 4. Top 10 ưu tiên

Sắp xếp theo:

Impact × Frequency × Confidence ÷ Effort

Không ưu tiên vấn đề chỉ vì dễ sửa.

### 5. Kế hoạch refactor

Chia thành các phase nhỏ, mỗi phase phải:

* Có phạm vi rõ ràng.
* Có tiêu chí hoàn thành.
* Có test hoặc phương pháp xác nhận.
* Có phương án rollback.
* Không làm thay đổi quá nhiều phần không liên quan.

### 6. Quick wins

Chỉ liệt kê những thay đổi:

* Ít rủi ro.
* Có bằng chứng.
* Có thể kiểm tra kết quả.
* Không làm thay đổi kiến trúc lớn.

### 7. Những việc không nên làm

Nêu rõ các refactor phổ biến nhưng không phù hợp với dự án hiện tại.

Dừng lại sau báo cáo audit. Không chỉnh sửa code cho đến khi đã có danh sách ưu tiên rõ ràng.
