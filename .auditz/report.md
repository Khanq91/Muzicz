# Auditz report — Muzicz
_Generated 2026-08-27 14:13 UTC · model claude-code · stack: cached_network_image, core, flutter, http, liquid_glass, provider, riverpod_

| Severity | New | Baseline |
|---|---|---|
| high | 2 | 0 |
| medium | 30 | 0 |
| low | 57 | 0 |

_Dropped: 0 unverified evidence · 65 low confidence · 0 suppressed · 1 invalid · 0 parse errors_

## [HIGH] singleton_state_leak — `lib/features/downloader/providers/download_provider.dart:17`
confidence 0.85
related: lib/features/downloader/services/downloader_storage_service.dart, lib/features/downloader/screens/analyze/analyze_screen.dart, lib/features/downloader/screens/format/format_screen.dart, lib/features/downloader/screens/summary/summary_screen.dart

Thư mục lưu là session state nằm trong singleton toàn cục `DownloaderStorageService.instance._downloadPath`, ngoài Riverpod. `Provider<String>` (không autoDispose, không dependency) cache giá trị ở lần đọc đầu và không bao giờ được invalidate, trong khi analyze_screen/format_screen đổi thư mục qua `setAndSavePath` trực tiếp trên singleton. Kết quả: từ lần tải thứ hai trở đi trong cùng phiên, `ref.read(downloadOutputDirectoryProvider)` (dòng 273) vẫn trả về thư mục cũ và file bị lưu sai chỗ dù UI hiển thị đường dẫn mới.

```dart
final downloadOutputDirectoryProvider = Provider<String>(
  (ref) => DownloaderStorageService.instance.downloadPath,
);
```
**Fix:**
```dart
// Đưa path vào state: Notifier thay vì singleton
final downloadOutputDirectoryProvider =
    NotifierProvider<OutputDirNotifier, String>(OutputDirNotifier.new);

class OutputDirNotifier extends Notifier<String> {
  @override
  String build() => DownloaderStorageService.instance.downloadPath;
  Future<void> setPath(String path) async {
    await DownloaderStorageService.instance.setAndSavePath(path);
    state = path; // mọi ref.read/watch thấy giá trị mới
  }
}
// Screens: ref.read(downloadOutputDirectoryProvider.notifier).setPath(path)
// thay vì DownloaderStorageService.instance.setAndSavePath(path)
```

## [HIGH] race_shared_mutable — `lib/providers/music_provider.dart:445`
confidence 0.85

Commit chỉ xoá _homeFilterCache nhưng giữ nguyên _homeFilterCacheQuery/_homeFilterCacheRevision, nên chuỗi thao tác bình thường gõ "a" → xoá ô tìm kiếm → gõ lại "a" khiến getter filteredSongs thấy key cache khớp và chạy `return _homeFilterCache!` trên null → crash 'Null check operator used on a null value'. Cùng lỗi ở _commitLibrarySearchQuery/libraryFilteredSongs (2 site).

```dart
    _homeSearchQuery = query;
    _homeFilterCache = null;
```
**Fix:**
```dart
void _commitHomeSearchQuery(String query) {
  _homeSearchQuery = query;
  _homeFilterCache = null;
  _homeFilterCacheQuery = null; // invalidate key cùng lúc với value
  notifyListeners();
}
// tương tự: _libraryFilterCacheQuery = null; trong _commitLibrarySearchQuery
// hoặc trong getter: final cached = _homeFilterCache; if (cached != null && key match) return cached;
```

## [MEDIUM] duplicate_logic — `lib/features/downloader/core/theme/app_colors.dart:7`
confidence 0.90
related: lib/theme/app_colors.dart, lib/theme/app_colors_data.dart, lib/features/downloader/core/theme/app_theme.dart, lib/theme/app_theme.dart

Hai class cùng tên `AppColors` với cùng bộ hằng hex (primary/secondary/surface/text/glass…) tồn tại ở `lib/theme/app_colors.dart` (nguồn màu chính thức, có `context.appColors` theme-aware) và `lib/features/downloader/core/theme/app_colors.dart` (bản copy tĩnh, chỉ dark). 10 file downloader dùng bản copy nên toàn bộ feature downloader không đổi theo theme light/dark mà người dùng chọn ở ThemeProvider, và mỗi lần chỉnh palette phải sửa 2 nơi. `core/theme/app_theme.dart` của downloader (`AppTheme.darkTheme`) cũng là bản sao của `lib/theme/app_theme.dart` và hiện không được file nào tham chiếu (dead code).

```dart
  static const Color primary = Color(0xFF9D50FF);
```
**Fix:**
```dart
// Xoá lib/features/downloader/core/theme/{app_colors,app_theme}.dart
// Trong các screen downloader:
import 'package:muziczz/theme/app_colors_data.dart';
...
final c = context.appColors;           // theme-aware
Container(color: c.surfaceElevated)    // thay AppColors.surfaceElevated
```

## [MEDIUM] undisposed_resource — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:32`
confidence 0.90

State không override dispose(), _searchController không bao giờ được dispose → rò rỉ ChangeNotifier mỗi lần mở màn hình chọn playlist.

```dart
  final TextEditingController _searchController = TextEditingController();
```
**Fix:**
```dart
@override
void dispose() {
  _searchController.dispose();
  super.dispose();
}
```

## [MEDIUM] god_file — `lib/screens/now_playing_screen.dart:1195`
confidence 0.90
related: lib/features/downloader/screens/format/format_screen.dart, lib/screens/library_screen.dart

`now_playing_screen.dart` dài 2318 dòng (~10% toàn repo, gấp 1.6 lần file lớn thứ hai) chứa 20 class: màn hình chính, lyrics view, 3 bottom sheet (speed/sleep timer/queue), progress, controls, blurred background… Riêng `_TopBar` (dòng 1195–1745) là 550 dòng cho một thanh top bar, `_NowPlayingScreenState.build` 142 dòng, 10 điểm setState. Hai hotspot tiếp theo: `format_screen.dart` 1423 dòng (13 class) và `library_screen.dart` 1345 dòng (14 class). Đây cũng là các file gom nhiều finding per-file nhất trong lần audit này: now_playing_screen 9 finding (rebuild_scope_too_wide, blur_layer_abuse, undisposed_resource…), playlist_screen 8, analyze_screen 7, library_screen 5 — tách file trước sẽ giảm chi phí sửa các finding còn lại.

```dart
class _TopBar extends StatelessWidget {
```
**Fix:**
```dart
// Tách theo seam đã có sẵn (mỗi class private -> file riêng):
// lib/widgets/now_playing/lyrics_view.dart        <- _LyricsView, _LyricsListView
// lib/widgets/now_playing/sheets/speed_sheet.dart  <- _SpeedSheet
// lib/widgets/now_playing/sheets/sleep_timer_sheet.dart <- _SleepTimerSheet
// lib/widgets/now_playing/sheets/queue_sheet.dart  <- _QueueSheet
// lib/widgets/now_playing/top_bar.dart             <- _TopBar (tách tiếp menu/actions)
// lib/widgets/now_playing/controls.dart            <- _ControlsSection, _PlayButton, _IconBtn, _ProgressSection
// lib/widgets/now_playing/album_art_section.dart   <- _AlbumArtSection, _FlipCard, _BlurredBackground
// Tương tự: format_screen -> widgets/format/{folder_sheet,preset_list,format_tile,bottom_bar}.dart
//           library_screen -> widgets/library/{songs_tab,albums_tab,artists_tab,folders_tab,bulk_playlist_sheet}.dart
```

## [MEDIUM] async_context_use — `lib/features/downloader/screens/analyze/analyze_screen.dart:77`
confidence 0.85

_analyze await Connectivity().checkConnectivity() rồi gọi _showSnack → ScaffoldMessenger.of(context) mà không kiểm tra mounted; nếu user rời màn hình trong lúc chờ sẽ ném lỗi 'Looking up a deactivated widget ancestor'.

```dart
      _showSnack('Không có kết nối mạng');
```
**Fix:**
```dart
final results = await Connectivity().checkConnectivity();
if (!mounted) return;
if (!isOnline) { _showSnack('Không có kết nối mạng'); return; }
```

## [MEDIUM] setstate_after_async_gap — `lib/screens/library_screen.dart:174`
confidence 0.85

_exitSelecting() gọi setState sau 2 lần await (showDialog + hideSongsFromLibrary) mà không kiểm tra mounted; nếu người dùng rời màn hình khi đang ẩn bài sẽ ném 'setState() called after dispose()'.

```dart
    await music.hideSongsFromLibrary(songs);
    _exitSelecting();
```
**Fix:**
```dart
await music.hideSongsFromLibrary(songs);
if (!mounted) return;
_exitSelecting();
```

## [MEDIUM] logic_in_presentation — `lib/features/downloader/screens/format/format_screen.dart:248`
confidence 0.80
related: lib/features/downloader/screens/analyze/analyze_screen.dart, lib/features/downloader/providers/download_provider.dart, lib/features/downloader/models/playlist_entry.dart

`_FormatScreenState._startDownload` chứa toàn bộ nghiệp vụ bắt đầu tải: lưu output path, xin quyền notification theo platform, map `PlaylistEntry` → `VideoInfo`, quyết định gọi `enqueue` / `enqueueBatch` / `enqueuePlaylist`. Tương tự `_AnalyzeScreenState._initServices` khởi tạo storage service + xin quyền storage từ initState của widget. Logic này không tái sử dụng được (vd. tải lại từ SummaryScreen) và không test được nếu không dựng widget.

```dart
      final notificationStatus = await Permission.notification.request();
```
**Fix:**
```dart
// providers/download_provider.dart
class DownloadNotifier extends Notifier<DownloadState> {
  Future<void> startFromFormat({
    required VideoInfo info,
    required FormatOption format,
    List<PlaylistEntry>? selectedEntries,
    String? outputPath,
  }) async {
    if (outputPath != null) await ref.read(outputDirProvider.notifier).setPath(outputPath);
    await ref.read(permissionServiceProvider).ensureNotification();
    if (selectedEntries case final e? when e.isNotEmpty) {
      return enqueueBatch(infos: e.map((x) => x.toVideoInfo(info.platform)).toList(), format: format);
    }
    return info.type == VideoType.playlist
        ? enqueuePlaylist(playlistInfo: info, format: format)
        : enqueue(info: info, format: format);
  }
}
// format_screen: await ref.read(downloadProvider.notifier).startFromFormat(...); rồi navigate
```

## [MEDIUM] no_action_feedback — `lib/features/downloader/screens/format/format_screen.dart:473`
confidence 0.80

_startDownload có nhiều await (lưu path, hộp thoại xin quyền notification, enqueue) nhưng nút 'Bắt đầu tải' không disable/spinner trong lúc chạy → bấm đúp sẽ enqueue video/playlist 2 lần và pushNamedAndRemoveUntil 2 lần.

```dart
              onDownload: _canDownload ? _startDownload : null,
```
**Fix:**
```dart
bool _submitting = false;
Future<void> _startDownload() async {
  if (_submitting) return;
  setState(() => _submitting = true);
  try { ... } finally { if (mounted) setState(() => _submitting = false); }
}
// PrimaryButton(isLoading: _submitting, onPressed: _canDownload && !_submitting ? _startDownload : null)
```

## [MEDIUM] layering_violation — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:58`
confidence 0.80
related: lib/features/downloader/screens/analyze/analyze_screen.dart, lib/features/downloader/screens/format/format_screen.dart, lib/features/downloader/screens/summary/summary_screen.dart, lib/features/downloader/providers/analyze_provider.dart, lib/features/downloader/providers/download_provider.dart, lib/features/downloader/services/downloader_storage_service.dart, lib/features/downloader/services/ytdlp_service.dart

Feature downloader đã thiết lập pattern gateway qua Riverpod (`analyzeGatewayProvider`/`downloadGatewayProvider` bọc `YtdlpService.instance`, `downloadOutputDirectoryProvider` bọc storage) để widget không chạm service. Nhưng `playlist_picker_screen` gọi thẳng `YtdlpService.instance`, và analyze/format/summary screen gọi thẳng `DownloaderStorageService.instance` (init, requestStoragePermission, setAndSavePath, getExternalBasePath) — bỏ qua tầng provider, không mock/test được và là nguồn gốc của lỗi stale path ở download_provider.

```dart
    final result = await YtdlpService.instance.getPlaylistEntries(
```
**Fix:**
```dart
// providers/analyze_provider.dart
abstract interface class PlaylistGateway {
  Future<PlaylistEntriesResult> getPlaylistEntries(String url);
}
final playlistGatewayProvider = Provider<PlaylistGateway>((ref) => YtdlpService.instance);

// playlist_picker_screen.dart (ConsumerStatefulWidget)
final result = await ref.read(playlistGatewayProvider).getPlaylistEntries(widget.playlistInfo.url);
```

## [MEDIUM] missing_autodispose — `lib/features/downloader/providers/download_provider.dart:480`
confidence 0.75

Provider.family không autoDispose: mỗi taskId từng được watch sẽ giữ một instance sống suốt vòng đời app, không bao giờ được giải phóng kể cả sau khi task bị remove/clearFinished — rò rỉ bộ nhớ tăng dần theo số lượt tải.

```dart
final downloadTaskProvider = Provider.family<DownloadTask?, String>((ref, id) {
```
**Fix:**
```dart
final downloadTaskProvider = Provider.autoDispose.family<DownloadTask?, String>((ref, id) {
  return ref.watch(downloadProvider.select((s) => s.tasks.cast<DownloadTask?>().firstWhere((t) => t?.id == id, orElse: () => null)));
});
```

## [MEDIUM] image_unbounded — `lib/features/downloader/screens/download/download_screen.dart:345`
confidence 0.75

Thumbnail YouTube (1280x720) decode full-res vào ô 64x42 cho mỗi item trong ListView — tốn ~3.5MB RAM/ảnh, raster cache phình, GC churn khi cuộn danh sách dài.

```dart
                    imageUrl: task.thumbnail!,
```
**Fix:**
```dart
CachedNetworkImage(imageUrl: task.thumbnail!, width: 64, height: 42, memCacheWidth: 192, memCacheHeight: 126, fit: BoxFit.cover, ...)
```

## [MEDIUM] expensive_work_in_build — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:46`
confidence 0.75

_filteredEntries chạy vnNormalize (~134 lần replaceAll mỗi chuỗi) cho toàn bộ entries trong mỗi build và chạy lại lần nữa trong onToggle; playlist vài trăm video sẽ giật theo từng phím gõ và từng lần tap chọn.

```dart
    return _entries.where((e) {
      final title = vnNormalize(e.title);
```
**Fix:**
```dart
// khi load: _normTitle = {for (final e in entries) e.id: vnNormalize(e.title)};
// onChanged: setState(() => _filtered = q.isEmpty ? _entries : _entries.where((e) => _normTitle[e.id]!.contains(vnNormalize(q))).toList());
// onToggle nhận entry.id thay vì index
```

## [MEDIUM] image_unbounded — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:363`
confidence 0.75

Thumbnail decode full-res (thường 1280x720) vào ô 72x46 cho từng item của playlist dài — playlist 200+ video phình raster cache và gây GC churn khi cuộn.

```dart
                        imageUrl: entry.thumbnail!,
```
**Fix:**
```dart
CachedNetworkImage(imageUrl: entry.thumbnail!, width: 72, height: 46, memCacheWidth: 216, memCacheHeight: 138, fit: BoxFit.cover, ...)
```

## [MEDIUM] silent_catch — `lib/features/downloader/services/downloader_storage_service.dart:102`
confidence 0.75

Nếu tạo thư mục thất bại (thiếu quyền, đường dẫn không hợp lệ) lỗi bị nuốt và code vẫn gán _downloadPath rồi lưu vào SharedPreferences; các lần tải sau sẽ ghi vào thư mục không tồn tại và lỗi khó hiểu. Các catch (_) khác ở dòng 64, 93, 140 cũng không log.

```dart
await dir.create(recursive: true);
      } catch (_) {}
```
**Fix:**
```dart
try {
  await dir.create(recursive: true);
} catch (e) {
  debugPrint('[StorageService] cannot create $path: $e');
  rethrow; // hoặc return false để UI báo user
}
```

## [MEDIUM] rebuild_scope_too_wide — `lib/screens/library_screen.dart:315`
confidence 0.75

build() của _LibraryScreenState dài ~230 dòng và setState() rỗng được gọi trên mỗi phím gõ (và trên mỗi lần đổi tab qua _tabCtrl.addListener) chỉ để cập nhật icon xoá/chỉ báo phạm vi, khiến toàn bộ header, TabBar và tab content rebuild lại.

```dart
                    context.read<MusicProvider>().setLibrarySearchQuery(q);
                    setState(() {});
```
**Fix:**
```dart
// Tách ô search thành widget riêng, dùng ValueListenableBuilder<TextEditingValue>(valueListenable: _searchCtrl, ...) cho suffixIcon/scope row thay vì setState toàn màn hình.
```

## [MEDIUM] image_unbounded — `lib/screens/playlist_screen.dart:157`
confidence 0.75

Ảnh bìa tuỳ chỉnh được decode ở độ phân giải gốc (ảnh camera có thể 12MP) cho ô 52x52 trong ListView; mỗi playlist có cover sẽ chiếm hàng chục MB raster cache và gây GC/jank khi cuộn.

```dart
        child: Image.file(
          File(playlist.coverPath!),
```
**Fix:**
```dart
Image.file(
  File(playlist.coverPath!),
  width: size, height: size, fit: BoxFit.cover,
  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
)
```

## [MEDIUM] silent_catch — `lib/services/audio_handler.dart:40`
confidence 0.75

_init() (được gọi fire-and-forget trong constructor) nuốt hoàn toàn lỗi setAudioSource; nếu thất bại thì player không có source, mọi loadSongs/play sau đó im lặng không phát nhạc và không có log nào để chẩn đoán.

```dart
      await _player.setAudioSource(_playlist);
    } catch (_) {}
```
**Fix:**
```dart
Future<void> _init() async {
  try {
    await _player.setAudioSource(_playlist);
  } catch (e, s) {
    debugPrint('[AudioHandler] setAudioSource failed: $e\n$s');
    _initError = e; // expose cho PlayerProvider hiển thị / retry
  }
}
// và lưu Future _ready = _init(); để loadSongs await _ready trước khi addAll
```

## [MEDIUM] expensive_work_in_build — `lib/services/audio_handler.dart:162`
confidence 0.75

Getter tạo stream combineLatest3 mới mỗi lần truy cập, mà nó được dùng trực tiếp làm `stream:` của StreamBuilder trong build (mini_player._MiniProgressBar, now_playing_screen x2); mỗi rebuild StreamBuilder thấy stream khác → unsubscribe/resubscribe 3 stream của just_audio, snapshot về hasData=false trong 1 frame → thanh progress nháy và tốn CPU vô ích.

```dart
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
```
**Fix:**
```dart
late final Stream<PositionData> positionDataStream =
    Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
      _player.positionStream,
      _player.bufferedPositionStream,
      _player.durationStream,
      (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
    ).shareValue(); // 1 broadcast stream dùng chung, identity ổn định
```

## [MEDIUM] rebuild_scope_too_wide — `lib/widgets/music_list_tile.dart:38`
confidence 0.75

Mỗi tile trong mọi danh sách subscribe toàn bộ MusicProvider chỉ để lấy isFav — giá trị chỉ dùng trong menu long-press, không hiển thị trên tile. MusicProvider.onSongPlayed()/toggleFavorite() gọi notifyListeners nên mỗi lần phát một bài, toàn bộ tile đang hiển thị (kèm QueryArtworkWidget) rebuild.

```dart
    final musicProvider = context.watch<MusicProvider>();
```
**Fix:**
```dart
// bỏ context.watch trong build; lấy khi cần:
onLongPress: onLongPress ?? () {
  HapticFeedback.mediumImpact();
  final music = context.read<MusicProvider>();
  _showContextMenu(context, music.isFavorite(song.id), music);
},
```

## [MEDIUM] silent_catch — `lib/features/downloader/services/ytdlp_service.dart:255`
confidence 0.72

Lỗi từ channel/JSON bị nuốt hoàn toàn không log (3 chỗ: restoreDownloads, _withLiveProgress, cancel). Khi getDownloadTasks lỗi, toàn bộ lịch sử tải đang chạy biến mất im lặng; khi cancelDownload lỗi, UI chỉ nhận false mà không ai biết nguyên nhân.

```dart
} catch (_) {
      return const [];
    }
```
**Fix:**
```dart
} catch (e, st) {
  debugPrint('[YtdlpService] restoreDownloads failed: $e\n$st');
  return const [];
}
```

## [MEDIUM] error_state_missing — `lib/features/downloader/screens/analyze/analyze_screen.dart:54`
confidence 0.70

Lỗi khởi động hiển thị raw exception $e cho user, không có nút thử lại, và nút Phân tích kẹt ở 'Đang khởi động...' (isLoading = !_serviceReady) vĩnh viễn — user chỉ còn cách thoát app.

```dart
      if (mounted) setState(() => _initError = 'Khởi động thất bại: $e');
```
**Fix:**
```dart
_ErrorCard(message: 'Không thể khởi động bộ tải. Vui lòng thử lại.', onRetry: _initServices)
// và: isLoading: analyzeState.isLoading || (!_serviceReady && _initError == null)
```

## [MEDIUM] async_context_use — `lib/features/downloader/screens/analyze/analyze_screen.dart:62`
confidence 0.70

_paste dùng _controller.text và ref.read sau await Clipboard.getData mà không có guard mounted; riverpod 3.x ném StateError 'Using ref when a widget has been unmounted' và TextEditingController đã dispose sẽ crash nếu user thoát màn hình đúng lúc.

```dart
      ref.read(analyzeProvider.notifier).onUrlChanged(data.text!);
```
**Fix:**
```dart
final data = await Clipboard.getData(Clipboard.kTextPlain);
if (!mounted || data?.text == null) return;
_controller.text = data!.text!;
```

## [MEDIUM] unawaited_future — `lib/providers/music_provider.dart:322`
confidence 0.70

createPlaylist bỏ rơi Future ghi SharedPreferences (không await, không unawaited, không bắt lỗi) trong khi mọi hàm playlist khác đều await; caller nhận PlaylistItem và tưởng đã lưu, nếu ghi thất bại playlist mới biến mất sau khi restart mà không ai biết.

```dart
    notifyListeners();
    _persistPlaylists();
```
**Fix:**
```dart
Future<PlaylistItem> createPlaylist(String name) async {
  final pl = PlaylistItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name);
  _playlists.add(pl);
  notifyListeners();
  await _persistPlaylists();
  return pl;
}
```

## [MEDIUM] unawaited_future — `lib/providers/player_provider.dart:134`
confidence 0.70

Khi hết playlist ở chế độ shuffleLoop, chuỗi loadSongs→play không được await và không có catchError; nếu loadSongs/play ném lỗi (file bị xoá, player lỗi) thì exception rơi vào zone không ai bắt, còn _currentSong/_playQueue đã đổi nên UI hiển thị bài mới mà không phát gì.

```dart
      _loadQueueToHandler(0).then((_) => _handler.play());
```
**Fix:**
```dart
Future<void> _onPlaylistEnded() async {
  if (_repeatMode != RepeatMode.shuffleLoop || _originalQueue.isEmpty) return;
  _buildShuffledQueueTrueRandom(startIndex: Random().nextInt(_originalQueue.length));
  _currentPlayIndex = 0;
  _currentSong = _playQueue[0];
  notifyListeners();
  try {
    await _loadQueueToHandler(0);
    await _handler.play();
  } catch (e) {
    debugPrint('shuffleLoop reload failed: $e');
  }
}
```

## [MEDIUM] race_shared_mutable — `lib/providers/player_provider.dart:171`
confidence 0.70

playSongs/playSongsShuffled không có token huỷ hay cờ đang-load: người dùng bấm nhanh 2 bài khác nhau → hai lần clear()/addAll() trên ConcatenatingAudioSource đan xen (playlist thực tế = A+B) trong khi _playQueue chỉ là B; ngoài ra currentIndexStream bắn trong lúc load không bị chặn (_isChangingTrack=false) nên _applyCurrentIndex ghi sai _currentSong/_historyStack theo index của queue cũ.

```dart
    await _loadQueueToHandler(_currentPlayIndex);
```
**Fix:**
```dart
int _loadGeneration = 0;
...
final gen = ++_loadGeneration;
_isChangingTrack = true;
try {
  await _loadQueueToHandler(_currentPlayIndex);
} finally {
  _isChangingTrack = false;
}
if (gen != _loadGeneration) return; // có lệnh play mới hơn, bỏ qua
await _handler.play();
```

## [MEDIUM] rebuild_scope_too_wide — `lib/screens/now_playing_screen.dart:170`
confidence 0.70

build() của cả màn hình (~180 dòng, gồm nền blur, flip card, queue sheet) watch toàn bộ PlayerProvider và LyricsProvider; PlayerProvider notify mỗi 1 giây khi bật hẹn giờ ngủ (Timer.periodic trong setSleepTimer) và LyricsProvider notify mỗi lần đổi dòng lời (updatePosition gọi từ post-frame ở dòng 502) → toàn bộ cây widget rebuild liên tục chỉ để đổi vài chữ.

```dart
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
```
**Fix:**
```dart
// Chỉ lấy slice cần thiết ở tầng màn hình, phần còn lại dùng Selector/Consumer cục bộ
final song = context.select<PlayerProvider, SongItem?>((p) => p.currentSong);
// _ExpandablePillBar: Selector<PlayerProvider, (double, bool)>(selector: (_, p) => (p.speed, p.sleepTimerActive), ...)
// _LyricsView: Consumer<LyricsProvider>(builder: ...) thay vì watch ở NowPlayingScreen
```

## [MEDIUM] blur_layer_abuse — `lib/screens/now_playing_screen.dart:1187`
confidence 0.70

BackdropFilter sigma 40 phủ toàn màn hình nằm cùng repaint boundary với đĩa cover xoay 60fps (Transform.rotate không có RepaintBoundary ở Normal mode) nên GPU chạy lại blur full-screen + 2 BoxShadow blurRadius 60/40 mỗi frame suốt lúc phát; khi mở queue lại chồng thêm BackdropFilter sigma 10 ở dòng 2313 → 2 lớp saveLayer, jank rõ trên máy tầm trung.

```dart
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
```
**Fix:**
```dart
// Blur ảnh tĩnh 1 lần thay vì BackdropFilter, cover xoay tách RepaintBoundary
RepaintBoundary(
  child: ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
    child: QueryArtworkWidget(id: albumId, type: ArtworkType.ALBUM, artworkFit: BoxFit.cover),
  ),
)
// ... và trong _AlbumArtSection: RepaintBoundary(child: ReactiveCoverArtTransform(...))
```

## [MEDIUM] undisposed_resource — `lib/screens/now_playing_screen.dart:1582`
confidence 0.70

Hai TextEditingController (titleCtrl, artistCtrl) được tạo mỗi lần mở sheet 'Sửa thông tin' nhưng không bao giờ dispose → rò rỉ controller + listener sau mỗi lần người dùng mở/đóng sheet.

```dart
    final titleCtrl = TextEditingController(text: song.title);
```
**Fix:**
```dart
showModalBottomSheet(...).whenComplete(() {
  titleCtrl.dispose();
  artistCtrl.dispose();
});
// hoặc tách _EditMetaSheet thành StatefulWidget và dispose trong dispose()
```

## [MEDIUM] no_action_feedback — `lib/screens/playlist_screen.dart:62`
confidence 0.70

Xoá playlist từ menu ba chấm thực hiện ngay lập tức, không có dialog xác nhận, không SnackBar/Undo; một cú chạm nhầm mất cả danh sách không thể khôi phục.

```dart
                  onDelete: () => music.deletePlaylist(pl.id),
```
**Fix:**
```dart
onDelete: () async {
  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('Xóa ${pl.name}?'), actions: [...]));
  if (ok == true) { await music.deletePlaylist(pl.id); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa'))); }
},
```

## [MEDIUM] rebuild_scope_too_wide — `lib/screens/playlist_screen.dart:340`
confidence 0.70

build() của PlaylistDetailScreen dài ~330 dòng và watch cả MusicProvider lẫn PlayerProvider ở gốc, nên mỗi notify của player (play/pause, đổi bài, sleep-timer tick mỗi giây) rebuild toàn bộ SliverAppBar, header ảnh, các nút và danh sách chỉ để đổi isActive của một tile.

```dart
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();
```
**Fix:**
```dart
// Chỉ watch PlayerProvider trong tile:
Selector<PlayerProvider, int?>(selector: (_, p) => p.currentSong?.id, builder: (_, activeId, __) => MusicListTile(song: song, isActive: activeId == song.id, ...))
```

## [MEDIUM] silent_catch — `lib/services/lyrics_service.dart:138`
confidence 0.70

clearCache và clearAllCache (2 site) nuốt sạch lỗi xoá file/thư mục; người dùng bấm 'xoá cache lyrics' thấy thành công trong khi cache vẫn còn, và không có log để biết vì sao.

```dart
      if (await file.exists()) await file.delete();
    } catch (_) {}
```
**Fix:**
```dart
Future<void> clearAllCache() async {
  try {
    final dir = await _getCacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    _cacheDir = null;
  } catch (e, s) {
    debugPrint('[Lyrics] clearAllCache error: $e\n$s');
    rethrow; // để UI báo lỗi cho người dùng
  }
}
```

## [LOW] duplicate_logic — `lib/features/downloader/models/playlist_entry.dart:61`
confidence 0.85
related: lib/features/downloader/models/video_info.dart, lib/models/song_item.dart, lib/screens/now_playing_screen.dart, lib/screens/playlist_screen.dart

Định dạng Duration/giây → chuỗi được viết lại 6 lần với 4 kiểu output khác nhau: `PlaylistEntry.formattedDuration` và `VideoInfo.formattedDuration` (giống nhau từng dòng), `SongItem.durationFormatted` (mm:ss từ ms), `_NowPlayingScreenState._fmt` (mm:ss), `_formatRemaining` ('$m phút'), `PlaylistDetailScreen._fmtDuration` ('Xh Ym'). Cùng một bài hát có thể hiện '3:05' ở nơi này và '03:05' ở nơi khác; sửa một chỗ không đồng bộ chỗ khác.

```dart
    final h = duration! ~/ 3600;
    final m = (duration! % 3600) ~/ 60;
```
**Fix:**
```dart
// lib/utils/duration_format.dart
extension DurationFormat on Duration {
  String get mmss => '${inMinutes.toString().padLeft(2, '0')}:${(inSeconds % 60).toString().padLeft(2, '0')}';
  String get clock => inHours > 0
      ? '$inHours:${(inMinutes % 60).toString().padLeft(2, '0')}:${(inSeconds % 60).toString().padLeft(2, '0')}'
      : '${inMinutes}:${(inSeconds % 60).toString().padLeft(2, '0')}';
  String get compact => inHours > 0 ? '${inHours}h ${inMinutes % 60}m' : '${inMinutes}m';
}
// PlaylistEntry/VideoInfo: Duration(seconds: duration!).clock ; SongItem: Duration(milliseconds: duration).mmss
```

## [LOW] hardcoded_style — `lib/screens/album_detail_screen.dart:43`
confidence 0.85

Icon back ghi cứng Colors.white trong SliverAppBar pinned có backgroundColor c.background: khi cuộn thu gọn ở theme Light, icon trắng trên nền sáng gần như biến mất. Các chỗ khác cũng dùng Colors.white/white70/white54 và Colors.black.withValues(alpha: 0.50) thay vì c.onPlayer/c.scrimLight (ArtistDetailScreen đã dùng token đúng).

```dart
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Colors.white,
```
**Fix:**
```dart
icon: Icon(
  Icons.arrow_back_ios_new_rounded,
  size: 20,
  color: c.onPlayer,
),
```

## [LOW] hardcoded_style — `lib/screens/welcome_screen.dart:99`
confidence 0.85

Tiêu đề 'Muzic' ghi cứng Colors.white trên Scaffold backgroundColor c.background: ở theme Light chữ trắng trên nền sáng không đọc được, trong khi dòng 'AUDIO' ngay dưới đã dùng token c.textTertiary.

```dart
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
```
**Fix:**
```dart
color: c.textPrimary,
```

## [LOW] empty_state_missing — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:286`
confidence 0.80

Khi playlist không có video hợp lệ hoặc từ khoá tìm kiếm không khớp, _EntryList render trống hoàn toàn — user tưởng app lỗi/đang tải.

```dart
      itemCount: entries.length,
```
**Fix:**
```dart
if (entries.isEmpty) return const _EmptyLabel(text: 'Không tìm thấy video nào');
return ListView.builder(...);
```

## [LOW] duplicate_logic — `lib/features/downloader/widgets/glass_card.dart:33`
confidence 0.80
related: lib/widgets/glass_container.dart

`GlassCard` (downloader) và `GlassContainer` (lib/widgets) là cùng một widget: ClipRRect → BackdropFilter(blur 12) → Container(glassBg, glassBorder, radius 16). Khác biệt duy nhất là GlassContainer lấy màu theo theme (`context.appColors`) còn GlassCard dùng hằng tĩnh, nên card kính của downloader không đổi theo theme. Nên giữ một `GlassContainer` và thêm `onTap`/`width` nếu cần.

```dart
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
```
**Fix:**
```dart
// Xoá glass_card.dart; trong downloader:
import 'package:muziczz/widgets/glass_container.dart';
GlassContainer(
  padding: const EdgeInsets.all(16),
  child: onTap == null ? child : InkWell(onTap: onTap, child: child),
)
```

## [LOW] opacity_animation — `lib/screens/onboarding_screen.dart:173`
confidence 0.80

Widget Opacity được rebuild mỗi tick của _pulseCtrl (repeat suốt >5 giây quét), mỗi frame tạo saveLayer mới. FadeTransition dùng OpacityLayer ở compositor, không rebuild widget.

```dart
                          Opacity(opacity: _pulseOpacity.value, child: child),
```
**Fix:**
```dart
ScaleTransition(
  scale: _pulseScale,
  child: FadeTransition(
    opacity: _pulseOpacity,
    child: Container(/* pulse icon */),
  ),
)
```

## [LOW] feature_structure_drift — (cross-file)
confidence 0.75
related: lib/features/downloader/core/theme/app_colors.dart, lib/features/music_visual/poc/android_visualizer_poc_screen.dart, lib/screens/profile_screen.dart, lib/providers/music_provider.dart, lib/services/storage_service.dart

Repo dùng 2 quy ước cùng lúc: phần lõi là layered-flat (`lib/screens`, `lib/providers`, `lib/services`, `lib/widgets`, `lib/models`, `lib/theme`) còn `lib/features/downloader` và `lib/features/music_visual` là feature-module tự chứa (mỗi feature có models/providers/services/widgets riêng, downloader còn có `core/theme` + `core/constants` riêng, music_visual có `poc/` chứa màn hình vẫn được navigate tới từ profile). Muốn tìm 'provider của màn hình X' phải đoán xem X thuộc quy ước nào; theme và glass widget vì thế bị nhân đôi.

**Fix:**
```dart
// Chọn một quy ước. Đề xuất: feature-first, dùng chung core/
// lib/core/{theme,widgets,utils}      <- app_colors*, app_theme, glass_container, duration_format
// lib/features/player/{screens,providers,services,widgets}   <- now_playing, mini_player, player_provider, audio_handler
// lib/features/library/{screens,providers,services,widgets}  <- library, playlist, album/artist detail, music_provider, music_scanner, storage_service
// lib/features/downloader/...  (bỏ core/theme, dùng lib/core/theme)
// lib/features/music_visual/...  (đổi poc/ -> screens/ hoặc gate sau feature flag)
```

## [LOW] tap_target_small — `lib/features/downloader/screens/download/download_screen.dart:581`
confidence 0.75

_TinyButton (Hủy/Thử lại/Xóa) là GestureDetector padding 10x5 với icon 13 + text 12 → cao ~26dp, dưới ngưỡng 44dp; nút Xóa/Hủy cạnh nhau dễ bấm nhầm.

```dart
class _TinyButton extends StatelessWidget {
```
**Fix:**
```dart
ConstrainedBox(constraints: const BoxConstraints(minHeight: 44, minWidth: 44), child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(...))))
```

## [LOW] tap_target_small — `lib/features/downloader/screens/summary/summary_screen.dart:338`
confidence 0.75

Nút 'Thử lại tất cả' là GestureDetector padding 10x4 với text 12px → cao ~24dp, dưới ngưỡng 44dp.

```dart
                onTap: onRetryAll,
```
**Fix:**
```dart
TextButton.icon(onPressed: onRetryAll, style: TextButton.styleFrom(minimumSize: const Size(44, 44)), icon: const Icon(Icons.refresh_rounded, size: 14), label: const Text('Thử lại tất cả'))
```

## [LOW] missing_semantics — `lib/features/downloader/widgets/primary_icon_button.dart:68`
confidence 0.75

Nút chỉ có icon, không có tooltip hay Semantics label nên TalkBack chỉ đọc 'button' không rõ chức năng (paste/clear/analyze...).

```dart
: Icon(icon, color: Colors.white, size: 20),
```
**Fix:**
```dart
class PrimaryIconButton { final String semanticLabel; ... }

return Semantics(
  button: true,
  enabled: enabled,
  label: semanticLabel,
  child: Tooltip(message: semanticLabel, child: AnimatedOpacity(...)),
);
```

## [LOW] hardcoded_style — `lib/screens/library_screen.dart:456`
confidence 0.75

Menu sắp xếp dùng token tĩnh AppColors (hằng dark-only) trong khi phần còn lại của file dùng context.appColors theo theme; ở light mode chữ trong PopupMenu (nền c.card) sẽ sai màu. Ngoài ra Colors.white xuất hiện 2 chỗ (dòng 726, 1270) dù đã có token c.onPlayer.

```dart
          color: _sortType == t ? AppColors.primary : AppColors.textPrimary,
```
**Fix:**
```dart
final c = context.appColors;
color: _sortType == t ? c.primary : c.textPrimary,
```

## [LOW] tap_target_small — `lib/screens/now_playing_screen.dart:826`
confidence 0.75

Nút đóng pill bar chỉ 16 + 6*2 = 28dp; các action icon trong _buildActionIcon 20 + 10*2 = 40dp; link tên album ở _TopBar (chữ 12sp + icon 9) chỉ cao ~18dp → 3 vùng bấm dưới ngưỡng 44–48dp, khó chạm chính xác.

```dart
                              padding: const EdgeInsets.all(6),
```
**Fix:**
```dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => setState(() => _isExpanded = false),
  child: SizedBox(
    width: 48, height: 48,
    child: Center(child: Container(padding: const EdgeInsets.all(6), ... child: const Icon(Icons.close_rounded, size: 16))),
  ),
)
```

## [LOW] opacity_animation — `lib/widgets/theme_switch_wrapper.dart:69`
confidence 0.75

Overlay toàn màn hình dùng Opacity rebuild mỗi tick trong AnimatedBuilder (560ms) ngay lúc cả cây widget đang rebuild vì đổi theme — mỗi frame thêm một saveLayer full-screen. FadeTransition dùng OpacityLayer, không rebuild widget.

```dart
                      ? Opacity(
                        opacity: _opacity.value * 0.45,
```
**Fix:**
```dart
FadeTransition(
  opacity: Tween(begin: 0.0, end: 0.45).animate(_opacity),
  child: IgnorePointer(
    ignoring: !_ctrl.isAnimating,
    child: const ModalBarrier(color: Colors.black),
  ),
)
```

## [LOW] tap_target_small — `lib/features/downloader/screens/analyze/analyze_screen.dart:149`
confidence 0.70

Nút back là GestureDetector 36x36 và _ActionIconButton (Dán/Xóa) cũng 36x36 — dưới ngưỡng 44-48dp, dễ bấm trượt (2 chỗ trong file).

```dart
                              Navigator.of(context, rootNavigator: true).pop(),
```
**Fix:**
```dart
SizedBox(width: 48, height: 48, child: IconButton(tooltip: 'Quay lại', icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onPressed: () => Navigator.of(context, rootNavigator: true).pop()))
```

## [LOW] missing_semantics — `lib/features/downloader/screens/analyze/analyze_screen.dart:519`
confidence 0.70

Nút chọn thư mục và nút back chỉ có icon, không tooltip/Semantics label — TalkBack đọc 'button' không rõ chức năng.

```dart
            PrimaryIconButton(
              icon: Icons.folder_open_rounded,
              onPressed: onPickFolder,
```
**Fix:**
```dart
Semantics(label: 'Chọn thư mục lưu', button: true, child: PrimaryIconButton(icon: Icons.folder_open_rounded, onPressed: onPickFolder))
```

## [LOW] form_field_ergonomics — `lib/features/downloader/screens/analyze/analyze_screen.dart:633`
confidence 0.70

TextField khai báo action 'Go' nhưng không có onSubmitted, bấm Go trên bàn phím không phân tích gì — user phải đóng bàn phím rồi tìm nút Phân tích.

```dart
                  textInputAction: TextInputAction.go,
```
**Fix:**
```dart
onSubmitted: (_) => onSubmit(), // truyền _analyze xuống _UrlInputCard
```

## [LOW] hardcoded_style — `lib/features/downloader/screens/analyze/analyze_screen.dart:857`
confidence 0.70

Màu ngữ nghĩa (error 0xFFFF3B30 x4, success 0xFF34C759, warning 0xFFFF9F0A) hardcode rải rác thay vì token trong AppColors — đổi theme phải sửa từng chỗ.

```dart
        color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
```
**Fix:**
```dart
// AppColors: static const Color error = Color(0xFFFF3B30);
color: AppColors.error.withValues(alpha: 0.08),
```

## [LOW] hardcoded_style — `lib/features/downloader/screens/download/download_screen.dart:136`
confidence 0.70

Màu trạng thái queued/done/error (0xFFFF9F0A, 0xFF34C759, 0xFFFF3B30) hardcode lặp lại ~12 lần trong 4 widget khác nhau thay vì token AppColors.

```dart
            color: const Color(0xFFFF9F0A),
```
**Fix:**
```dart
// AppColors: static const warning = Color(0xFFFF9F0A); success = Color(0xFF34C759); error = Color(0xFFFF3B30);
color: AppColors.warning,
```

## [LOW] hardcoded_ui_strings — `lib/features/downloader/screens/downloader_gateway_screen.dart:93`
confidence 0.70

Toàn bộ copy của màn hình ('Tải nhạc từ URL', 'Quét lại thư viện', 'Cần kết nối mạng để tải nhạc', các dòng Lưu ý...) nằm inline trong widget, không có file strings tập trung.

```dart
'Tải nhạc',
```
**Fix:**
```dart
Text(DownloaderStrings.gatewayTitle, style: ...)
```

## [LOW] hardcoded_style — `lib/features/downloader/screens/downloader_gateway_screen.dart:161`
confidence 0.70

Màu trạng thái online/offline, màu cảnh báo 0xFFFF9500 (dòng 310), gradient 0xFF5C6BC0 (dòng 136) và màu disabled 0xFF2A2A2A (dòng 406) viết cứng thay vì token AppColors; cùng màu 34C759/FF3B30 lặp lại ở network_status_badge nên đổi theme sẽ lệch nhau.

```dart
final color = isOnline ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
```
**Fix:**
```dart
final color = isOnline ? AppColors.success : AppColors.error;
```

## [LOW] missing_semantics — `lib/features/downloader/screens/downloader_gateway_screen.dart:388`
confidence 0.70

Hai nút chính của màn hình là GestureDetector bọc Container, không có Semantics(button: true, enabled:) nên TalkBack không nhận ra là nút và không đọc trạng thái disabled/lý do; IconButton back ở dòng 84 cũng thiếu tooltip.

```dart
onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
```
**Fix:**
```dart
return Semantics(
  button: true,
  enabled: widget.enabled,
  label: widget.label,
  hint: widget.enabled ? widget.subtitle : widget.disabledReason,
  child: AnimatedOpacity(...),
);
```

## [LOW] hardcoded_style — `lib/features/downloader/screens/format/format_screen.dart:338`
confidence 0.70

Màu warning 0xFFFF9500 (x4), success 0xFF34C759, warning 0xFFFF9F0A hardcode trong widget thay vì token AppColors — 2 sắc cam khác nhau cho cùng ngữ nghĩa warning.

```dart
                    color: const Color(0xFFFF9500).withValues(alpha: 0.1),
```
**Fix:**
```dart
color: AppColors.warning.withValues(alpha: 0.1), // AppColors.warning = Color(0xFFFF9F0A)
```

## [LOW] tap_target_small — `lib/features/downloader/screens/playlist_picker/playlist_picker_screen.dart:253`
confidence 0.70

Nút 'Chọn tất cả / Bỏ chọn tất cả' là GestureDetector text 12px padding 6 dọc → cao ~28dp, dưới ngưỡng 44dp.

```dart
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
```
**Fix:**
```dart
ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: TextButton(onPressed: allSelected ? onDeselectAll : onSelectAll, child: Text(...)))
```

## [LOW] hardcoded_style — `lib/features/downloader/screens/summary/summary_screen.dart:195`
confidence 0.70

Màu success/error (0xFF34C759, 0xFF30D158, 0xFFFF3B30 x4) hardcode rải rác thay vì token AppColors — không đồng bộ với các màn khác nếu đổi palette.

```dart
                      colors: [Color(0xFF34C759), Color(0xFF30D158)],
```
**Fix:**
```dart
gradient: AppColors.successGradient, // định nghĩa trong AppColors
```

## [LOW] hardcoded_style — `lib/features/downloader/widgets/network_status_badge.dart:76`
confidence 0.70

Màu online/offline viết cứng (trùng với downloader_gateway_screen) và fontSize 11 magic number thay vì token AppColors / textTheme; đổi theme sẽ không đồng bộ.

```dart
? const Color(0xFF34C759) // xanh lá hệ thống iOS
```
**Fix:**
```dart
final color = isOnline ? AppColors.success : AppColors.error;
```

## [LOW] hardcoded_ui_strings — `lib/features/music_visual/widgets/visual_mode_selector_sheet.dart:97`
confidence 0.70

Tiêu đề, mô tả, nút 'Áp dụng', badge 'Hiện tại' và mô tả từng mode viết inline trong widget; không có file strings tập trung.

```dart
                      'Chọn phong cách hiển thị khi phát nhạc',
```
**Fix:**
```dart
Text(S.visualModeSubtitle, style: ...),
```

## [LOW] missing_semantics — `lib/screens/album_detail_screen.dart:41`
confidence 0.70

2 control chỉ có icon không có nhãn a11y: nút back (không tooltip) và nút info Shuffle Loop (GestureDetector bọc Icon, dòng 117).

```dart
            leading: IconButton(
              icon: const Icon(
```
**Fix:**
```dart
IconButton(
  tooltip: 'Quay lại',
  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
  onPressed: () => Navigator.pop(context),
)
```

## [LOW] hardcoded_ui_strings — `lib/screens/album_detail_screen.dart:198`
confidence 0.70

Nhãn nút, chuỗi đếm bài và nội dung dialog Shuffle Loop ghi cứng inline (trùng nguyên văn với ArtistDetailScreen, nên càng cần gom về một file strings).

```dart
                '${songs.length} bài hát',
```
**Fix:**
```dart
AppStrings.songCount(songs.length)
```

## [LOW] missing_semantics — `lib/screens/artist_detail_screen.dart:46`
confidence 0.70

2 control chỉ có icon không có nhãn a11y: nút back (không tooltip) và nút info Shuffle Loop (GestureDetector bọc Icon, dòng 119) — screen reader không biết chúng là nút hay làm gì.

```dart
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
```
**Fix:**
```dart
IconButton(
  tooltip: 'Quay lại',
  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.onPlayer),
  onPressed: () => Navigator.pop(context),
)
// nút info: Semantics(button: true, label: 'Giải thích Shuffle Loop', child: GestureDetector(...))
```

## [LOW] hardcoded_ui_strings — `lib/screens/artist_detail_screen.dart:72`
confidence 0.70

Nhãn nút, tiêu đề section, nội dung dialog Shuffle Loop và chuỗi đếm '$songCount bài hát · $albumCount album' đều ghi cứng inline.

```dart
                      label: 'Phát tất cả',
```
**Fix:**
```dart
label: AppStrings.playAll,
```

## [LOW] expensive_work_in_build — `lib/screens/artist_detail_screen.dart:218`
confidence 0.70

Mỗi item của ListView album tạo lại toàn bộ list entries (O(n) cho từng item → O(n²)), và bản thân việc gom bài theo album (dòng 29-32) chạy lại trong build mỗi khi PlayerProvider/MusicProvider notify (play/pause, onSongPlayed).

```dart
                    final entry = albumMap.entries.toList()[i];
```
**Fix:**
```dart
final albums = albumMap.entries.toList(); // ngoài itemBuilder
...
itemBuilder: (_, i) {
  final entry = albums[i];
// hoặc nhận albumMap đã gom sẵn từ MusicProvider.artistAlbums(artistId)
```

## [LOW] hardcoded_ui_strings — `lib/screens/hidden_songs_screen.dart:31`
confidence 0.70

Chuỗi giao diện viết cứng trong widget, không có file strings tập trung.

```dart
          'Bài hát đã ẩn',
```
**Fix:**
```dart
Text(AppStrings.hiddenSongs)
```

## [LOW] hardcoded_ui_strings — `lib/screens/home_screen.dart:359`
confidence 0.70

Chuỗi giao diện (lời chào, hint, tiêu đề section, empty state) viết cứng trong widget, không có file strings tập trung.

```dart
          hintText: 'Tìm bài hát, nghệ sĩ, album…',
```
**Fix:**
```dart
hintText: AppStrings.searchHint,
```

## [LOW] hardcoded_ui_strings — `lib/screens/library_screen.dart:260`
confidence 0.70

Toàn bộ chuỗi giao diện (tiêu đề, hint, snackbar, dialog) viết cứng trong widget, không có file strings tập trung nên không thể địa phương hoá.

```dart
                        'Thư viện',
```
**Fix:**
```dart
Text(AppStrings.library) // gom vào lib/l10n hoặc lib/constants/strings.dart
```

## [LOW] tap_target_small — `lib/screens/library_screen.dart:341`
confidence 0.70

Nút xoá tìm kiếm là GestureDetector bọc Icon 18px không padding nên vùng chạm chỉ ~18x18dp, rất khó bấm trúng.

```dart
                                Icons.close_rounded,
                                color: c.textTertiary,
                                size: 18,
```
**Fix:**
```dart
suffixIcon: IconButton(
  tooltip: 'Xóa tìm kiếm',
  icon: Icon(Icons.close_rounded, size: 18, color: c.textTertiary),
  onPressed: () { _searchCtrl.clear(); context.read<MusicProvider>().setLibrarySearchQuery(''); setState(() {}); },
)
```

## [LOW] hardcoded_style — `lib/screens/now_playing_screen.dart:391`
confidence 0.70

Nhiều màu raw (Colors.black.withValues 0.55/0.75, Colors.white54/white38/white24, Slider activeTrackColor: Colors.white) rải rác dù đã có token c.onPlayer*/c.surface* trong AppColorsData → không đồng bộ khi đổi theme/độ tương phản.

```dart
              color: Colors.black.withValues(alpha: 0.75),
```
**Fix:**
```dart
color: c.onPlayerGhostBg, // hoặc thêm token c.overlayStrong vào AppColorsData
style: GoogleFonts.outfit(fontSize: 12, color: c.onPlayerLow),
```

## [LOW] hardcoded_ui_strings — `lib/screens/now_playing_screen.dart:423`
confidence 0.70

Hàng chục chuỗi tiếng Việt (nhãn menu, tiêu đề sheet, snackbar, dialog) viết inline trong widget; dự án chưa có i18n hay file strings tập trung nên khó sửa/dịch thống nhất.

```dart
              'Đang tải lời bài hát…',
```
**Fix:**
```dart
// lib/core/strings.dart
abstract final class S {
  static const lyricsLoading = 'Đang tải lời bài hát…';
}
// Text(S.lyricsLoading, ...)
```

## [LOW] missing_semantics — `lib/screens/now_playing_screen.dart:604`
confidence 0.70

Bìa album (chạm để lật sang lời bài hát) và _LyricsView (chạm để lật về) là GestureDetector trần không có Semantics button/label; các chip tốc độ và preset hẹn giờ cũng là GestureDetector thuần → screen reader không biết đây là nút bấm được (5 vị trí).

```dart
    return GestureDetector(
      onTap: onTap,
      child: Center(
```
**Fix:**
```dart
Semantics(
  button: true,
  label: 'Bìa album, chạm để xem lời bài hát',
  child: GestureDetector(onTap: onTap, child: Center(...)),
)
```

## [LOW] form_field_ergonomics — `lib/screens/now_playing_screen.dart:1677`
confidence 0.70

Form 2 trường (Tên bài hát, Nghệ sĩ) không có textInputAction next/done và không có onSubmitted → nhấn Enter trên bàn phím không chuyển trường/không lưu, người dùng phải tự đóng bàn phím rồi bấm 'Lưu'.

```dart
          controller: ctrl,
```
**Fix:**
```dart
TextField(
  controller: ctrl,
  textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
  onSubmitted: isLast ? (_) => onSave() : null,
  ...
)
```

## [LOW] hardcoded_ui_strings — `lib/screens/onboarding_screen.dart:289`
confidence 0.70

Mọi chuỗi trạng thái quét, lỗi, nút 'Thử lại'/'Mở cài đặt' và 20 câu quote đều ghi cứng inline, không có file strings trung tâm.

```dart
          'Đang quét nhạc của bạn…',
```
**Fix:**
```dart
Text(AppStrings.scanningLibrary)  // lib/l10n/app_strings.dart
```

## [LOW] hardcoded_ui_strings — `lib/screens/online_screen.dart:34`
confidence 0.70

Chuỗi giao diện viết cứng trong widget, không có file strings tập trung.

```dart
                    'Trực tuyến',
```
**Fix:**
```dart
Text(AppStrings.online)
```

## [LOW] missing_semantics — `lib/screens/playlist_screen.dart:248`
confidence 0.70

FAB tạo playlist, nút info (dòng 492), nút gỡ bài (dòng 652) là GestureDetector bọc Icon không có Semantics/tooltip; các IconButton back/edit (dòng 354, 363) cũng không có tooltip nên screen reader không biết chức năng.

```dart
    return GestureDetector(
      onTap: () => _showCreateDialog(context),
```
**Fix:**
```dart
Semantics(
  button: true,
  label: 'Tạo danh sách phát',
  child: GestureDetector(onTap: () => _showCreateDialog(context), child: ...),
)
```

## [LOW] undisposed_resource — `lib/screens/playlist_screen.dart:267`
confidence 0.70

TextEditingController tạo trong _showCreateDialog không bao giờ được dispose; mỗi lần mở dialog tạo playlist rò rỉ một controller.

```dart
    final ctrl = TextEditingController();
```
**Fix:**
```dart
showDialog(...).whenComplete(ctrl.dispose);
```

## [LOW] hardcoded_ui_strings — `lib/screens/playlist_screen.dart:381`
confidence 0.70

Mọi chuỗi giao diện (nút, dialog, empty state) viết cứng tiếng Việt trong widget, không có file strings tập trung.

```dart
                        label: 'Phát tất cả',
```
**Fix:**
```dart
label: AppStrings.playAll,
```

## [LOW] tap_target_small — `lib/screens/playlist_screen.dart:576`
confidence 0.70

Nút 'Thêm bài' là GestureDetector bọc Row icon 18px + chữ 13px không padding (cao ~20dp); nút gỡ bài trong danh sách (dòng 652) cũng chỉ ~36dp. Khó chạm chính xác.

```dart
                  GestureDetector(
                    onTap: () => _showAddSongsSheet(context, music, playlist),
```
**Fix:**
```dart
TextButton.icon(
  onPressed: () => _showAddSongsSheet(context, music, playlist),
  icon: Icon(Icons.add_rounded, size: 18),
  label: Text('Thêm bài'),
)
```

## [LOW] undisposed_resource — `lib/screens/playlist_screen.dart:679`
confidence 0.70

TextEditingController trong _showEditDialog không được dispose sau khi dialog đóng, rò rỉ mỗi lần đổi tên.

```dart
    final ctrl = TextEditingController(text: playlist.name);
```
**Fix:**
```dart
showDialog(...).whenComplete(ctrl.dispose);
```

## [LOW] hardcoded_ui_strings — `lib/screens/profile_screen.dart:130`
confidence 0.70

Toàn bộ chuỗi UI ghi cứng; đặc biệt số phiên bản '1.0.0' lệch với pubspec (2.0.0+19) và hộp About viết sai tên app 'Muzizc Audio'. Nên đọc version từ package_info_plus và gom chuỗi vào một file strings.

```dart
                          subtitle: 'Muzicz Audio v1.0.0',
```
**Fix:**
```dart
final info = await PackageInfo.fromPlatform();
subtitle: '${AppStrings.appName} v${info.version}',
```

## [LOW] missing_semantics — `lib/screens/profile_screen.dart:493`
confidence 0.70

IconButton quay lại chỉ có icon, không có tooltip nên TalkBack đọc là 'Button' không rõ chức năng.

```dart
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
```
**Fix:**
```dart
IconButton(
  tooltip: 'Quay lại',
  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.textPrimary),
  onPressed: () => Navigator.pop(context),
)
```

## [LOW] hardcoded_ui_strings — `lib/screens/welcome_screen.dart:128`
confidence 0.70

Tagline và nhãn CTA ghi cứng inline, không có file strings trung tâm.

```dart
                        label: 'Quét nhạc trên máy',
```
**Fix:**
```dart
label: AppStrings.scanDeviceMusic,
```

## [LOW] hardcoded_ui_strings — `lib/widgets/add_to_playlist_sheet.dart:88`
confidence 0.70

Chuỗi giao diện (tiêu đề, hint, snackbar, dialog) viết cứng trong widget, không có file strings tập trung.

```dart
                        'Lưu vào danh sách',
```
**Fix:**
```dart
Text(AppStrings.saveToPlaylist)
```

## [LOW] tap_target_small — `lib/widgets/add_to_playlist_sheet.dart:156`
confidence 0.70

Nút xoá tìm kiếm là GestureDetector bọc Icon 18px không padding nên vùng chạm chỉ ~18x18dp.

```dart
                              Icons.close_rounded,
                              color: c.textTertiary,
                              size: 18,
```
**Fix:**
```dart
suffixIcon: IconButton(tooltip: 'Xóa', icon: Icon(Icons.close_rounded, size: 18, color: c.textTertiary), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
```

## [LOW] undisposed_resource — `lib/widgets/add_to_playlist_sheet.dart:266`
confidence 0.70

TextEditingController tạo trong _showCreateDialog không bao giờ được dispose; rò rỉ mỗi lần mở dialog tạo playlist.

```dart
    final ctrl = TextEditingController();
```
**Fix:**
```dart
showDialog(...).whenComplete(ctrl.dispose);
```

## [LOW] hardcoded_ui_strings — `lib/widgets/app_bottom_navigation.dart:73`
confidence 0.70

Nhãn tab ghi cứng và lặp 2 lần (glass + normal), trộn tiếng Anh 'Home' với 'Trực tuyến'/'Thư viện' tiếng Việt.

```dart
          label: 'Home',
```
**Fix:**
```dart
label: AppStrings.tabHome,
```

## [LOW] hardcoded_ui_strings — `lib/widgets/bottom_nav_style_selector_sheet.dart:94`
confidence 0.70

Tiêu đề, mô tả, nhãn 'Áp dụng', 'Hiện tại' và subtitle option ghi cứng inline.

```dart
                      'Chọn phong cách thanh điều hướng dưới',
```
**Fix:**
```dart
Text(AppStrings.bottomNavStyleSubtitle, ...)
```

## [LOW] hardcoded_ui_strings — `lib/widgets/mini_player.dart:228`
confidence 0.70

Chuỗi dialog và nhãn semantics ('Dừng phát nhạc?', 'Hàng chờ hiện tại sẽ bị xóa.', 'Đóng trình phát', 'Bài trước'...) viết inline; không có file strings tập trung.

```dart
              'Dừng phát nhạc?',
```
**Fix:**
```dart
title: Text(S.stopPlaybackTitle, ...),
content: Text(S.stopPlaybackBody, ...),
```

## [LOW] hardcoded_ui_strings — `lib/widgets/music_list_tile.dart:337`
confidence 0.70

Nhãn menu ngữ cảnh, SnackBar và bảng 'Thông tin bài hát' ghi cứng inline.

```dart
            label: 'Thêm vào danh sách phát',
```
**Fix:**
```dart
label: AppStrings.addToPlaylist,
```

## [LOW] hardcoded_ui_strings — `lib/widgets/theme_selector_sheet.dart:101`
confidence 0.70

Tiêu đề, mô tả, nhãn 'Áp dụng', 'Hiện tại', hint và 3 subtitle theme ghi cứng inline.

```dart
                      'Chọn bộ màu sắc cho ứng dụng',
```
**Fix:**
```dart
Text(AppStrings.themeSheetSubtitle, ...)
```
