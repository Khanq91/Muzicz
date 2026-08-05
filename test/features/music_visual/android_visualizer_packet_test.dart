import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/features/music_visual/poc/android_visualizer_packet.dart';

void main() {
  test('normalizes an Android Visualizer packet contract', () {
    final packet = AndroidVisualizerPacket.fromMap({
      'sequence': 12,
      'timestampUs': 345678,
      'sessionId': 9,
      'sampleRateHz': 48000,
      'rms': 1.4,
      'peak': -0.2,
    });

    expect(packet.sequence, 12);
    expect(packet.timestampUs, 345678);
    expect(packet.sessionId, 9);
    expect(packet.sampleRateHz, 48000);
    expect(packet.rms, 1);
    expect(packet.peak, 0);
  });

  test('permission request stays behind the Phase-3 sub-toggle', () {
    final screen =
        File(
          'lib/features/music_visual/poc/android_visualizer_poc_screen.dart',
        ).readAsStringSync();
    final selector =
        File(
          'lib/features/music_visual/widgets/visual_mode_selector_sheet.dart',
        ).readAsStringSync();

    expect(screen, contains('Permission.microphone.request()'));
    expect(screen, contains('Future<void> _toggleCapture(bool enabled)'));
    expect(selector, isNot(contains('Permission.microphone.request()')));
  });

  test('POC remains isolated from production player state', () {
    final controller =
        File(
          'lib/features/music_visual/poc/android_visualizer_poc_controller.dart',
        ).readAsStringSync();

    expect(controller, contains('androidAudioSessionIdStream'));
    expect(controller, isNot(contains('player_provider.dart')));
    expect(controller, isNot(contains('audio_handler.dart')));
  });
}
