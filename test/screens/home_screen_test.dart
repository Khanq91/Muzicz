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
import 'package:muziczz/services/audio_handler.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muziczz/core/app_strings.dart';

import 'package:muziczz/screens/home_screen.dart';
import 'package:muziczz/widgets/home_song_sections.dart';
import 'package:muziczz/widgets/app_bottom_navigation.dart';
import 'package:muziczz/screens/profile_screen.dart';

import 'package:muziczz/screens/playlist_screen.dart';

void main() {
  testWidgets('Home opens favorites without starting playback', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    // The existing Settings tab builds offstage and emits this SDK diagnostic.
    // Keep the same narrow filter as the existing accessibility fixtures.
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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final gateway = _FakePlayerAudioGateway();
    final player = PlayerProvider(gateway);
    addTearDown(() async {
      player.dispose();
      await gateway.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MusicProvider>(create: (_) => _PreviewMusic()),
          ChangeNotifierProvider.value(value: player),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => VisualModeProvider()),
          ChangeNotifierProvider<LyricsProvider>(
            create: (_) => _FakeLyricsProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(AppColorPresets.dark),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.appName), findsNWidgets(2));
    expect(find.text('Your Songs'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined).hitTestable());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
          .currentIndex,
      2,
    );
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(ProfileScreen))).canPop(),
      isFalse,
    );
    await tester.tap(find.byIcon(Icons.library_music_rounded).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined).hitTestable());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
          .currentIndex,
      2,
    );
    expect(
      Navigator.of(tester.element(find.byType(ProfileScreen))).canPop(),
      isFalse,
    );
    // Interrupt a transition and return Home without losing its scroll state.
    await tester.tap(find.byIcon(Icons.library_music_rounded).hitTestable());
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byIcon(Icons.home_rounded).hitTestable());
    await tester.pumpAndSettle();
    final section = find.byType(HomeSongSection);
    expect(section.hitTestable(), findsNothing);
    expect(
      tester.getBottomLeft(find.byType(HomeSongCollage)).dy,
      greaterThanOrEqualTo(844),
    );
    await tester.drag(
      find.byKey(const PageStorageKey('home-scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(section.first).dy, lessThan(844));
    await tester.drag(
      find.byKey(const PageStorageKey('home-scroll')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    expect(
      find.byTooltip(AppStrings.shufflePlay).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(AppStrings.favorites).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistDetailScreen), findsOneWidget);
    expect(player.currentSong, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _PreviewMusic extends MusicProvider {
  final songs = List.generate(
    8,
    (i) => SongItem(
      id: i,
      title:
          [
            'Midnight City',
            'After Hours',
            'Blue Hour',
            'Golden',
            'Home Again',
            'Slow Motion',
            'Daylight',
            'Bloom',
          ][i],
      artist: 'Muzicz Sessions',
      album: 'Evening collection',
      albumId: i,
      artistId: 1,
      data: '/music/$i.mp3',
      duration: 180000,
    ),
  );
  @override
  List<SongItem> get allSongs => songs;
  @override
  List<SongItem> get filteredSongs => songs;
  @override
  List<SongItem> get recentlyAdded => songs;
  @override
  List<SongItem> get recentlyPlayed => songs;
  @override
  List<SongItem> get favorites => songs.take(2).toList();
  @override
  List<SongItem> homeSongsSortedBy(LibrarySongSort sort) => songs;
  @override
  LibraryStatus get status => LibraryStatus.done;
  @override
  bool get hasScannedOnce => true;
}

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
