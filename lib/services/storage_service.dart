import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_item.dart';
import '../models/song_item.dart';

class StorageService {
  static const _keyFirstRun = 'first_run';
  static const _keyScannedOnce = 'scanned_once';
  static const _keyRecentlyPlayed = 'recently_played';
  static const _keyPlayCount = 'play_count';
  static const _keyFavorites = 'favorites';
  static const _keyPlaylists = 'playlists';
  static const _keyMetaOverrides = 'meta_overrides'; // Map<id, {title, artist}>
  static const _keyHiddenSongs = 'hidden_songs'; // Set<int>

  late SharedPreferences _prefs;
  final List<int> _recentlyPlayedIds = [];
  final Map<int, int> _playCounts = {};
  final Set<int> _favoriteIds = {};
  final Map<int, Map<String, String>> _metaOverrides = {};
  final Map<int, Map<String, String>> _hiddenSongs = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _replaceList(_recentlyPlayedIds, _readIntList(_keyRecentlyPlayed));
    _replaceMap(_playCounts, _readIntMap(_keyPlayCount));
    _replaceSet(_favoriteIds, _readIntList(_keyFavorites));
    _replaceMap(_metaOverrides, _readStringMap(_keyMetaOverrides));
    _replaceMap(_hiddenSongs, _readStringMap(_keyHiddenSongs));
  }

  // ── First-run / Scan ──────────────────────────────────────────────────────

  bool get isFirstRun => _prefs.getBool(_keyFirstRun) ?? true;
  Future<void> markFirstRunDone() => _prefs.setBool(_keyFirstRun, false);

  bool get hasScannedOnce => _prefs.getBool(_keyScannedOnce) ?? false;
  Future<void> markScannedOnce() => _prefs.setBool(_keyScannedOnce, true);

  // ── Recently Played ───────────────────────────────────────────────────────

  List<int> get recentlyPlayedIds => UnmodifiableListView(_recentlyPlayedIds);

  Future<void> addRecentlyPlayed(int songId) async {
    final list = [..._recentlyPlayedIds];
    list.remove(songId);
    list.insert(0, songId);
    if (list.length > 30) list.removeLast();
    await _prefs.setString(_keyRecentlyPlayed, jsonEncode(list));
    _replaceList(_recentlyPlayedIds, list);
  }

  // ── Play Count ────────────────────────────────────────────────────────────

  Map<int, int> get playCounts => UnmodifiableMapView(_playCounts);

  Future<void> incrementPlayCount(int songId) async {
    final counts = {..._playCounts};
    counts[songId] = (counts[songId] ?? 0) + 1;
    await _prefs.setString(
      _keyPlayCount,
      jsonEncode(counts.map((k, v) => MapEntry(k.toString(), v))),
    );
    _replaceMap(_playCounts, counts);
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  Set<int> get favoriteIds => UnmodifiableSetView(_favoriteIds);

  Future<void> toggleFavorite(int songId) async {
    final favs = {..._favoriteIds};
    if (favs.contains(songId)) {
      favs.remove(songId);
    } else {
      favs.add(songId);
    }
    await _prefs.setString(_keyFavorites, jsonEncode(favs.toList()));
    _replaceSet(_favoriteIds, favs);
  }

  bool isFavorite(int songId) => _favoriteIds.contains(songId);

  Future<void> setBulkFavoriteStatus(List<int> songIds, bool addToFav) async {
    final favs = {..._favoriteIds};
    for (final id in songIds) {
      if (addToFav) {
        favs.add(id);
      } else {
        favs.remove(id);
      }
    }
    await _prefs.setString(_keyFavorites, jsonEncode(favs.toList()));
    _replaceSet(_favoriteIds, favs);
  }

  // ── Playlists (persist across restarts) ──────────────────────────────────

  /// Đọc danh sách playlist từ SharedPreferences.
  /// Trả về [] nếu chưa có hoặc data bị lỗi.
  List<PlaylistItem> get playlists {
    final raw = _prefs.getString(_keyPlaylists);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PlaylistItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Data bị corrupt → trả về rỗng, không crash app
      return [];
    }
  }

  /// Ghi toàn bộ danh sách playlist vào SharedPreferences.
  Future<void> savePlaylists(List<PlaylistItem> playlists) async {
    try {
      final encoded = jsonEncode(playlists.map((p) => p.toJson()).toList());
      await _prefs.setString(_keyPlaylists, encoded);
    } catch (e) {
      // Serialization error — log nhưng không crash
      assert(() {
        debugPrint('[StorageService] savePlaylists error: $e');
        return true;
      }());
    }
  }
  // ── Meta overrides ────────────────────────────────────────────────────────

  Map<int, Map<String, String>> get metaOverrides =>
      UnmodifiableMapView(_metaOverrides);

  Future<void> saveMetaOverride(int songId, String title, String artist) async {
    final map = {..._metaOverrides};
    map[songId] = {'title': title, 'artist': artist};
    await _prefs.setString(
      _keyMetaOverrides,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
    _replaceMap(_metaOverrides, map);
  }

  Future<void> removeMetaOverride(int songId) async {
    final map = {..._metaOverrides};
    map.remove(songId);
    await _prefs.setString(
      _keyMetaOverrides,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
    _replaceMap(_metaOverrides, map);
  }

  // ── Hidden songs ──────────────────────────────────────────────────────────

  Map<int, Map<String, String>> get hiddenSongs =>
      UnmodifiableMapView(_hiddenSongs);

  Set<int> get hiddenSongIds => _hiddenSongs.keys.toSet();

  Future<void> hideSong(
    int songId,
    String title,
    String artist,
    String data,
  ) async {
    final map = {..._hiddenSongs};
    map[songId] = {'title': title, 'artist': artist, 'data': data};
    await _prefs.setString(
      _keyHiddenSongs,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
    _replaceMap(_hiddenSongs, map);
  }

  Future<void> hideSongs(List<SongItem> songs) async {
    if (songs.isEmpty) return;
    final map = {..._hiddenSongs};
    for (final song in songs) {
      map[song.id] = {
        'title': song.title,
        'artist': song.artist,
        'data': song.data,
      };
    }
    await _prefs.setString(
      _keyHiddenSongs,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
    _replaceMap(_hiddenSongs, map);
  }

  Future<void> unhideSong(int songId) async {
    final map = {..._hiddenSongs};
    map.remove(songId);
    await _prefs.setString(
      _keyHiddenSongs,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
    _replaceMap(_hiddenSongs, map);
  }

  List<int> _readIntList(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>).cast<int>();
    } catch (_) {
      return [];
    }
  }

  Map<int, int> _readIntMap(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(int.parse(k), v as int));
    } catch (_) {
      return {};
    }
  }

  Map<int, Map<String, String>> _readStringMap(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(int.parse(k), Map<String, String>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  void _replaceList<T>(List<T> target, Iterable<T> values) {
    target
      ..clear()
      ..addAll(values);
  }

  void _replaceSet<T>(Set<T> target, Iterable<T> values) {
    target
      ..clear()
      ..addAll(values);
  }

  void _replaceMap<K, V>(Map<K, V> target, Map<K, V> values) {
    target
      ..clear()
      ..addAll(values);
  }
}
