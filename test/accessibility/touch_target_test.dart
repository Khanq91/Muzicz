import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muziczz/features/downloader/widgets/primary_icon_button.dart';
import 'package:muziczz/features/music_visual/providers/visual_mode_provider.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/lyrics_provider.dart';
import 'package:muziczz/providers/music_provider.dart';
import 'package:muziczz/providers/player_provider.dart';
import 'package:muziczz/providers/theme_provider.dart';
import 'package:muziczz/screens/now_playing_screen.dart';
import 'package:muziczz/services/audio_handler.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:muziczz/widgets/mini_player.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kMinTapSize = 48.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('mini player controls have at least 48dp touch targets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final handle = tester.ensureSemantics();

    final gateway = _FakePlayerAudioGateway();
    final player = PlayerProvider(gateway);
    addTearDown(() async {
      player.dispose();
      await gateway.dispose();
    });
    await player.playSongs([_songA]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: player),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(AppColorPresets.dark),
          home: const Scaffold(body: MiniPlayer()),
        ),
      ),
    );
    await tester.pump();

    _expectMinTapSize(tester, find.bySemanticsLabel('Bài trước'));
    _expectMinTapSize(tester, find.bySemanticsLabel('Bài tiếp theo'));
    _expectMinTapSize(
      tester,
      find.bySemanticsLabel(RegExp('^(Phát|Tạm dừng)\$')),
    );
    _expectMinTapSize(tester, find.bySemanticsLabel('Đóng trình phát'));
    handle.dispose();
  });

  testWidgets('now playing controls have at least 48dp touch targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();

    final gateway = _FakePlayerAudioGateway();
    final player = PlayerProvider(gateway);
    addTearDown(() async {
      player.dispose();
      await gateway.dispose();
    });
    await player.playSongs([_songA, _songB]);

    await _pumpNowPlaying(tester, player);

    _expectMinTapSize(tester, find.bySemanticsLabel('Phát ngẫu nhiên'));
    _expectMinTapSize(tester, find.bySemanticsLabel('Lặp lại'));
    _expectMinTapSize(tester, find.bySemanticsLabel('Bài trước'));
    _expectMinTapSize(tester, find.bySemanticsLabel('Bài tiếp theo'));
    handle.dispose();
  });

  testWidgets('queue remove control has at least a 48dp touch target', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();

    final gateway = _FakePlayerAudioGateway();
    final player = PlayerProvider(gateway);
    addTearDown(() async {
      player.dispose();
      await gateway.dispose();
    });
    await player.playSongs([_songA, _songB]);

    await _pumpNowPlaying(tester, player);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(
      find.byIcon(Icons.queue_music_rounded),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 600));

    _expectMinTapSize(tester, find.bySemanticsLabel('Xóa khỏi hàng chờ'));
    handle.dispose();
  });

  testWidgets('downloader primary icon button defaults to 48dp', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PrimaryIconButton(
              icon: Icons.folder_open_rounded,
              semanticLabel: 'Chọn thư mục lưu',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(PrimaryIconButton));
    expect(size.width, greaterThanOrEqualTo(_kMinTapSize));
    expect(size.height, greaterThanOrEqualTo(_kMinTapSize));
  });
}

void _expectMinTapSize(WidgetTester tester, Finder finder) {
  final rect = tester.getSemantics(finder).rect;
  expect(
    rect.width,
    greaterThanOrEqualTo(_kMinTapSize),
    reason: 'chiều rộng vùng chạm của $finder phải ≥ $_kMinTapSize',
  );
  expect(
    rect.height,
    greaterThanOrEqualTo(_kMinTapSize),
    reason: 'chiều cao vùng chạm của $finder phải ≥ $_kMinTapSize',
  );
}

Future<void> _pumpNowPlaying(WidgetTester tester, PlayerProvider player) async {
  SharedPreferences.setMockInitialValues({});
  // Diagnostic có sẵn của queue sheet (ListTile trong DecoratedBox) nằm ngoài
  // phạm vi UI-04/UI-05; chỉ lọc đúng thông báo đó, lỗi khác vẫn fail test.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains(
      'ListTile background color or ink splashes may be invisible',
    )) {
      return;
    }
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider<LyricsProvider>(
          create: (_) => _FakeLyricsProvider(),
        ),
        ChangeNotifierProvider(create: (_) => VisualModeProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(AppColorPresets.dark),
        home: const NowPlayingScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

const _songA = SongItem(
  id: 1,
  title: 'Bài hát thứ nhất',
  artist: 'Nghệ sĩ A',
  album: 'Album A',
  albumId: 1,
  artistId: 1,
  data: '/music/1.mp3',
  duration: 180000,
);

const _songB = SongItem(
  id: 2,
  title: 'Bài hát thứ hai',
  artist: 'Nghệ sĩ B',
  album: 'Album B',
  albumId: 2,
  artistId: 2,
  data: '/music/2.mp3',
  duration: 200000,
);

class _FakeLyricsProvider extends LyricsProvider {
  @override
  Future<void> loadLyrics(SongItem song) async {}
}

class _FakePlayerAudioGateway implements PlayerAudioGateway {
  final _playingController = StreamController<bool>.broadcast();
  final _currentIndexController = StreamController<int?>.broadcast();
  final _processingStateController =
      StreamController<ProcessingState>.broadcast();

  Future<void> dispose() async {
    await Future.wait([
      _playingController.close(),
      _currentIndexController.close(),
      _processingStateController.close(),
    ]);
  }

  @override
  Future<void> addSongToQueue(SongItem song) async {}

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Future<void> loadSongs(List<SongItem> songs, {int initialIndex = 0}) async {}

  @override
  Future<void> moveSong(int oldIndex, int newIndex) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<PositionData> get positionDataStream =>
      const Stream<PositionData>.empty();

  @override
  Stream<ProcessingState> get processingStateStream =>
      _processingStateController.stream;

  @override
  Future<void> removeSongAt(int index) async {}

  @override
  Future<void> reorderTo(List<SongItem> newOrder) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> seekToIndex(int index) async {}

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}
}
