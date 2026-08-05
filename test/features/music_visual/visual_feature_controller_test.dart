import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/features/music_visual/providers/visual_feature_controller.dart';

void main() {
  group('VisualFeatureController.sampleAmplitude', () {
    test('interpolates the playhead between precomputed samples', () {
      expect(VisualFeatureController.sampleAmplitude(const [0, 1], 0.25), 0.25);
      expect(
        VisualFeatureController.sampleAmplitude(const [0, 1, 0], 0.75),
        0.5,
      );
    });

    test('clamps the playhead and malformed sample values', () {
      expect(VisualFeatureController.sampleAmplitude(const [-1, 2], -0.5), 0);
      expect(VisualFeatureController.sampleAmplitude(const [-1, 2], 1.5), 1);
      expect(VisualFeatureController.sampleAmplitude(const [], 0.5), 0);
    });
  });
}
