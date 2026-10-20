import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_strings.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors_data.dart';
import '../widgets/library/library_chrome.dart';
import '../widgets/library/library_collections_page.dart';
import '../widgets/library/library_preferences.dart';
import '../widgets/library/library_search_bar.dart';
import '../widgets/library/library_songs_page.dart';
import 'onboarding_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.active = true, this.onSettings});
  final bool active;
  final VoidCallback? onSettings;
  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  final _pages = PageController();
  final _preferences = LibraryPreferences();
  final _searchCtrl = TextEditingController();
  LibrarySection _selected = LibrarySection.songs;
  List<LibrarySection> _order = defaultLibrarySections.toList();
  bool _searchOpen = false;
  bool _sheetOpen = false;
  bool _restoringOrder = false;

  @override
  void initState() {
    super.initState();
    _preferences.addListener(_onPreferences);
    unawaited(_preferences.load());
  }

  void _onPreferences() {
    if (!mounted) return;
    final order = _preferences.sections;
    final reordered = List.generate(
      order.length,
      (i) => order[i] != _order[i],
    ).any((v) => v);
    setState(() {
      _order = order;
      _restoringOrder = reordered;
    });
    if (reordered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pages.hasClients) _pages.jumpToPage(_order.indexOf(_selected));
        _restoringOrder = false;
      });
    }
  }

  @override
  void dispose() {
    _preferences.removeListener(_onPreferences);
    _preferences.dispose();
    _pages.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Home/Search use stable semantic indices, independent of display order.
  void showTab(int index, {String? searchQuery}) {
    if (searchQuery != null) {
      _searchCtrl.text = searchQuery;
      context.read<MusicProvider>().setLibrarySearchQuery(searchQuery);
      _searchOpen = searchQuery.isNotEmpty;
    }
    _select(LibrarySection.values[index.clamp(0, 3)]);
  }

  void _select(LibrarySection section) {
    setState(() => _selected = section);
    if (!_pages.hasClients) return;
    final index = _order.indexOf(section);
    final duration = libraryMotion(context, 340);
    if (duration == Duration.zero) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    context.read<MusicProvider>().setLibrarySearchQuery('');
  }

  void _scan() => Navigator.of(
    context,
  ).push(libraryDetailRoute(context, const OnboardingScreen()));

  Future<void> _tabs() async {
    setState(() => _sheetOpen = true);
    final reorder = await showLibrarySheet<bool>(
      context,
      LibraryTabSheet(
        preferences: _preferences,
        selected: _selected,
        onSelect: (section) {
          _select(section);
          Navigator.pop(context);
        },
        onReorder: () => Navigator.pop(context, true),
      ),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (reorder == true) {
      await showLibrarySheet(
        context,
        LibraryReorderSheet(preferences: _preferences),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final status = context.select<MusicProvider, LibraryStatus>(
      (m) => m.status,
    );
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LibraryPill(
                        section: _selected,
                        expanded: _sheetOpen,
                        onTap: _tabs,
                        onNext:
                            () => _select(
                              _order[(_order.indexOf(_selected) + 1) %
                                  _order.length],
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: AppStrings.librarySearchHint,
                    color: c.primary,
                    onPressed:
                        () => setState(() {
                          _searchOpen = !_searchOpen;
                          if (!_searchOpen) _clearSearch();
                        }),
                    icon: Icon(
                      _searchOpen
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                    ),
                  ),
                  LibraryIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: AppStrings.settings,
                    onPressed: widget.onSettings ?? () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final section in _order)
                    Semantics(
                      label: section.title,
                      selected: section == _selected,
                      button: true,
                      child: GestureDetector(
                        onTap: () => _select(section),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: section == _selected ? 30 : 24,
                          height: 24,
                          child: Center(
                            child: AnimatedContainer(
                              duration: libraryMotion(context, 220),
                              width: section == _selected ? 22 : 10,
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: c.primary.withValues(
                                  alpha: section == _selected ? 1 : .3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: ColoredBox(
                  color: c.surface,
                  child: Column(
                    children: [
                      AnimatedSize(
                        duration: libraryMotion(context, 220),
                        alignment: Alignment.topCenter,
                        child:
                            _searchOpen
                                ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: 12,
                                    bottom: 4,
                                  ),
                                  child: LibrarySearchBar(
                                    controller: _searchCtrl,
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                      AnimatedSize(
                        duration: libraryMotion(context, 220),
                        child:
                            status == LibraryStatus.scanning
                                ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    12,
                                    18,
                                    4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.libraryLoadingEllipsis,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        color: c.primary,
                                        backgroundColor: c.divider,
                                        minHeight: 3,
                                      ),
                                    ],
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                      if (status == LibraryStatus.error ||
                          status == LibraryStatus.permissionDenied)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  status == LibraryStatus.permissionDenied
                                      ? AppStrings.libraryScanPermission
                                      : AppStrings.libraryRefreshFailed,
                                  style: TextStyle(color: c.error),
                                ),
                              ),
                              TextButton(
                                onPressed: _scan,
                                child: const Text(AppStrings.retry),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pages,
                          itemCount: _order.length,
                          onPageChanged: (index) {
                            if (!_restoringOrder) {
                              setState(() => _selected = _order[index]);
                            }
                          },
                          findChildIndexCallback:
                              (key) =>
                                  key is ValueKey<LibrarySection>
                                      ? _order.indexOf(key.value)
                                      : null,
                          itemBuilder: (context, index) {
                            final section = _order[index];
                            final key = ValueKey(section);
                            if (section == LibrarySection.songs ||
                                section == LibrarySection.folders) {
                              return LibrarySongsPage(
                                key: key,
                                preferences: _preferences,
                                active: widget.active && section == _selected,
                                folders: section == LibrarySection.folders,
                                onScanTap: _scan,
                                onClearSearch: _clearSearch,
                              );
                            }
                            return LibraryCollectionsPage(
                              key: key,
                              section: section,
                              preferences: _preferences,
                              onScanTap: _scan,
                              onClearSearch: _clearSearch,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
