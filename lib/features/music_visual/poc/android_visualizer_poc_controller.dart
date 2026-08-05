import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'android_visualizer_packet.dart';
import 'android_visualizer_poc_bridge.dart';

/// Standalone Phase-3 harness. It deliberately owns a separate player and does
/// not import PlayerProvider or the production audio handler.
class AndroidVisualizerPocController extends ChangeNotifier {
  AndroidVisualizerPocController({
    AudioPlayer? player,
    AndroidVisualizerPocBridge? bridge,
  }) : _player = player ?? AudioPlayer(),
       _bridge = bridge ?? AndroidVisualizerPocBridge();

  final AudioPlayer _player;
  final AndroidVisualizerPocBridge _bridge;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _initialized = false;
  bool _captureEnabled = false;
  bool _isPlaying = false;
  int? _sessionId;
  String? _filePath;
  String? _error;
  AndroidVisualizerPacket? _lastPacket;
  int _packetCount = 0;
  int _sequenceGaps = 0;
  int? _previousSequence;
  DateTime? _packetWindowStartedAt;

  bool get captureEnabled => _captureEnabled;
  bool get isPlaying => _isPlaying;
  int? get sessionId => _sessionId;
  String? get filePath => _filePath;
  String? get error => _error;
  AndroidVisualizerPacket? get lastPacket => _lastPacket;
  int get packetCount => _packetCount;
  int get sequenceGaps => _sequenceGaps;
  Stream<Duration> get positionStream => _player.positionStream;
  Duration get duration => _player.duration ?? Duration.zero;
  double get packetsPerSecond {
    final start = _packetWindowStartedAt;
    if (start == null) return 0;
    final seconds = DateTime.now().difference(start).inMilliseconds / 1000;
    return seconds <= 0 ? 0 : _packetCount / seconds;
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _subscriptions.add(
      _player.androidAudioSessionIdStream.distinct().listen((sessionId) {
        _sessionId = sessionId;
        _syncAttachment();
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.playingStream.distinct().listen((playing) {
        _isPlaying = playing;
        _syncAttachment();
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _bridge.packets.listen(
        _onPacket,
        onError: (Object exception) {
          _error = exception.toString();
          notifyListeners();
        },
      ),
    );
  }

  Future<bool> pickTrack() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return false;

    await _bridge.detach();
    await _player.setFilePath(path);
    _filePath = path;
    _resetPacketStats();
    _error = null;
    notifyListeners();
    return true;
  }

  Future<void> setCaptureEnabled(bool enabled) async {
    _captureEnabled = enabled;
    _error = null;
    if (!enabled) {
      await _bridge.detach();
    } else {
      await _syncAttachment();
    }
    notifyListeners();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> _syncAttachment() async {
    try {
      if (!_captureEnabled || !_isPlaying || _sessionId == null) {
        await _bridge.detach();
        return;
      }
      await _bridge.attach(_sessionId!);
    } catch (exception) {
      _error = exception.toString();
      notifyListeners();
    }
  }

  void _onPacket(AndroidVisualizerPacket packet) {
    _packetWindowStartedAt ??= DateTime.now();
    final previous = _previousSequence;
    if (previous != null && packet.sequence > previous + 1) {
      _sequenceGaps += packet.sequence - previous - 1;
    }
    _previousSequence = packet.sequence;
    _lastPacket = packet;
    _packetCount++;
    notifyListeners();
  }

  void _resetPacketStats() {
    _lastPacket = null;
    _packetCount = 0;
    _sequenceGaps = 0;
    _previousSequence = null;
    _packetWindowStartedAt = null;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_bridge.detach());
    unawaited(_player.dispose());
    super.dispose();
  }
}
