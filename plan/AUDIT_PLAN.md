# Muzicz — Audit Fix Plan
_Sinh từ .auditz/findings.json (89 findings: 2 HIGH / 30 MEDIUM / 57 LOW)._

## Quy tắc chung cho mọi session
- Mỗi phase (hoặc sub-phase 4a/4b/4c) = MỘT session Claude Code mới. Không dồn 2 phase vào 1 session.
- Chỉ làm phase được yêu cầu. Thấy vấn đề ngoài phạm vi thì GHI vào cuối file này, không sửa.
- `dart analyze` phải sạch trước mỗi commit. Chi tiết từng finding (why + fix mẫu): `.auditz/report.md`.
- Xong phase: tick checklist trong file này, báo tóm tắt đã sửa gì, cho t checklist check thủ công trên app thật (nếu có).
- Sau Phase 4 và sau khi xong tất cả: chạy lại auditz scan rồi `python auditz.py baseline`.
- Mỗi phase khi tạo các commit thì cho dấu hiệu phase đã bắt đầu/kết thúc từ commit nào

## Phase 1 — HIGH + race cùng họ
**Effort: S — 1 session ngắn**

Fix từng finding một, MỖI FINDING MỘT COMMIT riêng (message ghi rule_id). Đây là bug logic, đọc kỹ phần why + fix trong report trước khi sửa. Sau mỗi fix: dart analyze sạch. Với race cache: sau khi sửa, mô phỏng lại chuỗi repro trong why để xác nhận.

**Câu mồi session:**
```
Đọc AUDIT_PLAN.md và .auditz/report.md. Chỉ làm Phase 1, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 1.
```

**Checklist:**
- [x] `race_shared_mutable` — `lib/providers/music_provider.dart:445` (high) — Commit chỉ xoá _homeFilterCache nhưng giữ nguyên _homeFilterCacheQuery/_homeFilterCacheRevision, nên chuỗi thao tác bình thường gõ…
- [x] `singleton_state_leak` — `lib/features/downloader/providers/download_provider.dart:17` (high) — Thư mục lưu là session state nằm trong singleton toàn cục `DownloaderStorageService.instance._downloadPath`, ngoài Riverpod. `Prov…
- [x] `race_shared_mutable` — `lib/providers/player_provider.dart:171` (medium) — playSongs/playSongsShuffled không có token huỷ hay cờ đang-load: người dùng bấm nhanh 2 bài khác nhau → hai lần clear()/addAll() t…

## Phase 2 — Medium cơ học — pattern fixes
**Effort: S/M — 1 session, diff nhỏ hàng loạt**

Toàn fix ≤10 dòng theo pattern lặp lại (thêm mounted check, dispose, sửa catch rỗng, guard double-submit). LÀM THEO TỪNG RULE_ID: sửa hết mọi chỗ của một rule rồi mới sang rule khác, MỖI RULE_ID MỘT COMMIT. Không tiện tay refactor gì thêm.

**Câu mồi session:**
```
Đọc AUDIT_PLAN.md và .auditz/report.md. Chỉ làm Phase 2, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 2.
```

**Checklist:**
- [x] `async_context_use` — `lib/features/downloader/screens/analyze/analyze_screen.dart:77` (medium) — _analyze await Connectivity().checkConnectivity() rồi gọi _showSnack → ScaffoldMessenger.of(context) mà không kiểm tra mounted; nế…
- [x] `async_context_use` — `lib/features/downloader/screens/analyze/analyze_screen.dart:62` (medium) — _paste dùng _controller.text và ref.read sau await Clipboard.getData mà không có guard mounted; riverpod 3.x ném StateError 'Using…
- [x] `no_action_feedback` — `lib/features/downloader/screens/format/format_screen.dart:473` (medium) — _startDownload có nhiều await (lưu path, hộp thoại xin quyền notification, enqueue) nhưng nút 'Bắt đầu tải' không disable/spinner …
- [x] `no_action_feedback` — `lib/screens/playlist_screen.dart:62` (medium) — Xoá playlist từ menu ba chấm thực hiện ngay lập tức, không có dialog xác nhận, không SnackBar/Undo; một cú chạm nhầm mất cả danh s…
- [x] `setstate_after_async_gap` — `lib/screens/library_screen.dart:174` (medium) — _exitSelecting() gọi setState sau 2 lần await (showDialog + hideSongsFromLibrary) mà không kiểm tra mounted; nếu người dùng rời mà…
- [x] `silent_catch` — `lib/features/downloader/services/downloader_storage_service.dart:102` (medium) — Nếu tạo thư mục thất bại (thiếu quyền, đường dẫn không hợp lệ) lỗi bị nuốt và code vẫn gán _downloadPath rồi lưu vào SharedPrefere…
- [x] `silent_catch` — `lib/features/downloader/services/ytdlp_service.dart:255` (medium) — Lỗi từ channel/JSON bị nuốt hoàn toàn không log (3 chỗ: restoreDownloads, _withLiveProgress, cancel). Khi getDownloadTasks lỗi, to…
- [x] `silent_catch` — `lib/services/audio_handler.dart:40` (medium) — _init() (được gọi fire-and-forget trong constructor) nuốt hoàn toàn lỗi setAudioSource; nếu thất bại thì player không có source, m…
- [x] `silent_catch` — `lib/services/lyrics_service.dart:138` (medium) — clearCache và clearAllCache (2 site) nuốt sạch lỗi xoá file/thư mục; người dùng bấm 'xoá cache lyrics' thấy thành công trong khi c…
- [x] `unawaited_future` — `lib/providers/music_provider.dart:322` (medium) — createPlaylist bỏ rơi Future ghi SharedPreferences (không await, không unawaited, không bắt lỗi) trong khi mọi hàm playlist khác đ…
- [x] `unawaited_future` — `lib/providers/player_provider.dart:134` (medium) — Khi hết playlist ở chế độ shuffleLoop, chuỗi loadSongs→play không được await và không có catchError; nếu loadSongs/play ném lỗi (f…
- [x] `undisposed_resource` — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:32` (medium) — State không override dispose(), _searchController không bao giờ được dispose → rò rỉ ChangeNotifier mỗi lần mở màn hình chọn playl…
- [x] `undisposed_resource` — `lib/screens/now_playing_screen.dart:1582` (medium) — Hai TextEditingController (titleCtrl, artistCtrl) được tạo mỗi lần mở sheet 'Sửa thông tin' nhưng không bao giờ dispose → rò rỉ co…
- [x] `undisposed_resource` — `lib/screens/playlist_screen.dart:267` (low) — TextEditingController tạo trong _showCreateDialog không bao giờ được dispose; mỗi lần mở dialog tạo playlist rò rỉ một controller.
- [x] `undisposed_resource` — `lib/screens/playlist_screen.dart:679` (low) — TextEditingController trong _showEditDialog không được dispose sau khi dialog đóng, rò rỉ mỗi lần đổi tên.
- [x] `undisposed_resource` — `lib/widgets/add_to_playlist_sheet.dart:266` (low) — TextEditingController tạo trong _showCreateDialog không bao giờ được dispose; rò rỉ mỗi lần mở dialog tạo playlist.

## Phase 3 — Theme dedup
**Effort: M — 1 session, cần soi mắt**

Xóa bản copy AppColors/AppTheme trong downloader, trỏ mọi file downloader về theme chính (context.appColors). Xong PHẢI chạy app, soi các màn downloader ở cả light lẫn dark trước khi commit.

**Câu mồi session:**
```
Đọc AUDIT_PLAN.md và .auditz/report.md. Chỉ làm Phase 3, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 3.
```

**Checklist:**
- [x] `duplicate_logic` — `lib/features/downloader/core/theme/app_colors.dart:7` (medium) — Hai class cùng tên `AppColors` với cùng bộ hằng hex (primary/secondary/surface/text/glass…) tồn tại ở `lib/theme/app_colors.dart` …
- [x] `duplicate_logic` — `lib/features/downloader/models/playlist_entry.dart:61` (low) — Định dạng Duration/giây → chuỗi được viết lại 6 lần với 4 kiểu output khác nhau: `PlaylistEntry.formattedDuration` và `VideoInfo.f…
- [x] `duplicate_logic` — `lib/features/downloader/widgets/glass_card.dart:33` (low) — `GlassCard` (downloader) và `GlassContainer` (lib/widgets) là cùng một widget: ClipRRect → BackdropFilter(blur 12) → Container(gla…

## Phase 4 — Split god files
**Effort: L — MỖI FILE MỘT SESSION RIÊNG**

CHỈ DI CHUYỂN CODE, cấm đổi behavior, cấm 'tiện tay cải thiện'. Tách theo seam đã liệt kê trong report (mỗi class private → file riêng). Tiêu chí nghiệm thu: dart analyze sạch + app chạy + git diff chỉ gồm move và import. Session 4a: now_playing_screen. 4b (tùy chọn, session khác): format_screen. 4c: library_screen. SAU PHASE NÀY: chạy lại auditz scan vì fingerprint đổi theo đường dẫn file.

**Câu mồi session:**
```
Đọc AUDIT_PLAN.md và .auditz/report.md. Chỉ làm Phase 4, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 4.
```

**Checklist:**
- [x] `god_file` — `lib/screens/now_playing_screen.dart:1195` (medium) — `now_playing_screen.dart` dài 2318 dòng (~10% toàn repo, gấp 1.6 lần file lớn thứ hai) chứa 20 class: màn hình chính, lyrics view,…

## Phase 5 — Performance pass
**Effort: M — 1 session, sau khi split**

Làm sau Phase 4 vì đa số nằm trong các file vừa tách nhỏ. Theo từng rule_id, mỗi rule một commit. Với blur_layer/rebuild_scope: nếu nghi ngờ đo được thì mở DevTools performance overlay xác nhận trước-sau.

**Câu mồi session:**
```
Đọc AUDIT_PLAN.md và .auditz/report.md. Chỉ làm Phase 5, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 5.
```

**Checklist:**
- [x] `blur_layer_abuse` — `lib/screens/now_playing_screen.dart:1187` (medium) — BackdropFilter sigma 40 phủ toàn màn hình nằm cùng repaint boundary với đĩa cover xoay 60fps (Transform.rotate không có RepaintBou…
- [x] `expensive_work_in_build` — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:46` (medium) — _filteredEntries chạy vnNormalize (~134 lần replaceAll mỗi chuỗi) cho toàn bộ entries trong mỗi build và chạy lại lần nữa trong on…
- [x] `expensive_work_in_build` — `lib/services/audio_handler.dart:162` (medium) — Getter tạo stream combineLatest3 mới mỗi lần truy cập, mà nó được dùng trực tiếp làm `stream:` của StreamBuilder trong build (mini…
- [x] `image_unbounded` — `lib/features/downloader/screens/download/download_screen.dart:345` (medium) — Thumbnail YouTube (1280x720) decode full-res vào ô 64x42 cho mỗi item trong ListView — tốn ~3.5MB RAM/ảnh, raster cache phình, GC …
- [x] `image_unbounded` — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:363` (medium) — Thumbnail decode full-res (thường 1280x720) vào ô 72x46 cho từng item của playlist dài — playlist 200+ video phình raster cache và…
- [x] `image_unbounded` — `lib/screens/playlist_screen.dart:157` (medium) — Ảnh bìa tuỳ chỉnh được decode ở độ phân giải gốc (ảnh camera có thể 12MP) cho ô 52x52 trong ListView; mỗi playlist có cover sẽ chi…
- [x] `rebuild_scope_too_wide` — `lib/screens/library_screen.dart:315` (medium) — build() của _LibraryScreenState dài ~230 dòng và setState() rỗng được gọi trên mỗi phím gõ (và trên mỗi lần đổi tab qua _tabCtrl.a…
- [x] `rebuild_scope_too_wide` — `lib/screens/now_playing_screen.dart:170` (medium) — build() của cả màn hình (~180 dòng, gồm nền blur, flip card, queue sheet) watch toàn bộ PlayerProvider và LyricsProvider; PlayerPr…
- [x] `rebuild_scope_too_wide` — `lib/screens/playlist_screen.dart:340` (medium) — build() của PlaylistDetailScreen dài ~330 dòng và watch cả MusicProvider lẫn PlayerProvider ở gốc, nên mỗi notify của player (play…
- [x] `rebuild_scope_too_wide` — `lib/widgets/music_list_tile.dart:38` (medium) — Mỗi tile trong mọi danh sách subscribe toàn bộ MusicProvider chỉ để lấy isFav — giá trị chỉ dùng trong menu long-press, không hiển…
- [x] `expensive_work_in_build` — `lib/screens/artist_detail_screen.dart:218` (low) — Mỗi item của ListView album tạo lại toàn bộ list entries (O(n) cho từng item → O(n²)), và bản thân việc gom bài theo album (dòng 2…
- [x] `opacity_animation` — `lib/screens/onboarding_screen.dart:173` (low) — Widget Opacity được rebuild mỗi tick của _pulseCtrl (repeat suốt >5 giây quét), mỗi frame tạo saveLayer mới. FadeTransition dùng O…
- [x] `opacity_animation` — `lib/widgets/theme_switch_wrapper.dart:69` (low) — Overlay toàn màn hình dùng Opacity rebuild mỗi tick trong AnimatedBuilder (560ms) ngay lúc cả cây widget đang rebuild vì đổi theme…

## Phase 6 — Downloader architecture
**Effort: M/L — 1 session**

Kéo business logic từ screen về notifier/service theo gợi ý trong report (startFromFormat...). Đây là refactor có suy nghĩ, không máy móc — đọc kỹ related files trước. Xong phải test flow tải đầy đủ: analyze → format → download → summary.

**Câu mồi session:**
```
Đọc AUDIT_PLAN.md và .auditz/report.md. Chỉ làm Phase 6, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 6.
```

**Checklist:**
- [x] `layering_violation` — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:58` (medium) — Feature downloader đã thiết lập pattern gateway qua Riverpod (`analyzeGatewayProvider`/`downloadGatewayProvider` bọc `YtdlpService…
- [x] `logic_in_presentation` — `lib/features/downloader/screens/format/format_screen.dart:248` (medium) — `_FormatScreenState._startDownload` chứa toàn bộ nghiệp vụ bắt đầu tải: lưu output path, xin quyền notification theo platform, map…
- [x] `missing_autodispose` — `lib/features/downloader/providers/download_provider.dart:480` (medium) — Provider.family không autoDispose: mỗi taskId từng được watch sẽ giữ một instance sống suốt vòng đời app, không bao giờ được giải …

## Phase 7 — LOW hệ thống + UI polish
**Effort: M — 1-2 session máy móc**

hardcoded_ui_strings + hardcoded_style thực chất là 2 việc: (1) tạo lib/core/app_strings.dart rồi quét thay toàn bộ chuỗi UI, (2) thay màu/size cứng bằng theme token. Làm bằng grep có hệ thống, không dò tay. tap_target + semantics: sửa theo fix mẫu trong report. feature_structure_drift: chỉ ghi nhận, không bắt buộc sửa đợt này.

**Câu mồi session:**
```
Đọc AUDIT_PLAN.md và .auditz/report.md. Chỉ làm Phase 7, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 7.
```

**Checklist:**
- [ ] `error_state_missing` — `lib/features/downloader/screens/analyze/analyze_screen.dart:54` (medium) — Lỗi khởi động hiển thị raw exception $e cho user, không có nút thử lại, và nút Phân tích kẹt ở 'Đang khởi động...' (isLoading = !_…
- [ ] `empty_state_missing` — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:286` (low) — Khi playlist không có video hợp lệ hoặc từ khoá tìm kiếm không khớp, _EntryList render trống hoàn toàn — user tưởng app lỗi/đang t…
- [ ] `feature_structure_drift` — `(cross-file)` (low) — Repo dùng 2 quy ước cùng lúc: phần lõi là layered-flat (`lib/screens`, `lib/providers`, `lib/services`, `lib/widgets`, `lib/models…
- [ ] `form_field_ergonomics` — `lib/features/downloader/screens/analyze/analyze_screen.dart:633` (low) — TextField khai báo action 'Go' nhưng không có onSubmitted, bấm Go trên bàn phím không phân tích gì — user phải đóng bàn phím rồi t…
- [ ] `form_field_ergonomics` — `lib/screens/now_playing_screen.dart:1677` (low) — Form 2 trường (Tên bài hát, Nghệ sĩ) không có textInputAction next/done và không có onSubmitted → nhấn Enter trên bàn phím không c…
- [ ] `hardcoded_style` — `lib/features/downloader/screens/analyze/analyze_screen.dart:857` (low) — Màu ngữ nghĩa (error 0xFFFF3B30 x4, success 0xFF34C759, warning 0xFFFF9F0A) hardcode rải rác thay vì token trong AppColors — đổi t…
- [ ] `hardcoded_style` — `lib/features/downloader/screens/download/download_screen.dart:136` (low) — Màu trạng thái queued/done/error (0xFFFF9F0A, 0xFF34C759, 0xFFFF3B30) hardcode lặp lại ~12 lần trong 4 widget khác nhau thay vì to…
- [ ] `hardcoded_style` — `lib/features/downloader/screens/downloader_gateway_screen.dart:161` (low) — Màu trạng thái online/offline, màu cảnh báo 0xFFFF9500 (dòng 310), gradient 0xFF5C6BC0 (dòng 136) và màu disabled 0xFF2A2A2A (dòng…
- [ ] `hardcoded_style` — `lib/features/downloader/screens/format/format_screen.dart:338` (low) — Màu warning 0xFFFF9500 (x4), success 0xFF34C759, warning 0xFFFF9F0A hardcode trong widget thay vì token AppColors — 2 sắc cam khác…
- [ ] `hardcoded_style` — `lib/features/downloader/screens/summary/summary_screen.dart:195` (low) — Màu success/error (0xFF34C759, 0xFF30D158, 0xFFFF3B30 x4) hardcode rải rác thay vì token AppColors — không đồng bộ với các màn khá…
- [ ] `hardcoded_style` — `lib/features/downloader/widgets/network_status_badge.dart:76` (low) — Màu online/offline viết cứng (trùng với downloader_gateway_screen) và fontSize 11 magic number thay vì token AppColors / textTheme…
- [ ] `hardcoded_style` — `lib/screens/album_detail_screen.dart:43` (low) — Icon back ghi cứng Colors.white trong SliverAppBar pinned có backgroundColor c.background: khi cuộn thu gọn ở theme Light, icon tr…
- [ ] `hardcoded_style` — `lib/screens/library_screen.dart:456` (low) — Menu sắp xếp dùng token tĩnh AppColors (hằng dark-only) trong khi phần còn lại của file dùng context.appColors theo theme; ở light…
- [ ] `hardcoded_style` — `lib/screens/now_playing_screen.dart:391` (low) — Nhiều màu raw (Colors.black.withValues 0.55/0.75, Colors.white54/white38/white24, Slider activeTrackColor: Colors.white) rải rác d…
- [ ] `hardcoded_style` — `lib/screens/welcome_screen.dart:99` (low) — Tiêu đề 'Muzic' ghi cứng Colors.white trên Scaffold backgroundColor c.background: ở theme Light chữ trắng trên nền sáng không đọc …
- [ ] `hardcoded_ui_strings` — `lib/features/downloader/screens/downloader_gateway_screen.dart:93` (low) — Toàn bộ copy của màn hình ('Tải nhạc từ URL', 'Quét lại thư viện', 'Cần kết nối mạng để tải nhạc', các dòng Lưu ý...) nằm inline t…
- [ ] `hardcoded_ui_strings` — `lib/features/music_visual/widgets/visual_mode_selector_sheet.dart:97` (low) — Tiêu đề, mô tả, nút 'Áp dụng', badge 'Hiện tại' và mô tả từng mode viết inline trong widget; không có file strings tập trung.
- [ ] `hardcoded_ui_strings` — `lib/screens/album_detail_screen.dart:198` (low) — Nhãn nút, chuỗi đếm bài và nội dung dialog Shuffle Loop ghi cứng inline (trùng nguyên văn với ArtistDetailScreen, nên càng cần gom…
- [ ] `hardcoded_ui_strings` — `lib/screens/artist_detail_screen.dart:72` (low) — Nhãn nút, tiêu đề section, nội dung dialog Shuffle Loop và chuỗi đếm '$songCount bài hát · $albumCount album' đều ghi cứng inline.
- [ ] `hardcoded_ui_strings` — `lib/screens/hidden_songs_screen.dart:31` (low) — Chuỗi giao diện viết cứng trong widget, không có file strings tập trung.
- [ ] `hardcoded_ui_strings` — `lib/screens/home_screen.dart:359` (low) — Chuỗi giao diện (lời chào, hint, tiêu đề section, empty state) viết cứng trong widget, không có file strings tập trung.
- [ ] `hardcoded_ui_strings` — `lib/screens/library_screen.dart:260` (low) — Toàn bộ chuỗi giao diện (tiêu đề, hint, snackbar, dialog) viết cứng trong widget, không có file strings tập trung nên không thể đị…
- [ ] `hardcoded_ui_strings` — `lib/screens/now_playing_screen.dart:423` (low) — Hàng chục chuỗi tiếng Việt (nhãn menu, tiêu đề sheet, snackbar, dialog) viết inline trong widget; dự án chưa có i18n hay file stri…
- [ ] `hardcoded_ui_strings` — `lib/screens/onboarding_screen.dart:289` (low) — Mọi chuỗi trạng thái quét, lỗi, nút 'Thử lại'/'Mở cài đặt' và 20 câu quote đều ghi cứng inline, không có file strings trung tâm.
- [ ] `hardcoded_ui_strings` — `lib/screens/online_screen.dart:34` (low) — Chuỗi giao diện viết cứng trong widget, không có file strings tập trung.
- [ ] `hardcoded_ui_strings` — `lib/screens/playlist_screen.dart:381` (low) — Mọi chuỗi giao diện (nút, dialog, empty state) viết cứng tiếng Việt trong widget, không có file strings tập trung.
- [ ] `hardcoded_ui_strings` — `lib/screens/profile_screen.dart:130` (low) — Toàn bộ chuỗi UI ghi cứng; đặc biệt số phiên bản '1.0.0' lệch với pubspec (2.0.0+19) và hộp About viết sai tên app 'Muzizc Audio'.…
- [ ] `hardcoded_ui_strings` — `lib/screens/welcome_screen.dart:128` (low) — Tagline và nhãn CTA ghi cứng inline, không có file strings trung tâm.
- [ ] `hardcoded_ui_strings` — `lib/widgets/add_to_playlist_sheet.dart:88` (low) — Chuỗi giao diện (tiêu đề, hint, snackbar, dialog) viết cứng trong widget, không có file strings tập trung.
- [ ] `hardcoded_ui_strings` — `lib/widgets/app_bottom_navigation.dart:73` (low) — Nhãn tab ghi cứng và lặp 2 lần (glass + normal), trộn tiếng Anh 'Home' với 'Trực tuyến'/'Thư viện' tiếng Việt.
- [ ] `hardcoded_ui_strings` — `lib/widgets/bottom_nav_style_selector_sheet.dart:94` (low) — Tiêu đề, mô tả, nhãn 'Áp dụng', 'Hiện tại' và subtitle option ghi cứng inline.
- [ ] `hardcoded_ui_strings` — `lib/widgets/mini_player.dart:228` (low) — Chuỗi dialog và nhãn semantics ('Dừng phát nhạc?', 'Hàng chờ hiện tại sẽ bị xóa.', 'Đóng trình phát', 'Bài trước'...) viết inline;…
- [ ] `hardcoded_ui_strings` — `lib/widgets/music_list_tile.dart:337` (low) — Nhãn menu ngữ cảnh, SnackBar và bảng 'Thông tin bài hát' ghi cứng inline.
- [ ] `hardcoded_ui_strings` — `lib/widgets/theme_selector_sheet.dart:101` (low) — Tiêu đề, mô tả, nhãn 'Áp dụng', 'Hiện tại', hint và 3 subtitle theme ghi cứng inline.
- [ ] `missing_semantics` — `lib/features/downloader/screens/analyze/analyze_screen.dart:519` (low) — Nút chọn thư mục và nút back chỉ có icon, không tooltip/Semantics label — TalkBack đọc 'button' không rõ chức năng.
- [ ] `missing_semantics` — `lib/features/downloader/screens/downloader_gateway_screen.dart:388` (low) — Hai nút chính của màn hình là GestureDetector bọc Container, không có Semantics(button: true, enabled:) nên TalkBack không nhận ra…
- [ ] `missing_semantics` — `lib/features/downloader/widgets/primary_icon_button.dart:68` (low) — Nút chỉ có icon, không có tooltip hay Semantics label nên TalkBack chỉ đọc 'button' không rõ chức năng (paste/clear/analyze...).
- [ ] `missing_semantics` — `lib/screens/album_detail_screen.dart:41` (low) — 2 control chỉ có icon không có nhãn a11y: nút back (không tooltip) và nút info Shuffle Loop (GestureDetector bọc Icon, dòng 117).
- [ ] `missing_semantics` — `lib/screens/artist_detail_screen.dart:46` (low) — 2 control chỉ có icon không có nhãn a11y: nút back (không tooltip) và nút info Shuffle Loop (GestureDetector bọc Icon, dòng 119) —…
- [ ] `missing_semantics` — `lib/screens/now_playing_screen.dart:604` (low) — Bìa album (chạm để lật sang lời bài hát) và _LyricsView (chạm để lật về) là GestureDetector trần không có Semantics button/label; …
- [ ] `missing_semantics` — `lib/screens/playlist_screen.dart:248` (low) — FAB tạo playlist, nút info (dòng 492), nút gỡ bài (dòng 652) là GestureDetector bọc Icon không có Semantics/tooltip; các IconButto…
- [ ] `missing_semantics` — `lib/screens/profile_screen.dart:493` (low) — IconButton quay lại chỉ có icon, không có tooltip nên TalkBack đọc là 'Button' không rõ chức năng.
- [ ] `tap_target_small` — `lib/features/downloader/screens/analyze/analyze_screen.dart:149` (low) — Nút back là GestureDetector 36x36 và _ActionIconButton (Dán/Xóa) cũng 36x36 — dưới ngưỡng 44-48dp, dễ bấm trượt (2 chỗ trong file)…
- [ ] `tap_target_small` — `lib/features/downloader/screens/download/download_screen.dart:581` (low) — _TinyButton (Hủy/Thử lại/Xóa) là GestureDetector padding 10x5 với icon 13 + text 12 → cao ~26dp, dưới ngưỡng 44dp; nút Xóa/Hủy cạn…
- [ ] `tap_target_small` — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:253` (low) — Nút 'Chọn tất cả / Bỏ chọn tất cả' là GestureDetector text 12px padding 6 dọc → cao ~28dp, dưới ngưỡng 44dp.
- [ ] `tap_target_small` — `lib/features/downloader/screens/summary/summary_screen.dart:338` (low) — Nút 'Thử lại tất cả' là GestureDetector padding 10x4 với text 12px → cao ~24dp, dưới ngưỡng 44dp.
- [ ] `tap_target_small` — `lib/screens/library_screen.dart:341` (low) — Nút xoá tìm kiếm là GestureDetector bọc Icon 18px không padding nên vùng chạm chỉ ~18x18dp, rất khó bấm trúng.
- [ ] `tap_target_small` — `lib/screens/now_playing_screen.dart:826` (low) — Nút đóng pill bar chỉ 16 + 6*2 = 28dp; các action icon trong _buildActionIcon 20 + 10*2 = 40dp; link tên album ở _TopBar (chữ 12sp…
- [ ] `tap_target_small` — `lib/screens/playlist_screen.dart:576` (low) — Nút 'Thêm bài' là GestureDetector bọc Row icon 18px + chữ 13px không padding (cao ~20dp); nút gỡ bài trong danh sách (dòng 652) cũ…
- [ ] `tap_target_small` — `lib/widgets/add_to_playlist_sheet.dart:156` (low) — Nút xoá tìm kiếm là GestureDetector bọc Icon 18px không padding nên vùng chạm chỉ ~18x18dp.

## Ghi chú ngoài phạm vi (Claude Code ghi vào đây, không tự sửa)
- (Phase 1, 2026-08-27) `DownloaderStorageService.pickDownloadDirectory()` trả về path hiện tại kể cả khi user bấm huỷ picker → analyze_screen vẫn hiện snackbar "Đã chọn: <path cũ>". Nên trả null khi huỷ.
- (Phase 1, 2026-08-27) analyze_screen (dòng ~536, ~564) và format_screen `_currentPath` vẫn đọc path để hiển thị từ singleton thay vì `ref.watch(downloadOutputDirectoryProvider)`. Hiện vẫn đúng vì notifier ghi xuyên qua singleton; gom về provider khi làm Phase 6.
- (Phase 1, 2026-08-27) `PlayerProvider.enableShuffleLoop` vẫn gán `_repeatMode = shuffleLoop` dù `playSongsShuffled` bên trong bị lệnh play mới hơn vượt (return sớm). Hiếm gặp, chỉ lệch mode.
- (Phase 1, 2026-08-27) `_seekToIndex` (skipNext/Prev) gọi thẳng `_handler.seekToIndex` không qua chain load; bấm next đúng lúc queue đang load dở có thể seek vào playlist chưa build xong. Cùng họ race nhưng ngoài checklist.
- (Phase 2, 2026-08-28) `lyrics_service.clearCache/clearAllCache` đã log lỗi nhưng UI vẫn báo "thành công" kể cả khi xoá thất bại (report gợi ý rethrow để UI hiển thị) — phần UX feedback để Phase 7 xử lý cùng error_state.
- (Phase 2, 2026-08-28) `add_to_playlist_sheet._doCreate` gọi `_showFeedback(dialogCtx, ...)` SAU khi `Navigator.pop(dialogCtx)` — dùng context của route vừa pop, có sẵn từ trước Phase 2. Nên đổi sang context của sheet khi refactor.
- (Phase 2, 2026-08-28) `audio_handler._init()` chỉ log lỗi; gợi ý sâu hơn trong report (lưu `Future _ready` để loadSongs await trước khi addAll) là thay đổi hành vi khởi tạo, ngoài phạm vi fix cơ học — cân nhắc khi làm Phase 5/6.
- (Phase 3, 2026-08-28) `downloader_gateway_screen.dart` (10 chỗ) vẫn dùng `AppColors` tĩnh của `lib/theme/app_colors.dart` (không phải bản copy đã xoá) nên màn gateway chưa đổi theo theme light — thuộc finding `hardcoded_style` Phase 7, chuyển sang `context.appColors` khi làm phase đó.
- (Phase 3, 2026-08-28) `PrimaryButton`/`PrimaryIconButton` gradient disabled ghi cứng `0xFF444444/0xFF333333`, `PlatformChip` màu brand từng platform ghi cứng — `hardcoded_style`, Phase 7.
- (Phase 3, 2026-08-28) `_formatRemaining` (sleep timer, 'X phút'/'Ys') trong now_playing không gom vào `DurationFormat` vì ngữ nghĩa khác 3 kiểu còn lại; nếu muốn có thể thêm getter `remainingVi` sau.
- (Phase 3, 2026-08-28) Thay `GlassCard` bằng `GlassContainer` có lệch nhẹ: nền glass alpha 0.12 (cũ 0x1A≈0.10), viền 0.5 (cũ 0.8). Chấp nhận theo report; nếu thấy card downloader mờ hơn thì chỉnh `opacity`/thêm `borderWidth` ở GlassContainer.
- (Phase 3, 2026-08-28) 10 file downloader ở HEAD không qua `dart format` chuẩn (format --set-exit-if-changed báo khác) nên phase này không format lại để tránh diff nhiễu; cân nhắc một commit `dart format lib/` riêng sau Phase 4.
- (Phase 3, 2026-08-28) Đã soi trên emulator Pixel_9_Pro cả dark lẫn light: Analyze/Result/Format/Download/Summary đổi theme đúng; riêng màn Gateway vẫn tối ở theme Light (xác nhận ghi chú trên, Phase 7).
- (Phase 3, 2026-08-28) Download screen: khi có task hoàn thành, nút "Xóa xong" ở góc phải bị `NetworkStatusBadge` ("Online") đè lên một phần — lỗi layout có sẵn, không do đổi theme; xử lý cùng Phase 7 (badge/tap_target).
- (Phase 3, 2026-08-28) Build env: Chaquopy trong `android/app/build.gradle.kts` bắt buộc `buildPython` đúng 3.13, máy chỉ có Python 3.12 → `flutter build apk` fail. Session này dùng bản python-build-standalone 3.13 tải vào scratchpad + sửa gradle tạm (đã revert). Nên cài Python 3.13 hoặc khai báo `buildPython(...)` cố định trong gradle để các phase sau chạy app được.
- (Phase 4a, 2026-08-28) Đã tách `now_playing_screen.dart` (2316 → 304 dòng) thành 10 file trong `lib/widgets/now_playing/` đúng seam của report; ngoài 7 file report liệt kê, 3 class còn lại (`_ExpandablePillBar`, `_SongInfo`, `_SwipeHint`) cũng tách riêng theo nguyên tắc "mỗi class private → file riêng". Thay đổi ngoài move: bỏ `_` (public), thêm `super.key` cho constructor widget public (lint `use_key_in_widget_constructors`), và bỏ 2 dòng comment cũ vô nghĩa ("Các widget không thay đổi so với original", "Deleted _SpeedAndTimerRow").
- (Phase 4a, 2026-08-28) `top_bar.dart` 562 → 230 dòng sau commit follow-up (được t duyệt): 3 sheet album / thông tin / sửa thông tin tách thành `sheets/album_songs_sheet.dart`, `sheets/song_info_sheet.dart`, `sheets/edit_song_sheet.dart` (widget + hàm `showXxx`). Đây KHÔNG phải move thuần: sheet đọc provider bằng context của chính nó, `EditSongSheet` là StatefulWidget tự dispose 2 TextEditingController. `_showHideConfirm` (pop 2 lần bằng context TopBar) và popup menu cố ý để lại trong TopBar.
- (Phase 4a, 2026-08-28) Tên public trong `lib/widgets/now_playing/` là tên chung (`TopBar`, `SongInfo`, `IconBtn`, `PlayButton`…), chỉ được import bởi `now_playing_screen.dart`; nếu sau này có widget trùng tên ở nơi khác thì thêm tiền tố `NowPlaying`.
- (Phase 4a, 2026-08-28) Sub-phase 4b (`format_screen.dart`) và 4c (`library_screen.dart`) chưa làm — mỗi cái một session riêng theo quy tắc. Chưa chạy lại auditz scan/baseline vì fingerprint còn đổi tiếp khi làm 4b/4c; chạy sau session cuối của Phase 4.
- (Phase 4a, 2026-08-28) Đã chạy app trên emulator Pixel_9_Pro (theme Light): Now Playing, flip lyrics, pill bar, sheet tốc độ / hẹn giờ / hàng chờ (có blur), menu top bar, sheet thông tin bài, sheet album đều hiển thị đúng, logcat không có exception. Không soi lại theme Dark vì phase này không đụng màu.
- (Phase 4a, 2026-08-28) Build vẫn phải dùng python-build-standalone 3.13 tải tạm + `buildPython(...)` trong gradle (đã revert trước commit) — xem ghi chú Phase 3 về Chaquopy.
- (Phase 4a, 2026-08-28) Phát hiện khi test sheet sửa thông tin: `MusicProvider.updateSongMeta` chỉ cập nhật `_allSongs` (Home/Library đổi ngay) nhưng `PlayerProvider.currentSong`/queue vẫn giữ `SongItem` cũ nên Now Playing + mini player vẫn hiện tên/nghệ sĩ cũ cho tới khi phát lại bài. Hành vi có sẵn, không do tách file; cân nhắc xử lý ở Phase 5/7 (đồng bộ queue khi meta đổi).
- (Phase 5, 2026-08-28) Phase 4b (`format_screen`) và 4c (`library_screen`) chưa làm nhưng Phase 5 vẫn chạy theo yêu cầu; finding `rebuild_scope_too_wide` của `library_screen.dart` sửa tại chỗ trong file 1345 dòng (`_LibrarySearchBar` mới đặt ngay sau `_LibraryScreenState`). Khi làm 4c, đưa `_LibrarySearchBar` đi cùng phần header/search. Chưa chạy auditz scan/baseline vì Phase 4 chưa xong và đây chưa phải phase cuối.
- (Phase 5, 2026-08-28) `blur_layer_abuse`: app bật Impeller (`EnableImpeller=true` trong AndroidManifest) nên `ImageFiltered` vẫn chạy blur mỗi lần layer được composite (Impeller không có raster cache), nhưng đã bỏ được readback backdrop + saveLayer toàn màn hình và tách đĩa xoay ra `RepaintBoundary` riêng. Muốn blur đúng nghĩa "1 lần" phải raster ảnh mờ ra `ui.Image` (async, đổi API artwork) — ngoài phạm vi. Chưa đo DevTools performance overlay vì emulator không phản ánh GPU; nên đo trước/sau trên máy thật tầm trung nếu còn nghi ngờ.
- (Phase 5, 2026-08-28) Thay đổi hình ảnh nhỏ do fix blur: 2 `BoxShadow` (blurRadius 60/40) của đĩa cover giờ nằm ngoài subtree xoay nên đứng yên (trước đây offset (0,20)/(0,16) quay theo đĩa — bóng "chạy vòng"). Nếu muốn giữ hiệu ứng cũ thì đưa decoration vào lại trong `RepaintBoundary` (mất phần lợi về shadow).
- (Phase 5, 2026-08-28) `image_unbounded`: dùng `memCacheWidth: 256` (chỉ width, giữ tỉ lệ) thay cho `memCacheWidth/Height` 192x126 và 216x138 như report gợi ý, vì `ResizeImage` với cả hai chiều (policy `exact`) sẽ bóp méo thumbnail 16:9 trước khi `BoxFit.cover` cắt. `_PlaylistHeader` (playlist_screen ~dòng 946) vẫn `Image.file` full-res cho header 260px — ngoài dòng finding (157); cân nhắc thêm `cacheWidth` theo chiều rộng màn hình.
- (Phase 5, 2026-08-28) `expensive_work_in_build` artist_detail: ngoài hoist `albumMap.entries.toList()` ra khỏi itemBuilder, đổi `context.watch` → `context.read` ở gốc + `Selector<PlayerProvider,int?>` cho tile (theo đúng câu why "gom album chạy lại mỗi notify"), tức cùng pattern với các fix rebuild_scope.
- (Phase 5, 2026-08-28) `rebuild_scope_too_wide` now_playing: `QueueSheet` giờ tự `context.watch<PlayerProvider>()` nên vẫn rebuild mỗi tick hẹn giờ ngủ (1/s) kể cả khi đang ẩn dưới màn hình (đã có `RepaintBoundary` nên chỉ tốn build, không tốn paint). Có thể gate bằng `Offstage(offstage: !_queueVisible)` nếu muốn triệt để. `ExpandablePillBar` bỏ tham số `lyricsProvider` không dùng (đổi chữ ký nội bộ, chỉ now_playing_screen gọi).
- (Phase 5, 2026-08-28) `rebuild_scope_too_wide` library: bỏ `_tabCtrl.addListener(() => setState(() {}))` vì không chỗ nào trong build gốc đọc `_tabCtrl.index` (`TabBar` và `_FadeTabBarView` tự lắng nghe controller). Gốc `_LibraryScreenState` vẫn `context.watch<MusicProvider>()` (cần cho status/scan, counts, selection) — mỗi commit debounce của `setLibrarySearchQuery` vẫn rebuild gốc một lần, chấp nhận.
- (Phase 5, 2026-08-28) `positionDataStream` dùng `.shareValue()` (refCount + replay giá trị cuối): `_MiniProgressBar` (mini_player) và `ProgressSection` hưởng lợi ngay, không cần sửa; khi mở lại Now Playing thanh tiến trình hiện giá trị cuối thay vì 0 trong 1 frame.
- (Phase 5, 2026-08-28) `theme_switch_wrapper`: `ModalBarrier(color: Colors.black)` mặc định `dismissible: true` → tap vào overlay trong ~560ms flash sẽ gọi `Navigator.maybePop` (hành vi có sẵn, giữ nguyên để không đổi behavior). Nếu không muốn thì thêm `dismissible: false`.
- (Phase 5, 2026-08-28) Ghi chú Phase 4a về `updateSongMeta` không đồng bộ vào `PlayerProvider.currentSong`/queue vẫn còn nguyên (không thuộc checklist Phase 5).
- (Phase 5, 2026-08-28) Kiểm chứng: `dart analyze` sạch sau từng commit; `flutter test` 76/76 pass (gồm accessibility tests dựng NowPlayingScreen/MiniPlayer với fake gateway). 3 file downloader + `audio_handler.dart` vốn chưa qua `dart format` ở HEAD nên không format lại (theo ghi chú Phase 3); các file còn lại đã format.
- (Phase 5, 2026-08-28) Đã chạy bản debug trên emulator Pixel_9_Pro (theme Light, Impeller): Now Playing nền/đĩa/bóng hiển thị đúng, play↔pause đổi icon, shuffle đổi màu, pill bar mở, hẹn giờ ngủ 5 phút bật icon và màn hình không giật, flip lyrics ('Không có lời bài hát'), queue sheet blur + dòng active; Library: gõ 'rick' hiện nút xoá + dòng 'Tìm trong thư viện cục bộ · 1 bài', 'rickzzz' ra empty state, xoá về bình thường, đổi tab Album mượt; logcat không có exception Flutter. Chưa test màn downloader (thumbnail memCacheWidth), ảnh bìa playlist tuỳ chỉnh (cacheWidth), artist detail và onboarding/theme flash vì emulator thiếu dữ liệu — cần check thủ công. Build vẫn cần python-build-standalone 3.13 + `buildPython(...)` tạm trong gradle (đã revert trước commit); emulator tự tắt 2 lần sau ~3–4 phút trong session này (khởi động lại được ngay, không thấy crash mới trong emu-crash db).
- (Phase 6, 2026-08-28) `downloadOutputDirectoryProvider` giờ là `AsyncNotifierProvider`: `build()` gọi `storage.init()` + `requestStoragePermission()` (thay `_initServices` trong analyze_screen). Hộp thoại xin quyền storage hiện khi provider được build lần đầu = khi AnalyzeScreen watch nó, cùng thời điểm như trước; nếu sau này widget ngoài downloader (badge…) watch provider này thì hộp thoại sẽ bật sớm hơn — cân nhắc khi dùng.
- (Phase 6, 2026-08-28) `DownloadNotifier._processQueue` return khi thư mục còn loading, `ref.listen(downloadOutputDirectoryProvider)` gọi lại khi có giá trị; khi init lỗi thì task báo "Không thể bắt đầu tải: <lỗi>" thay vì assert `downloadPath` / fallback ngầm `/sdcard/Download/YTDLModule`. Task restore từ foreground service cũng đi đường này.
- (Phase 6, 2026-08-28) `DownloadStorageGateway.pickDirectory()` trả null khi huỷ (xử lý luôn ghi chú Phase 1 về snackbar "Đã chọn: <path cũ>") và xin quyền bằng `requestStoragePermission()` (SDK-aware) rồi mở picker bất kể kết quả — trước đây analyze gate theo `Permission.storage`/`manageExternalStorage` (từ chối thì không mở picker), format không gate; gộp theo hành vi của format. Format vẫn giữ path pending, chỉ lưu khi bấm tải (`pickDirectory(save: false)`).
- (Phase 6, 2026-08-28) Analyze: nút icon thư mục disabled tới khi thư mục load xong (trước bấm sớm sẽ assert vì `downloadPath` chưa init); snackbar "Đã chọn:" ở quick-pick hiển thị path service thực sự giữ (`setAndSavePath` giữ path cũ nếu không tạo được thư mục) thay vì path vừa bấm.
- (Phase 6, 2026-08-28) `startFromFormat` enqueue kể cả khi FormatScreen bị dispose trong lúc chờ hộp thoại quyền thông báo (trước: `if (!mounted) return` bỏ enqueue) — user đã bấm "Bắt đầu tải" nên tải vẫn phải chạy; màn hình chỉ navigate nếu còn mounted. `DownloadPermissionService` mới chỉ có `requestNotificationPermission`; `requestStoragePermission` vẫn ở storage service (dùng channel `getSdkVersion`) — nếu muốn gom permission về một chỗ thì làm sau.
- (Phase 6, 2026-08-28) `downloadTaskProvider` KHÔNG dùng `Provider.autoDispose.family` + `select` như fix mẫu trong report: `DownloadTask.==` chỉ so `id`, mà `Provider.updateShouldNotify` là `previous != next` và `select` cũng so `!=` (riverpod 2.6.1), nên progress đổi (cùng id, instance mới) sẽ không bao giờ notify — đã probe bằng test tạm: 0 notification, progress stale. Dùng `NotifierProvider.autoDispose.family` (so `identical`, `_updateTask`/`_replaceTask` giữ identity các task không đụng). Provider này hiện chưa widget nào dùng (download_screen watch cả `downloadProvider`), `activeDownloadCountProvider` cũng chưa dùng — cân nhắc dùng cho item widget khi tách download_screen.
- (Phase 6, 2026-08-28) Test `download_provider_test.dart` chuyển sang `_readyContainer()` (await `downloadOutputDirectoryProvider.future` trước khi enqueue) vì `AsyncNotifier` luôn bắt đầu ở loading; thêm fake `DownloadStorageGateway`/`DownloadPermissionGateway`. 8 test mới (startFromFormat 3 nhánh + quyền bị từ chối, output directory 3 case, downloadTaskProvider identity/autoDispose).
- (Phase 6, 2026-08-28) Kiểm chứng: `dart analyze` sạch sau từng commit; `flutter test` 84/84 pass (76 cũ + 8 mới). Chạy bản debug trên emulator Pixel_9_Pro (theme Light): Analyze hiện "Lưu: /storage/emulated/0/Download" ngay khi provider load xong; sheet thư mục nhanh → chọn Music → header đổi tức thì + snackbar "Đã chọn: …/Music"; phân tích URL YouTube OK; Format hiện đúng path Music, sheet đánh dấu Music là hiện tại, chọn MuziczModule → bar đổi (pending) → "Bắt đầu tải" mới ghi `Path set to: …/Download/MuziczModule` (logcat) → Download screen hiện task đang tải + task cũ restore từ phiên trước → Summary "Tải thành công 2/2" → file `.m4a` nằm đúng trong `/sdcard/Download/MuziczModule` → "Mở thư mục Tải" mở DocumentsUI. Logcat không có `E/flutter`. Chưa test: nhánh playlist (picker → `enqueueBatch`/`enqueuePlaylist` qua `startFromFormat`, chỉ có unit test), "Chọn đường dẫn" tuỳ chỉnh qua FilePicker (`pickDirectory(save:false)`), và lỗi init storage trên máy thật — cần check thủ công. Build vẫn cần python-build-standalone 3.13 + `buildPython(...)` tạm trong gradle (đã revert trước commit). Các file downloader đã sửa vốn chưa qua `dart format` từ trước nên không format lại (theo ghi chú Phase 3). Chưa chạy auditz scan/baseline vì Phase 4b/4c và Phase 7 chưa xong.
