import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/features/downloader/models/download_task.dart';
import 'package:muziczz/features/downloader/models/format_option.dart';
import 'package:muziczz/features/downloader/models/video_info.dart';
import 'package:muziczz/features/downloader/providers/download_provider.dart';
import 'package:muziczz/features/downloader/services/ytdlp_service.dart';

void main() {
  test('rapid sequential enqueue starts each task exactly once', () async {
    final gateway = _RecordingDownloadGateway();
    final container = ProviderContainer(
      overrides: [
        downloadGatewayProvider.overrideWithValue(gateway),
        downloadOutputDirectoryProvider.overrideWithValue('/downloads'),
      ],
    );
    addTearDown(() {
      container.dispose();
      gateway.dispose();
    });

    final notifier = container.read(downloadProvider.notifier);
    await notifier.enqueue(info: _video('one'), format: _format);
    await notifier.enqueue(info: _video('two'), format: _format);

    expect(gateway.startedTaskIds, hasLength(2));
    expect(gateway.startedTaskIds.toSet(), hasLength(2));
    expect(container.read(downloadProvider).activeTasks, hasLength(2));
    expect(container.read(downloadProvider).queuedTasks, isEmpty);
  });

  test('synchronous start failure moves the task to error', () async {
    final gateway = _ThrowingDownloadGateway();
    final container = ProviderContainer(
      overrides: [
        downloadGatewayProvider.overrideWithValue(gateway),
        downloadOutputDirectoryProvider.overrideWithValue('/downloads'),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(downloadProvider.notifier)
        .enqueue(info: _video('one'), format: _format);

    final task = container.read(downloadProvider).tasks.single;
    expect(task.status, DownloadStatus.error);
    expect(task.errorMessage, contains('start failed'));
  });
}

const _format = FormatOption(
  formatId: 'audio',
  ext: 'm4a',
  quality: 'Audio',
  isAudioOnly: true,
);

VideoInfo _video(String id) => VideoInfo(
  id: id,
  title: 'Video $id',
  url: 'https://example.com/$id',
  platform: VideoPlatform.youtube,
  type: VideoType.video,
  skippedCount: null,
  formats: const [],
);

class _RecordingDownloadGateway implements DownloadGateway {
  final List<String> startedTaskIds = [];
  final List<StreamController<DownloadTask>> _controllers = [];

  @override
  Stream<DownloadTask> download(DownloadTask task, {String? outputDir}) {
    startedTaskIds.add(task.id);
    final controller = StreamController<DownloadTask>();
    _controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<ExtractAudioResult> extractAudioNative({
    required String inputPath,
  }) async => const ExtractAudioResult(success: true);

  void dispose() {
    for (final controller in _controllers) {
      controller.close();
    }
  }
}

class _ThrowingDownloadGateway implements DownloadGateway {
  @override
  Stream<DownloadTask> download(DownloadTask task, {String? outputDir}) {
    throw StateError('start failed');
  }

  @override
  Future<ExtractAudioResult> extractAudioNative({
    required String inputPath,
  }) async => const ExtractAudioResult(success: true);
}
