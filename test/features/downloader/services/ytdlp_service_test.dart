import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/features/downloader/models/download_task.dart';
import 'package:muziczz/features/downloader/services/ytdlp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ytdlp_channel');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('download sends task id and maps native cancellation', () async {
    MethodCall? downloadCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'download') {
            downloadCall = call;
            return json.encode({'success': false, 'cancelled': true});
          }
          if (call.method == 'getProgress') {
            return json.encode({'status': 'idle'});
          }
          return null;
        });

    final events =
        await YtdlpService.instance
            .download(_task, outputDir: '/downloads')
            .toList();

    expect(downloadCall?.arguments, containsPair('taskId', _task.id));
    expect(events.last.status, DownloadStatus.cancelled);
  });

  test('cancel requires both accepted and stopped acknowledgement', () async {
    var stopped = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancelDownload') {
            return json.encode({'accepted': true, 'stopped': stopped});
          }
          return null;
        });

    expect(await YtdlpService.instance.cancel(_task.id), isFalse);

    stopped = true;
    expect(await YtdlpService.instance.cancel(_task.id), isTrue);
  });

  test('concurrent streams receive progress for their own task ids', () async {
    final downloadResults = {
      _task.id: Completer<String>(),
      _secondTask.id: Completer<String>(),
    };
    final progressTaskIds = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map<Object?, Object?>?;
          final taskId = arguments?['taskId'] as String?;
          if (call.method == 'download') return downloadResults[taskId]!.future;
          if (call.method == 'getProgress') {
            progressTaskIds.add(taskId!);
            return json.encode({
              'status': 'downloading',
              'percent': taskId == _task.id ? 25 : 75,
              'speed': '1 MB/s',
              'eta': '3s',
            });
          }
          return null;
        });

    final firstEventsFuture =
        YtdlpService.instance.download(_task, outputDir: '/downloads').toList();
    final secondEventsFuture =
        YtdlpService.instance
            .download(_secondTask, outputDir: '/downloads')
            .toList();

    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(progressTaskIds, containsAll({_task.id, _secondTask.id}));

    for (final entry in downloadResults.entries) {
      entry.value.complete(
        json.encode({'success': true, 'path': '/${entry.key}'}),
      );
    }
    final firstEvents = await firstEventsFuture;
    final secondEvents = await secondEventsFuture;
    expect(
      firstEvents,
      contains(
        predicate<DownloadTask>((task) {
          return task.id == _task.id && task.progress == 0.25;
        }),
      ),
    );
    expect(
      secondEvents,
      contains(
        predicate<DownloadTask>((task) {
          return task.id == _secondTask.id && task.progress == 0.75;
        }),
      ),
    );
  });
}

const _task = DownloadTask(
  id: 'task-1',
  title: 'Video one',
  url: 'https://example.com/one',
  formatId: 'audio',
  ext: 'm4a',
);

const _secondTask = DownloadTask(
  id: 'task-2',
  title: 'Video two',
  url: 'https://example.com/two',
  formatId: 'audio',
  ext: 'm4a',
);
