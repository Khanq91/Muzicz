import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
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
import 'package:muziczz/widgets/app_bottom_navigation.dart';
import 'package:muziczz/widgets/mini_player.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muziczz/core/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('mini player controls expose labeled button semantics', (
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

    expect(find.bySemanticsLabel('Bài trước'), findsOneWidget);
    expect(find.bySemanticsLabel('Bài tiếp theo'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^(Phát|Tạm dừng)\$')), findsOneWidget);
    expect(find.bySemanticsLabel('Đóng trình phát'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Bài trước')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Đóng trình phát')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('normal bottom navigation announces every tab and selection', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(AppColorPresets.dark),
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: 1,
            onTap: (_) {},
            style: BottomNavStyle.normal,
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel(AppStrings.tabHome)),
      isSemantics(isButton: true, hasTapAction: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(AppStrings.settings)),
      isSemantics(isButton: true, hasTapAction: true, isSelected: false),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Thư viện')),
      isSemantics(isButton: true, hasTapAction: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('now playing controls expose labels and toggle states', (
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

    expect(
      tester.getSemantics(find.bySemanticsLabel('Phát ngẫu nhiên')),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        hasToggledState: true,
        isToggled: false,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Lặp lại')),
      isSemantics(isButton: true, hasTapAction: true, hasToggledState: true),
    );
    expect(find.bySemanticsLabel('Bài trước'), findsOneWidget);
    expect(find.bySemanticsLabel('Bài tiếp theo'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^(Phát|Tạm dừng)\$')), findsOneWidget);
    expect(
      tester.getSemantics(find.byTooltip('Yêu thích')),
      isSemantics(hasTapAction: true, hasToggledState: true, isToggled: false),
    );
    expect(find.byTooltip(AppStrings.songOptions), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'album swipe commits only after settling; rapid skips stay in sync',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final gateway = _FakePlayerAudioGateway();
      final player = PlayerProvider(gateway);
      addTearDown(() async {
        player.dispose();
        await gateway.dispose();
      });
      final songs = List.generate(
        5,
        (i) => SongItem(
          id: i + 10,
          title: 'Song $i',
          artist: 'Artist',
          album: 'Album',
          albumId: i,
          artistId: 1,
          data: '/$i.mp3',
          duration: 180000,
        ),
      );
      await player.playSongs(songs);
      await _pumpNowPlaying(tester, player);
      final carousel = find.byKey(const ValueKey('album-carousel'));
      final start = tester.getCenter(carousel);
      final drag = await tester.startGesture(start);
      await drag.moveBy(const Offset(-20, 0));
      await drag.moveBy(const Offset(-65, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(player.currentQueueIndex, 0);
      await drag.up();
      await tester.pumpAndSettle();
      expect(player.currentQueueIndex, 0);
      await tester.drag(carousel, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(player.currentQueueIndex, 1);
      final next = find.byKey(const ValueKey('transport-2'));
      final previous = find.byKey(const ValueKey('transport-0'));
      final width = tester.getSize(next).width;
      await tester.tap(next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(next).width, greaterThan(width));
      expect(tester.getSize(previous).width, lessThan(width));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(player.currentQueueIndex, 3);
      expect(
        tester.widget<PageView>(carousel).controller!.page,
        closeTo(3, .01),
      );
      expect(tester.getSize(next).width, closeTo(width, .2));
      await tester.drag(carousel, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(player.currentQueueIndex, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('queue sheet rows expose a labeled remove control', (
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

    final queueButton = find.byTooltip(AppStrings.queue).hitTestable();
    expect(queueButton, findsOneWidget);
    await tester.tap(queueButton);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.byTooltip(AppStrings.collapseQueue).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Tùy chọn bài hát').last);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Xóa khỏi hàng chờ').hitTestable(),
      findsOneWidget,
    );

    handle.dispose();
  });

  testWidgets('player opening drag can cancel, commit and close continuously', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final gateway = _FakePlayerAudioGateway();
    final player = PlayerProvider(gateway);
    addTearDown(() async {
      player.dispose();
      await gateway.dispose();
    });
    await player.playSongs([_songA, _songB]);
    await _pumpNowPlaying(tester, player, mini: true);
    final start = tester.getCenter(find.byType(MiniPlayer));
    final cancel = await tester.startGesture(start);
    await cancel.moveBy(const Offset(0, -20));
    await cancel.moveBy(const Offset(0, -70));
    await tester.pump();
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await cancel.up();
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingScreen), findsNothing);
    final open = await tester.startGesture(start);
    await open.moveBy(const Offset(0, -20));
    await open.moveBy(const Offset(0, -260));
    await tester.pump();
    final intermediateTop = tester.getTopLeft(find.byType(NowPlayingScreen)).dy;
    expect(intermediateTop, greaterThan(0));
    expect(intermediateTop, lessThan(start.dy));
    await open.up();
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(NowPlayingScreen)).dy,
      closeTo(0, 0.01),
    );
    final close = await tester.startGesture(const Offset(195, 160));
    await close.moveBy(const Offset(0, 20));
    await close.moveBy(const Offset(0, 350));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(NowPlayingScreen)).dy, greaterThan(0));
    await close.up();
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpNowPlaying(
  WidgetTester tester,
  PlayerProvider player, {
  bool mini = false,
}) async {
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(AppColorPresets.dark),
        home:
            mini
                ? Scaffold(
                  bottomNavigationBar: AppBottomNavigation(
                    currentIndex: 1,
                    onTap: (_) {},
                    style: BottomNavStyle.normal,
                    miniPlayer: const MiniPlayer(embeddedInDock: true),
                  ),
                )
                : const NowPlayingScreen(),
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
  Future<void> insertSongAt(int index, SongItem song) async {}

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
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}
}
