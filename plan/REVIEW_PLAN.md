# Muzicz — Review Fix Plan (2026-09-03)
_Sinh từ session review toàn project ngày 2026-09-03 (Claude Code), sau khi AUDIT_PLAN.md xong Phase 7. Đánh số phase tiếp theo AUDIT_PLAN (8 → 14) để tag commit `[phaseN-start]` / `[phaseN-end]` không trùng._

## Quy tắc chung cho mọi session
- Mỗi phase = MỘT session Claude Code mới. Không dồn 2 phase vào 1 session.
- Chỉ làm phase được yêu cầu. Thấy vấn đề ngoài phạm vi thì GHI vào cuối file này ("Ghi chú ngoài phạm vi"), không sửa.
- `dart analyze` sạch và `flutter test` pass trước mỗi commit. Mỗi finding (hoặc mỗi nhóm cơ học cùng loại) một commit, message ghi tag trong checklist; commit đầu phase gắn `[phaseN-start]`, commit docs tick checklist gắn `[phaseN-end]`.
- Xong phase: tick checklist trong file này, ghi "Kiểm chứng" (analyze/test/emulator) vào "Ghi chú ngoài phạm vi", báo tóm tắt và đưa checklist check tay trên máy thật.
- Mục đánh dấu **[CHỜ QUYẾT ĐỊNH]** / **[CHỜ DUYỆT]**: hỏi t trước khi làm, không tự chọn.
- Build local cần Python 3.13 cho Chaquopy (xem ghi chú Phase 3/4a trong AUDIT_PLAN.md).

## Quyết định đã chốt (2026-09-03)
- Sửa bug thanh tiến trình đứng (Phase 8) ngay trong session review, 1 commit riêng + test hồi quy.
- Được xoá: nhóm file rác (Phase 9 A), code chết đã xác minh không có caller (Phase 9 B), `cupertino_icons` trong pubspec (Phase 9 C).
- App KHÔNG lên Play Store → giữ `MANAGE_EXTERNAL_STORAGE`, chỉ sửa cách xin quyền (không bật màn cài đặt mỗi lần mở Analyze).
- Keystore release: t nói "có vẻ là rồi" → Phase 13 hỏi vị trí file trước khi nối vào gradle (KHÔNG commit keystore).
- Làm theo từng phase, mỗi phase một session, như AUDIT_PLAN.

## Câu hỏi còn mở (trả lời trước khi làm phase tương ứng)
1. **Hết hàng chờ khi không bật lặp (Phase 10).** Hiện tại: bài cuối kết thúc, nhạc im nhưng app vẫn coi là "đang phát" (nút hiện icon tạm dừng, đĩa vẫn xoay); bấm nút đó rồi bấm lại không phát gì vì `play()` của just_audio không tự quay về 0. Chọn một:
   - A. Tạm dừng và đưa bài cuối về 0:00 (nút hiện "play", bấm thì phát lại bài cuối).
   - B. Tạm dừng và quay về bài đầu hàng chờ (bấm play thì nghe lại từ đầu danh sách). **Khuyên B.**
   - C. Giữ như hiện tại.
2. **"Phát tiếp theo" trong menu bài hát (Phase 10).** Hiện nó thêm bài vào CUỐI hàng chờ: hàng chờ 50 bài thì 49 bài nữa mới tới. Chọn một:
   - A. Chèn ngay sau bài đang phát, đúng nghĩa tên nút. **Khuyên A.**
   - B. Giữ hành vi, đổi tên nút thành "Thêm vào hàng chờ".
   - C. Có cả hai nút.
3. **Preset video của downloader cần ffmpeg (Phase 12).** Các preset "Tốt nhất / 1080p / 720p / 480p" dùng selector `bestvideo+bestaudio`: yt-dlp tải hình và tiếng thành 2 file rồi cần ffmpeg để ghép, nhưng APK chỉ có yt-dlp. Khả năng cao ra file mp4 không tiếng kèm 1 file m4a rời. Bước 1 (làm trước, không cần quyết định): tải thử 1 video YouTube 1080p trên máy thật để xác nhận. Nếu đúng, chọn một:
   - A. Đóng gói ffmpeg vào APK (nặng thêm vài chục MB, cần kiểm tra cách nhúng cùng Chaquopy).
   - B. Chỉ hiện các stream có sẵn cả hình lẫn tiếng (YouTube thường tối đa 720p mp4), preset cao hơn bị ẩn. **Khuyên B.**
4. **Keystore release (Phase 13).** File keystore đang ở đâu (đường dẫn local, KHÔNG đưa vào repo)? CI trên GitHub có cần ký bằng keystore đó không (phải thêm secrets), hay chỉ build local là đủ?
5. **Chờ duyệt xoá/sửa thêm** (chưa nằm trong danh sách đã duyệt):
   - POC Visualizer (`lib/features/music_visual/poc/**`, `AndroidVisualizerPocPlugin.kt`, quyền `RECORD_AUDIO`): xoá hẳn, hay chỉ ẩn ở bản release (`kDebugMode`)?
   - `flutter_launcher_icons` chuyển sang `dev_dependencies` + xoá block placeholder `path/to/image.png` cho web/windows/macos.
   - Manifest: bỏ `ACCESS_WIFI_STATE`, `RECEIVE_BOOT_COMPLETED` (không có consumer).
   - `.auditz/report.md`: sinh lại được từ `findings.json` (có sẵn why/fix) nhưng AUDIT_PLAN Phase 4b/4c vẫn tham chiếu; xoá luôn hay giữ tới khi xong 4b/4c?

## Phase 8 — Bug thanh tiến trình đứng sau khi đóng mini player
**Effort: S — làm trong session review 2026-09-03**

Nguyên nhân: `positionDataStream` dùng `.shareValue()` (rxdart 0.27.7). Khi ấn X trên mini player, `stopAndClear()` đặt currentSong = null, mọi StreamBuilder bị dispose, listener về 0 → `refCount()` đóng BehaviorSubject bên dưới (`ConnectableStreamSubscription.cancel()` gọi `_subject.close()`); bài sau subscribe lại chỉ nhận giá trị cuối + done. Hồi quy từ commit 1faa85b (Phase 5). rxdart 0.28 hành vi giống hệt nên không nâng. Âm thanh vẫn phát từ 0, chỉ UI (thanh tiến trình, lyrics sync, waveform, pulse bìa) đứng.

**Checklist:**
- [ ] `position_stream_closed` — `lib/services/audio_handler.dart:169` (high) — Thay `.shareValue()` bằng `PositionDataFeed`: BehaviorSubject được nuôi bởi 1 subscription cố định tới combineLatest3, sống suốt vòng đời handler, replay giá trị cuối cho listener mới, không đóng khi hết listener. Test hồi quy `test/services/position_data_feed_test.dart` (listen → cancel hết → listen lại vẫn nhận cập nhật).

**Check tay trên máy thật:** phát bài → mở Now Playing → đóng → ấn X → phát bài khác: thanh tiến trình mini player + Now Playing chạy tiếp, lyrics sync/waveform chạy; lặp lại 2-3 lần.

## Phase 9 — Dọn dẹp đã duyệt (file rác, code chết, dependency)
**Effort: S — 1 session, chỉ xoá, không refactor**

Trước khi xoá từng mục: grep lại symbol trong `lib/` + `test/` để chắc không có caller (danh sách dưới đã xác minh ngày 2026-09-03 nhưng code có thể đổi). Mỗi nhóm (A/B/C) một commit. Không đụng các mục trong câu hỏi 5.

**Câu mồi session:**
```
Đọc plan/REVIEW_PLAN.md. Chỉ làm Phase 9, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 9.
```

**Checklist A — file:**
- [ ] `stray_file` — `promt.md` (root) — prompt lập kế hoạch cũ 27KB, không thuộc source; xoá (hoặc MOVE vào `plan/old_plan/` nếu t muốn giữ lịch sử).
- [ ] `generated_output` — `audit/flutter_analyze.txt` — output của `scripts/flutter_analyze.bat`, cũ từ 2026-08-14, chứa tên máy; xoá và thêm `audit/` vào `.gitignore`.
- [ ] `generated_output` — `.auditz/findings.sarif` — sinh từ `auditz.py`; xoá, thêm vào `.gitignore`. (`.auditz/report.md`: xem câu hỏi 5.)
- [ ] `unused_asset` — `assets/screenshots/z7674788519808_a0bf243ef3e2faa0031fa0fe5e97694c.jpg` — README không dùng; xoá.
- [ ] `dead_file` — `lib/theme/app_colors.dart` (172 dòng) — không file nào import; xoá cùng 2 dòng comment `AppColors.` ở `lib/screens/playlist_screen.dart:298-302`.
- [ ] `dead_file` — `lib/features/downloader/services/audio_extract_service.dart` — 100% comment; xoá.
- [ ] `dead_file` — `lib/features/downloader/utils/fake_progress.dart` — chỉ còn 2 dòng comment tham chiếu ở `download_provider.dart:156,387`; xoá cả file lẫn comment.
- [ ] `placeholder_test` — `test/widget_test.dart` — chỉ `expect(true, isTrue)`; xoá.

**Checklist B — code chết (đã xác minh không có caller ngoài file khai báo):**
- [ ] `lib/services/audio_handler.dart:9,139-140` — `typedef VoidCallback` (che VoidCallback của Flutter), `seekToNext`, `seekToPrevious`.
- [ ] `lib/services/audio_handler.dart` `setShuffleModeEnabled` + `PlayerAudioGateway.setShuffleModeEnabled` — tham số bị bỏ qua (luôn false), shuffle làm ở Dart; bỏ khỏi gateway, bỏ lời gọi trong `PlayerProvider.toggleShuffle` (`player_provider.dart:270`) và 4 fake gateway trong `test/`.
- [ ] `lib/providers/music_provider.dart:47-48,80,118` — `scanCount`/`_lastNotifiedCount`/`onProgress` (scanner chỉ gọi 1 lần cuối), `searchQuery`, `setSearchQuery` (`searchQuery` xuất hiện 4 lần trong lib — grep kỹ trước khi xoá).
- [ ] `lib/services/storage_service.dart:146-154` — `removeMetaOverride`.
- [ ] `lib/services/music_scanner.dart:48-56,118-134` — `checkPermission`, `scanAlbums`, `scanArtists`.
- [ ] `lib/providers/lyrics_provider.dart` — `reset`, `clearCacheForCurrent` (tính `id` rồi không dùng), `clearAllCache`; `lib/services/lyrics_service.dart` — `clearCache`, `clearAllCache`, `LyricsResult.isPlain` (:38), `errorMessage` (:35, gán nhưng không đọc); `lib/models/lyric_line.dart:13,16` — `isSynced`, `toString`.
- [ ] `lib/providers/theme_provider.dart:65-66,118-122` — `isSwitching`, `cycleTheme`.
- [ ] `lib/models/playlist_item.dart:7,32-36` — `coverPath` (không nơi nào gán → nhánh `Image.file` ở `playlist_screen.dart:222-237,972-973` không bao giờ chạy), `reorder`.
- [ ] `lib/models/song_item.dart:13-14` — `size`, `track` chỉ được copy trong `_applyOverride`, không đọc. Kiểm tra `fromAudioQuery`/JSON trước khi bỏ.
- [ ] `lib/screens/welcome_screen.dart:139-150,251-318` — khối comment + `_OutlinedButton`/`_OutlinedButtonState`.
- [ ] `lib/screens/library_screen.dart:248-256,360-367` và `lib/screens/online_screen.dart:24-33` — nhánh `isEmbedded == false` (chỉ được dựng với `isEmbedded: true` ở `home_screen.dart:36-37`); bỏ tham số luôn.
- [ ] `lib/widgets/music_list_tile.dart:20,32` — tham số `index` không đọc; `showAlbumArt` không bao giờ truyền false.
- [ ] `lib/screens/profile_screen.dart:286-289,642-643` — comment cũ, `Opacity(opacity: 1.0)` vô nghĩa; `lib/widgets/now_playing/sheets/edit_song_sheet.dart:56` — ternary chết `t.isEmpty ? song.title : t` trong `if (t.isNotEmpty)`.
- [ ] `lib/features/downloader/providers/download_provider.dart:386-395,420-455,477-555` — khối legacy comment; `isOnlineProvider`, `activeDownloadCountProvider` (0 widget dùng — `downloadTaskProvider` GIỮ vì có test + dự định dùng khi tách download_screen).
- [ ] `lib/features/downloader/models/download_task.dart:3,83-84,101,132,164-224` — field `Process` kéo `dart:io` vào model, `applyLogLine` không dùng; `core/constants/app_constants.dart` — chỉ `defaultDownloadFolder`/`maxConcurrentDownloads` được dùng, comment "libytdlp.so" cũ; `core/app_router.dart:14-18,58-59` — nhánh `VideoInfo` legacy không tới được; `download_screen.dart:23,44` — `_sub` không bao giờ gán.
- [ ] `lib/core/app_strings.dart:119-120` — `tabOnline`, `tabLibrary` không dùng. (`paste`/`clear`/`retryAll` KHÔNG xoá: Phase 12 nối vào downloader.)

**Checklist C — pubspec:**
- [ ] `unused_dependency` — `pubspec.yaml` — `cupertino_icons` (0 import), dòng comment `#  just_audio_background: ^0.0.1-beta.11`, `description: "A new Flutter project."` (đổi thành mô tả thật; cả `web/manifest.json`).

## Phase 10 — Player & điều hướng
**Effort: M — 1 session**

Mỗi mục một commit. Có 2 mục [CHỜ QUYẾT ĐỊNH] (câu hỏi 1, 2) — hỏi trước khi bắt đầu session. Sau phase: check tay trên máy thật theo danh sách cuối phase.

**Câu mồi session:**
```
Đọc plan/REVIEW_PLAN.md. Chỉ làm Phase 10, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 10.
```

**Checklist:**
- [ ] `queue_end_state` **[CHỜ QUYẾT ĐỊNH – câu 1]** — `lib/providers/player_provider.dart:136` (high) — `_onPlaylistEnded` chỉ xử lý shuffleLoop; với repeat tắt just_audio giữ `playing = true` ở `completed` (mini player icon pause, đĩa xoay, bấm play không kêu — `AudioPlayer.java:965-980` không seek). Xử lý `ProcessingState.completed` theo phương án đã chọn (pause + seek / seekToIndex(0)).
- [ ] `nav_stack_duplicate` — `lib/screens/onboarding_screen.dart:111` (high) — `_navigateHome` dùng `pushReplacement` trong khi 6 nơi gọi (`welcome_screen:134`, `home_screen:322,738`, `library_screen:215`, `profile_screen:104`, `downloader_gateway_screen:68`) đều `push` → lần đầu stack `[Welcome, Home]` (back về Welcome), quét lại tạo Home thứ hai. Lần đầu: `pushAndRemoveUntil(home, (_) => false)`; quét lại: `pop()` về màn gọi.
- [ ] `empty_shuffle_loop` — `lib/screens/playlist_screen.dart:533-571` + `player_provider.dart:221-226` (high) — Hàng nút Shuffle Loop nằm ngoài guard `songs.isNotEmpty`; `enableShuffleLoop([])` vẫn gán `_repeatMode` và mở Now Playing trống. Đưa vào guard/disable khi rỗng; `enableShuffleLoop` return sớm khi rỗng (đóng luôn ghi chú Phase 1 của AUDIT_PLAN).
- [ ] `double_push_now_playing` — `playlist_screen.dart:498-524,542-568`, `album_detail_screen.dart:86-91,110-115`, `artist_detail_screen.dart:94-99,116-121` (medium) — Shuffle/Shuffle Loop `await playSongsShuffled()` xong mới push Now Playing, nút vẫn bấm được → double-tap ra 2 màn Now Playing. Push ngay như "Phát tất cả" (currentSong đã set trước await đầu) hoặc cờ busy.
- [ ] `play_next_semantics` **[CHỜ QUYẾT ĐỊNH – câu 2]** — `lib/widgets/music_list_tile.dart:361-389` + `player_provider.dart:343-348` (medium) — "Phát tiếp theo" gọi `addToQueue` (thêm cuối). Theo phương án đã chọn: thêm `insertNext` (chèn `_currentPlayIndex + 1` vào `_playQueue`, `_originalQueue` và handler `insert`) và/hoặc đổi nhãn.
- [ ] `play_count_source` — `lib/providers/music_provider.dart:360-367` + 11 chỗ gọi `onSongPlayed` trên UI (medium) — Auto-next, Next/Prev, queue, shuffle không được ghi "Nghe gần đây/Nghe nhiều". Ghi 1 lần từ PlayerProvider khi currentSong đổi (callback inject từ main.dart), xoá 11 lời gọi UI. Chú ý mục `prefs_write_race` (Phase 11) khi bấm Next liên tục.
- [ ] `selection_mode_back` — `lib/screens/library_screen.dart` (low) — Không có `PopScope`: back khi đang chọn thoát luôn màn. `PopScope(canPop: !_isSelecting, onPopInvokedWithResult: … _exitSelecting())`.
- [ ] `selection_mode_scroll_jump` — `lib/screens/library_screen.dart:320-348` (medium) — Vào/ra chế độ chọn đổi child của `Expanded` giữa `_FadeTabBarView` và `_SongsTab` trần → ListView dựng lại, nhảy về đầu. Giữ 1 element `_SongsTab` (truyền `isSelecting` xuống) hoặc `PageStorageKey`.
- [ ] `search_clear_incomplete` — `lib/screens/library_screen.dart:1362-1365` (medium) — "Xóa tìm kiếm" ở empty state chỉ `setLibrarySearchQuery('')`, `_searchCtrl` vẫn giữ chữ, gõ lại cùng chữ bị bỏ qua. Truyền `onClear` xoá controller như `home_screen.dart:139-143`.
- [ ] `rescan_fixed_delay` — `lib/screens/onboarding_screen.dart:82` (medium) — Mỗi lần quét lại chờ cứng 5s intro + 2s kết quả. Bỏ intro khi `music.hasScannedOnce`, overlap thời gian tối thiểu với scan như `AppStartupService`.
- [ ] `seek_during_load` — `lib/providers/player_provider.dart:473-481` (low, ghi chú Phase 1 AUDIT_PLAN) — `_seekToIndex` không qua `_loadChain`; bấm Next đúng lúc queue đang load có thể seek vào playlist chưa build xong. Chờ `_loadChain` trước khi seek.

**Check tay:** lần đầu cài: Welcome → quét → Home, back không về Welcome; quét lại từ Home/Hồ sơ xong quay về đúng màn; hết hàng chờ (repeat tắt) đúng phương án; "Phát tiếp theo"; playlist rỗng không mở Now Playing; double-tap Shuffle chỉ 1 màn; chọn nhiều bài ở Library không nhảy list, back thoát chế độ chọn.

## Phase 11 — Quyền, dữ liệu lưu trữ, lyrics, tìm kiếm
**Effort: M — 1 session**

Mỗi mục một commit; thêm test cho mục nào có logic thuần (storage, lyrics, folder, search).

**Câu mồi session:**
```
Đọc plan/REVIEW_PLAN.md. Chỉ làm Phase 11, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 11.
```

**Checklist:**
- [ ] `permission_triple_request` — `lib/services/music_scanner.dart:19-46` (high) — 3 request liên tiếp (on_audio_query → `Permission.audio` → `Permission.storage`): người dùng bị hỏi 2 lần, cờ `permissionPermanentlyDenied` gần như không bao giờ bật → onboarding không hiện "Mở cài đặt", "Thử lại" tự thất bại im lặng. Giữ `permissionsStatus()` để check, chỉ request MỘT lần qua permission_handler (`audio` trên API 33+, `storage` dưới đó); cân nhắc bỏ fork `packages/on_audio_query_android-1.1.0` khi plugin không còn tự hỏi quyền (fork chỉ khác `PermissionController.kt`, commit 843d71a).
- [ ] `prefs_corrupt_hang` — `lib/services/storage_service.dart:205-213` + `lib/screens/splash_screen.dart:74-86` (medium) — `_readIntList` trả `CastList` lười, TypeError nổ ở `_replaceList` ngoài try/catch → `MusicProvider.init()` ném, splash không bắt → treo vĩnh viễn. `.map((e) => e as int).toList()` trong try; splash try/catch fallback về Home.
- [ ] `prefs_all_or_nothing` — `lib/services/storage_service.dart:104-116,226-237` (low) — 1 entry playlist/hidden/meta hỏng → trả `[]`, lần ghi sau xoá sạch dữ liệu thật. Parse từng entry, bỏ entry hỏng; thêm `schema_version`.
- [ ] `prefs_write_race` — `lib/services/storage_service.dart:47-98,136-203` (low) — Mutator copy → await setString → thay in-memory: 2 lời gọi chồng nhau mất 1 update. Sửa in-memory trước rồi persist snapshot (hoặc queue ghi). Gộp 5 khối `jsonEncode(map.map(...))` giống nhau (:141,151,173,190,200) thành 1 helper.
- [ ] `theme_persist_delay` — `lib/providers/theme_provider.dart:74-95` (low) — Lưu theme sau 16ms+320ms, 3 lần notify cho `_isSwitching` không ai đọc; kill app trong ~0.3s mất theme. `setString` ngay sau khi gán `_mode`, bỏ delay.
- [ ] `lyrics_cache_key_ascii` — `lib/services/lyrics_service.dart:64-67` (medium) — `\w` của Dart chỉ ASCII: "群青"/"怪物" cùng key, "Chờ/Chở/Chó" cùng key → hiện sai lời. Key = sha1/base64Url của `'$artist $title'.toLowerCase()`. Có cache cũ trên máy: đổi tên thư mục cache hoặc xoá cache cũ khi nâng.
- [ ] `lyrics_negative_cache` — `lib/providers/lyrics_provider.dart:68-71,148-163` + `lyrics_service.dart:134-153` (low) — Không cache "không có lời": mỗi lần mở Now Playing bài không lời lại gọi LRCLIB. Cache notFound có TTL.
- [ ] `lrc_parse` — `lib/services/lyrics_service.dart:231-261` (low) — Dòng nhiều mốc `[00:05.00][00:30.00]text` mất mốc lặp và hiện thừa `[00:30.00]`, `[mm:ss]` không phần lẻ bị bỏ, `cs * 10 ~/ 10` vô nghĩa, sort không ổn định. Regex `\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]` + `allMatches`, 1 LyricLine mỗi mốc. Thêm `test/services/lyrics_service_test.dart`.
- [ ] `folder_group_key` — `lib/providers/music_provider.dart:482-488` (medium) — Nhóm theo tên thư mục cuối → `/storage/emulated/0/Music` và `/storage/XXXX/Music` gộp một. Key theo đường dẫn cha, hiển thị basename (kèm cha khi trùng).
- [ ] `search_no_normalize` — `lib/providers/music_provider.dart:148-171,466-471,495-502` + `lib/utils/vietnamese_normalize.dart` (medium) — Index/query chỉ lowercase: "nhac" không ra "Nhạc" (picker downloader thì có bỏ dấu); sort `compareTo` thô ("apple" sau "Zebra"). Dùng `vnNormalize` cho index + query, sort theo key đã normalize.
- [ ] `playlist_snapshot_stale` — `lib/providers/music_provider.dart:390-398` + `lib/models/playlist_item.dart:39-60` (medium, đóng ghi chú Phase 4a AUDIT_PLAN) — Playlist lưu nguyên `SongItem`, `updateSongMeta` chỉ rebuild `_allSongs` → playlist, `PlayerProvider.currentSong`/queue giữ tên cũ, file xoá vẫn nằm trong playlist. Lưu id trong playlist và resolve qua `_allSongs` khi `_replaceAllSongs` (bỏ/đánh dấu id thiếu); đồng bộ `PlayerProvider` (thêm `updateSongInQueue(SongItem)`).
- [ ] `hide_during_scan` — `lib/providers/music_provider.dart:112-115,193-203,231-238,400-424` (low) — hide/unhide không serialize với scan đang chạy; `unhideSong` rescan toàn bộ MediaStore. Nếu `_activeScan != null` thì await rồi scan mới; lâu dài áp filter hidden như bước derived trên mỗi `_replaceAllSongs`.
- [ ] `scan_error_silent` — `lib/providers/music_provider.dart:244-246` (low) — `_performScan` `catch (e)` nuốt lỗi, `LibraryStatus.error` không debug được. `debugPrint` trước khi set status.
- [ ] `hide_single_dup` — `lib/providers/music_provider.dart` (low, merge) — `hideSongFromLibrary` nên gọi `hideSongsFromLibrary([song])`; 2 bộ cache `filteredSongs`/`libraryFilteredSongs` gộp thành 1 `_FilterCache`.

**Test nên thêm:** `storage_service_test` (entry hỏng, `[1,"2"]` không throw, toggleFavorite chồng nhau), `lyrics_service_test` (parseLrc, cache key), `music_provider_scan_test` (updateSongMeta vào playlist, folder trùng tên, onSongPlayed khi auto-next), `theme_provider` (setTheme lưu ngay), `app_startup_service_test` (init throw không treo).

## Phase 12 — Downloader
**Effort: M/L — 1 session, cần máy thật để test tải**

Bước đầu tiên của session: tải thử 1 video YouTube 1080p bằng preset "1080p" trên máy thật để xác nhận mục `video_merge_no_ffmpeg` (câu hỏi 3) trước khi sửa. Nếu Phase 4b (tách `format_screen.dart` 1418 dòng) chưa làm thì sửa tại chỗ, không tách.

**Câu mồi session:**
```
Đọc plan/REVIEW_PLAN.md. Chỉ làm Phase 12, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 12.
```

**Checklist:**
- [ ] `video_only_formats` — `lib/features/downloader/models/video_info.dart:140-141` + `screens/format/format_screen.dart:194-209` (high) — `videoFormats` = mọi format không audio-only → stream DASH video-only (137/136/248…) lọt vào tab Video và `_bestVideoFormat` → tải ra mp4 câm. Lọc `acodec != 'none' && vcodec != 'none'`.
- [ ] `video_merge_no_ffmpeg` **[CHỜ QUYẾT ĐỊNH – câu 3]** — `format_screen.dart:63-96` (preset `bestvideo+bestaudio/...`), `android/app/src/main/python/ytdlp_bridge.py:264,272-284`, `android/app/build.gradle.kts:57-64` (chỉ `pip install yt-dlp`) (high) — Selector "+" cần ffmpeg để ghép; `ignoreerrors: True` → yt-dlp cảnh báo và để lại `title.f137.mp4` + `title.f140.m4a`. Kiểm tra thêm nhánh `__extract_audio__` (Phase 6 test ra `.m4a` OK, nhưng nghi `DownloadForegroundService.kt:216-221` có thể mux file lên chính nó khi `extractedPath == outputPath`) — guard `extractedPath != outputPath`.
- [ ] `outtmpl_collision` — `ytdlp_bridge.py:267` + `test/features/downloader/android/download_foreground_service_test.dart:49-50` (medium) — `%(title)s.%(ext)s`: 2 video trùng tên → "already downloaded", task báo xong trỏ file cũ; `AudioExtractor.kt:33` xoá `title.m4a` có sẵn. Dùng `%(title)s [%(id)s].%(ext)s`, bỏ assertion `isNot(contains('[%(id)s]'))`.
- [ ] `summary_nav_blank` — `screens/summary/summary_screen.dart:128-134,152-154` + `analyze_screen.dart:139-141` (medium) — "Tải thêm video" `pushNamedAndRemoveUntil(analyze, (_) => false)` xoá cả Home/Gateway → back từ Analyze pop route cuối → màn đen; "Về trang chủ" chỉ pop Summary. `popUntil(name == analyze)` / `popUntil((r) => r.isFirst)`.
- [ ] `manage_storage_prompt` — `services/downloader_storage_service.dart:160-176` + `providers/download_provider.dart:51-56` (medium) — `manageExternalStorage.request()` chạy mỗi lần `OutputDirectoryNotifier` build và mỗi `pickDirectory()` → API 30+ bật màn "Truy cập tất cả file" ngay khi mở Analyze. Giữ quyền (không lên store) nhưng check `status` trước, chỉ request khi người dùng chọn thư mục ngoài Download/Music.
- [ ] `legacy_write_permission` — `AndroidManifest.xml:16-18,37` (medium, chưa test máy) — `WRITE_EXTERNAL_STORAGE maxSdkVersion=28` nhưng `requestLegacyExternalStorage=true` đưa Android 10 (API 29) vào chế độ legacy cần quyền này → yt-dlp không tạo được file. Đổi `maxSdkVersion="29"`.
- [ ] `send_intent_unhandled` — `AndroidManifest.xml:66-71` + `MainActivity.kt` (medium) — Đăng ký `ACTION_SEND text/plain` nhưng không đọc `EXTRA_TEXT` → app hiện trong share sheet nhưng share link chỉ mở app. Đọc intent → channel → `AnalyzeNotifier.onUrlChanged`, hoặc bỏ filter.
- [ ] `ytdlp_error_swallowed` — `ytdlp_bridge.py:116-126,145-155,290-295` + `services/ytdlp_service.dart:383-389` (medium) — `ignoreerrors: True` + `patched_report_error` nuốt lỗi thật (video private/login → "Không lấy được thông tin" chung chung, `_parseError` không bao giờ khớp); `verbose: True` dump log ở release. `ignoreerrors: 'only_download'`, trả text `report_error` trong JSON `error`, verbose chỉ debug.
- [ ] `online_tab_downloader_link` — `lib/screens/online_screen.dart:121-127` (medium) — Tile "Tải nhạc từ URL" gắn nhãn "Sớm", không bấm được dù downloader đã có (Hồ sơ → Gateway). Cho tile mở `DownloaderGatewayScreen`, bỏ badge.
- [ ] `badge_overlap` — `widgets/app_shell.dart:55-62` (low, ghi chú Phase 3 AUDIT_PLAN) — `NetworkStatusBadge` đè nút "Xóa xong" ở download screen.
- [ ] `downloader_inline_strings` — `analyze_screen.dart:646`, `download_screen.dart:569,577,584`, `summary_screen.dart:357` + ~60 dòng literal khác ở 5 màn (low) — Ghi chú Phase 7 nói đã dùng `AppStrings` là chưa đúng; `AppStrings.paste/clear/retryAll` (app_strings.dart:371-373) chưa được nối. Quét về `AppStrings`.
- [ ] `notifier_error_unlogged` — `download_provider.dart:51-56` (low) — `OutputDirectoryNotifier.build` throw không log. `debugPrint` trước khi throw.

**Check tay:** tải 1 video 720p/1080p có tiếng; 2 video trùng tên ra 2 file; Summary → "Tải thêm" → back không đen; mở Analyze lần đầu không bật màn "Tất cả file"; share link từ app YouTube vào Muzicz (nếu làm).

## Phase 13 — Build, release, README, manifest
**Effort: S/M — 1 session; cần câu hỏi 4 và 5**

**Câu mồi session:**
```
Đọc plan/REVIEW_PLAN.md. Chỉ làm Phase 13, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 13.
```

**Checklist:**
- [ ] `release_debug_signing` **[CHỜ QUYẾT ĐỊNH – câu 4]** — `android/app/build.gradle.kts:47-53` + `.github/workflows/build-apk.yml:62-90` (high) — Release ký bằng `signingConfigs.getByName("debug")`, CI đẩy lên release "latest" với debug keystore mới mỗi lần chạy → bản sau không cài đè bản trước. `signingConfigs.create("release")` đọc `key.properties` (gitignore) / secrets CI; fail build release khi thiếu.
- [ ] `chaquopy_build_python` — `android/app/build.gradle.kts:57-64` (low, ghi chú Phase 3 AUDIT_PLAN) — Không có `buildPython` → cần `python3.13` trên PATH (máy chỉ có 3.12). `buildPython("py", "-3.13")` hoặc ghi prerequisite README.
- [ ] `readme_outdated` — `README.md` (medium) — Mô tả bản Provider local cũ: thiếu downloader (yt-dlp/Chaquopy, foreground service), lyrics đồng bộ (lrclib), sleep timer/tốc độ, 3 theme + bottom-nav style, Liquid Glass, Music Visual, tìm kiếm, playlist/ẩn bài/sửa meta; tech stack thiếu Riverpod, just_audio/audio_service, Kotlin + Python; thiếu prerequisites (Python 3.13, NDK 27.0.12077973, minSdk 24, arm64/x86_64, Android-only); "Future: Search" đã có. Viết lại.
- [ ] `app_label` — `AndroidManifest.xml:38` + `lib/main.dart:23-24` + `app_strings.dart:15` (low) — Label launcher "muziczz", channel "Muziczz Audio", tên app "Muzicz Audio" — 3 cách viết. `@string/app_name` = "Muzicz", thống nhất channel (giữ `applicationId`).
- [ ] `global_error_handlers` — `lib/main.dart:18-57` (low) — Không có `FlutterError.onError`/`PlatformDispatcher.instance.onError` → lỗi async (MissingPluginException, storage init) chỉ ra console. Cài handler trong `main()` (debugPrint + giữ hành vi mặc định).
- [ ] `manifest_unused_perms` **[CHỜ DUYỆT – câu 5]** — `AndroidManifest.xml:8,32` (low) — `ACCESS_WIFI_STATE`, `RECEIVE_BOOT_COMPLETED` không có consumer.
- [ ] `launcher_icons_dev_dep` **[CHỜ DUYỆT – câu 5]** — `pubspec.yaml:49,58-72` (medium) — `flutter_launcher_icons` ở dependencies chính, config web/windows/macos còn placeholder `path/to/image.png`/`#hexcode` (`dart run flutter_launcher_icons` sẽ fail).
- [ ] `poc_in_release` **[CHỜ DUYỆT – câu 5]** — `lib/features/music_visual/widgets/visual_mode_selector_sheet.dart:145-160`, `core/visual_feature_flag.dart:3`, `AndroidManifest.xml:12` (medium) — POC Visualizer (AudioPlayer thứ 2 + `Permission.microphone`) vào được ở release qua Fancy → tile "science"; `RECORD_AUDIO` trong manifest production. Gate `kDebugMode`/flag riêng, chuyển `RECORD_AUDIO` sang `src/debug/AndroidManifest.xml`, hoặc xoá `poc/**` + `AndroidVisualizerPocPlugin.kt` + test POC.
- [ ] `gradle_jvm_target` — `android/build.gradle.kts:26-36`, `app/build.gradle.kts:16-28`, `gradle.properties:9-11` (low, optional) — Ép jvmTarget 11 mọi subproject, `kotlin.jvm.target.validation.mode=warning` che lỗi package_info_plus; Kotlin 1.8.22, `enableJetifier=true`. Lên 17, bỏ override + flag, Kotlin 2.1.x, bỏ jetifier — làm riêng, build + chạy lại toàn bộ.
- [ ] `abi_filters` — `app/build.gradle.kts:41-44` (low, hỏi t) — chỉ arm64-v8a + x86_64: máy ARM 32-bit (Android 7–9 mà minSdk 24 cho phép) báo không tương thích. Thêm `armeabi-v7a` (APK nặng hơn) hoặc nâng minSdk và ghi README.
- [ ] `ci_flutter_version` — `.github/workflows/build-apk.yml:34` (trivial) — CI 3.44.0, local 3.44.5; đồng bộ.

## Phase 14 — Gộp trùng lặp UI + UX nhỏ
**Effort: M — 1 session, sau Phase 10**

Chỉ tạo widget chung cho các bản copy giống hệt; mỗi nhóm một commit; không đổi hình ảnh.

**Câu mồi session:**
```
Đọc plan/REVIEW_PLAN.md. Chỉ làm Phase 14, đúng quy tắc chung và hướng dẫn của phase. Không đụng code ngoài checklist Phase 14.
```

**Checklist — gộp:**
- [ ] `dup_now_playing_route` — 3 hàm top-level `_playerRoute()` (`library_screen.dart:1382`, `album_detail_screen.dart:408`, `artist_detail_screen.dart:502`) + 6 bản inline (`home_screen.dart:227-242`, `playlist_screen.dart:467-488,501-522,545-566,719-740`, `mini_player.dart:27-43`) → `lib/widgets/now_playing_route.dart` (`pushNowPlaying(context)`); dùng luôn cho `_QuickCard` (`home_screen.dart:574-584`) hiện phát mà không mở Now Playing.
- [ ] `dup_shuffle_loop_dialog` — `album_detail_screen.dart:119-194`, `artist_detail_screen.dart:125-200`, `playlist_screen.dart:574-643` giống hệt → 1 widget.
- [ ] `dup_action_button` — `_ActionButton` (`album_detail_screen.dart:362-406`, `artist_detail_screen.dart:456-500`) và `_PlayButton` (`playlist_screen.dart:1034-1084`) giống hệt → 1 widget.
- [ ] `dup_empty_state` — 6 empty state (`library_screen.dart:1272-1380`, `hidden_songs_screen.dart:120-140`, `home_screen.dart:424-445`, `playlist_screen.dart:26-48,715-736`, `add_to_playlist_sheet.dart:182-213`) → 1 widget có tham số.
- [ ] `dup_create_playlist_dialog` — `playlist_screen.dart:343-406` vs `add_to_playlist_sheet.dart:266-326` → 1.
- [ ] `dup_song_info_sheet` — `sheets/song_info_sheet.dart` vs `music_list_tile.dart:404-467` (`_showSongInfo` + `_infoRow`, bản này có thêm dòng đường dẫn) → dùng `showSongInfoSheet` từ tile.
- [ ] `dup_sheet_boilerplate` — `AddToPlaylistSheet.show(context, song)` thay 3 đoạn `showModalBottomSheet` + `ChangeNotifierProvider.value` (`song_info.dart:56-65`, `top_bar.dart:107-116`, `music_list_tile.dart:348-357`); `.value` thừa vì MusicProvider đã nằm trên MaterialApp — cả `profile_screen.dart:173-176,375-378`, `library_screen.dart:205-208`, `expandable_pill_bar.dart:45-48,61-64`, theme/bottom-nav `show()`.
- [ ] `dup_selector_sheets` — `ThemeSelectorSheet` / `BottomNavStyleSelectorSheet` / `VisualModeSelectorSheet` cùng skeleton; `_CurrentBadge` inline lại ở `theme_selector_sheet.dart:238-255` (low).

**Checklist — UX nhỏ:**
- [ ] `mini_player_missing_detail` — `album_detail_screen.dart`, `artist_detail_screen.dart`, `playlist_screen.dart` (PlaylistDetailScreen), `hidden_songs_screen.dart` (medium) — Không có MiniPlayer khi đang phát → phải back về Home để pause/skip. 1 scaffold wrapper chung `Column(Expanded(body), MiniPlayer)`.
- [ ] `fancy_nav_overlay` — `library_screen.dart:944,352-358`, `playlist_screen.dart:69` (medium, chưa test máy) — Với style liquid glass, MiniPlayer là overlay 68dp đè lên tab body; Home/Profile đệm 120dp nhưng tab Library, FAB tạo playlist, action bar chọn nằm dưới overlay. Padding theo bottom inset chung.
- [ ] `share_stub` — `widgets/now_playing/top_bar.dart:121-128` (medium) — "Chia sẻ" chỉ snackbar. Bỏ mục, hoặc dùng `share_plus` (thêm dependency — hỏi t).
- [ ] `short_file_filter_stub` — `profile_screen.dart:350-356` + `music_scanner.dart:99` (medium) — Toggle "Lọc file dưới 30 giây" giả (`value: true`, `onChanged: (_) {}`), ngưỡng cứng. Lưu pref và đọc trong scanner, hoặc xoá dòng + `AppStrings.filterShortFiles*`.
- [ ] `snackbar_under_sheet` — `add_to_playlist_sheet.dart:251-263,339` (medium, chưa test máy) — `_showFeedback` hiện SnackBar qua ScaffoldMessenger gốc trong khi sheet còn mở → bị sheet che, hết 2s trước khi đóng; kèm ghi chú Phase 2 (dùng `dialogCtx` sau pop). Hiện feedback trong sheet hoặc snack sau khi pop.
- [ ] `detail_screen_snapshot` — `album_detail_screen.dart:20-26`, `artist_detail_screen.dart:22` (low) — Giữ `List<SongItem>` snapshot; sửa/ẩn từ Now Playing không phản ánh khi quay lại; `album_detail:25` vẫn `watch` PlayerProvider ở gốc (rebuild mỗi tick hẹn giờ). Truyền key album/artist và đọc `music.albumMap[key]` trong build; `Selector` cho isActive.
- [ ] `playlist_add_sheet_inconsistent` — `playlist_screen.dart:942-945` (low) — `_showAddSongsSheet` đóng sau 1 lần thêm không feedback, `AddToPlaylistSheet` thì giữ mở → thống nhất.
- [ ] `queue_sheet_hidden_rebuild` — `queue_sheet.dart:20` (low, ghi chú Phase 5) — `Offstage(offstage: !_queueVisible)` để không rebuild mỗi tick khi ẩn.
- [ ] `theme_flash_dismissible` — `theme_switch_wrapper.dart:75` (low, ghi chú Phase 5) — `ModalBarrier` mặc định dismissible trong ~560ms flash → `dismissible: false`.
- [ ] `colors_white_leftover` — ~27 `Colors.white/black` ngoài checklist Phase 7 (`home_screen` 5, `app_theme` 5, `music_list_tile`/`mini_player`/`add_to_playlist_sheet` 2, `splash`/`profile`/`theme_switch_wrapper`/`app_bottom_navigation` 1) (low) — quét nốt sang token.

## Ghi chú audit cũ còn mở (AUDIT_PLAN.md)
- Phase 4b (`format_screen.dart` 1418 dòng) và 4c (`library_screen.dart` 1393 dòng) chưa làm — vẫn theo AUDIT_PLAN, làm trước Phase 12/14 nếu muốn tách; nếu không thì các phase trên sửa tại chỗ.
- Chưa chạy lại auditz scan/baseline (`findings.json` 2026-08-27, trước Phase 4-7). Chạy sau khi xong Phase 14.
- `audio_handler._init()` chỉ log lỗi `setAudioSource` (ghi chú Phase 2) — thực tế splash 1.3s che race; giữ nguyên trừ khi thấy lỗi thật.

## Chi tiết kiểm chứng session review 2026-09-03
- `flutter analyze --no-pub`: sạch. `flutter test --no-pub`: 84/84 pass trước khi sửa.
- Bug Phase 8: tái hiện bằng script rxdart thuần (listen → cancel hết → listen lại: nhận `pos=6s` rồi `DONE`); xác nhận trong source `rxdart-0.27.7/lib/src/streams/connectable_stream.dart` (`ConnectableStreamSubscription.cancel()` → `_subject.close()`), 0.28.0 giống hệt.
- just_audio 0.9.46: `play()` ở `completed` chỉ set `playWhenReady` (AudioPlayer.java:965-980), docs ghi rõ `playing` giữ true sau completed → cơ sở cho mục `queue_end_state`.
- Các claim "không có caller" ở Phase 9 B đã grep ngày 2026-09-03; số dòng trong checklist là tại HEAD e2f13dc, có thể lệch sau các phase khác.

## Ghi chú ngoài phạm vi (Claude Code ghi vào đây, không tự sửa)
