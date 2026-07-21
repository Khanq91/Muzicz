import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/features/downloader/core/constants/app_constants.dart';

void main() {
  test('Android manifest declares a data-sync foreground download service', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'),
    );
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android:name=".DownloadForegroundService"'));
    expect(manifest, contains('android:foregroundServiceType="dataSync"'));
    expect(manifest, contains('android.permission.READ_MEDIA_AUDIO'));
    expect(manifest, isNot(contains('android.permission.READ_MEDIA_VIDEO')));
    expect(manifest, isNot(contains('android.permission.READ_MEDIA_IMAGES')));
  });

  test('foreground service owns queue persistence and notification counts', () {
    final service =
        File(
          'android/app/src/main/kotlin/com/muziczz/muziczz/DownloadForegroundService.kt',
        ).readAsStringSync();
    final activity =
        File(
          'android/app/src/main/kotlin/com/muziczz/muziczz/MainActivity.kt',
        ).readAsStringSync();

    expect(service, contains('class DownloadForegroundService : Service()'));
    expect(service, contains('START_STICKY'));
    expect(service, contains('MAX_CONCURRENT_DOWNLOADS = 2'));
    expect(service, contains('synchronized(queueLock)'));
    expect(AppConstants.maxConcurrentDownloads, 2);
    expect(service, contains('MAX_TRANSIENT_RETRIES = 2'));
    expect(service, contains('STATUS_WAITING_TO_RETRY'));
    expect(service, contains('while (!isNetworkAvailable())'));
    expect(service, contains('persistRecordsLocked'));
    expect(service, contains(r'Đang tải ${counts.active}'));
    expect(service, contains('AudioExtractor.extractToM4a'));
    expect(activity, contains('"enqueueDownload"'));
    expect(activity, isNot(contains('activeDownloadJobs')));

    final bridge =
        File('android/app/src/main/python/ytdlp_bridge.py').readAsStringSync();
    expect(bridge, contains('%(title)s [%(id)s].%(ext)s'));
  });

  test('audio scanner does not request visual media or expose WebM', () {
    final activity =
        File(
          'android/app/src/main/kotlin/com/muziczz/muziczz/MainActivity.kt',
        ).readAsStringSync();
    final scanner = File('lib/services/music_scanner.dart').readAsStringSync();
    final permissionController =
        File(
          'packages/on_audio_query_android-1.1.0/android/src/main/kotlin/com/lucasjosino/on_audio_query/controllers/PermissionController.kt',
        ).readAsStringSync();

    expect(scanner, isNot(contains('Permission.videos')));
    expect(scanner, contains("if (ext == 'webm') return false"));
    expect(
      permissionController,
      contains('Manifest.permission.READ_MEDIA_AUDIO'),
    );
    expect(permissionController, isNot(contains('READ_MEDIA_IMAGES')));
    expect(permissionController, isNot(contains('READ_MEDIA_VIDEO')));
    expect(activity, isNot(contains('scanWebmAudio')));
  });
}
