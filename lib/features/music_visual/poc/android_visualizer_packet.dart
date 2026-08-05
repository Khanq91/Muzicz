class AndroidVisualizerPacket {
  const AndroidVisualizerPacket({
    required this.sequence,
    required this.timestampUs,
    required this.sessionId,
    required this.sampleRateHz,
    required this.rms,
    required this.peak,
  });

  factory AndroidVisualizerPacket.fromMap(Map<Object?, Object?> map) {
    return AndroidVisualizerPacket(
      sequence: (map['sequence'] as num).toInt(),
      timestampUs: (map['timestampUs'] as num).toInt(),
      sessionId: (map['sessionId'] as num).toInt(),
      sampleRateHz: (map['sampleRateHz'] as num).toInt(),
      rms: (map['rms'] as num).toDouble().clamp(0, 1),
      peak: (map['peak'] as num).toDouble().clamp(0, 1),
    );
  }

  final int sequence;
  final int timestampUs;
  final int sessionId;
  final int sampleRateHz;
  final double rms;
  final double peak;
}
