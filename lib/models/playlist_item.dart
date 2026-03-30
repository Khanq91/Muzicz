import 'song_item.dart';

class PlaylistItem {
  final String id;
  String name;
  List<SongItem> songs;
  String? coverPath; // custom image path picked by user
  final DateTime createdAt;

  PlaylistItem({
    required this.id,
    required this.name,
    List<SongItem>? songs,
    this.coverPath,
    DateTime? createdAt,
  })  : songs = songs ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get songCount => songs.length;

  Duration get totalDuration => songs.fold(
        Duration.zero,
        (prev, s) => prev + Duration(milliseconds: s.duration),
      );

  void addSong(SongItem song) {
    if (!songs.any((s) => s.id == song.id)) songs.add(song);
  }

  void removeSong(int songId) => songs.removeWhere((s) => s.id == songId);

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final item = songs.removeAt(oldIndex);
    songs.insert(newIndex, item);
  }
}
