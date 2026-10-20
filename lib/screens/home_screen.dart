import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_strings.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors_data.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/main_tab_transition.dart';
import '../widgets/mini_player.dart';
import '../widgets/home_song_sections.dart';
import '../widgets/library/library_empty_state.dart';
import 'library_screen.dart';
import 'playlist_screen.dart';
import 'profile_screen.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;
  final _libraryScreenKey = GlobalKey<LibraryScreenState>();

  late final _tabs = [
    _HomeTabBody(
      onSettings: () => _selectTab(2),
      onShowAllPlaylists: () => _showLibraryTab(0),
      onShowAllSongs: (query) => _showLibraryTab(1, searchQuery: query),
    ),
    const ProfileScreen(embeddedInHome: true),
  ];

  void _selectTab(int index) {
    if (_currentIndex != index) setState(() => _currentIndex = index);
  }

  void _showLibraryTab(int tabIndex, {String searchQuery = ''}) {
    _libraryScreenKey.currentState?.showTab(tabIndex, searchQuery: searchQuery);
    _selectTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottomNavStyle = context.watch<ThemeProvider>().bottomNavStyle;
    return Scaffold(
      backgroundColor: c.background,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: MainTabTransition(
              index: _currentIndex,
              children: [
                LibraryScreen(
                  key: _libraryScreenKey,
                  active: _currentIndex == 0,
                  onSettings: () => _selectTab(2),
                ),
                ..._tabs,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Selector<PlayerProvider, bool>(
        selector: (_, player) => player.currentSong != null,
        builder:
            (_, hasSong, __) => AppBottomNavigation(
              currentIndex: _currentIndex,
              onTap: _selectTab,
              style: bottomNavStyle,
              miniPlayer:
                  hasSong ? const MiniPlayer(embeddedInDock: true) : null,
            ),
      ),
    );
  }
}

class _HomeTabBody extends StatelessWidget {
  const _HomeTabBody({
    required this.onShowAllPlaylists,
    required this.onShowAllSongs,
    required this.onSettings,
  });
  final VoidCallback onShowAllPlaylists;
  final ValueChanged<String> onShowAllSongs;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final songs = context.select<MusicProvider, List<SongItem>>(
      (m) => m.allSongs,
    );
    final status = context.select<MusicProvider, LibraryStatus>(
      (m) => m.status,
    );
    final hasSong = context.select<PlayerProvider, bool>(
      (p) => p.currentSong != null,
    );
    final c = context.appColors;
    return LayoutBuilder(
      builder:
          (context, viewport) => RefreshIndicator(
            onRefresh: context.read<MusicProvider>().scanMusic,
            child: CustomScrollView(
              key: const PageStorageKey('home-scroll'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: c.background,
                  surfaceTintColor: c.primary,
                  automaticallyImplyLeading: false,
                  title: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceElevated,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Text(
                      AppStrings.appName,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  actions: [
                    IconButton.filledTonal(
                      tooltip: AppStrings.searchHint,
                      style: IconButton.styleFrom(
                        backgroundColor: c.surfaceElevated,
                      ),
                      onPressed: () => onShowAllSongs(''),
                      icon: const Icon(Icons.search_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: AppStrings.playlist,
                      style: IconButton.styleFrom(
                        backgroundColor: c.surfaceElevated,
                      ),
                      onPressed: onShowAllPlaylists,
                      icon: const Icon(Icons.library_music_outlined),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: AppStrings.settings,
                      style: IconButton.styleFrom(
                        backgroundColor: c.surfaceElevated,
                      ),
                      onPressed: onSettings,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: (viewport.maxHeight -
                            MediaQuery.paddingOf(context).top -
                            kToolbarHeight)
                        .clamp(580.0, double.infinity),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 68, 24, 36),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 330;
                              final title = Text(
                                AppStrings.appName,
                                style: TextStyle(
                                  fontSize: narrow ? 48 : 60,
                                  height: .94,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -3.5,
                                  color: c.textPrimary,
                                ),
                              );
                              final actions = Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HomeActionButton(
                                    label: AppStrings.favorites,
                                    icon: Icons.favorite_border_rounded,
                                    size: 52,
                                    color: c.surfaceElevated,
                                    onTap:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (
                                                  _,
                                                ) => const PlaylistDetailScreen(
                                                  playlistId:
                                                      MusicProvider
                                                          .favoritesPlaylistId,
                                                ),
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  HomeActionButton(
                                    label: AppStrings.shufflePlay,
                                    icon: Icons.shuffle_rounded,
                                    size: narrow ? 74 : 88,
                                    color: c.tertiary.withValues(alpha: .25),
                                    onTap:
                                        songs.isEmpty
                                            ? null
                                            : () => context
                                                .read<PlayerProvider>()
                                                .playSongsShuffled(songs),
                                  ),
                                ],
                              );
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(child: title),
                                      const SizedBox(width: 12),
                                      actions,
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Your Songs',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppStrings.songCount(songs.length),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: HomeSongCollage(
                            songs: songs,
                            onSongTap:
                                (song) => context
                                    .read<PlayerProvider>()
                                    .playSongs(songs, specificSong: song),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: HomeSongSection(
                      title: AppStrings.yourSongs.toUpperCase(),
                      subtitle: AppStrings.songCount(songs.length),
                      songs: songs,
                      onViewAll: () => onShowAllSongs(''),
                    ),
                  ),
                  const SliverToBoxAdapter(child: HomeListeningSections()),
                ] else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 260,
                      child:
                          status == LibraryStatus.scanning
                              ? const Center(child: CircularProgressIndicator())
                              : LibraryEmptyState(
                                icon: Icons.music_note_rounded,
                                message: AppStrings.emptyLibrary,
                                onScanTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const OnboardingScreen(),
                                      ),
                                    ),
                              ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: AppBottomNavigation.scrollBottomPadding(
                      context,
                      hasMiniPlayer: hasSong,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
