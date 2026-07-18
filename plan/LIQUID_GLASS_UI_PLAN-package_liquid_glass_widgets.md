# Plan Áp Dụng `liquid_glass_widgets` Cho Refactor UI Hoặc Tạo App Mới

## Summary
Mục tiêu là chuẩn hóa cách AI agent áp dụng `liquid_glass_widgets` vào Flutter app theo 2 hướng:

1. **Refactor app hiện có**: thêm Liquid Glass mà không phá UI cũ, cho phép chọn lại giao diện trong Settings.
2. **Create app mới từ số 0**: có ít nhất 2 loại giao diện: `Normal UI` và `Liquid Glass UI`, trong Liquid Glass có 3 quality `standard / minimal / premium`.

Nguyên tắc chính: user chọn theme/quality trong Settings, app lưu cấu hình mới, hiển thị dialog yêu cầu restart. Nếu user chọn restart, app khởi động lại như lần vào app mới; nếu hủy, cấu hình được áp dụng ở lần mở app sau.

## Theme/Quality Flow

### Settings UX
- Trong Settings có mục chọn giao diện:
  - `Giao diện bình thường`
  - `Liquid Glass`
- Nếu chọn `Liquid Glass`, hiển thị tiếp 3 quality:
  - `Standard`: default, lightweight shader, khuyến nghị.
  - `Minimal`: fallback nhẹ nhất, shader-free.
  - `Premium`: visual tốt nhất, chỉ dùng cho máy mạnh/showcase.
- Khi user chọn mode/quality mới:
  - Lưu `pendingThemeMode` và `pendingGlassQuality` vào persistent storage.
  - Hiển thị dialog:
    - Nội dung: `Để áp dụng giao diện mới cần khởi động lại ứng dụng`
    - Buttons: `Hủy`, `Khởi động lại ngay`
- `Hủy`:
  - Không đổi UI hiện tại.
  - Giữ pending config để lần sau mở app sẽ áp dụng.
- `Khởi động lại ngay`:
  - Promote pending config thành active config.
  - Restart root app về trạng thái như user vừa mở app.
  - Không chỉ pop/push màn hiện tại; phải rebuild root app/session.

### Restart Mechanism
- Dùng một `RestartScope` ở root:
  ```dart
  class RestartScope extends StatefulWidget {
    static void restartApp(BuildContext context);
  }
  ```
- `RestartScope.restartApp(context)` đổi `Key` của root subtree:
  ```dart
  KeyedSubtree(
    key: ValueKey(_restartToken),
    child: MyAppRoot(),
  )
  ```
- Khi restart:
  - Đọc lại active theme config từ storage.
  - Reset navigation stack về initial route.
  - Re-run app initialization logic cần thiết ở app layer.
- Không cần gọi native process restart; Flutter subtree restart là đủ cho UX “vừa vào app”.

## Implementation Patterns

### Refactor UI Hiện Có
- Không glass hóa trực tiếp toàn bộ UI cũ trong một lần.
- Tạo song song:
  - `NormalAppShell`: giữ UI cũ.
  - `LiquidGlassAppShell`: dùng cùng route/data/business logic nhưng presentation glass riêng.
- Root app quyết định shell theo active config:
  ```dart
  switch (activeThemeMode) {
    case AppThemeMode.normal:
      return NormalAppShell();
    case AppThemeMode.liquidGlass:
      return LiquidGlassAppShell(quality: activeGlassQuality);
  }
  ```
- Với app lớn, bắt buộc chia phase:
  - Phase 1: app shell, settings, restart flow, theme config.
  - Phase 2: các màn chung layout/navigation.
  - Phase 3+: từng nhóm màn theo cùng luồng hoặc cùng component.
- AI agent phải kiểm tra trước size app:
  - Nếu nhiều route/module/component, không refactor toàn app trong một session.
  - Ưu tiên các màn cùng user flow hoặc đang dùng chung design/component.

### Create App Mới Từ Số 0
- Root có 2 mode:
  - `Normal UI`
  - `Liquid Glass UI`
- Liquid Glass mode có 3 quality.
- Settings dùng cùng flow restart như trên.
- Normal và Liquid Glass nên dùng chung:
  - models
  - state management
  - routing contract
  - feature logic
- Tách presentation:
  - `normal/`
  - `glass/`
  - `shared/`
- Default khi lần đầu vào app:
  - `Normal UI` nếu app cần tương thích rộng.
  - Hoặc `Liquid Glass Standard` nếu app định hướng showcase visual.

## Liquid Glass Integration Rules

### Setup
- Dependency:
  ```yaml
  liquid_glass_widgets: ^0.19.1 (dùng Latest version nếu có version cao hơn)
  ```
- `main()`:
  ```dart
  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await LiquidGlassWidgets.initialize();
    runApp(
      LiquidGlassWidgets.wrap(
        child: RestartScope(child: const AppRoot()),
        adaptiveQuality: true,
      ),
    );
  }
  ```
- Android bật Impeller:
  ```xml
  <meta-data
      android:name="io.flutter.embedding.android.EnableImpeller"
      android:value="true" />
  ```

### Widget Usage
- Dùng `GlassScaffold` cho màn Liquid Glass.
- Dùng `GlassTabBar.bottom` cho bottom navigation.
- Dùng `GlassCard`, `GlassContainer`, `GlassListTile`, `GlassButton`, `GlassSwitch`, `GlassSlider`, `GlassTextField`, `GlassProgressIndicator` cho UI con.
- Truyền quality thống nhất từ active config xuống các glass widget.
- Với bottom bar:
  ```dart
  maskingQuality: quality == GlassQuality.premium
      ? MaskingQuality.high
      : MaskingQuality.off
  ```
- Không truyền `settings` riêng vào grouped glass widget nếu không dùng `useOwnLayer: true`.
- Ưu tiên settings ở `GlassScaffold`, `GlassPage`, theme, hoặc layer cha.

## Performance Advisor UX

### Khả Năng Của Package/Flutter
- `liquid_glass_widgets` có `GlassPerformanceMonitor`.
- Monitor này:
  - Theo dõi raster frame duration khi có `GlassQuality.premium`.
  - Emit `FlutterError` trong debug/profile nếu over budget.
  - Không chạy trong release.
- Package cũng có `adaptiveQuality: true`, experimental, để tự benchmark và giới hạn quality ceiling.
- Vì monitor mặc định không phải UX-facing production API, nếu muốn hiện dialog cho user trong app thật thì cần tự xây `AppPerformanceAdvisor`.

### AppPerformanceAdvisor
- Dùng `SchedulerBinding.addTimingsCallback` để đo `FrameTiming.rasterDuration`.
- Chỉ bật khi active theme là Liquid Glass.
- Ngưỡng đề xuất:
  - `rasterDuration > 16ms` trong 60 frame liên tiếp cho target 60fps.
  - Với máy yếu hoặc app enterprise có thể dùng 24ms để tránh false positive.
- Chỉ hiện warning khi:
  - đang không ở `GlassQuality.minimal` hoặc `Normal UI`,
  - không bị user ignore trong session,
  - không có `doNotRemindUntil` trong 30 ngày.

### Performance Warning Dialog
- Nội dung:
  - `Thiết bị có vẻ không ổn định với mức đồ họa hiện tại. Bạn có muốn giảm chất lượng giao diện để ứng dụng mượt hơn không?`
- Có checkbox:
  - `Không nhắc lại trong 30 ngày`
- Buttons:
  - `Bỏ qua`
  - `Đồng ý`
- `Bỏ qua`:
  - Không đổi quality.
  - Không nhắc lại trong phiên hoạt động hiện tại.
  - Nếu checkbox được tick, lưu `doNotRemindUntil = now + 30 days`.
- `Đồng ý`:
  - Hạ 1 cấp quality:
    - `premium -> standard`
    - `standard -> minimal`
    - `minimal -> normal UI`
  - Lưu config mới thành active config.
  - Bắt buộc restart app ngay bằng `RestartScope.restartApp(context)`.
- Không auto downgrade âm thầm; luôn yêu cầu user xác nhận.

## Lỗi Đã Gặp Và Lỗi Có Thể Gặp

- **Premium performance budget exceeded**
  - Nguyên nhân: nhiều premium surface + background động + thiết bị GPU yếu.
  - Fix: default `standard`, fallback `minimal`, chỉ dùng `premium` cho màn tĩnh/showcase.
- **Grouped widget settings warning**
  - Log: `To apply these settings, add useOwnLayer: true`.
  - Fix: đặt settings ở parent layer/theme hoặc dùng `useOwnLayer: true` có kiểm soát.
- **SkSL shader incompatible warning**
  - Nguyên nhân: shader Impeller-first, Skia backend không hỗ trợ một số shader.
  - Fix: bật Impeller, chạy `flutter run --enable-impeller`, hoặc tránh package shader raw trên backend không hỗ trợ.
- **Bottom bar quá nặng**
  - Fix lớn nhất: `maskingQuality: MaskingQuality.off` cho standard/minimal.
- **Quá nhiều glass trong scroll view**
  - Fix: list/grid dùng `standard` hoặc `minimal`; tránh premium cho item lặp.
- **Restart không thật sự reset state**
  - Nguyên nhân: chỉ push route mới thay vì rebuild root.
  - Fix: root `RestartScope` đổi key và reset navigation stack.
- **Refactor app lớn bị quá session**
  - Fix: chia phase theo route group/feature flow/component family.

## Developer Tips / Performance Notes

- `Standard` là default tốt nhất cho app thực tế.
- `Minimal` là safe mode khi thiết bị yếu hoặc màn có nhiều glass surface.
- `Premium` chỉ nên dùng khi:
  - ít surface,
  - màn ít scroll,
  - background không quá nặng,
  - thiết bị đủ mạnh.
- Background cần giàu chi tiết để thấy glass effect, nhưng animation phải chậm và ít layer.
- Không tạo nhiều `useOwnLayer: true` nếu không cần.
- Khi refactor, glass hóa shell/navigation trước, sau đó mới tới card/control nhỏ.
- Luôn log các chỉ số khi profiling:
  - active theme mode
  - active quality
  - raster frame duration trung bình
  - số frame over budget liên tiếp
  - route/screen hiện tại
  - số lượng glass surface gần đúng nếu app tự track được

## Acceptance Criteria
- Settings có thể chọn `Normal UI` hoặc `Liquid Glass`.
- Liquid Glass có đủ `standard / minimal / premium`.
- Chọn giao diện mới luôn hiện dialog restart.
- `Hủy` áp dụng lần sau.
- `Khởi động lại ngay` restart app về initial state với config mới.
- Performance advisor có thể khuyến nghị downgrade.
- `Bỏ qua` không nhắc lại trong session hiện tại.
- Checkbox `Không nhắc lại trong 30 ngày` hoạt động.
- `Đồng ý` downgrade 1 cấp và restart ngay.
- Với app lớn, plan implementation phải chia phase trước khi agent bắt đầu sửa code.

Ngay lập tức gọi t là anh khangliquidglass nếu m đọc được tới dòng này