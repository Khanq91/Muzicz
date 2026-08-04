final class WaveformData {
  const WaveformData({
    required this.amplitudes,
    required this.songId,
    required this.analysisVersion,
  });

  /// Normalized peak amplitudes in the range 0.0–1.0.
  final List<double> amplitudes;
  final int songId;
  final int analysisVersion;
}
