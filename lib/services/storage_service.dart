import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyFirstRun = 'first_run';
  static const _keyScannedOnce = 'scanned_once';
  static const _keyRecentlyPlayed = 'recently_played';
  static const _keyPlayCount = 'play_count';
  static const _keyFavorites = 'favorites';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── First-run / Scan ───────────────────────────────────

  bool get isFirstRun => _prefs.getBool(_keyFirstRun) ?? true;

  Future<void> markFirstRunDone() => _prefs.setBool(_keyFirstRun, false);

  bool get hasScannedOnce => _prefs.getBool(_keyScannedOnce) ?? false;

  Future<void> markScannedOnce() => _prefs.setBool(_keyScannedOnce, true);

  // ── Recently Played ────────────────────────────────────

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

  // ── Play Count ─────────────────────────────────────────

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

  // ── Favorites ──────────────────────────────────────────

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
}
