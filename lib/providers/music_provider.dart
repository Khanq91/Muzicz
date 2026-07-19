import 'dart:async';

import 'package:flutter/material.dart';
import '../models/song_item.dart';
import '../models/playlist_item.dart';
import '../services/music_scanner.dart';
import '../services/storage_service.dart';

enum LibraryStatus { idle, scanning, done, error, permissionDenied }

enum LibrarySongSort { title, recentlyAdded, duration }

class MusicProvider extends ChangeNotifier {
  MusicProvider({MusicScanner? scanner, StorageService? storage})
    : _scanner = scanner ?? MusicScanner(),
      _storage = storage ?? StorageService();

  final MusicScanner _scanner;
  final StorageService _storage;

  LibraryStatus _status = LibraryStatus.idle;
  LibraryStatus get status => _status;
  bool get permissionPermanentlyDenied => _scanner.permissionPermanentlyDenied;

  List<SongItem> _allSongs = [];
  List<SongItem> get allSongs => _allSongs;

  Map<String, List<SongItem>> _albumMap = {};
  Map<String, List<SongItem>> get albumMap => _albumMap;
  List<MapEntry<String, List<SongItem>>> _sortedAlbumGroups = const [];
  List<MapEntry<String, List<SongItem>>> get sortedAlbumGroups =>
      _sortedAlbumGroups;

  Map<String, List<SongItem>> _artistMap = {};
  Map<String, List<SongItem>> get artistMap => _artistMap;
  List<MapEntry<String, List<SongItem>>> _sortedArtistGroups = const [];
  List<MapEntry<String, List<SongItem>>> get sortedArtistGroups =>
      _sortedArtistGroups;

  List<MapEntry<String, List<SongItem>>> _sortedFolderGroups = const [];
  List<MapEntry<String, List<SongItem>>> get sortedFolderGroups =>
      _sortedFolderGroups;

  List<PlaylistItem> _playlists = [];
  List<PlaylistItem> get playlists => _playlists;

  int _scanCount = 0;
  int get scanCount => _scanCount;

  Map<int, Map<String, String>> get hiddenSongs => _storage.hiddenSongs;

  String _homeSearchQuery = '';
  String _librarySearchQuery = '';
  Timer? _homeSearchTimer;
  Timer? _librarySearchTimer;

  static const _searchDebounceDuration = Duration(milliseconds: 160);

  int _libraryRevision = 0;
  Map<int, String> _normalizedSearchText = const {};
  String? _homeFilterCacheQuery;
  int _homeFilterCacheRevision = -1;
  List<SongItem>? _homeFilterCache;
  String? _libraryFilterCacheQuery;
  int _libraryFilterCacheRevision = -1;
  List<SongItem>? _libraryFilterCache;
  final Map<LibrarySongSort, List<SongItem>> _librarySortCache = {};

  List<SongItem>? _recentlyAddedCache;
  List<SongItem>? _recentlyPlayedCache;
  List<SongItem>? _mostPlayedCache;
  List<SongItem>? _favoritesCache;
  List<SongItem>? _neverPlayedCache;
  List<SongItem>? _randomMixCache;

  String get homeSearchQuery => _homeSearchQuery;
  String get librarySearchQuery => _librarySearchQuery;

  // Deprecated - kept for backward compat but redirects to home
  String get searchQuery => _homeSearchQuery;

  void setHomeSearchQuery(String q) {
    final query = q.toLowerCase().trim();
    _homeSearchTimer?.cancel();
    _homeSearchTimer = null;
    if (query == _homeSearchQuery) return;
    if (query.isEmpty) {
      _commitHomeSearchQuery(query);
      return;
    }
    _homeSearchTimer = Timer(_searchDebounceDuration, () {
      _homeSearchTimer = null;
      _commitHomeSearchQuery(query);
    });
  }

  void setLibrarySearchQuery(String q) {
    final query = q.toLowerCase().trim();
    _librarySearchTimer?.cancel();
    _librarySearchTimer = null;
    if (query == _librarySearchQuery) return;
    if (query.isEmpty) {
      _commitLibrarySearchQuery(query);
      return;
    }
    _librarySearchTimer = Timer(_searchDebounceDuration, () {
      _librarySearchTimer = null;
      _commitLibrarySearchQuery(query);
    });
  }

  Future<void> unhideSong(int songId) async {
    await _storage.unhideSong(songId);
    await scanMusic();
  }

  // Deprecated
  void setSearchQuery(String q) => setHomeSearchQuery(q);

  List<SongItem> get filteredSongs {
    if (_homeSearchQuery.isEmpty) return _allSongs;
    if (_homeFilterCacheQuery == _homeSearchQuery &&
        _homeFilterCacheRevision == _libraryRevision) {
      return _homeFilterCache!;
    }
    final result = _filterSongs(_homeSearchQuery);
    _homeFilterCacheQuery = _homeSearchQuery;
    _homeFilterCacheRevision = _libraryRevision;
    return _homeFilterCache = List.unmodifiable(result);
  }

  List<SongItem> get libraryFilteredSongs {
    if (_librarySearchQuery.isEmpty) return _allSongs;
    if (_libraryFilterCacheQuery == _librarySearchQuery &&
        _libraryFilterCacheRevision == _libraryRevision) {
      return _libraryFilterCache!;
    }
    final result = _filterSongs(_librarySearchQuery);
    _libraryFilterCacheQuery = _librarySearchQuery;
    _libraryFilterCacheRevision = _libraryRevision;
    return _libraryFilterCache = List.unmodifiable(result);
  }

  List<SongItem> _filterSongs(String query) {
    return _allSongs
        .where((song) => _normalizedSearchText[song.id]!.contains(query))
        .toList();
  }

  List<SongItem> librarySongsSortedBy(LibrarySongSort sort) {
    return _librarySortCache.putIfAbsent(sort, () {
      final songs = [...libraryFilteredSongs];
      switch (sort) {
        case LibrarySongSort.title:
          songs.sort((a, b) => a.title.compareTo(b.title));
        case LibrarySongSort.recentlyAdded:
          songs.sort(
            (a, b) => (b.dateAdded ?? DateTime(0)).compareTo(
              a.dateAdded ?? DateTime(0),
            ),
          );
        case LibrarySongSort.duration:
          songs.sort((a, b) => b.duration.compareTo(a.duration));
      }
      return List.unmodifiable(songs);
    });
  }

  bool get isFirstRun => _storage.isFirstRun;
  bool get hasScannedOnce => _storage.hasScannedOnce;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _storage.init();
    _playlists = _storage.playlists;
    _invalidateSmartListCaches();
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

    try {
      final hasPermission = await _scanner.requestPermission();
      if (!hasPermission) {
        _status = LibraryStatus.permissionDenied;
        notifyListeners();
        return;
      }

      var songs = await _scanner.scanSongs(
        ensurePermission: false,
        onProgress: (count) {
          _scanCount = count;
          // FIX P1: Only notify every 50 songs to avoid excessive rebuilds
          if (count - _lastNotifiedCount >= 50 || count == 0) {
            _lastNotifiedCount = count;
            notifyListeners();
          }
        },
      );

      // Filter hidden
      final hidden = _storage.hiddenSongIds;
      songs = songs.where((song) => !hidden.contains(song.id)).toList();

      // Apply overrides
      final overrides = _storage.metaOverrides;
      songs = songs.map((song) => _applyOverride(song, overrides)).toList();
      await _replaceAllSongs(songs);

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
    final cached = _recentlyAddedCache;
    if (cached != null) return cached;
    final sorted = [..._allSongs]..sort(
      (a, b) =>
          (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)),
    );
    return _recentlyAddedCache = List.unmodifiable(sorted.take(20));
  }

  List<SongItem> get recentlyPlayed {
    final cached = _recentlyPlayedCache;
    if (cached != null) return cached;
    final ids = _storage.recentlyPlayedIds;
    final map = {for (final s in _allSongs) s.id: s};
    return _recentlyPlayedCache = List.unmodifiable(
      ids.map((id) => map[id]).whereType<SongItem>().take(20),
    );
  }

  List<SongItem> get mostPlayed {
    final cached = _mostPlayedCache;
    if (cached != null) return cached;
    final counts = _storage.playCounts;
    final sorted = [..._allSongs]
      ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    return _mostPlayedCache = List.unmodifiable(
      sorted.where((song) => (counts[song.id] ?? 0) > 0).take(20),
    );
  }

  List<SongItem> get favorites {
    final cached = _favoritesCache;
    if (cached != null) return cached;
    final ids = _storage.favoriteIds;
    return _favoritesCache = List.unmodifiable(
      _allSongs.where((song) => ids.contains(song.id)),
    );
  }

  List<SongItem> get neverPlayed {
    final cached = _neverPlayedCache;
    if (cached != null) return cached;
    final counts = _storage.playCounts;
    return _neverPlayedCache = List.unmodifiable(
      _allSongs.where((song) => (counts[song.id] ?? 0) == 0).take(30),
    );
  }

  List<SongItem> get randomMix {
    final cached = _randomMixCache;
    if (cached != null) return cached;
    final list = [..._allSongs]..shuffle();
    return _randomMixCache = List.unmodifiable(list.take(20));
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  bool isFavorite(int songId) => _storage.isFavorite(songId);

  Future<void> toggleFavorite(int songId) async {
    await _storage.toggleFavorite(songId);
    _favoritesCache = null;
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
    _recentlyPlayedCache = null;
    _mostPlayedCache = null;
    _neverPlayedCache = null;
    notifyListeners();
  }

  SongItem _applyOverride(
    SongItem song,
    Map<int, Map<String, String>> overrides,
  ) {
    final o = overrides[song.id];
    if (o == null) return song;
    return SongItem(
      id: song.id,
      title: o['title'] ?? song.title,
      artist: o['artist'] ?? song.artist,
      album: song.album,
      albumId: song.albumId,
      artistId: song.artistId,
      data: song.data,
      duration: song.duration,
      size: song.size,
      track: song.track,
      dateAdded: song.dateAdded,
    );
  }

  Future<void> updateSongMeta(int songId, String title, String artist) async {
    await _storage.saveMetaOverride(songId, title, artist);

    final overrides = _storage.metaOverrides;
    await _replaceAllSongs(
      _allSongs.map((song) => _applyOverride(song, overrides)),
    );
    notifyListeners();
  }

  Future<void> hideSongFromLibrary(SongItem song) async {
    await _storage.hideSong(song.id, song.title, song.artist, song.data);
    await _replaceAllSongs(_allSongs.where((item) => item.id != song.id));
    for (final pl in _playlists) {
      pl.removeSong(song.id);
    }
    await _persistPlaylists();
    notifyListeners();
  }

  /// Bulk hide — rescan 1 lần thay vì N lần
  Future<void> hideSongsFromLibrary(List<SongItem> songs) async {
    await _storage.hideSongs(songs);
    for (final song in songs) {
      for (final pl in _playlists) {
        pl.removeSong(song.id);
      }
    }
    final hiddenIds = songs.map((s) => s.id).toSet();
    await _replaceAllSongs(
      _allSongs.where((song) => !hiddenIds.contains(song.id)),
    );
    await _persistPlaylists();
    notifyListeners();
  }

  /// Smart toggle: tất cả đã fav → bỏ fav; còn lại → thêm fav
  Future<void> bulkFavoriteToggle(List<int> songIds) async {
    if (songIds.isEmpty) return;
    final allFav = songIds.every((id) => _storage.isFavorite(id));
    await _storage.setBulkFavoriteStatus(songIds, !allFav);
    _favoritesCache = null;
    notifyListeners();
  }

  /// Thêm nhiều bài vào playlist — bài đã có bị bỏ qua
  Future<void> bulkAddToPlaylist(
    String playlistId,
    List<SongItem> songs,
  ) async {
    final pl = _playlists.firstWhere((p) => p.id == playlistId);
    for (final song in songs) {
      pl.addSong(song);
    }
    notifyListeners();
    await _persistPlaylists();
  }

  void _commitHomeSearchQuery(String query) {
    _homeSearchQuery = query;
    _homeFilterCache = null;
    notifyListeners();
  }

  void _commitLibrarySearchQuery(String query) {
    _librarySearchQuery = query;
    _libraryFilterCache = null;
    _librarySortCache.clear();
    notifyListeners();
  }

  Future<void> _replaceAllSongs(Iterable<SongItem> songs) async {
    _allSongs = songs.toList();
    _libraryRevision += 1;
    _normalizedSearchText = {
      for (final song in _allSongs)
        song.id:
            '${song.title}\u0000${song.artist}\u0000${song.album}'
                .toLowerCase(),
    };
    _homeFilterCache = null;
    _libraryFilterCache = null;
    _librarySortCache.clear();
    _invalidateSmartListCaches();
    await _rebuildLibraryGroups();
  }

  Future<void> _rebuildLibraryGroups() async {
    _albumMap = await _scanner.groupByAlbum(_allSongs);
    _artistMap = await _scanner.groupByArtist(_allSongs);
    final folderMap = <String, List<SongItem>>{};
    for (final song in _allSongs) {
      final parts = song.data.split('/');
      parts.removeLast();
      final folderName = parts.isNotEmpty ? parts.last : 'Root';
      folderMap.putIfAbsent(folderName, () => []).add(song);
    }

    _sortedAlbumGroups = _sortedGroups(_albumMap);
    _sortedArtistGroups = _sortedGroups(_artistMap);
    _sortedFolderGroups = _sortedGroups(folderMap);
  }

  List<MapEntry<String, List<SongItem>>> _sortedGroups(
    Map<String, List<SongItem>> groups,
  ) {
    final entries =
        groups.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return List.unmodifiable(entries);
  }

  void _invalidateSmartListCaches() {
    _recentlyAddedCache = null;
    _recentlyPlayedCache = null;
    _mostPlayedCache = null;
    _favoritesCache = null;
    _neverPlayedCache = null;
    _randomMixCache = null;
  }

  @override
  void dispose() {
    _homeSearchTimer?.cancel();
    _librarySearchTimer?.cancel();
    super.dispose();
  }
}
