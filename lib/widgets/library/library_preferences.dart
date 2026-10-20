import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/song_item.dart';
import '../../utils/vietnamese_normalize.dart';

// Values are also the public showTab indices used by Home/Search.
enum LibrarySection { playlists, songs, artists, folders }

const defaultLibrarySections = [
  LibrarySection.songs,
  LibrarySection.playlists,
  LibrarySection.artists,
  LibrarySection.folders,
];

enum LibraryOrder { name, newest, duration, count }

class LibraryPreferences extends ChangeNotifier {
  List<LibrarySection> _sections = defaultLibrarySections.toList();
  final Map<LibrarySection, LibraryOrder> _orders = {};
  final Set<LibrarySection> _descending = {};
  SharedPreferences? _storage;
  bool _disposed = false;
  int _edits = 0;

  List<LibrarySection> get sections => List.unmodifiable(_sections);
  LibraryOrder order(LibrarySection section) =>
      _orders[section] ?? LibraryOrder.name;
  bool descending(LibrarySection section) => _descending.contains(section);

  Future<void> load() async {
    final edits = _edits;
    final storage = await SharedPreferences.getInstance();
    if (_disposed) return;
    _storage = storage;
    if (_edits != edits) {
      await _save();
      return;
    }
    final names = storage.getStringList('library_tab_order') ?? const [];
    _sections =
        <LibrarySection>{
          for (final name in names)
            ...LibrarySection.values.where((s) => s.name == name),
          ...defaultLibrarySections,
        }.toList();
    for (final section in LibrarySection.values) {
      final name = storage.getString('library_sort_${section.name}');
      _orders[section] = LibraryOrder.values.firstWhere(
        (order) => order.name == name,
        orElse: () => LibraryOrder.name,
      );
      if (storage.getBool('library_desc_${section.name}') ?? false) {
        _descending.add(section);
      }
    }
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    move(oldIndex, newIndex);
  }

  void move(int oldIndex, int newIndex) {
    _sections.insert(newIndex, _sections.removeAt(oldIndex));
    _changed();
  }

  void resetTabs() {
    _sections = defaultLibrarySections.toList();
    _changed();
  }

  void setSort(LibrarySection section, LibraryOrder order, bool descending) {
    _orders[section] = order;
    descending ? _descending.add(section) : _descending.remove(section);
    _changed();
  }

  void _changed() {
    _edits++;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final storage = _storage;
    if (storage == null) return;
    await storage.setStringList(
      'library_tab_order',
      _sections.map((s) => s.name).toList(),
    );
    for (final section in LibrarySection.values) {
      await storage.setString(
        'library_sort_${section.name}',
        order(section).name,
      );
      await storage.setBool(
        'library_desc_${section.name}',
        descending(section),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

List<SongItem> orderLibrarySongs(
  Iterable<SongItem> songs,
  LibraryOrder order,
  bool descending,
) {
  final result = songs.toList();
  result.sort((a, b) {
    var comparison = switch (order) {
      LibraryOrder.newest => (a.dateAdded ?? DateTime(0)).compareTo(
        b.dateAdded ?? DateTime(0),
      ),
      LibraryOrder.duration => a.duration.compareTo(b.duration),
      _ => vnNormalize(a.title).compareTo(vnNormalize(b.title)),
    };
    if (comparison == 0) comparison = a.id.compareTo(b.id);
    return descending ? -comparison : comparison;
  });
  return result;
}

String libraryParentPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash <= 0 ? '/' : normalized.substring(0, slash);
}

class LibraryFolder {
  LibraryFolder(this.path);
  final String path;
  final Map<String, LibraryFolder> children = {};
  final List<SongItem> songs = [];
  int totalSongs = 0;
  int totalDuration = 0;
  DateTime newest = DateTime(0);
  String get name =>
      path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '/';
}

/// Index once per library revision. Full paths keep identically named folders
/// on different volumes separate, and every node has precomputed sort metadata.
Map<String, LibraryFolder> buildLibraryFolders(List<SongItem> songs) {
  final folders = <String, LibraryFolder>{'/': LibraryFolder('/')};
  for (final song in songs) {
    final parent = libraryParentPath(song.data);
    var node = folders['/']!;
    node.totalSongs++;
    node.totalDuration += song.duration;
    if (song.dateAdded != null && song.dateAdded!.isAfter(node.newest)) {
      node.newest = song.dateAdded!;
    }
    var path = '';
    for (final part in parent.split('/').where((p) => p.isNotEmpty)) {
      path += '/$part';
      final child = folders.putIfAbsent(path, () => LibraryFolder(path));
      node.children[path] = child;
      node = child;
      node.totalSongs++;
      node.totalDuration += song.duration;
      if (song.dateAdded != null && song.dateAdded!.isAfter(node.newest)) {
        node.newest = song.dateAdded!;
      }
    }
    node.songs.add(song);
  }
  return folders;
}
