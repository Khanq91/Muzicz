import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The fixture supplies local SDK fonts so screenshots and tests need no network.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:just_audio/just_audio.dart';
import 'package:muziczz/core/app_strings.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/music_provider.dart';
import 'package:muziczz/providers/player_provider.dart';
import 'package:muziczz/screens/library_screen.dart';
import 'package:muziczz/screens/artist_detail_screen.dart';
import 'package:muziczz/screens/playlist_screen.dart';
import 'package:muziczz/services/audio_handler.dart';
import 'package:muziczz/services/music_scanner.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:muziczz/widgets/library/library_chrome.dart';
import 'package:muziczz/widgets/library/library_preferences.dart';
import 'package:muziczz/widgets/library/selection_header.dart';
import 'package:muziczz/widgets/music_list_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _screen = GlobalKey<LibraryScreenState>();
final _preview = GlobalKey();

class _FontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'Light'])
      'Outfit-$weight.ttf',
  ];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

class _Scanner extends MusicScanner {
  int scans = 0;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<List<SongItem>> scanSongs({bool ensurePermission = true}) async {
    scans++;
    return List.generate(
      40,
      (i) => SongItem(
        id: i,
        title: 'Track ${i.toString().padLeft(2, '0')}',
        artist: 'Artist ${i % 3}',
        album: 'Album',
        albumId: 0,
        artistId: 0,
        data: '/Music/${i < 20 ? 'Chill' : 'Live'}/track$i.mp3',
        duration: (i + 1) * 60000,
        dateAdded: DateTime(2026, 1, i + 1),
      ),
    );
  }
}

class _Audio implements PlayerAudioGateway {
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  @override
  Stream<ProcessingState> get processingStateStream => const Stream.empty();
  @override
  Stream<PositionData> get positionDataStream => const Stream.empty();
  @override
  Future<void> loadSongs(List<SongItem> songs, {int initialIndex = 0}) async {}
  @override
  Future<void> setLoopMode(LoopMode mode) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> insertSongAt(int index, SongItem song) async {}
  @override
  Future<void> addSongToQueue(SongItem song) async {}
  @override
  Future<void> moveSong(int oldIndex, int newIndex) async {}
  @override
  Future<void> removeSongAt(int index) async {}
  @override
  Future<void> reorderTo(List<SongItem> newOrder) async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> seekToIndex(int index) async {}
  @override
  Future<void> setSpeed(double speed) async {}
}

Future<(MusicProvider, PlayerProvider, _Scanner)> mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  AppColorsData colors = AppColorPresets.dark,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final scanner = _Scanner();
  final music = MusicProvider(scanner: scanner);
  await music.init();
  await music.scanMusic();
  final player = PlayerProvider(_Audio());
  addTearDown(() {
    music.dispose();
    player.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: music),
        ChangeNotifierProvider.value(value: player),
      ],
      child: RepaintBoundary(
        key: _preview,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.buildTheme(colors),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: LibraryScreen(key: _screen),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (music, player, scanner);
}

Future<void> preview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('LIBRARY_PREVIEW')) return;
  await tester.pumpAndSettle();
  final boundary =
      _preview.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/library_previews').create(recursive: true);
    await File(
      'build/library_previews/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    font_test.assetManifest = _FontManifest();
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    await (FontLoader('MaterialIcons')..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    )).load();
    final bytes =
        File(
          '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        ).readAsBytesSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = const StringCodec().decodeMessage(message);
          if (key?.startsWith('Outfit-') ?? false) {
            return ByteData.sublistView(bytes);
          }
          return null;
        });
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('four-tab picker, swipe navigation and per-tab sort', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip(AppStrings.libraryChooseSection));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(LibraryTabSheet), findsOneWidget);
    expect(
      tester
          .widget<GridView>(find.byType(GridView))
          .childrenDelegate
          .estimatedChildCount,
      4,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(GridView),
        matching: find.text(AppStrings.songs),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MusicListTile).first, findsOneWidget);
    await preview(tester, 'songs-dark');
    await tester.tap(find.byTooltip(AppStrings.sort).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.duration));
    await tester.tap(find.text(AppStrings.libraryAscending));
    Navigator.of(tester.element(find.byType(LibrarySortSheet))).pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<MusicListTile>(find.byType(MusicListTile).first).song.id,
      39,
    );
    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LibraryPill>(find.byType(LibraryPill)).section,
      LibrarySection.artists,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home semantic indices survive saved display order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'library_tab_order': ['folders', 'artists', 'songs', 'playlists'],
    });
    await mount(tester);
    _screen.currentState!.showTab(1);
    await tester.pumpAndSettle();
    expect(
      tester.widget<LibraryPill>(find.byType(LibraryPill)).section,
      LibrarySection.songs,
    );
    expect(find.text('Track 00'), findsOneWidget);
    _screen.currentState!.showTab(0);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.favorites), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bulk favorite, locate through search, and pull to refresh', (
    tester,
  ) async {
    final (music, player, scanner) = await mount(tester);
    _screen.currentState!.showTab(1);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Track 00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.selectAll));
    await tester.tap(find.text(AppStrings.libraryActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.favorites));
    await tester.pumpAndSettle();
    expect(music.favorites.length, 40);
    expect(find.byType(SelectionHeader), findsNothing);
    await player.playSongs(music.allSongs, specificSong: music.allSongs.last);
    _screen.currentState!.showTab(1, searchQuery: 'Track 00');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.libraryLocate).hitTestable());
    await tester.pumpAndSettle();
    expect(music.librarySearchQuery, isEmpty);
    expect(find.text('Track 39').hitTestable(), findsOneWidget);
    // Reset to the top before pulling down.
    final scroll =
        tester
            .widget<CustomScrollView>(
              find.byType(CustomScrollView).hitTestable().first,
            )
            .controller!;
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).hitTestable().first,
      const Offset(0, 450),
    );
    await tester.pumpAndSettle();
    expect(scanner.scans, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folders navigate without playback and Back goes to parent', (
    tester,
  ) async {
    final (_, player, _) = await mount(tester);
    _screen.currentState!.showTab(3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Music').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chill').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Track 00'), findsOneWidget);
    expect(player.currentSong, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Chill').hitTestable(), findsOneWidget);
    expect(find.text('Track 00'), findsNothing);
    await preview(tester, 'folders-dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow layout and large text stay usable in light theme', (
    tester,
  ) async {
    await mount(
      tester,
      size: const Size(320, 740),
      textScale: 1.5,
      colors: AppColorPresets.light,
    );
    _screen.currentState!.showTab(1);
    await tester.pumpAndSettle();
    await preview(tester, 'songs-light-large-text');
    await tester.tap(find.byTooltip(AppStrings.libraryChooseSection));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryTabSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reordering keeps the selected tab and saves the new order', (
    tester,
  ) async {
    await mount(tester);
    _screen.currentState!.showTab(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.libraryChooseSection));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.libraryReorder));
    await tester.pumpAndSettle();
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(1, 3);
    await tester.pumpAndSettle();
    expect(
      tester.widget<LibraryPill>(find.byType(LibraryPill)).section,
      LibrarySection.songs,
    );
    await tester.tap(find.byTooltip(AppStrings.libraryDone));
    await tester.pumpAndSettle();
    expect(find.text('Track 00'), findsOneWidget);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getStringList('library_tab_order')!.last, 'songs');
    expect(tester.takeException(), isNull);
  });

  testWidgets('locate crosses folders hidden by the active search', (
    tester,
  ) async {
    final (music, player, _) = await mount(tester);
    await player.playSongs(music.allSongs, specificSong: music.allSongs.last);
    _screen.currentState!.showTab(3, searchQuery: 'Track 00');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.libraryLocate).hitTestable());
    await tester.pumpAndSettle();
    expect(music.librarySearchQuery, isEmpty);
    expect(find.text('Track 39').hitTestable(), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('artist album sections collapse and favorites opens its detail', (
    tester,
  ) async {
    final (music, _, _) = await mount(tester);
    _screen.currentState!.showTab(2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artist 0').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(ArtistDetailScreen), findsOneWidget);
    await preview(tester, 'artist-dark');
    await tester.tap(find.text('Album').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(MusicListTile), findsNothing);
    await tester.tap(find.text('Album').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(MusicListTile), findsWidgets);
    Navigator.of(tester.element(find.byType(ArtistDetailScreen))).pop();
    await tester.pumpAndSettle();
    await music.bulkFavoriteToggle([0, 1]);
    _screen.currentState!.showTab(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.favorites).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistDetailScreen), findsOneWidget);
    expect(find.byType(MusicListTile), findsNWidgets(2));
    await preview(tester, 'favorites-dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('song menu queues a track and Shuffle starts the library queue', (
    tester,
  ) async {
    final (_, player, _) = await mount(tester);
    _screen.currentState!.showTab(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.songOptions).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.addToQueue));
    await tester.pumpAndSettle();
    expect(player.currentSong!.id, 0);
    await tester.tap(find.text(AppStrings.shuffle));
    await tester.pumpAndSettle();
    expect(player.queue.length, 40);
    expect(tester.takeException(), isNull);
  });
}
