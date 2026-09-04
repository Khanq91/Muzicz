import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song_item.dart';

class MusicScanner {
  MusicScanner({OnAudioQuery? audioQuery})
    : _audioQuery = audioQuery ?? OnAudioQuery();

  final OnAudioQuery _audioQuery;
  bool _permissionPermanentlyDenied = false;

  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;

  /// Yêu cầu quyền đọc nhạc — xử lý đúng cho Android 13+ (READ_MEDIA_AUDIO)
  /// và Android ≤ 12 (READ_EXTERNAL_STORAGE).
  Future<bool> requestPermission() async {
    _permissionPermanentlyDenied = false;

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

      if (audioStatus.isPermanentlyDenied ||
          storageStatus.isPermanentlyDenied) {
        _permissionPermanentlyDenied = true;
      }
    }

    return false;
  }

  Future<List<SongItem>> scanSongs({bool ensurePermission = true}) async {
    if (ensurePermission) {
      final hasPermission = await requestPermission();
      if (!hasPermission) return [];
    }

    final raw = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // set flag này cho tất cả audio files hợp lệ (nhạc tải về, copy thủ công,
    // file từ yt-dlp, v.v.). Thay bằng kiểm tra extension + duration.
    final audioExtensions = {
      'mp3',
      'flac',
      'm4a',
      'aac',
      'ogg',
      'opus',
      'wav',
      'wma',
      'ape',
      'alac',
      'aiff',
      'mid',
      'mkv',
      '3gp',
    };

    final filtered =
        raw.where((s) {
          // Phải có path và duration hợp lệ
          if (s.data.isEmpty || s.duration == null) return false;

          // Lọc file quá ngắn (< 30s) — nhạc chuông, thông báo
          if (s.duration! <= 30000) return false;

          // WebM is intentionally unsupported. Discovering WebM through the
          // visual-media collection would require an unrelated video grant.
          final ext = s.data.split('.').last.toLowerCase();
          if (ext == 'webm') return false;

          // Chấp nhận nếu on_audio_query đã đánh dấu là music
          if (s.isMusic == true) return true;

          // Fallback: kiểm tra extension
          return audioExtensions.contains(ext);
        }).toList();

    return filtered.map(SongItem.fromAudioQuery).toList();
  }

  Future<Map<String, List<SongItem>>> groupByAlbum(List<SongItem> songs) async {
    final map = <String, List<SongItem>>{};
    for (final s in songs) {
      map.putIfAbsent(s.album, () => []).add(s);
    }
    return map;
  }

  Future<Map<String, List<SongItem>>> groupByArtist(
    List<SongItem> songs,
  ) async {
    final map = <String, List<SongItem>>{};
    for (final s in songs) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    return map;
  }
}
