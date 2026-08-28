/// ════════════════════════════════════════════════════════════════════════════
/// AppStrings — nguồn chuỗi giao diện duy nhất của ứng dụng.
///
/// ⚠️  KHÔNG viết chuỗi hiển thị cho người dùng trực tiếp trong widget/screen.
///
/// - Chuỗi tĩnh: `static const` → dùng được trong `const Text(...)`.
/// - Chuỗi có tham số: `static String xxx(...)` — gom cả định dạng đếm
///   ('$n bài hát') về đây để sau này địa phương hoá một chỗ.
/// - Nhóm theo màn hình/widget; chuỗi dùng chung nằm ở phần "Chung".
/// ════════════════════════════════════════════════════════════════════════════
abstract final class AppStrings {
  // ─────────────────────────────────────────────────────────────────────────
  // Thương hiệu
  // ─────────────────────────────────────────────────────────────────────────
  static const appName = 'Muzicz Audio';
  static const brandName = 'Muzic';
  static const brandSuffix = 'AUDIO';
  static const copyright = '© 2026 Muzicz Audio';
  static String appVersion(String version) => '$appName v$version';

  // ─────────────────────────────────────────────────────────────────────────
  // Chung — nút / nhãn dùng ở nhiều màn
  // ─────────────────────────────────────────────────────────────────────────
  static const ok = 'OK';
  static const cancel = 'Hủy';
  static const delete = 'Xóa';
  static const save = 'Lưu';
  static const create = 'Tạo';
  static const hide = 'Ẩn';
  static const close = 'Đóng';
  static const back = 'Quay lại';
  static const apply = 'Áp dụng';
  static const current = 'Hiện tại';
  static const retry = 'Thử lại';
  static const restore = 'Khôi phục';
  static const rename = 'Đổi tên';
  static const reset = 'Đặt lại';
  static const stop = 'Dừng';
  static const loading = 'Đang tải';
  static const unknown = 'Unknown';
  static const comingSoon = 'Sắp có';
  static const soon = 'Sớm';
  static const inDevelopment = 'Đang phát triển';

  static const play = 'Phát';
  static const pause = 'Tạm dừng';
  static const playAll = 'Phát tất cả';
  static const shuffle = 'Ngẫu nhiên';
  static const shufflePlay = 'Phát ngẫu nhiên';
  static const shuffleLoop = 'Shuffle Loop';
  static const shuffleLoopDescription =
      'Phát ngẫu nhiên toàn bộ danh sách. Khi hết, tự động xáo bài và phát lại từ đầu — không trùng lặp theo chu kì.';
  static const shuffleLoopInfo = 'Giải thích Shuffle Loop';
  static const previousTrack = 'Bài trước';
  static const nextTrack = 'Bài tiếp theo';
  static const repeat = 'Lặp lại';
  static const repeatOne = 'Lặp lại một bài';
  static const playNext = 'Phát tiếp theo';

  static const favorites = 'Yêu thích';
  static const unfavorite = 'Bỏ yêu thích';
  static const addToFavorites = 'Thêm vào yêu thích';
  static const addToPlaylist = 'Thêm vào danh sách phát';

  // Thông tin bài hát
  static const songInfo = 'Thông tin bài hát';
  static const songDetails = 'Chi tiết bài hát';
  static const editInfo = 'Sửa thông tin';
  static const hideFromLibrary = 'Ẩn khỏi thư viện';
  static const share = 'Chia sẻ';
  static String shareText(String title) => 'Chia sẻ: $title';
  static const fieldTitle = 'Tên bài';
  static const songTitle = 'Tên bài hát';
  static const artist = 'Nghệ sĩ';
  static const album = 'Album';
  static const duration = 'Thời lượng';
  static const filePath = 'Đường dẫn';
  static const songs = 'Bài hát';
  static const playlist = 'Playlist';
  static const folders = 'Thư mục';
  static const library = 'Thư viện';
  static const online = 'Trực tuyến';
  static const profile = 'Hồ sơ';
  static const settings = 'Cài đặt';
  static const appearance = 'Giao diện';
  static const graphics = 'Đồ họa';
  static const musicVisual = 'Music Visual';
  static const hiddenSongs = 'Bài hát đã ẩn';
  static const downloadMusic = 'Tải nhạc';
  static const downloadFromUrl = 'Tải nhạc từ URL';
  static const rescanMusic = 'Quét lại nhạc';
  static const rescanLibrary = 'Quét lại thư viện';

  // Đếm
  static String songCount(int n) => '$n bài hát';
  static String songCountShort(int n) => '$n bài';
  static String artistCount(int n) => '$n nghệ sĩ';
  static String allSongsWithCount(int n) => 'Tất cả bài hát ($n)';
  static String artistStats(int songs, int albums) =>
      '$songs bài hát · $albums album';
  static String albumHeaderSubtitle(String artist, int songs) =>
      '$artist · $songs bài hát';
  static String playlistMeta(int songs, String duration) =>
      '$songs bài · $duration';
  static String selectedCount(int n) => '$n bài đã chọn';

  // Tìm kiếm
  static const searchHint = 'Tìm bài hát, nghệ sĩ, album…';
  static const clearSearch = 'Xóa tìm kiếm';
  static const noResults = 'Không tìm thấy kết quả';
  static const noResultsDot = 'Không tìm thấy kết quả.';
  static const searchTip = 'Thử tìm bằng tên nghệ sĩ hoặc album';
  static const searchSuggestions = 'Gợi ý tìm kiếm:';

  // ─────────────────────────────────────────────────────────────────────────
  // Thanh điều hướng dưới
  // ─────────────────────────────────────────────────────────────────────────
  static const tabHome = 'Trang chủ';
  static const tabOnline = online;
  static const tabLibrary = library;

  // ─────────────────────────────────────────────────────────────────────────
  // Welcome / Onboarding
  // ─────────────────────────────────────────────────────────────────────────
  static const welcomeTagline =
      'Trải nghiệm âm nhạc trong tầm tay.\nTất cả từ bộ sưu tập của bạn.';
  static const scanDeviceMusic = 'Quét nhạc trên máy';

  static const needPermissionTitle = 'Cần quyền truy cập nhạc';
  static const needPermissionBody =
      'Muzicz cần quyền đọc tệp âm thanh để tìm nhạc trên thiết bị.';
  static const scanFailedTitle = 'Không thể quét thư viện';
  static const scanFailedBody = 'Đã có lỗi khi đọc thư viện nhạc. Hãy thử lại.';
  static const scanning = 'Đang quét nhạc của bạn…';
  static const scanningHint = 'Chỉ mất vài giây, hứa!';
  static const openSettings = 'Mở cài đặt';

  static const onboardingQuotes = [
    // Thơ / cảm xúc
    'Âm nhạc là tiếng lòng không cần phiên dịch.',
    'Mỗi bài hát là một chiếc thuyền chở ký ức.',
    'Có những nỗi buồn chỉ nhạc mới hiểu được.',
    'Giai điệu đúng lúc — như một cái ôm vô hình.',
    // Hài hước
    'Tại sao nhạc sĩ giỏi mở khóa? Vì họ có nhiều phím! 🎹',
    'Headphone = giáp trụ cách ly khỏi người đời. 🎧',
    'Bài hát yêu thích là bài bạn bỏ play 47 lần trong một ngày.',
    '– Em đang làm gì vậy?\n– Nghe nhạc.\n– Ừ, không cần nói chuyện nữa.',
    // Quotes
    '"Without music, life would be a mistake." — Nietzsche',
    '"Music gives a soul to the universe." — Plato',
    '"One good thing about music, when it hits you, you feel no pain." — Bob Marley',
    '"Music is the shorthand of emotion." — Tolstoy',
    // Có thể bạn chưa biết
    'Có thể bạn chưa biết: Nghe nhạc buồn thực ra giúp não giải phóng dopamine 🎵',
    'Có thể bạn chưa biết: Tim người có xu hướng đồng bộ nhịp với âm nhạc đang nghe.',
    'Có thể bạn chưa biết: Nhạc nền giúp tăng hiệu suất làm việc lặp lại lên ~15%.',
    'Có thể bạn chưa biết: Bạch tuộc có thể "cảm nhận" âm nhạc qua da 🐙',
    // Triết lý nhẹ
    'Âm nhạc không cần lý do. Cứ bật lên và sống.',
    'Bạn không cần hiểu lời — đôi khi chỉ cần cảm nhận.',
    'Playlist của bạn là nhật ký không có chữ.',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Home
  // ─────────────────────────────────────────────────────────────────────────
  static const greetingMorning = 'Chào buổi sáng';
  static const greetingAfternoon = 'Chào buổi chiều';
  static const greetingEvening = 'Chào buổi tối';
  static const libraryLoading = 'Đang tải thư viện nhạc';
  static const libraryLoadingEllipsis = 'Đang tải thư viện nhạc…';
  static const recentlyPlayed = 'Nghe gần đây';
  static const mostPlayed = 'Nghe nhiều nhất';
  static const randomMix = 'Random Mix';
  static const quickAccess = 'Truy cập nhanh';
  static const recentlyAdded = 'Mới thêm gần đây';
  static const neverPlayed = 'Chưa từng nghe';
  static const emptyLibraryHint =
      'Chưa có nhạc nào.\nHãy quét thư viện nhạc của bạn.';
  static const scanLibraryNow = 'Quét thư viện ngay';

  // ─────────────────────────────────────────────────────────────────────────
  // Library
  // ─────────────────────────────────────────────────────────────────────────
  static const librarySearchHint = 'Tìm trong thư viện…';
  static String searchLocalLibrary(int n) =>
      'Tìm trong thư viện cục bộ · $n bài';
  static const sortAZ = 'A → Z';
  static const sortNewest = 'Mới thêm';
  static const selectSongs = 'Chọn bài hát';
  static const selectAll = 'Chọn tất cả';
  static const deselectAll = 'Bỏ chọn tất cả';
  static const tabPlaylistsShort = 'DS Phát';
  static const emptyLibrary = 'Chưa có nhạc nào trong thư viện.';
  static const noAlbums = 'Không có album nào.';
  static const noArtists = 'Không có nghệ sĩ nào.';
  static const noFolders = 'Không có thư mục nào.';
  static const noPlaylists = 'Chưa có danh sách phát nào.';
  static const scanNow = 'Quét ngay';
  static String addedToFavorites(int n) => 'Đã thêm $n bài vào yêu thích';
  static String removedFromFavorites(int n) => 'Đã bỏ $n bài khỏi yêu thích';
  static String hideSongsTitle(int n) => 'Ẩn $n bài hát?';
  static const hideSongsBody =
      'Các bài hát này sẽ bị ẩn khỏi thư viện. File gốc không bị xóa.';
  static String hiddenSongsDone(int n) => 'Đã ẩn $n bài hát';
  static String addedSongsToPlaylist(int n, String name) =>
      'Đã thêm $n bài vào "$name"';

  // ─────────────────────────────────────────────────────────────────────────
  // Hidden songs
  // ─────────────────────────────────────────────────────────────────────────
  static const restoreSongTitle = 'Khôi phục bài hát?';
  static String restoreSongBody(String title) =>
      '"$title" sẽ xuất hiện lại trong thư viện.';
  static const noHiddenSongs = 'Không có bài hát nào bị ẩn';

  // ─────────────────────────────────────────────────────────────────────────
  // Now Playing
  // ─────────────────────────────────────────────────────────────────────────
  static const nowPlaying = 'ĐANG PHÁT';
  static const fromLibrary = 'Từ thư viện';
  static const albumSongsHint = 'Xem các bài trong album';
  static const albumArtHint = 'Bìa album, chạm để xem lời bài hát';
  static const lyricsHint = 'Lời bài hát, chạm để xem bìa album';
  static const playbackOptions = 'Tùy chọn phát';
  static const collapseOptions = 'Thu gọn tùy chọn';
  static const lyrics = 'Lời bài hát';
  static const lyricsLoading = 'Đang tải lời bài hát…';
  static const lyricsError = 'Không thể tải lời bài hát';
  static const lyricsNone = 'Không có lời bài hát';
  static const queue = 'Hàng chờ phát';
  static const queueShort = 'Hàng chờ';
  static const openQueue = 'Mở hàng chờ phát';
  static const collapseQueue = 'Thu gọn hàng chờ';
  static const removeFromQueue = 'Xóa khỏi hàng chờ';
  static String addedToQueue(String title) => 'Đã thêm "$title" vào hàng chờ';
  static const playbackSpeed = 'Tốc độ phát';
  static const speedNormal = 'Bình thường';
  static String speedMultiplier(String speed) => '$speed×';
  static const sleepTimer = 'Hẹn giờ ngủ';
  static const sleepTimerTitle = 'Hẹn giờ tắt nhạc';
  static const cancelSleepTimer = 'Hủy hẹn giờ';
  static const stopAfterPrefix = 'Dừng sau ';
  static const chooseDuration = 'Chọn thời gian';
  static String minutes(int m) => '$m phút';
  static String seconds(int s) => '${s}s';
  static const hideSongTitle = 'Ẩn bài hát?';
  static String hideSongBody(String title) =>
      '"$title" sẽ bị ẩn khỏi thư viện. File gốc không bị xóa. Có thể quét lại để khôi phục.';

  // ─────────────────────────────────────────────────────────────────────────
  // Mini player
  // ─────────────────────────────────────────────────────────────────────────
  static const closePlayer = 'Đóng trình phát';
  static const stopPlaybackTitle = 'Dừng phát nhạc?';
  static const stopPlaybackBody = 'Hàng chờ hiện tại sẽ bị xóa.';

  // ─────────────────────────────────────────────────────────────────────────
  // Playlist
  // ─────────────────────────────────────────────────────────────────────────
  static const createPlaylist = 'Tạo danh sách phát';
  static const createNewPlaylist = 'Tạo danh sách mới';
  static const playlistNameHint = 'Tên danh sách…';
  static const noPlaylistsCreateHint =
      'Chưa có danh sách phát nào.\nNhấn + để tạo mới.';
  static String deletePlaylistTitle(String name) => 'Xóa "$name"?';
  static const deletePlaylistBody =
      'Danh sách phát sẽ bị xóa. Các bài hát trong máy không bị ảnh hưởng.';
  static String deletedPlaylist(String name) => 'Đã xóa "$name"';
  static const addSongs = 'Thêm bài';
  static const addSongsTitle = 'Thêm bài hát';
  static const removeFromPlaylist = 'Gỡ khỏi danh sách';
  static const emptyPlaylistHint =
      'Danh sách trống.\nNhấn "Thêm bài" để bắt đầu.';
  static const allSongsAlreadyInPlaylist =
      'Tất cả bài hát đã có trong danh sách.';

  // Add-to-playlist sheet
  static const saveToPlaylist = 'Lưu vào danh sách';
  static const searchPlaylistsHint = 'Tìm danh sách…';
  static const noPlaylistsAddHint =
      'Chưa có danh sách nào.\nNhấn "+ Tạo mới" để bắt đầu.';
  static const noPlaylistsFound = 'Không tìm thấy danh sách nào.';
  static String addedToPlaylist(String name) => 'Đã thêm vào "$name"';
  static String removedFromPlaylist(String name) => 'Đã xóa khỏi "$name"';
  static const createAndAdd = 'Tạo & Thêm';
  static String createdPlaylistAndAdded(String name) =>
      'Đã tạo "$name" và thêm bài hát';

  // ─────────────────────────────────────────────────────────────────────────
  // Online
  // ─────────────────────────────────────────────────────────────────────────
  static const onlineComingBody =
      'Tính năng phát nhạc trực tuyến đang được\nxây dựng. Cảm ơn bạn đã chờ đợi!';
  static const onlineDownloadSubtitle =
      'TikTok, YouTube, SoundCloud và hơn thế nữa';
  static const onlineRadio = 'Radio trực tuyến';
  static const onlineRadioSubtitle = 'Nghe các kênh radio từ khắp nơi';
  static const onlineSearch = 'Tìm kiếm trực tuyến';
  static const onlineSearchSubtitle = 'Tìm và phát nhạc trực tiếp từ web';
  static const playlistSync = 'Đồng bộ danh sách phát';
  static const playlistSyncSubtitle = 'Đồng bộ playlist với các nền tảng khác';

  // ─────────────────────────────────────────────────────────────────────────
  // Profile / Settings
  // ─────────────────────────────────────────────────────────────────────────
  static const listener = 'Thính giả';
  static const profileTagline = 'Nocturne Audio';
  static const features = 'Chức năng';
  static const rescanMusicSubtitle = 'Cập nhật thư viện từ bộ nhớ máy';
  static const downloadMusicSubtitle = 'Tải âm thanh dễ dàng chỉ từ URL';
  static const settingsSubtitle = 'Tùy chỉnh giao diện và ứng dụng';
  static const about = 'Về ứng dụng';
  static const colorScheme = 'Bộ màu sắc';
  static const themeDarkLabel = 'Dark — nền tối';
  static const themeAmoledLabel = 'AMOLED — pure black';
  static const themeLightLabel = 'Light — nền sáng';
  static const musicLibrary = 'Thư viện nhạc';
  static const filterShortFiles = 'Lọc file dưới 30 giây';
  static const filterShortFilesSubtitle = 'Bỏ qua nhạc chuông, thông báo';
  static const hiddenSongsSubtitle = 'Xem và khôi phục bài hát bị ẩn';

  // Theme sheet
  static const themeSheetSubtitle = 'Chọn bộ màu sắc cho ứng dụng';
  static String applyThemeHint(String label) =>
      'Nhấn "Áp dụng" để chuyển sang giao diện $label';
  static const themeDarkDesc = 'Nền đen xám, dễ dùng ban đêm';
  static const themeAmoledDesc = 'Pure black, tiết kiệm pin OLED';
  static const themeLightDesc = 'Nền sáng, dễ đọc ngoài trời';

  // Bottom-nav style sheet
  static const bottomNavStyleSubtitle = 'Chọn phong cách thanh điều hướng dưới';
  static const bottomNavFancyDesc = 'Liquid Glass Premium';
  static const bottomNavNormalDesc = 'Thanh điều hướng hiện tại';

  // Music visual sheet
  static const visualModeSubtitle = 'Chọn phong cách hiển thị khi phát nhạc';
  static const visualModeFancyDesc = 'Hiệu ứng âm nhạc — đang phát triển';
  static const visualModeNormalDesc = 'Giao diện phát nhạc hiện tại';
  static const visualizerPocTitle = 'Android Visualizer POC';
  static const visualizerPocSubtitle =
      'Harness riêng; quyền mic chỉ hỏi trong sub-toggle Realtime RMS';

  // ─────────────────────────────────────────────────────────────────────────
  // Downloader — gateway
  // ─────────────────────────────────────────────────────────────────────────
  static const gatewayDownloadSubtitle =
      'YouTube · TikTok · Instagram và hơn thế nữa';
  static const gatewayNeedNetwork = 'Cần kết nối mạng để tải nhạc';
  static const rescanLibrarySubtitle = 'Cập nhật nhạc từ bộ nhớ thiết bị';
  static const networkOnline = 'Đang kết nối mạng';
  static const networkOffline = 'Không có mạng';
  static const networkReady = 'Sẵn sàng tải nhạc';
  static const networkConnectHint =
      'Kết nối Wi-Fi hoặc dữ liệu di động để tiếp tục';
  static const note = 'Lưu ý';
  static const gatewayNoteStorage =
      'File tải về được lưu vào thư mục Downloads (Có thể tùy chỉnh) trên thiết bị.';
  static const gatewayNoteAudio =
      'Hỗ trợ tách audio M4A từ video — không mất chất lượng.';
  static const gatewayNoteInternet = 'Tải nhạc từ URL yêu cầu kết nối Internet.';
  static const gatewayNoteRescan =
      'Quét lại thư viện không cần mạng — chỉ đọc từ bộ nhớ máy.';

  // Downloader — chuỗi mới thêm ở Phase 7 (các màn còn lại vẫn inline)
  static const pickSaveFolder = 'Chọn thư mục lưu';
  static const initFailed = 'Không thể khởi động bộ tải. Vui lòng thử lại.';
  static const noVideosFound = 'Không tìm thấy video nào';
  static const paste = 'Dán';
  static const clear = 'Xóa';
  static const retryAll = 'Thử lại tất cả';
}
