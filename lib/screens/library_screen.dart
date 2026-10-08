import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors_data.dart';
import '../widgets/library/artists_tab.dart';
import '../widgets/library/fade_tab_bar_view.dart';
import '../widgets/library/folders_tab.dart';
import '../widgets/library/library_search_bar.dart';
import '../widgets/library/library_tab_bar.dart';
import 'onboarding_screen.dart';
import 'playlist_screen.dart';
import 'package:muziczz/core/app_strings.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigateToScan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isScanning = music.status == LibraryStatus.scanning;
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.library,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  if (isScanning)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.primary,
                      ),
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isScanning ? 2 : 0,
              child:
                  isScanning
                      ? LinearProgressIndicator(
                        backgroundColor: c.divider,
                        color: c.primary,
                      )
                      : const SizedBox.shrink(),
            ),
            LibrarySearchBar(controller: _searchCtrl),
            LibraryTabBar(tabCtrl: _tabCtrl, music: music),
            Expanded(
              child: FadeTabBarView(
                controller: _tabCtrl,
                children: [
                  const PlaylistsTab(),
                  ArtistsTab(onScanTap: _navigateToScan),
                  FoldersTab(onScanTap: _navigateToScan),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
