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

## [Phase 2] - 2026-07-18 23:09
- Dùng `Map<taskId, progress>` được bảo vệ bằng cùng lock của task tracking thay cho `_progress` global; snapshot trả bản sao để polling không đọc dict đang bị hook cập nhật.
- Xóa progress entry trong `_clear_task_tracking` cùng cancel/file state để không giữ dữ liệu task đã kết thúc; response download vẫn là source-of-truth cho trạng thái terminal nên không cần giữ progress sau completion.
- Giữ `maxConcurrentDownloads = 1` dù protocol đã task-scoped: automated test chứng minh contract và mapping độc lập nhưng chưa chứng minh hai Chaquopy download song song an toàn/runtime tốt trên thiết bị thật.
- Không thay public `DownloadGateway`, package hoặc UI; task identity chỉ được bổ sung trong MethodChannel/Python protocol nội bộ.

## [Phase 0] - 2026-07-18 23:22
- Tạo `PlayerAudioGateway` ngay tại biên `PlayerProvider` → audio engine để fake queue/index trong unit test; không abstract thêm UI, service khác hoặc đổi state management vì PLAY-01 chỉ cần seam này.

## [Phase 3] - 2026-07-18 23:22
- Chọn engine-first transaction cho remove/reorder: validate index, chờ `ConcatenatingAudioSource` thành công rồi mới commit `_playQueue`, `_currentPlayIndex` và `_currentSong`; nếu engine ném lỗi, provider giữ nguyên state thay vì tạo lệch queue.
- Dùng move/remove trực tiếp trên `ConcatenatingAudioSource` thay vì clear/reload playlist để không chủ động ngắt bài đang phát; cập nhật mirror `_currentSongs` chỉ sau khi operation engine thành công.
- Tái sử dụng `_isReordering` để bỏ qua index stream và mutation queue thứ hai trong cửa sổ async ngắn; tradeoff là thao tác người dùng lặp cực nhanh có thể bị bỏ qua, nhưng tránh hai mutation dùng index cũ chạy chồng nhau.
- Clear history index sau remove/reorder vì các index cũ không còn ổn định; phần thiết kế history theo track ID/central track-change vẫn để issue Phase 3 riêng.

## [Phase 3] - 2026-07-19 00:08
- Giữ ownership `MuzicAudioHandler` ở app root vì audio/background playback phải sống lâu hơn `PlayerProvider`; provider chỉ cancel các subscription và timer do chính nó tạo, không dispose audio engine.
- Dùng một `_applyCurrentIndex` cho cả seek chủ động và event auto-next; cờ `_isChangingTrack` chặn event đồng bộ trong lúc seek, còn kiểm tra song ID loại event đến muộn, nhờ đó mỗi transition chỉ thêm history một lần.
- Giữ history theo index trong issue này để không mở rộng schema/public API; queue remove/reorder đã clear history nên index còn hợp lệ giữa các mutation queue.

## [Phase 1] - 2026-07-19 00:27
- Dùng `ProviderScope` duy nhất ở app root thay vì giữ container theo route; downloader state và network provider vì thế sống theo app lifecycle, không bị orphan khi pop feature.
- Cho `networkServiceProvider` tạo và dispose một `NetworkService` mới theo container thay vì cố làm singleton đã đóng có thể tái sử dụng; seam callback chỉ ở biên Connectivity để test, không thay state management hay package.
- Mở downloader bằng named route trên navigator gốc và truyền `RouteSettings` vào `PageRouteBuilder`; đây giữ predicate back-stack hiện tại trong khi loại nested `MaterialApp`.

## [Phase 0] - 2026-07-19 00:38
- Dùng `AnalyzeGateway` rất nhỏ tại biên MethodChannel để test orchestration mà không thay package, public native protocol hoặc state management hiện tại.
- Mỗi lần URL/reset/analyze tăng revision; chỉ response có revision hiện hành được commit. Cách này không hủy native request nhưng ngăn response đến muộn làm sai UI với chi phí và phạm vi nhỏ.
- Xóa result/error ngay khi chuỗi URL thực sự thay đổi và dùng sentinel cho field nullable trong `copyWith`; tradeoff là card cũ biến mất khi user sửa typo, đổi lại UI không bao giờ ghép URL mới với metadata cũ.

## [Phase 4] - 2026-07-19 00:47
- Dùng Kotlin `lazy(LazyThreadSafetyMode.SYNCHRONIZED)` cho `ytdlp_bridge` thay vì khởi tạo trong `configureFlutterEngine`; downloader call đầu tiên chịu init cost, các call đồng thời dùng chung một initializer và module được cache sau khi thành công.
- Giữ lazy property trong `MainActivity` thay vì thêm service/package mới vì lifecycle hiện tại đã gắn MethodChannel với activity; exception khởi tạo tiếp tục được map qua error code hiện có của từng method.
- Giữ regression test ở mức architectural invariant vì repo chưa có Android unit-test harness; test chứng minh cold-start setup không tham chiếu Python, nhưng không thay thế Macrobenchmark/runtime validation.

## [Phase 1] - 2026-07-19 01:16
- Giữ đúng hai lựa chọn user-facing `Bình thường`/`Xịn xò`; `Xịn xò` khóa `GlassQuality.premium` và `MaskingQuality.high`, không đưa minimal/standard vào settings theo xác nhận của user.
- Mở rộng `ThemeProvider` hiện có thay vì thêm state management/service mới: cùng provider sở hữu preference đồ họa và `visualRevision`, nhờ đó đổi bottom nav dùng chung loading transition với đổi bộ màu mà không restart app.
- Tách `AppBottomNavigation` thành widget presentation riêng; bản thường là code hiện tại được di chuyển nguyên hành vi, bản glass dùng API công khai `GlassTabBar.bottom` của package 0.22.1, còn `HomeScreen` tiếp tục sở hữu index/navigation.
- Chỉ tab đang focus truyền `label` cho `GlassTab`; các tab còn lại giữ `semanticLabel`, nên Liquid Glass vẫn khớp contract icon + text khi focus và không làm giảm accessibility.
- Không bật adaptive quality vì user yêu cầu Premium cố định; đổi lại cần device profiling trước khi khẳng định runtime mượt trên máy yếu.

## [Phase 2] - 2026-07-19 14:21
- Cho Android foreground service sở hữu queue, persistence, retry, concurrency và audio extraction; Dart chỉ enqueue/poll/hydrate. Cách này tránh download phụ thuộc lifecycle của Flutter engine và không nhân đôi orchestration giữa UI/native.
- Dùng foreground service type `dataSync` cùng notification ongoing thay vì WorkManager vì download bắt đầu trực tiếp từ thao tác user, cần tiến trình liên tục và cooperative cancel theo task ID.
- Persist snapshot bằng Android `SharedPreferences` JSON vì model queue nhỏ và chưa cần query/index; không thêm package/database khi chưa có bằng chứng cần thiết. Task interrupted được đưa lại `queued` để yt-dlp tiếp tục partial file.
- Retry chỉ áp dụng tối đa 2 lần cho lỗi mạng/timeout/429/5xx; backoff 2/4 giây và chờ network thay vì retry cancel, private, unsupported hoặc lỗi terminal.
- Giới hạn concurrency = 2: protocol đã task-scoped nhưng chưa có device benchmark; queue reservation dùng lock riêng và output template thêm media ID để tránh duplicate start/file collision.
- Dùng một `YtdlpPython` initializer/cache chung cho Activity và service để giữ lazy startup và ngăn hai lock độc lập cùng gọi `Python.start`.

## [Phase 4] - 2026-07-19 14:21
- Dùng `MediaStore.Files` + `MediaMetadataRetriever` cho WebM fallback thay vì duyệt recursive filesystem; chỉ ứng viên `.webm` chịu metadata I/O và malformed file không làm fail toàn scan.
- Ưu tiên record `on_audio_query` khi trùng path vì record đó có MediaStore album/artist ID đầy đủ; fallback dùng negative synthetic ID và metadata trong container.
- Xin `READ_MEDIA_VIDEO` best-effort trên Android 13+ vì WebM có thể bị phân loại `video/webm`; từ chối quyền này không chặn thư viện audio thông thường.

## [Phase 4] - 2026-07-19 15:06
- Dùng `AppStartupService` làm seam orchestration nhỏ thay vì đưa thêm state management: minimum splash, storage init và destination có thể test độc lập trong khi `SplashScreen` giữ nguyên navigation/presentation.
- Chọn minimum splash 1,3 giây vì khớp thời điểm hai animation hiện tại hoàn tất (logo bắt đầu ở 200 ms, text ở 600 ms); đây là ngưỡng UX, không phải kết quả benchmark.
- Với returning user, start scan ngay sau storage init nhưng không await trước Home; Home dùng `LibraryStatus.scanning && allSongs.isEmpty` để hiện loading thay vì empty state. Tradeoff là scan vẫn tiêu thụ I/O sau navigation, cần Perfetto/device measurement trước khi đánh giá frame/runtime.
- Mở rộng `scanMusic` catch bao quanh cả permission request để background scan luôn kết thúc bằng state `permissionDenied` hoặc `error`, không tạo unhandled async error.

## [Phase 4] - 2026-07-19 15:22
- Đặt `MusicProvider.scanMusic` làm owner duy nhất của permission trong flow refresh; truyền `ensurePermission: false` xuống scanner sau khi quyền đã được xác nhận để không lặp platform call.
- Normal refresh chỉ query MediaStore và không deep-scan root shared storage. Cách này giảm công việc I/O có thể tránh được; tradeoff là file chưa được MediaStore index cần một action manual riêng hoặc scan đúng path khi downloader hoàn tất.
- Giữ `ensurePermission = true` làm mặc định của `MusicScanner.scanSongs` để không phá caller độc lập/public behavior; constructor injection chỉ là seam additive phục vụ regression test.

## [Phase 4] - 2026-07-19 15:53
- Chọn một API batch `StorageService.hideSongs(List<SongItem>)` tại đúng biên persistence thay vì cache/song repository mới; phạm vi này loại write amplification mà không đổi state management hoặc schema.
- Batch đọc hidden map một lần và ghi một lần, đồng thời giữ merge với entries cũ; storage write hoàn tất trước khi provider mutate library/playlist để tránh in-memory state đi trước persistence khi write ném lỗi.
- Giữ `hideSong`/`unhideSong` cho luồng đơn lẻ và không gom các persistence finding khác vào session này; PERF-03 typed cache và derived-list memoization để issue Phase 4 riêng.

## [Phase 4] - 2026-07-19 16:07
- Hydrate năm collection JSON thường dùng đúng một lần trong `StorageService.init` và giữ typed cache, thay vì thêm repository/state-management mới; `isFavorite` giờ là lookup `Set` trực tiếp cho từng tile.
- Getter trả unmodifiable view để caller không thể sửa cache mà bỏ qua persistence. Mutation tạo candidate copy, await `SharedPreferences.setString`, rồi mới thay nội dung cache để giữ disk/in-memory nhất quán khi write thất bại.
- JSON collection hỏng fallback về collection rỗng theo cùng hướng tolerant đã có ở playlists; không tự xóa raw data để còn khả năng chẩn đoán/khôi phục và không thêm migration schema trong issue performance này.

## [Phase 4] - 2026-07-19 16:50
- Giữ derived state trong `MusicProvider` thay vì thêm package/repository hoặc state management mới; provider đã sở hữu library revision và mọi mutation cần thiết để invalidate cache đúng chỗ.
- Chọn debounce 160 ms, nằm trong khoảng 120–200 ms của audit; query rỗng commit ngay để Clear không có độ trễ, còn timer được cancel khi query đổi hoặc provider dispose.
- Normalize title/artist/album một lần khi library revision đổi và cache snapshot theo query/sort; smart list dùng unmodifiable snapshot để caller không thể làm bẩn cache.
- Invalidate chọn lọc: scan/meta/hide xóa toàn bộ derived cache, favorite chỉ xóa favorites, play tracking chỉ xóa recently/most/never played. Random Mix chỉ đổi khi library đổi để không tự shuffle bởi notify không liên quan.

## [Phase 4] - 2026-07-19 17:04
- Giữ `albumMap`/`artistMap` hiện có để không phá public API; bổ sung sorted snapshot trong `MusicProvider` cho Library UI thay vì chuyển state management hoặc tạo repository mới.
- Rebuild cả album, artist và folder tại một điểm `_replaceAllSongs`, vì scan, metadata edit và hide đều đi qua library revision này; notify favorite/history/search không làm lại grouping/sorting.
- Dùng cùng folder snapshot cho tab count và folder list để tránh hai lần quét độc lập nhưng giữ nguyên quy tắc tên folder hiện tại và thứ tự alphabet, nên business behavior/navigation không đổi.
- Không trộn `context.select`/Selector của PERF-02 vào issue này: snapshot loại work thực tế trong build, còn thu hẹp widget rebuild cần widget test và profile riêng để tránh UI stale do selector thiếu field.

## [Phase 5] - 2026-07-19 18:06
- Giữ `LibraryStatus` hiện có làm source of truth cho onboarding thay vì thêm state machine hoặc package mới; local state chỉ giữ scan-in-flight và timer navigation, nên UI không thể tự suy diễn failure thành success.
- `MusicScanner` không tự mở App Settings khi permanent-denied. Scanner chỉ ghi nhận trạng thái, `MusicProvider` expose getter additive và onboarding hiển thị CTA chủ động; cách này tránh navigation hệ thống bất ngờ và giữ quyền giải thích/retry cho UI.
- Chỉ permanent denial mới hiện `Mở cài đặt`; denial thường ưu tiên `Thử lại`. Error dùng thông báo chung vì provider hiện không expose exception, tránh mở rộng error model ngoài UI-01.
- Dùng `FilledButton` cho Retry, `OutlinedButton` cho Settings, token màu app/`ColorScheme.error` và live-region semantics theo skill Flutter nội bộ; giữ nguyên presentation, business behavior và navigation success hiện có.
- Thay `Future.delayed` điều hướng bằng `Timer` có owner/cancel trong widget và guard `LibraryStatus.done`; tradeoff là vẫn giữ delay success 2 giây để không đổi UX, nhưng không còn callback navigation sau dispose.

## [Phase 5] - 2026-08-14 08:20
- Dùng `Semantics` wrapper quanh GestureDetector hiện có thay vì migrate sang `IconButton`/`NavigationBar` để không đổi presentation, animation press-scale và haptic hiện tại; IconButton có sẵn chỉ thêm `tooltip`, favorite dùng `MergeSemantics` để gộp toggled + tooltip vào một node.
- Bottom nav thường dùng `ExcludeSemantics` quanh Text của tab active để tránh TalkBack đọc trùng label; tab inactive vẫn công bố tên nhờ Semantics label. Bản Liquid Glass đã có `semanticLabel` từ trước nên không sửa.
- Mở hit area bằng `SizedBox` 48 + `Center` + `HitTestBehavior.opaque` thay vì tăng icon size hoặc padding; visual không đổi, chỉ vùng chạm mở rộng. Không đụng pill bar (Row 280px chứa 6 item, 6×48=288 sẽ tràn) và bottom nav item height — hai chỗ này cần quyết định layout riêng, không trộn vào issue accessibility.
- Test đo qua semantics node rect thay vì `androidTapTargetGuideline` toàn màn để giữ phạm vi đúng danh sách audit UI-05; guideline toàn màn sẽ ép sửa cả các control ngoài scope (album link, swipe hint, top bar) trong cùng diff.
- Lọc đúng một diagnostic có sẵn `ListTile trong DecoratedBox` của queue sheet trong test harness, lỗi khác vẫn fail; diagnostic này đã ghi nhận từ session UI-02 và cần issue UI riêng.
- Tôn trọng nguyên trạng `TextScaler` do hệ điều hành cung cấp thay vì thay clamp 1.15 bằng một ngưỡng lớn hơn; accessibility setting là source of truth và giới hạn toàn app không phải giải pháp responsive lâu dài.
- Chỉ bỏ wrapper `MediaQuery` ở root, giữ `ThemeSwitchWrapper` làm `MaterialApp.builder`; đây là thay đổi production nhỏ nhất, không đổi public API, package, state management, theme hoặc navigation.
- Dùng regression structural guard cho root vì `MuzicApp` hiện khởi tạo nhiều provider/plugin, đồng thời dùng widget test thực cho Now Playing ở 320×568 và scale 1.0/1.3/2.0 để kiểm tra hành vi layout. Không refactor Now Playing khi test không chứng minh có overflow.
- Không thêm clamp cục bộ vào widget. Nếu device validation phát hiện route cụ thể bị vỡ, route đó phải được sửa responsive và có test riêng thay vì vô hiệu hóa font scale của toàn app.
