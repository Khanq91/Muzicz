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
      track: s.track,
      dateAdded: s.dateAdded != null
          ? DateTime.fromMillisecondsSinceEpoch(s.dateAdded! * 1000)
          : null,
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'albumId': albumId,
    'artistId': artistId,
    'data': data,
    'duration': duration,
    'size': size,
    'track': track,
    'dateAdded': dateAdded?.millisecondsSinceEpoch,
  };

  factory SongItem.fromJson(Map<String, dynamic> json) => SongItem(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String? ?? 'Unknown Artist',
    album: json['album'] as String? ?? 'Unknown Album',
    albumId: json['albumId'] as int? ?? 0,
    artistId: json['artistId'] as int? ?? 0,
    data: json['data'] as String? ?? '',
    duration: json['duration'] as int? ?? 0,
    size: json['size'] as int?,
    track: json['track'] as int?,
    dateAdded: json['dateAdded'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['dateAdded'] as int)
        : null,
  );

  // ── Helpers ───────────────────────────────────────────────────────────────
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