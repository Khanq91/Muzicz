import 'package:flutter/material.dart';
import '../models/song_item.dart';
import '../models/playlist_item.dart';
import '../services/music_scanner.dart';
import '../services/storage_service.dart';

enum LibraryStatus { idle, scanning, done, error, permissionDenied }

class MusicProvider extends ChangeNotifier {
  final _scanner = MusicScanner();
  final _storage = StorageService();

  LibraryStatus _status = LibraryStatus.idle;
  LibraryStatus get status => _status;

  List<SongItem> _allSongs = [];
  List<SongItem> get allSongs => _allSongs;

  Map<String, List<SongItem>> _albumMap = {};
  Map<String, List<SongItem>> get albumMap => _albumMap;

  Map<String, List<SongItem>> _artistMap = {};
  Map<String, List<SongItem>> get artistMap => _artistMap;

  List<PlaylistItem> _playlists = [];
  List<PlaylistItem> get playlists => _playlists;

  int _scanCount = 0;
  int get scanCount => _scanCount;

  // ── FIX Bug 1: Separate search query per scope ────────────────────────────
  // Mỗi screen có search riêng, không dùng chung 1 global string
  String _homeSearchQuery = '';
  String _librarySearchQuery = '';

  String get homeSearchQuery => _homeSearchQuery;
  String get librarySearchQuery => _librarySearchQuery;

  // Deprecated - kept for backward compat but redirects to home
  String get searchQuery => _homeSearchQuery;

  void setHomeSearchQuery(String q) {
    _homeSearchQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  void setLibrarySearchQuery(String q) {
    _librarySearchQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  // Deprecated
  void setSearchQuery(String q) => setHomeSearchQuery(q);

  List<SongItem> get filteredSongs => _filterSongs(_homeSearchQuery);

  List<SongItem> get libraryFilteredSongs => _filterSongs(_librarySearchQuery);

  List<SongItem> _filterSongs(String query) {
    if (query.isEmpty) return _allSongs;
    return _allSongs.where((s) {
      return s.title.toLowerCase().contains(query) ||
          s.artist.toLowerCase().contains(query) ||
          s.album.toLowerCase().contains(query);
    }).toList();
  }

  bool get isFirstRun => _storage.isFirstRun;
  bool get hasScannedOnce => _storage.hasScannedOnce;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _storage.init();
    _playlists = _storage.playlists;
    notifyListeners();
  }

  Future<void> _persistPlaylists() => _storage.savePlaylists(_playlists);

  // ── Scanning ──────────────────────────────────────────────────────────────

  // FIX P1: debounce notifyListeners during scan
  int _lastNotifiedCount = 0;

  Future<void> scanMusic() async {
    _status = LibraryStatus.scanning;
    _scanCount = 0;
    _lastNotifiedCount = 0;
    notifyListeners();

    final hasPermission = await _scanner.requestPermission();
    if (!hasPermission) {
      _status = LibraryStatus.permissionDenied;
      notifyListeners();
      return;
    }

    try {
      _allSongs = await _scanner.scanSongs(
        onProgress: (count) {
          _scanCount = count;
          // FIX P1: Only notify every 50 songs to avoid excessive rebuilds
          if (count - _lastNotifiedCount >= 50 || count == 0) {
            _lastNotifiedCount = count;
            notifyListeners();
          }
        },
      );

      _albumMap  = await _scanner.groupByAlbum(_allSongs);
      _artistMap = await _scanner.groupByArtist(_allSongs);

      await _storage.markScannedOnce();
      await _storage.markFirstRunDone();

      _status = LibraryStatus.done;
    } catch (e) {
      _status = LibraryStatus.error;
    }
    notifyListeners();
  }

  // ── Smart Lists ───────────────────────────────────────────────────────────

  List<SongItem> get recentlyAdded {
    final sorted = [..._allSongs]
      ..sort((a, b) =>
          (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)));
    return sorted.take(20).toList();
  }

  List<SongItem> get recentlyPlayed {
    final ids = _storage.recentlyPlayedIds;
    final map = {for (final s in _allSongs) s.id: s};
    return ids.map((id) => map[id]).whereType<SongItem>().take(20).toList();
  }

  List<SongItem> get mostPlayed {
    final counts = _storage.playCounts;
    final sorted = [..._allSongs]
      ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    return sorted.where((s) => (counts[s.id] ?? 0) > 0).take(20).toList();
  }

  List<SongItem> get favorites {
    final ids = _storage.favoriteIds;
    return _allSongs.where((s) => ids.contains(s.id)).toList();
  }

  List<SongItem> get neverPlayed {
    final counts = _storage.playCounts;
    return _allSongs
        .where((s) => (counts[s.id] ?? 0) == 0)
        .take(30)
        .toList();
  }

  List<SongItem> get randomMix {
    final list = [..._allSongs]..shuffle();
    return list.take(20).toList();
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  bool isFavorite(int songId) => _storage.isFavorite(songId);

  Future<void> toggleFavorite(int songId) async {
    await _storage.toggleFavorite(songId);
    notifyListeners();
  }

  // ── Playlists ─────────────────────────────────────────────────────────────

  PlaylistItem createPlaylist(String name) {
    final pl = PlaylistItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    _playlists.add(pl);
    notifyListeners();
    _persistPlaylists();
    return pl;
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persistPlaylists();
  }

  Future<void> addToPlaylist(String playlistId, SongItem song) async {
    final pl = _playlists.firstWhere((p) => p.id == playlistId);
    pl.addSong(song);
    notifyListeners();
    await _persistPlaylists();
  }

  Future<void> removeFromPlaylist(String playlistId, int songId) async {
    final pl = _playlists.firstWhere((p) => p.id == playlistId);
    pl.removeSong(songId);
    notifyListeners();
    await _persistPlaylists();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final pl = _playlists.firstWhere((p) => p.id == playlistId);
    pl.name = newName;
    notifyListeners();
    await _persistPlaylists();
  }

  // ── Play tracking ─────────────────────────────────────────────────────────

  Future<void> onSongPlayed(int songId) async {
    await _storage.addRecentlyPlayed(songId);
    await _storage.incrementPlayCount(songId);
    notifyListeners();
  }
}