import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/widgets/library/library_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

SongItem song(
  int id,
  String path, {
  String title = 'Song',
  int duration = 1000,
}) => SongItem(
  id: id,
  title: title,
  artist: 'Artist',
  album: 'Album',
  albumId: 1,
  artistId: 1,
  data: path,
  duration: duration,
  dateAdded: DateTime(2026, 1, id),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saved order recovers missing, duplicated and unknown tab IDs',
    () async {
      SharedPreferences.setMockInitialValues({
        'library_tab_order': ['folders', 'deleted', 'songs', 'folders'],
        'library_sort_songs': 'removed-sort',
      });
      final preferences = LibraryPreferences();
      await preferences.load();
      expect(preferences.sections, [
        LibrarySection.folders,
        LibrarySection.songs,
        LibrarySection.playlists,
        LibrarySection.artists,
      ]);
      expect(preferences.order(LibrarySection.songs), LibraryOrder.name);
      preferences.dispose();
    },
  );

  test('tab order and independent section sorts survive restart', () async {
    final preferences = LibraryPreferences();
    await preferences.load();
    preferences.reorder(0, 4);
    preferences.setSort(LibrarySection.songs, LibraryOrder.duration, true);
    preferences.setSort(LibrarySection.folders, LibraryOrder.count, false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final restored = LibraryPreferences();
    await restored.load();
    expect(restored.sections.last, LibrarySection.songs);
    expect(restored.order(LibrarySection.songs), LibraryOrder.duration);
    expect(restored.descending(LibrarySection.songs), isTrue);
    expect(restored.order(LibrarySection.folders), LibraryOrder.count);
    expect(restored.descending(LibrarySection.folders), isFalse);
    preferences.dispose();
    restored.dispose();
  });

  test('sorts both directions without changing the playback source', () {
    final songs = [
      song(1, '/a.mp3', title: 'Zulu', duration: 3000),
      song(2, '/b.mp3', title: 'Alpha', duration: 1000),
    ];
    expect(
      orderLibrarySongs(songs, LibraryOrder.name, false).map((s) => s.id),
      [2, 1],
    );
    expect(
      orderLibrarySongs(songs, LibraryOrder.duration, true).map((s) => s.id),
      [1, 2],
    );
    expect(orderLibrarySongs(songs, LibraryOrder.newest, true).first.id, 2);
    expect(songs.first.id, 1);
  });

  test('folder index separates volumes and includes recursive counts', () {
    final first = song(1, '/storage/emulated/0/Music/Live/one.mp3');
    final second = song(2, '/storage/card/Music/Live/two.mp3');
    final direct = song(3, '/storage/emulated/0/Music/three.mp3');
    final folders = buildLibraryFolders([first, second, direct]);
    expect(folders['/']!.totalSongs, 3);
    expect(folders['/storage/emulated/0/Music']!.totalSongs, 2);
    expect(folders['/storage/emulated/0/Music']!.songs, [direct]);
    expect(folders['/storage/card/Music/Live']!.songs, [second]);
    expect(libraryParentPath(r'C:\Music\Live\one.mp3'), 'C:/Music/Live');
    expect(libraryParentPath('/song.mp3'), '/');
  });
}
