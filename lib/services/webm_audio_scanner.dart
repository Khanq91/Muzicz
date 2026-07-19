import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/song_item.dart';

abstract interface class WebmAudioGateway {
  Future<List<SongItem>> scan();
}

class MethodChannelWebmAudioGateway implements WebmAudioGateway {
  const MethodChannelWebmAudioGateway();

  static const _channel = MethodChannel('music_scanner_channel');

  @override
  Future<List<SongItem>> scan() async {
    try {
      final raw = await _channel.invokeMethod<String>('scanWebmAudio');
      if (raw == null) return const [];
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SongItem.fromJson)
          .toList();
    } on PlatformException {
      return const [];
    }
  }
}
