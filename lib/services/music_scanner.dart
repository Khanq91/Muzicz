import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song_item.dart';

typedef ScanProgressCallback = void Function(int count);

class MusicScanner {
  final _audioQuery = OnAudioQuery();

  Future<bool> requestPermission() async {
    // on_audio_query has its own permission flow
    final granted = await _audioQuery.permissionsStatus();
    if (granted) return true;
    return _audioQuery.permissionsRequest();
  }

  Future<bool> checkPermission() async {
    // Also check via permission_handler for Android 13+
    final status = await Permission.audio.status;
    if (status.isGranted) return true;

    final storageStatus = await Permission.storage.status;
    return storageStatus.isGranted;
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

    // Filter out very short files (< 30s) — likely ringtones/notifs
    final filtered = raw
        .where((s) =>
            s.duration != null &&
            s.duration! > 30000 &&
            s.data.isNotEmpty &&
            s.isMusic == true)
        .toList();

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

  /// Songs grouped by album
  Future<Map<String, List<SongItem>>> groupByAlbum(
      List<SongItem> songs) async {
    final map = <String, List<SongItem>>{};
    for (final s in songs) {
      map.putIfAbsent(s.album, () => []).add(s);
    }
    return map;
  }

  /// Songs grouped by artist
  Future<Map<String, List<SongItem>>> groupByArtist(
      List<SongItem> songs) async {
    final map = <String, List<SongItem>>{};
    for (final s in songs) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    return map;
  }
}
