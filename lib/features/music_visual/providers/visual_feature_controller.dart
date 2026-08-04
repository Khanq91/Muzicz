import 'package:flutter/foundation.dart';

import '../models/waveform_data.dart';
import '../services/waveform_extract_service.dart';

final class VisualFeatureController extends ChangeNotifier {
  VisualFeatureController({WaveformExtractService? extractService})
    : _extractService = extractService ?? WaveformExtractService();

  final WaveformExtractService _extractService;

  WaveformData? _waveform;
  WaveformData? get waveform => _waveform;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  int _requestGeneration = 0;
  bool _disposed = false;

  Future<void> load({required int songId, required String filePath}) async {
    final generation = ++_requestGeneration;
    _waveform = null;
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

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }
}
