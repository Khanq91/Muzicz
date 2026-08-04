import 'dart:io';

import 'package:just_waveform/just_waveform.dart';
import 'package:path_provider/path_provider.dart';

import '../models/waveform_data.dart';

final class WaveformExtractService {
  WaveformExtractService({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  static const int analysisVersion = 1;
  static const int columnCount = 512;
  static final Map<String, Future<Waveform>> _inFlight = {};

  final Future<Directory> Function() _documentsDirectory;

  /// Extracts a local song once, then parses its isolated cached `.wave` file.
  ///
  /// Bump [analysisVersion] whenever the extraction/downsampling format changes.
  Future<WaveformData> extract({
    required int songId,
    required String filePath,
  }) async {
    final audioFile = File(filePath);
    if (!await audioFile.exists()) {
      throw FileSystemException('Audio file does not exist', filePath);
    }

    final documents = await _documentsDirectory();
    final cacheDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}music_visual_cache',
    );
    await cacheDirectory.create(recursive: true);

    final cacheKey = '${songId}_v$analysisVersion';
    final cacheFile = File(
      '${cacheDirectory.path}${Platform.pathSeparator}$cacheKey.wave',
    );

    final cached = await _tryParse(cacheFile);
    if (cached != null) return _toData(songId, cached);

    final existingExtraction = _inFlight[cacheFile.path];
    if (existingExtraction != null) {
      return _toData(songId, await existingExtraction);
    }

    final extraction = _extractAndCache(audioFile, cacheFile);
    _inFlight[cacheFile.path] = extraction;

    try {
      return _toData(songId, await extraction);
    } finally {
      if (identical(_inFlight[cacheFile.path], extraction)) {
        _inFlight.remove(cacheFile.path);
      }
    }
  }

  Future<Waveform> _extractAndCache(File audioFile, File cacheFile) async {
    final temporaryFile = File('${cacheFile.path}.tmp');
    if (await temporaryFile.exists()) await temporaryFile.delete();

    try {
      Waveform? extracted;
      await for (final progress in JustWaveform.extract(
        audioInFile: audioFile,
        waveOutFile: temporaryFile,
        zoom: const WaveformZoom.pixelsPerSecond(100),
      )) {
        extracted = progress.waveform ?? extracted;
      }

      extracted ??= await JustWaveform.parse(temporaryFile);
      if (await cacheFile.exists()) await cacheFile.delete();
      await temporaryFile.rename(cacheFile.path);
      return extracted;
    } catch (_) {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      rethrow;
    }
  }

  Future<Waveform?> _tryParse(File file) async {
    if (!await file.exists()) return null;

    try {
      return await JustWaveform.parse(file);
    } catch (_) {
      // A killed extraction can leave an invalid file. Rebuild it safely.
      await file.delete();
      return null;
    }
  }

  WaveformData _toData(int songId, Waveform waveform) {
    return WaveformData(
      amplitudes: List<double>.unmodifiable(_downsample(waveform, columnCount)),
      songId: songId,
      analysisVersion: analysisVersion,
    );
  }

  List<double> _downsample(Waveform waveform, int columns) {
    if (waveform.length <= 0) return List<double>.filled(columns, 0);

    final peaks = List<double>.filled(columns, 0);
    var trackPeak = 0.0;

    for (var column = 0; column < columns; column++) {
      final start = column * waveform.length ~/ columns;
      var end = (column + 1) * waveform.length ~/ columns;
      if (end <= start) end = start + 1;
      if (end > waveform.length) end = waveform.length;

      var bucketPeak = 0.0;
      for (var pixel = start; pixel < end; pixel++) {
        final min = waveform.getPixelMin(pixel).abs().toDouble();
        final max = waveform.getPixelMax(pixel).abs().toDouble();
        final peak = min > max ? min : max;
        if (peak > bucketPeak) bucketPeak = peak;
      }
      peaks[column] = bucketPeak;
      if (bucketPeak > trackPeak) trackPeak = bucketPeak;
    }

    if (trackPeak == 0) return peaks;
    for (var i = 0; i < peaks.length; i++) {
      peaks[i] = (peaks[i] / trackPeak).clamp(0.0, 1.0);
    }
    return peaks;
  }
}
