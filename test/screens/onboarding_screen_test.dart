import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/music_provider.dart';
import 'package:muziczz/screens/onboarding_screen.dart';
import 'package:muziczz/services/music_scanner.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  testWidgets('permission denial is not presented as a successful scan', (
    tester,
  ) async {
    final scanner = _OnboardingScanner(permissionGranted: false);
    final provider = MusicProvider(scanner: scanner);
    await provider.init();

    await tester.pumpWidget(_testApp(provider));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(provider.status, LibraryStatus.permissionDenied);
    expect(find.text('Cần quyền truy cập nhạc'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Mở cài đặt'), findsNothing);
    expect(find.byKey(const ValueKey('scan-result')), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('permanent permission denial offers an app settings action', (
    tester,
  ) async {
    final scanner = _OnboardingScanner(
      permissionGranted: false,
      permanentlyDenied: true,
    );
    final provider = MusicProvider(scanner: scanner);
    await provider.init();

    await tester.pumpWidget(_testApp(provider));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(provider.permissionPermanentlyDenied, isTrue);
    expect(find.text('Mở cài đặt'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('scanner failure shows a retry state and stays on onboarding', (
    tester,
  ) async {
    final scanner = _OnboardingScanner(scanError: Exception('query failed'));
    final provider = MusicProvider(scanner: scanner);
    await provider.init();

    await tester.pumpWidget(_testApp(provider));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(provider.status, LibraryStatus.error);
    expect(find.text('Không thể quét thư viện'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-result')), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('successful scan alone shows library counts', (tester) async {
    final scanner = _OnboardingScanner(songs: const [_song]);
    final provider = MusicProvider(scanner: scanner);
    await provider.init();

    await tester.pumpWidget(_testApp(provider));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(provider.status, LibraryStatus.done);
    expect(find.byKey(const ValueKey('scan-result')), findsOneWidget);
    expect(find.text('1 bài hát'), findsOneWidget);
    expect(find.text('1 nghệ sĩ'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rescan keeps scanning copy visible while status was done', (
    tester,
  ) async {
    final scanner = _OnboardingScanner(songs: const [_song]);
    final provider = MusicProvider(scanner: scanner);
    await provider.init();
    await provider.scanMusic();

    await tester.pumpWidget(_testApp(provider));
    await tester.pump();

    expect(find.byKey(const ValueKey('scanning')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-result')), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _testApp(MusicProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.buildTheme(AppColorPresets.dark),
      home: const OnboardingScreen(),
    ),
  );
}

const _song = SongItem(
  id: 1,
  title: 'Song',
  artist: 'Artist',
  album: 'Album',
  albumId: 1,
  artistId: 1,
  data: '/music/song.mp3',
  duration: 60000,
);

class _OnboardingScanner extends MusicScanner {
  _OnboardingScanner({
    this.permissionGranted = true,
    this.songs = const [],
    this.scanError,
    this.permanentlyDenied = false,
  });

  final bool permissionGranted;
  final List<SongItem> songs;
  final Object? scanError;
  final bool permanentlyDenied;

  @override
  bool get permissionPermanentlyDenied => permanentlyDenied;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<List<SongItem>> scanSongs({
    ScanProgressCallback? onProgress,
    bool ensurePermission = true,
  }) async {
    final error = scanError;
    if (error != null) throw error;
    onProgress?.call(songs.length);
    return songs;
  }
}
