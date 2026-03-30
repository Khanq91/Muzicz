import 'package:on_audio_query/on_audio_query.dart';

class SongItem {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int albumId;
  final int artistId;
  final String data; // absolute file path
  final int duration; // milliseconds
  final int? size;
  // final int? year;
  final int? track;
  final DateTime? dateAdded;

  const SongItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.artistId,
    required this.data,
    required this.duration,
    this.size,
    // this.year,
    this.track,
    this.dateAdded,
  });

  factory SongItem.fromAudioQuery(SongModel s) {
    return SongItem(
      id: s.id,
      title: s.title,
      artist: s.artist ?? 'Unknown Artist',
      album: s.album ?? 'Unknown Album',
      albumId: s.albumId ?? 0,
      artistId: s.artistId ?? 0,
      data: s.data,
      duration: s.duration ?? 0,
      size: s.size,
      // year: s.year,
      track: s.track,
      dateAdded: s.dateAdded != null
          ? DateTime.fromMillisecondsSinceEpoch(s.dateAdded! * 1000)
          : null,
    );
  }

  String get durationFormatted {
    final ms = duration;
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  bool operator ==(Object other) => other is SongItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
