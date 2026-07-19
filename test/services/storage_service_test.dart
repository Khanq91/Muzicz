import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('typed collections are hydrated once during init', () async {
    SharedPreferences.setMockInitialValues({
      'recently_played': jsonEncode([3, 2, 1]),
      'play_count': jsonEncode({'3': 4}),
      'favorites': jsonEncode([3]),
      'meta_overrides': jsonEncode({
        '3': {'title': 'Override', 'artist': 'Artist'},
      }),
      'hidden_songs': jsonEncode({
        '9': {'title': 'Hidden', 'artist': 'Artist', 'data': '/hidden.mp3'},
      }),
    });
    final storage = StorageService();
    await storage.init();

    final preferences = await SharedPreferences.getInstance();
    for (final key in const [
      'recently_played',
      'play_count',
      'favorites',
      'meta_overrides',
      'hidden_songs',
    ]) {
      await preferences.setString(key, 'invalid json after hydration');
    }

    expect(storage.recentlyPlayedIds, [3, 2, 1]);
    expect(storage.playCounts, {3: 4});
    expect(storage.favoriteIds, {3});
    expect(storage.metaOverrides[3], {'title': 'Override', 'artist': 'Artist'});
    expect(storage.hiddenSongs[9], {
      'title': 'Hidden',
      'artist': 'Artist',
      'data': '/hidden.mp3',
    });
  });

  test('corrupt typed collections fall back to empty values', () async {
    SharedPreferences.setMockInitialValues(const {
      'recently_played': 'invalid',
      'play_count': 'invalid',
      'favorites': 'invalid',
      'meta_overrides': 'invalid',
      'hidden_songs': 'invalid',
    });
    final storage = StorageService();

    await storage.init();

    expect(storage.recentlyPlayedIds, isEmpty);
    expect(storage.playCounts, isEmpty);
    expect(storage.favoriteIds, isEmpty);
    expect(storage.metaOverrides, isEmpty);
    expect(storage.hiddenSongs, isEmpty);
  });
}
