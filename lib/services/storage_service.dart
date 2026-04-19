import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_item.dart';

class StorageService {
  static const _keyFirstRun      = 'first_run';
  static const _keyScannedOnce   = 'scanned_once';
  static const _keyRecentlyPlayed = 'recently_played';
  static const _keyPlayCount     = 'play_count';
  static const _keyFavorites     = 'favorites';
  static const _keyPlaylists     = 'playlists';
  static const _keyMetaOverrides = 'meta_overrides'; // Map<id, {title, artist}>
  static const _keyHiddenSongs   = 'hidden_songs';   // Set<int>

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── First-run / Scan ──────────────────────────────────────────────────────

  bool get isFirstRun => _prefs.getBool(_keyFirstRun) ?? true;
  Future<void> markFirstRunDone() => _prefs.setBool(_keyFirstRun, false);

  bool get hasScannedOnce => _prefs.getBool(_keyScannedOnce) ?? false;
  Future<void> markScannedOnce() => _prefs.setBool(_keyScannedOnce, true);

  // ── Recently Played ───────────────────────────────────────────────────────

  List<int> get recentlyPlayedIds {
    final raw = _prefs.getString(_keyRecentlyPlayed);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<int>();
  }

  Future<void> addRecentlyPlayed(int songId) async {
    final list = recentlyPlayedIds;
    list.remove(songId);
    list.insert(0, songId);
    if (list.length > 30) list.removeLast();
    await _prefs.setString(_keyRecentlyPlayed, jsonEncode(list));
  }

  // ── Play Count ────────────────────────────────────────────────────────────

  Map<int, int> get playCounts {
    final raw = _prefs.getString(_keyPlayCount);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(int.parse(k), v as int));
  }

  Future<void> incrementPlayCount(int songId) async {
    final counts = playCounts;
    counts[songId] = (counts[songId] ?? 0) + 1;
    await _prefs.setString(
      _keyPlayCount,
      jsonEncode(counts.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  Set<int> get favoriteIds {
    final raw = _prefs.getString(_keyFavorites);
    if (raw == null) return {};
    return (jsonDecode(raw) as List).cast<int>().toSet();
  }

  Future<void> toggleFavorite(int songId) async {
    final favs = favoriteIds;
    if (favs.contains(songId)) {
      favs.remove(songId);
    } else {
      favs.add(songId);
    }
    await _prefs.setString(_keyFavorites, jsonEncode(favs.toList()));
  }

  bool isFavorite(int songId) => favoriteIds.contains(songId);

  Future<void> setBulkFavoriteStatus(List<int> songIds, bool addToFav) async {
    final favs = favoriteIds;
    for (final id in songIds) {
      if (addToFav) favs.add(id); else favs.remove(id);
    }
    await _prefs.setString(_keyFavorites, jsonEncode(favs.toList()));
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
      final encoded =
      jsonEncode(playlists.map((p) => p.toJson()).toList());
      await _prefs.setString(_keyPlaylists, encoded);
    } catch (e) {
      // Serialization error — log nhưng không crash
      assert(() {
        print('[StorageService] savePlaylists error: $e');
        return true;
      }());
    }
  }
  // ── Meta overrides ────────────────────────────────────────────────────────

  Map<int, Map<String, String>> get metaOverrides {
    final raw = _prefs.getString(_keyMetaOverrides);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(
      int.parse(k),
      Map<String, String>.from(v as Map),
    ));
  }

  Future<void> saveMetaOverride(int songId, String title, String artist) async {
    final map = metaOverrides;
    map[songId] = {'title': title, 'artist': artist};
    await _prefs.setString(
      _keyMetaOverrides,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  Future<void> removeMetaOverride(int songId) async {
    final map = metaOverrides;
    map.remove(songId);
    await _prefs.setString(
      _keyMetaOverrides,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

// ── Hidden songs ──────────────────────────────────────────────────────────

  Map<int, Map<String, String>> get hiddenSongs {
    final raw = _prefs.getString(_keyHiddenSongs);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(
      int.parse(k),
      Map<String, String>.from(v as Map),
    ));
  }

  Set<int> get hiddenSongIds => hiddenSongs.keys.toSet();

  Future<void> hideSong(int songId, String title, String artist, String data) async {
    final map = hiddenSongs;
    map[songId] = {'title': title, 'artist': artist, 'data': data};
    await _prefs.setString(
      _keyHiddenSongs,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  Future<void> unhideSong(int songId) async {
    final map = hiddenSongs;
    map.remove(songId);
    await _prefs.setString(
      _keyHiddenSongs,
      jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );
  }
}
