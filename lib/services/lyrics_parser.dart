import 'dart:convert';
import 'package:xml/xml.dart';
import '../models/lyric_line.dart';

class LyricsParser {
  static final _stamp = RegExp(r'\[(\d{1,3}:\d{2}(?:\.\d{1,3})?)\]');
  static final _word = RegExp(r'<(\d{1,3}:\d{2}(?:\.\d{1,3})?)>');

  static Duration? timestamp(String? text) {
    if (text == null) return null;
    if (text.endsWith('ms')) {
      final n = double.tryParse(text.substring(0, text.length - 2));
      return n == null ? null : Duration(milliseconds: n.round());
    }
    if (text.endsWith('s')) {
      final n = double.tryParse(text.substring(0, text.length - 1));
      return n == null ? null : Duration(milliseconds: (n * 1000).round());
    }
    final parts = text.replaceAll(',', '.').split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    var seconds = 0.0;
    for (final part in parts) {
      final n = double.tryParse(part);
      if (n == null || !n.isFinite) return null;
      seconds = seconds * 60 + n;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  static String decode(List<int> bytes) {
    if (bytes.length >= 2 &&
        ((bytes[0] == 255 && bytes[1] == 254) ||
            (bytes[0] == 254 && bytes[1] == 255))) {
      final little = bytes[0] == 255;
      if (bytes.length.isOdd) {
        throw const FormatException('UTF-16 không hợp lệ');
      }
      return String.fromCharCodes([
        for (var i = 2; i + 1 < bytes.length; i += 2)
          little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
      ]);
    }
    return utf8.decode(bytes).replaceFirst('\uFEFF', '');
  }

  static List<LyricLine> parse(String raw) {
    if (raw.length > 1024 * 1024) {
      throw const FormatException('File lời quá lớn');
    }
    final text = raw.replaceAll('\uFEFF', '').replaceAll('\r', '');
    if (text.trimLeft().startsWith('<') &&
        RegExp(r'<(?:\w+:)?tt[\s>]').hasMatch(text)) {
      return _ttml(text);
    }
    final offset =
        int.tryParse(
          RegExp(
                r'\[offset:([+-]?\d+)\]',
                caseSensitive: false,
              ).firstMatch(text)?.group(1) ??
              '',
        ) ??
        0;
    final lines = <LyricLine>[];
    for (final row in text.split('\n')) {
      final stamps = _stamp.allMatches(row).toList();
      if (stamps.isEmpty) continue;
      final content = row.substring(stamps.last.end);
      final markers = _word.allMatches(content).toList();
      final words = <LyricWord>[];
      for (var i = 0; i < markers.length; i++) {
        final start =
            timestamp(markers[i].group(1))! + Duration(milliseconds: offset);
        final end =
            i + 1 < markers.length
                ? timestamp(markers[i + 1].group(1))! +
                    Duration(milliseconds: offset)
                : null;
        final word = content.substring(
          markers[i].end,
          i + 1 < markers.length ? markers[i + 1].start : content.length,
        );
        if (word.isNotEmpty) {
          words.add(LyricWord(text: word, start: start, end: end));
        }
      }
      for (final stamp in stamps) {
        final time =
            timestamp(stamp.group(1))! + Duration(milliseconds: offset);
        lines.add(
          LyricLine(
            text: content.replaceAll(_word, '').trim(),
            time: time,
            words: stamps.length == 1 ? words : const [],
          ),
        );
      }
    }
    if (lines.isNotEmpty) {
      lines.sort((a, b) => a.time!.compareTo(b.time!));
      return lines;
    }
    // Do not silently accept malformed XML or a broken timed document as plain lyrics.
    if (text.trimLeft().startsWith('<') || RegExp(r'\[\d+:').hasMatch(text)) {
      throw const FormatException('Định dạng lời không hợp lệ');
    }
    return text
        .split('\n')
        .where(
          (l) =>
              l.trim().isNotEmpty &&
              !RegExp(
                r'^\[[a-z]+:.*\]$',
                caseSensitive: false,
              ).hasMatch(l.trim()),
        )
        .map((l) => LyricLine(text: l.trim()))
        .toList();
  }

  static List<LyricLine> _ttml(String text) {
    if (text.toUpperCase().contains('<!DOCTYPE') ||
        text.toUpperCase().contains('<!ENTITY')) {
      throw const FormatException('TTML không hỗ trợ DTD/entity');
    }
    final doc = XmlDocument.parse(text);
    final result = <LyricLine>[];
    String? attr(XmlElement e, String name) {
      for (final a in e.attributes) {
        if (a.name.local == name) return a.value;
      }
      return null;
    }

    bool auxiliary(XmlElement e) => [
      'x-translation',
      'x-roman',
      'x-romanization',
    ].contains(attr(e, 'role'));
    String mainText(XmlNode node) {
      if (node is XmlText) return node.value;
      if (node is XmlElement && auxiliary(node)) return '';
      if (node is XmlElement && node.name.local == 'br') return '\n';
      return node.children.map(mainText).join();
    }

    for (final p in doc.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'p',
    )) {
      final start = timestamp(attr(p, 'begin'));
      final end = timestamp(attr(p, 'end'));
      final spans = p.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'span',
      );
      final words = <LyricWord>[];
      String? translation, roman;
      for (final span in spans) {
        final role = attr(span, 'role');
        if (role == 'x-translation') {
          translation = span.innerText.trim();
          continue;
        }
        if (role == 'x-roman' || role == 'x-romanization') {
          roman = span.innerText.trim();
          continue;
        }
        if (span.ancestors.whereType<XmlElement>().any(auxiliary)) continue;
        final time = timestamp(attr(span, 'begin'));
        if (time != null &&
            !span.childElements.any((e) => attr(e, 'begin') != null)) {
          words.add(
            LyricWord(
              text: mainText(span),
              start: time,
              end: timestamp(attr(span, 'end')),
            ),
          );
        }
      }
      final value = mainText(p).trim();
      if (value.isNotEmpty || start != null) {
        result.add(
          LyricLine(
            text: value,
            time: start ?? (words.isEmpty ? null : words.first.start),
            end: end,
            words: words,
            translation: translation,
            romanization: roman,
          ),
        );
      }
    }
    if (result.isEmpty) throw const FormatException('TTML không có lời');
    result.sort(
      (a, b) => (a.time ?? Duration.zero).compareTo(b.time ?? Duration.zero),
    );
    return result;
  }

  static String stamp(Duration value) {
    final ms = value.inMilliseconds.clamp(0, 1 << 40);
    return '${(ms ~/ 60000).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
  }

  static String export(List<LyricLine> lines, {bool synced = true}) => lines
      .map((line) {
        if (!synced || line.time == null) return line.text;
        final text =
            line.words.isEmpty
                ? line.text
                : line.words.map((w) => '<${stamp(w.start)}>${w.text}').join();
        return '[${stamp(line.time!)}]$text';
      })
      .join('\n');

  /// Lossless app export for translated/word-timed lyrics; no AI-generated timings.
  static String toTtml(List<LyricLine> lines) {
    final builder = XmlBuilder();
    builder.element(
      'tt',
      attributes: {
        'xmlns': 'http://www.w3.org/ns/ttml',
        'xmlns:ttm': 'http://www.w3.org/ns/ttml#metadata',
      },
      nest:
          () => builder.element(
            'body',
            nest:
                () => builder.element(
                  'div',
                  nest: () {
                    for (final line in lines) {
                      builder.element(
                        'p',
                        attributes: {
                          if (line.time != null)
                            'begin': '${line.time!.inMilliseconds}ms',
                          if (line.end != null)
                            'end': '${line.end!.inMilliseconds}ms',
                        },
                        nest: () {
                          if (line.words.isEmpty) {
                            builder.text(line.text);
                          } else {
                            for (final word in line.words) {
                              builder.element(
                                'span',
                                attributes: {
                                  'begin': '${word.start.inMilliseconds}ms',
                                  if (word.end != null)
                                    'end': '${word.end!.inMilliseconds}ms',
                                },
                                nest: word.text,
                              );
                            }
                          }
                          if (line.translation != null) {
                            builder.element(
                              'span',
                              attributes: {'ttm:role': 'x-translation'},
                              nest: line.translation,
                            );
                          }
                          if (line.romanization != null) {
                            builder.element(
                              'span',
                              attributes: {'ttm:role': 'x-roman'},
                              nest: line.romanization,
                            );
                          }
                        },
                      );
                    }
                  },
                ),
          ),
    );
    return builder.buildDocument().toXmlString();
  }
}
