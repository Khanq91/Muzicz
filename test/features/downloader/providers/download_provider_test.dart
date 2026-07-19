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
        downloadDispatchLimitProvider.overrideWithValue(1),
      ],
    );
    addTearDown(() {
      container.dispose();
      gateway.dispose();
    });

    final notifier = container.read(downloadProvider.notifier);
    await notifier.enqueue(info: _video('one'), format: _format);
    await notifier.enqueue(info: _video('two'), format: _format);

    expect(gateway.startedTaskIds, hasLength(1));

    await gateway.complete(gateway.startedTaskIds.single);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.startedTaskIds, hasLength(2));
    expect(gateway.startedTaskIds.toSet(), hasLength(2));
    expect(container.read(downloadProvider).activeTasks, hasLength(1));
    expect(container.read(downloadProvider).queuedTasks, isEmpty);
  });

  test('synchronous start failure moves the task to error', () async {
    final gateway = _ThrowingDownloadGateway();
    final container = ProviderContainer(
      overrides: [
        downloadGatewayProvider.overrideWithValue(gateway),
        downloadOutputDirectoryProvider.overrideWithValue('/downloads'),
        downloadDispatchLimitProvider.overrideWithValue(1),
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

  test('dispatch limit override serializes the fake gateway', () async {
    final gateway = _RecordingDownloadGateway();
    final container = ProviderContainer(
      overrides: [
        downloadGatewayProvider.overrideWithValue(gateway),
        downloadOutputDirectoryProvider.overrideWithValue('/downloads'),
        downloadDispatchLimitProvider.overrideWithValue(1),
      ],
    );
    addTearDown(() {
      container.dispose();
      gateway.dispose();
    });

    await container
        .read(downloadProvider.notifier)
        .enqueueBatch(infos: [_video('one'), _video('two')], format: _format);

    expect(gateway.startedTaskIds, hasLength(1));
    expect(container.read(downloadProvider).activeTasks, hasLength(1));
    expect(container.read(downloadProvider).queuedTasks, hasLength(1));

    await gateway.complete(gateway.startedTaskIds.single);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.startedTaskIds, hasLength(2));
    expect(gateway.startedTaskIds.toSet(), hasLength(2));
    expect(container.read(downloadProvider).activeTasks, hasLength(1));
    expect(container.read(downloadProvider).queuedTasks, isEmpty);
  });

  test(
    'cancel waits for native acknowledgement before advancing queue',
    () async {
      final gateway = _RecordingDownloadGateway();
      final container = ProviderContainer(
        overrides: [
          downloadGatewayProvider.overrideWithValue(gateway),
          downloadOutputDirectoryProvider.overrideWithValue('/downloads'),
          downloadDispatchLimitProvider.overrideWithValue(1),
        ],
      );
      addTearDown(() {
        container.dispose();
        gateway.dispose();
      });

      await container
          .read(downloadProvider.notifier)
          .enqueueBatch(infos: [_video('one'), _video('two')], format: _format);

      final firstTaskId = gateway.startedTaskIds.single;
      final cancelFuture = container
          .read(downloadProvider.notifier)
          .cancel(firstTaskId);

      expect(gateway.cancelledTaskIds, [firstTaskId]);
      expect(
        container.read(downloadProvider).tasks.first.status,
        DownloadStatus.preparing,
      );
      expect(gateway.startedTaskIds, hasLength(1));

      await gateway.acknowledgeCancel(firstTaskId);
      await cancelFuture;
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(downloadProvider).tasks.first.status,
        DownloadStatus.cancelled,
      );
      expect(gateway.startedTaskIds, hasLength(2));
    },
  );

  test('failed native cancel keeps task active and queue blocked', () async {
    final gateway = _RecordingDownloadGateway();
    final container = ProviderContainer(
      overrides: [
        downloadGatewayProvider.overrideWithValue(gateway),
        downloadOutputDirectoryProvider.overrideWithValue('/downloads'),
        downloadDispatchLimitProvider.overrideWithValue(1),
      ],
    );
    addTearDown(() {
      container.dispose();
      gateway.dispose();
    });

    await container
        .read(downloadProvider.notifier)
        .enqueueBatch(infos: [_video('one'), _video('two')], format: _format);

    final firstTaskId = gateway.startedTaskIds.single;
    final cancelFuture = container
        .read(downloadProvider.notifier)
        .cancel(firstTaskId);
    gateway.rejectCancel(firstTaskId);

    expect(await cancelFuture, isFalse);
    expect(
      container.read(downloadProvider).tasks.first.status,
      DownloadStatus.preparing,
    );
    expect(container.read(downloadProvider).queuedTasks, hasLength(1));
    expect(gateway.startedTaskIds, hasLength(1));
  });

  test('restores completed tasks from the foreground service', () async {
    final restoredTask = DownloadTask(
      id: 'restored',
      title: 'Restored download',
      url: 'https://example.com/restored',
      formatId: _format.formatId,
      ext: _format.ext,
      status: DownloadStatus.done,
      progress: 1,
      completedAt: DateTime(2026),
    );
    final gateway = _RestoringDownloadGateway([restoredTask]);
    final container = ProviderContainer(
      overrides: [
        downloadGatewayProvider.overrideWithValue(gateway),
        downloadOutputDirectoryProvider.overrideWithValue('/downloads'),
        downloadDispatchLimitProvider.overrideWithValue(1),
      ],
    );
    addTearDown(() {
      container.dispose();
      gateway.dispose();
    });

    container.read(downloadProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(downloadProvider).tasks, [restoredTask]);
    expect(gateway.startedTaskIds, isEmpty);
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
  final List<String> cancelledTaskIds = [];
  final List<StreamController<DownloadTask>> _controllers = [];
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, StreamController<DownloadTask>> _controllersByTask = {};
  final Map<String, Completer<bool>> _cancelCompleters = {};

  @override
  Stream<DownloadTask> download(DownloadTask task, {String? outputDir}) {
    startedTaskIds.add(task.id);
    final controller = StreamController<DownloadTask>();
    _controllers.add(controller);
    _tasks[task.id] = task;
    _controllersByTask[task.id] = controller;
    return controller.stream;
  }

  @override
  Future<ExtractAudioResult> extractAudioNative({
    required String inputPath,
  }) async => const ExtractAudioResult(success: true);

  @override
  Future<bool> cancel(String taskId) {
    cancelledTaskIds.add(taskId);
    final completer = Completer<bool>();
    _cancelCompleters[taskId] = completer;
    return completer.future;
  }

  Future<void> acknowledgeCancel(String taskId) async {
    final task = _tasks[taskId]!;
    final controller = _controllersByTask[taskId]!;
    controller.add(task.copyWith(status: DownloadStatus.cancelled));
    await controller.close();
    _cancelCompleters.remove(taskId)!.complete(true);
  }

  void rejectCancel(String taskId) {
    _cancelCompleters.remove(taskId)!.complete(false);
  }

  Future<void> complete(String taskId) async {
    final task = _tasks[taskId]!;
    final controller = _controllersByTask[taskId]!;
    controller.add(task.copyWith(status: DownloadStatus.done, progress: 1));
    await controller.close();
  }

  void dispose() {
    for (final controller in _controllers) {
      if (!controller.isClosed) controller.close();
    }
  }
}

class _ThrowingDownloadGateway implements DownloadGateway {
  @override
  Future<bool> cancel(String taskId) async => false;

  @override
  Stream<DownloadTask> download(DownloadTask task, {String? outputDir}) {
    throw StateError('start failed');
  }

  @override
  Future<ExtractAudioResult> extractAudioNative({
    required String inputPath,
  }) async => const ExtractAudioResult(success: true);
}

class _RestoringDownloadGateway extends _RecordingDownloadGateway
    implements RestorableDownloadGateway {
  _RestoringDownloadGateway(this.restored);

  final List<DownloadTask> restored;

  @override
  Future<List<DownloadTask>> restoreDownloads() async => restored;
}
