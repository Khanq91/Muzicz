class LyricLine {
  const LyricLine({
    required this.text,
    this.time,
    this.end,
    this.words = const [],
    this.translation,
    this.romanization,
  });

  /// Nội dung dòng lyrics.
  final String text;

  /// null = plain lyrics (không có timestamp).
  final Duration? time;
  final Duration? end;
  final List<LyricWord> words;
  final String? translation;
  final String? romanization;
}

class LyricWord {
  const LyricWord({required this.text, required this.start, this.end});
  final String text;
  final Duration start;
  final Duration? end;
}
