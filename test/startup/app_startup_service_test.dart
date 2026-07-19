import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/providers/music_provider.dart';
import 'package:muziczz/services/app_startup_service.dart';

void main() {
  test(
    'first run waits for init and minimum splash without scanning',
    () async {
      final init = Completer<void>();
      final minimumSplash = Completer<void>();
      final provider = _FakeMusicProvider(isFirstRun: true, init: init);
      final service = AppStartupService(delay: (_) => minimumSplash.future);

      final result = service.initialize(provider);

      expect(provider.initCalls, 1);
      expect(provider.scanCalls, 0);

      init.complete();
      await Future<void>.delayed(Duration.zero);
      expect(provider.scanCalls, 0);

      minimumSplash.complete();
      expect(await result, AppStartupDestination.welcome);
    },
  );

  test('returning user scans in background after init', () async {
    final init = Completer<void>();
    final scan = Completer<void>();
    final minimumSplash = Completer<void>();
    final provider = _FakeMusicProvider(
      isFirstRun: false,
      init: init,
      scan: scan,
    );
    final service = AppStartupService(delay: (_) => minimumSplash.future);

    final result = service.initialize(provider);

    expect(provider.initCalls, 1);
    expect(provider.scanCalls, 0);

    init.complete();
    await Future<void>.delayed(Duration.zero);
    expect(provider.scanCalls, 1);

    minimumSplash.complete();
    expect(await result, AppStartupDestination.home);
    expect(scan.isCompleted, isFalse);

    scan.complete();
  });

  test(
    'slow init remains the only startup blocker after the minimum',
    () async {
      final init = Completer<void>();
      final scan = Completer<void>();
      final minimumSplash = Completer<void>()..complete();
      final provider = _FakeMusicProvider(
        isFirstRun: false,
        init: init,
        scan: scan,
      );
      final service = AppStartupService(delay: (_) => minimumSplash.future);
      var completed = false;

      final result = service.initialize(provider)
        ..then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      init.complete();
      expect(await result, AppStartupDestination.home);
      expect(provider.scanCalls, 1);
      expect(scan.isCompleted, isFalse);

      scan.complete();
    },
  );
}

class _FakeMusicProvider extends MusicProvider {
  _FakeMusicProvider({
    required bool isFirstRun,
    required Completer<void> init,
    Completer<void>? scan,
  }) : _isFirstRun = isFirstRun,
       _init = init,
       _scan = scan ?? (Completer<void>()..complete());

  final bool _isFirstRun;
  final Completer<void> _init;
  final Completer<void> _scan;

  int initCalls = 0;
  int scanCalls = 0;

  @override
  bool get isFirstRun => _isFirstRun;

  @override
  Future<void> init() {
    initCalls += 1;
    return _init.future;
  }

  @override
  Future<void> scanMusic() {
    scanCalls += 1;
    return _scan.future;
  }
}
