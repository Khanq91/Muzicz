import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'android_visualizer_poc_controller.dart';

class AndroidVisualizerPocScreen extends StatefulWidget {
  const AndroidVisualizerPocScreen({super.key});

  @override
  State<AndroidVisualizerPocScreen> createState() =>
      _AndroidVisualizerPocScreenState();
}

class _AndroidVisualizerPocScreenState
    extends State<AndroidVisualizerPocScreen> {
  late final AndroidVisualizerPocController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AndroidVisualizerPocController()..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleCapture(bool enabled) async {
    if (!enabled) {
      await _controller.setCaptureEnabled(false);
      return;
    }

    // The permission prompt lives here, immediately behind the Phase-3-only
    // sub-toggle. Selecting Fancy in Phase 1/2 never reaches this call.
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cần quyền mic cho Android Visualizer; app không ghi âm.',
          ),
        ),
      );
      return;
    }
    await _controller.setCaptureEnabled(true);
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const Scaffold(
        body: Center(child: Text('POC này chỉ dành cho Android.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Android Visualizer POC')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final packet = _controller.lastPacket;
          final duration = _controller.duration;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Harness độc lập — không dùng player production. Chọn file local, '
                'sau đó bật capture để xin RECORD_AUDIO đúng lúc.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _controller.pickTrack,
                icon: const Icon(Icons.audio_file_rounded),
                label: Text(
                  _controller.filePath == null
                      ? 'Chọn bài test'
                      : _controller.filePath!
                          .split(Platform.pathSeparator)
                          .last,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Realtime RMS (POC)'),
                subtitle: const Text(
                  'Chỉ sub-toggle này mới yêu cầu quyền RECORD_AUDIO.',
                ),
                value: _controller.captureEnabled,
                onChanged: _toggleCapture,
              ),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed:
                        _controller.filePath == null
                            ? null
                            : (_controller.isPlaying
                                ? _controller.pause
                                : _controller.play),
                    icon: Icon(
                      _controller.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(_controller.isPlaying ? 'Pause' : 'Play'),
                  ),
                  const SizedBox(width: 12),
                  Text('Session: ${_controller.sessionId ?? '—'}'),
                ],
              ),
              if (duration > Duration.zero)
                StreamBuilder<Duration>(
                  stream: _controller.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final maxMs = duration.inMilliseconds.toDouble();
                    return Slider(
                      min: 0,
                      max: maxMs,
                      value:
                          position.inMilliseconds
                              .clamp(0, maxMs.toInt())
                              .toDouble(),
                      onChanged:
                          (value) => _controller.seek(
                            Duration(milliseconds: value.round()),
                          ),
                    );
                  },
                ),
              const Divider(height: 32),
              _Metric(
                label: 'RMS',
                value: packet?.rms.toStringAsFixed(4) ?? '—',
              ),
              _Metric(
                label: 'Peak',
                value: packet?.peak.toStringAsFixed(4) ?? '—',
              ),
              _Metric(label: 'Packets', value: '${_controller.packetCount}'),
              _Metric(
                label: 'Packet rate',
                value: '${_controller.packetsPerSecond.toStringAsFixed(1)} Hz',
              ),
              _Metric(
                label: 'Sequence gaps',
                value: '${_controller.sequenceGaps}',
              ),
              _Metric(
                label: 'Sample rate',
                value: packet == null ? '—' : '${packet.sampleRateHz} Hz',
              ),
              if (_controller.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Gate thủ công: seek ≥3 lần; pause/resume ≥3 lần; chọn đổi bài '
                '≥3 lần; đổi Bluetooth route. Ghi nhận packet có tiếp tục và app '
                'có crash hay không trước khi cân nhắc merge production.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontFeatures: [])),
      ],
    ),
  );
}
