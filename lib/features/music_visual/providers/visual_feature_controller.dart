import 'package:flutter/foundation.dart';

import '../models/waveform_data.dart';
import '../services/waveform_extract_service.dart';

final class VisualFeatureController extends ChangeNotifier {
  VisualFeatureController({WaveformExtractService? extractService})
    : _extractService = extractService ?? WaveformExtractService();

  final WaveformExtractService _extractService;

  WaveformData? _waveform;
  WaveformData? get waveform => _waveform;

  double _amplitude = 0;
  double get amplitude => _amplitude;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  int _requestGeneration = 0;
  bool _disposed = false;

  Future<void> load({required int songId, required String filePath}) async {
    final generation = ++_requestGeneration;
    _waveform = null;
    _amplitude = 0;
    _error = null;
    _isLoading = true;
    notifyListeners();

    // Avoid starting extraction for tracks skipped through in quick succession.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (_disposed || generation != _requestGeneration) return;

    try {
      final waveform = await _extractService.extract(
        songId: songId,
        filePath: filePath,
      );
      if (_disposed || generation != _requestGeneration) return;
      _waveform = waveform;
    } catch (error) {
      if (_disposed || generation != _requestGeneration) return;
      _error = error;
    } finally {
      if (!_disposed && generation == _requestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Moves the precomputed waveform playhead and applies a light
  /// attack/release envelope suitable for the album-cover pulse.
  void updatePlayhead(double fraction, {required bool isPlaying}) {
    if (_disposed) return;

    final amplitudes = _waveform?.amplitudes;
    final rawAmplitude =
        isPlaying && amplitudes != null
            ? sampleAmplitude(amplitudes, fraction)
            : 0.0;
    final target = ((rawAmplitude - 0.06) / 0.94).clamp(0.0, 1.0);
    final response = target > _amplitude ? 0.58 : 0.16;
    final next = _amplitude + ((target - _amplitude) * response);

    if ((next - _amplitude).abs() < 0.001) return;
    _amplitude = next;
    notifyListeners();
  }

  void resetAmplitude() {
    if (_disposed || _amplitude == 0) return;
    _amplitude = 0;
    notifyListeners();
  }

  @visibleForTesting
  static double sampleAmplitude(List<double> amplitudes, double fraction) {
    if (amplitudes.isEmpty) return 0;
    if (amplitudes.length == 1) return amplitudes.first.clamp(0.0, 1.0);

    final position = fraction.clamp(0.0, 1.0) * (amplitudes.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    final blend = position - lower;
    final start = amplitudes[lower].clamp(0.0, 1.0);
    final end = amplitudes[upper].clamp(0.0, 1.0);
    return start + ((end - start) * blend);
  }

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }
}
