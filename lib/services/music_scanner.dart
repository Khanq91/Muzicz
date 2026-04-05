import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song_item.dart';

typedef ScanProgressCallback = void Function(int count);

class MusicScanner {
  final _audioQuery = OnAudioQuery();

  /// Yêu cầu quyền đọc nhạc — xử lý đúng cho Android 13+ (READ_MEDIA_AUDIO)
  /// và Android ≤ 12 (READ_EXTERNAL_STORAGE).
  Future<bool> requestPermission() async {
    // Bước 1: Thử qua on_audio_query (thường đủ trên mọi phiên bản)
    final alreadyGranted = await _audioQuery.permissionsStatus();
    if (alreadyGranted) return true;

    final requestedByQuery = await _audioQuery.permissionsRequest();
    if (requestedByQuery) return true;

    // Bước 2: Fallback — permission_handler
    if (Platform.isAndroid) {
      // READ_MEDIA_AUDIO cho Android 13+ (API 33+)
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) return true;

      // READ_EXTERNAL_STORAGE cho Android ≤ 12
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      // Người dùng từ chối vĩnh viễn → mở App Settings
      if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        await openAppSettings();
      }
    }

    return false;
  }

  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      final audio = await Permission.audio.status;
      if (audio.isGranted) return true;
      final storage = await Permission.storage.status;
      return storage.isGranted;
    }
    return _audioQuery.permissionsStatus();
  }

  Future<List<SongItem>> scanSongs({
    ScanProgressCallback? onProgress,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    final raw = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // ✅ BUG FIX: Bỏ filter `isMusic == true` — MediaStore không đảm bảo
    // set flag này cho tất cả audio files hợp lệ (nhạc tải về, copy thủ công,
    // file từ yt-dlp, v.v.). Thay bằng kiểm tra extension + duration.
    final audioExtensions = {
      'mp3', 'flac', 'm4a', 'aac', 'ogg', 'opus',
      'wav', 'wma', 'ape', 'alac', 'aiff', 'mid',
    };

    final filtered = raw.where((s) {
      // Phải có path và duration hợp lệ
      if (s.data.isEmpty || s.duration == null) return false;

      // Lọc file quá ngắn (< 30s) — nhạc chuông, thông báo
      if (s.duration! <= 30000) return false;

      // Chấp nhận nếu on_audio_query đã đánh dấu là music
      if (s.isMusic == true) return true;

      // Fallback: kiểm tra extension
      final ext = s.data.split('.').last.toLowerCase();
      return audioExtensions.contains(ext);
    }).toList();

    final result = filtered.map((s) => SongItem.fromAudioQuery(s)).toList();
    onProgress?.call(result.length);
    return result;
  }

  Future<List<AlbumModel>> scanAlbums() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];
    return _audioQuery.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
    );
  }

  Future<List<ArtistModel>> scanArtists() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];
    return _audioQuery.queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
    );
  }

  Future<Map<String, List<SongItem>>> groupByAlbum(List<SongItem> songs) async {
    final map = <String, List<SongItem>>{};
    for (final s in songs) {
      map.putIfAbsent(s.album, () => []).add(s);
    }
    return map;
  }

  Future<Map<String, List<SongItem>>> groupByArtist(List<SongItem> songs) async {
    final map = <String, List<SongItem>>{};
    for (final s in songs) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    return map;
  }
}