class LyricLine {
  const LyricLine({
    required this.text,
    this.time,
  });

  /// Nội dung dòng lyrics.
  final String text;

  /// null = plain lyrics (không có timestamp).
  final Duration? time;

  bool get isSynced => time != null;

  @override
  String toString() => 'LyricLine(${time?.inMilliseconds}ms, "$text")';
}