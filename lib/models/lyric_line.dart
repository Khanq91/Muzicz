class LyricLine {
  const LyricLine({
    required this.text,
    this.time,
  });

  /// Nội dung dòng lyrics.
  final String text;

  /// null = plain lyrics (không có timestamp).
  final Duration? time;
}