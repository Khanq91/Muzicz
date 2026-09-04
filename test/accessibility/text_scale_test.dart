import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/lyrics_provider.dart';
import 'package:muziczz/providers/music_provider.dart';
import 'package:muziczz/providers/player_provider.dart';
import 'package:muziczz/screens/now_playing_screen.dart';
import 'package:muziczz/services/audio_handler.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  final textScaleVariants = ValueVariant<double>({1.0, 1.3, 2.0});

  test('app root does not clamp the system text scaler', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, isNot(contains('maxScaleFactor')));
    expect(source, isNot(contains('textScaler:')));
  });

  testWidgets('Now Playing has no layout overflow at 320x568', (tester) async {
    final textScale = textScaleVariants.currentValue!;
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final flutterErrors = <Object>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      flutterErrors.add(details.exception);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);

    final gateway = _FakePlayerAudioGateway();
    final player = PlayerProvider(gateway);
    addTearDown(() async {
      player.dispose();
      await gateway.dispose();
    });
    await player.playSongs([_song]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MusicProvider()),
          ChangeNotifierProvider.value(value: player),
          ChangeNotifierProvider<LyricsProvider>(
            create: (_) => _FakeLyricsProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(AppColorPresets.dark),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: const NowPlayingScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(
      flutterErrors.where(
        (error) => error.toString().contains('overflowed by'),
      ),
      isEmpty,
    );
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(NowPlayingScreen)),
      ).scale(16),
      16 * textScale,
    );
  }, variant: textScaleVariants);
}

const _song = SongItem(
  id: 1,
  title: 'Một bài hát có tiêu đề dài để kiểm tra bố cục',
  artist: 'Nghệ sĩ thử nghiệm',
  album: 'Album thử nghiệm',
  albumId: 1,
  artistId: 1,
  data: '/music/1.mp3',
  duration: 180000,
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
