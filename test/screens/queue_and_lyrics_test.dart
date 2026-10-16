import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muziczz/core/app_strings.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/lyrics_provider.dart';
import 'package:muziczz/providers/player_provider.dart';
import 'package:muziczz/services/audio_handler.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:muziczz/widgets/now_playing/lyrics_view.dart';
import 'package:muziczz/widgets/now_playing/sheets/queue_sheet.dart';
import 'package:provider/provider.dart';

class _Gateway implements PlayerAudioGateway {
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  @override
  Stream<ProcessingState> get processingStateStream => const Stream.empty();
  @override
  Future<void> loadSongs(List<SongItem> songs, {int initialIndex = 0}) async {}
  @override
  Future<void> setLoopMode(LoopMode mode) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> seekToIndex(int index) async {}
  @override
  Stream<PositionData> get positionDataStream => const Stream.empty();
  @override
  Future<void> removeSongAt(int index) async {}
  @override
  Future<void> insertSongAt(int index, SongItem song) async {}
  @override
  Future<void> moveSong(int oldIndex, int newIndex) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [320.0, 390.0]) {
    testWidgets('queue interactions at width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.reset);
      final player = PlayerProvider(_Gateway());
      addTearDown(player.dispose);
      await player.playSongs(
        List.generate(
          8,
          (i) => SongItem(
            id: i,
            title: 'Track $i',
            artist: 'Artist',
            album: 'Album',
            albumId: i,
            artistId: 1,
            data: '/$i.mp3',
            duration: 180000,
          ),
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: player,
          child: MaterialApp(
            theme: AppTheme.buildTheme(AppColorPresets.light),
            home: QueueSheet(onClose: () {}, useBlur: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next up'), findsOneWidget);
      expect(find.text('All Songs'), findsOneWidget);
      await tester.tap(find.text('Track 2'));
      await tester.pumpAndSettle();
      expect(player.currentQueueIndex, 2);
      await tester.fling(find.text('Track 1'), Offset(-width, 0), 1000);
      await tester.pumpAndSettle();
      expect(player.queue.map((s) => s.id), [0, 2, 3, 4, 5, 6, 7]);
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      expect(player.queue.map((s) => s.id), [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(player.currentSong?.id, 2);
      // Drag the first non-active row below its neighbor.
      final handle = find.byIcon(Icons.drag_indicator_rounded).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 5));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(player.queue.map((s) => s.id).take(3), [1, 2, 0]);
      expect(tester.takeException(), isNull);
    });
  }

  for (final colors in [
    AppColorPresets.light,
    AppColorPresets.dark,
    AppColorPresets.amoled,
  ]) {
    testWidgets(
      'lyrics empty state follows theme ${colors.brightness} ${colors.background}',
      (tester) async {
        final player = PlayerProvider(_Gateway());
        final lyrics = LyricsProvider();
        final scroll = ScrollController();
        addTearDown(player.dispose);
        addTearDown(lyrics.dispose);
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: lyrics,
            child: MaterialApp(
              theme: AppTheme.buildTheme(colors),
              home: Scaffold(
                body: LyricsView(
                  player: player,
                  scrollCtrl: scroll,
                  onScrollToLine: (_) {},
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.text(AppStrings.lyricsNone));
        expect(text.style?.color, colors.textTertiary);
        final card = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == colors.surfaceElevated,
        );
        expect(card, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
