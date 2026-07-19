import 'dart:async';

import '../providers/music_provider.dart';

enum AppStartupDestination { welcome, home }

typedef StartupDelay = Future<void> Function(Duration duration);

Future<void> _defaultStartupDelay(Duration duration) =>
    Future<void>.delayed(duration);

class AppStartupService {
  const AppStartupService({
    this.minimumSplashDuration = const Duration(milliseconds: 1300),
    this.delay = _defaultStartupDelay,
  });

  final Duration minimumSplashDuration;
  final StartupDelay delay;

  Future<AppStartupDestination> initialize(MusicProvider musicProvider) async {
    final minimumSplash = delay(minimumSplashDuration);

    await musicProvider.init();

    if (musicProvider.isFirstRun) {
      await minimumSplash;
      return AppStartupDestination.welcome;
    }

    unawaited(musicProvider.scanMusic());
    await minimumSplash;
    return AppStartupDestination.home;
  }
}
