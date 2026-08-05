import 'dart:async';

import 'package:flutter/services.dart';

import 'android_visualizer_packet.dart';

class AndroidVisualizerPocBridge {
  static const methodChannelName =
      'muziczz/music_visual/android_visualizer_poc/methods';
  static const eventChannelName =
      'muziczz/music_visual/android_visualizer_poc/events';

  static const _methods = MethodChannel(methodChannelName);
  static const _events = EventChannel(eventChannelName);

  Stream<AndroidVisualizerPacket>? _packets;

  Stream<AndroidVisualizerPacket> get packets =>
      _packets ??=
          _events
              .receiveBroadcastStream()
              .map(
                (event) => AndroidVisualizerPacket.fromMap(
                  Map<Object?, Object?>.from(event as Map),
                ),
              )
              .asBroadcastStream();

  Future<void> attach(int audioSessionId) async {
    if (audioSessionId <= 0) {
      throw ArgumentError.value(audioSessionId, 'audioSessionId');
    }
    await _methods.invokeMethod<void>('attach', {
      'audioSessionId': audioSessionId,
    });
  }

  Future<void> detach() => _methods.invokeMethod<void>('detach');
}
