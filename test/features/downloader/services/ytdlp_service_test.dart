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
}

const _task = DownloadTask(
  id: 'task-1',
  title: 'Video one',
  url: 'https://example.com/one',
  formatId: 'audio',
  ext: 'm4a',
);
