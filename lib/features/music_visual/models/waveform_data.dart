/// Data contract reserved for the waveform implementation in Phase 1.
final class WaveformData {
  const WaveformData({
    required this.amplitudes,
    required this.songId,
    required this.analysisVersion,
  });

  final List<double> amplitudes;
  final int songId;
  final int analysisVersion;
}
