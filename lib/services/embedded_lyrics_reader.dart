import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'lyrics_parser.dart';

/// Reads bounded metadata, never decodes or uploads the audio stream.
class EmbeddedLyricsReader {
  static const limit = 2 * 1024 * 1024;

  Future<String?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final handle = await file.open();
    try {
      final size = await handle.length();
      final head = await handle.read(size.clamp(0, limit));
      final found = parse(head);
      if (found != null) return found;
      if (head.length >= 8 && latin1.decode(head.sublist(4, 8)) == 'ftyp') {
        return await _mp4(handle, 0, size, 0);
      }
      return null;
    } finally {
      await handle.close();
    }
  }

  static int _int(
    List<int> bytes,
    int start,
    int count, {
    bool little = false,
    bool sync = false,
  }) {
    if (start < 0 || start + count > bytes.length) return 0;
    var n = 0;
    for (var i = 0; i < count; i++) {
      n = (n << (sync ? 7 : 8)) | bytes[start + (little ? count - i - 1 : i)];
    }
    return n;
  }

  static String _text(List<int> bytes, int encoding) {
    if (encoding == 0) {
      return latin1.decode(bytes).replaceAll('\u0000', '').trim();
    }
    if (encoding == 2) {
      return LyricsParser.decode([
        254,
        255,
        ...bytes,
      ]).replaceAll('\u0000', '').trim();
    }
    return (encoding == 1
            ? LyricsParser.decode(bytes)
            : utf8.decode(bytes, allowMalformed: true))
        .replaceAll('\u0000', '')
        .trim();
  }

  static int _end(List<int> bytes, int start, int encoding) {
    final step = encoding == 1 || encoding == 2 ? 2 : 1;
    for (var i = start; i + step <= bytes.length; i += step) {
      if (bytes[i] == 0 && (step == 1 || bytes[i + 1] == 0)) return i + step;
    }
    return bytes.length;
  }

  static String? parse(Uint8List bytes) {
    if (bytes.length < 10) return null;
    final magic = latin1.decode(bytes.sublist(0, 4));
    if (magic.startsWith('ID3')) {
      final version = bytes[3];
      if (version < 2 || version > 4) return null;
      var data = bytes.sublist(
        10,
        (10 + _int(bytes, 6, 4, sync: true)).clamp(10, bytes.length),
      );
      if (bytes[5] & 0x80 != 0) {
        data = Uint8List.fromList([
          for (var i = 0; i < data.length; i++)
            if (!(i > 0 && data[i] == 0 && data[i - 1] == 255)) data[i],
        ]);
      }
      var pos = 0;
      if (bytes[5] & 0x40 != 0 && version >= 3) {
        pos = _int(data, 0, 4, sync: version == 4) + (version == 3 ? 4 : 0);
      }
      String? plain;
      final header = version == 2 ? 6 : 10;
      while (pos + header <= data.length) {
        final id = latin1.decode(
          data.sublist(pos, pos + (version == 2 ? 3 : 4)),
        );
        final length = _int(
          data,
          pos + (version == 2 ? 3 : 4),
          version == 2 ? 3 : 4,
          sync: version == 4,
        );
        if (length <= 0 || pos + header + length > data.length) break;
        final payload = data.sublist(pos + header, pos + header + length);
        pos += header + length;
        if (payload.length < 5) continue;
        final encoding = payload[0];
        if (id == 'USLT' || id == 'ULT') {
          plain = _text(payload.sublist(_end(payload, 4, encoding)), encoding);
        }
        if ((id == 'SYLT' || id == 'SLT') &&
            payload.length > 6 &&
            payload[4] == 2) {
          var cursor = _end(payload, 6, encoding);
          final lines = <String>[];
          while (cursor < payload.length) {
            final end = _end(payload, cursor, encoding);
            if (end + 4 > payload.length) break;
            final word = _text(payload.sublist(cursor, end), encoding);
            final time = Duration(milliseconds: _int(payload, end, 4));
            lines.add('[${LyricsParser.stamp(time)}]$word');
            cursor = end + 4;
          }
          if (lines.isNotEmpty) return lines.join('\n');
        }
      }
      return plain;
    }
    if (magic == 'fLaC') {
      var pos = 4;
      while (pos + 4 <= bytes.length) {
        final type = bytes[pos] & 127;
        final last = bytes[pos] & 128 != 0;
        final length = _int(bytes, pos + 1, 3);
        pos += 4;
        if (pos + length > bytes.length) break;
        if (type == 4) return _comments(bytes.sublist(pos, pos + length));
        pos += length;
        if (last) break;
      }
    }
    if (magic == 'OggS') {
      var pos = 0;
      final packet = BytesBuilder(copy: false);
      while (pos + 27 <= bytes.length) {
        if (latin1.decode(bytes.sublist(pos, pos + 4)) != 'OggS') break;
        final count = bytes[pos + 26];
        if (pos + 27 + count > bytes.length) break;
        final segments = bytes.sublist(pos + 27, pos + 27 + count);
        pos += 27 + count;
        for (final length in segments) {
          if (pos + length > bytes.length) return null;
          packet.add(bytes.sublist(pos, pos + length));
          pos += length;
          if (length < 255) {
            final value = packet.takeBytes();
            if (value.length > 8 &&
                latin1.decode(value.sublist(0, 8)) == 'OpusTags') {
              return _comments(value.sublist(8));
            }
            if (value.length > 7 &&
                value[0] == 3 &&
                latin1.decode(value.sublist(1, 7)) == 'vorbis') {
              return _comments(value.sublist(7));
            }
          }
        }
      }
    }
    return null;
  }

  static String? _comments(Uint8List bytes) {
    var pos = 4 + _int(bytes, 0, 4, little: true);
    final count = _int(bytes, pos, 4, little: true);
    pos += 4;
    for (var i = 0; i < count && pos + 4 <= bytes.length; i++) {
      final length = _int(bytes, pos, 4, little: true);
      pos += 4;
      if (pos + length > bytes.length) break;
      final value = utf8.decode(
        bytes.sublist(pos, pos + length),
        allowMalformed: true,
      );
      pos += length;
      final equal = value.indexOf('=');
      if (equal > 0 &&
          [
            'LYRICS',
            'UNSYNCEDLYRICS',
            'SYNCEDLYRICS',
          ].contains(value.substring(0, equal).toUpperCase())) {
        return value.substring(equal + 1);
      }
    }
    return null;
  }

  Future<String?> _mp4(
    RandomAccessFile file,
    int start,
    int end,
    int depth,
  ) async {
    if (depth > 8) return null;
    var pos = start;
    while (pos + 8 <= end) {
      await file.setPosition(pos);
      final header = await file.read(16);
      if (header.length < 8) break;
      var size = _int(header, 0, 4);
      final type = latin1.decode(header.sublist(4, 8));
      var offset = 8;
      if (size == 1) {
        size = _int(header, 8, 8);
        offset = 16;
      }
      if (size == 0) size = end - pos;
      if (size < offset || pos + size > end) break;
      if (type == '©lyr' && size <= limit) {
        await file.setPosition(pos + offset);
        final bytes = await file.read(size - offset);
        if (bytes.length > 16 && latin1.decode(bytes.sublist(4, 8)) == 'data') {
          return utf8.decode(bytes.sublist(16), allowMalformed: true);
        }
      }
      if (['moov', 'udta', 'meta', 'ilst'].contains(type)) {
        final found = await _mp4(
          file,
          pos + offset + (type == 'meta' ? 4 : 0),
          pos + size,
          depth + 1,
        );
        if (found != null) return found;
      }
      pos += size;
    }
    return null;
  }
}
