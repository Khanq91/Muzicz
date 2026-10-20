import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/app_strings.dart';
import '../../theme/app_colors_data.dart';
import 'library_preferences.dart';

extension LibrarySectionPresentation on LibrarySection {
  String get title => switch (this) {
    LibrarySection.playlists => AppStrings.tabPlaylistsShort,
    LibrarySection.songs => AppStrings.songs,
    LibrarySection.artists => AppStrings.artist,
    LibrarySection.folders => AppStrings.folders,
  };
  IconData get icon => switch (this) {
    LibrarySection.playlists => Icons.playlist_play_rounded,
    LibrarySection.songs => Icons.music_note_rounded,
    LibrarySection.artists => Icons.person_rounded,
    LibrarySection.folders => Icons.folder_outlined,
  };
}

Duration libraryMotion(BuildContext context, [int milliseconds = 280]) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);

Color libraryCardColor(BuildContext context) {
  final c = context.appColors;
  return c.isDark
      ? c.card
      : Color.alphaBlend(c.primary.withValues(alpha: .035), c.surface);
}

Future<T?> showLibrarySheet<T>(BuildContext context, Widget child) {
  final c = context.appColors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: c.surface,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder:
        (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: SafeArea(top: false, child: child),
        ),
  );
}

class LibraryPill extends StatelessWidget {
  const LibraryPill({
    super.key,
    required this.section,
    required this.expanded,
    required this.onTap,
    required this.onNext,
  });
  final LibrarySection section;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = c.primary.withValues(alpha: c.isDark ? .22 : .13);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Material(
            color: color,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(32),
              right: Radius.circular(5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onNext,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: AnimatedSize(
                  duration: libraryMotion(context),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: libraryMotion(context, 220),
                    transitionBuilder:
                        (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, .25),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                    child: FittedBox(
                      key: ValueKey(section),
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(section.icon, color: c.primary, size: 25),
                          const SizedBox(width: 10),
                          Text(
                            section.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: c.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Material(
          color: color,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(5),
            right: Radius.circular(32),
          ),
          child: IconButton(
            tooltip: AppStrings.libraryChooseSection,
            constraints: const BoxConstraints(minWidth: 52, minHeight: 56),
            onPressed: onTap,
            icon: AnimatedRotation(
              turns: expanded ? .5 : 0,
              duration: libraryMotion(context, 220),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: c.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class LibraryIconButton extends StatelessWidget {
  const LibraryIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.connected = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: c.primary.withValues(alpha: c.isDark ? .2 : .12),
        foregroundColor: c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(connected ? 12 : 26),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

class LibraryTabSheet extends StatelessWidget {
  const LibraryTabSheet({
    super.key,
    required this.preferences,
    required this.selected,
    required this.onSelect,
    required this.onReorder,
  });
  final LibraryPreferences preferences;
  final LibrarySection selected;
  final ValueChanged<LibrarySection> onSelect;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.librarySections,
            style: GoogleFonts.outfit(
              fontSize: 28,
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.librarySectionsHint,
            style: TextStyle(color: c.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 22),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 1.05 : 1.5,
            children: [
              for (final section in preferences.sections)
                Material(
                  color:
                      section == selected
                          ? c.primary.withValues(alpha: .2)
                          : c.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(section),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                section == selected
                                    ? c.primary
                                    : c.primary.withValues(alpha: .1),
                            child: Icon(
                              section.icon,
                              color:
                                  section == selected
                                      ? ThemeData.estimateBrightnessForColor(
                                                c.primary,
                                              ) ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black
                                      : c.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            section.title,
                            style: TextStyle(
                              fontSize: 18,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onReorder,
              icon: const Icon(Icons.edit_rounded),
              label: const Text(AppStrings.libraryReorder),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                backgroundColor: c.tertiary.withValues(alpha: .2),
                foregroundColor: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryReorderSheet extends StatelessWidget {
  const LibraryReorderSheet({super.key, required this.preferences});
  final LibraryPreferences preferences;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ListenableBuilder(
      listenable: preferences,
      builder:
          (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.libraryReorder,
                        style: TextStyle(fontSize: 24, color: c.textPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: preferences.resetTabs,
                      child: const Text(AppStrings.libraryReset),
                    ),
                    IconButton(
                      tooltip: AppStrings.libraryDone,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: preferences.sections.length,
                  onReorderItem: preferences.move,
                  itemBuilder: (context, index) {
                    final section = preferences.sections[index];
                    return Card(
                      key: ValueKey(section),
                      color: c.surfaceElevated,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ListTile(
                        leading: Icon(section.icon, color: c.primary),
                        title: Text(
                          section.title,
                          style: TextStyle(color: c.textPrimary),
                        ),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}

class LibrarySortSheet extends StatelessWidget {
  const LibrarySortSheet({
    super.key,
    required this.preferences,
    required this.section,
  });
  final LibraryPreferences preferences;
  final LibrarySection section;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final options = [
      LibraryOrder.name,
      LibraryOrder.newest,
      LibraryOrder.duration,
      if (section != LibrarySection.songs) LibraryOrder.count,
    ];
    return ListenableBuilder(
      listenable: preferences,
      builder:
          (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.sort} · ${section.title}',
                  style: TextStyle(
                    fontSize: 26,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: c.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(
                      preferences.descending(section)
                          ? Icons.south_rounded
                          : Icons.north_rounded,
                      color: c.primary,
                    ),
                    title: Text(
                      preferences.descending(section)
                          ? AppStrings.libraryDescending
                          : AppStrings.libraryAscending,
                      style: TextStyle(color: c.textPrimary),
                    ),
                    subtitle: Text(
                      AppStrings.libraryFlipDirection,
                      style: TextStyle(color: c.textSecondary),
                    ),
                    onTap:
                        () => preferences.setSort(
                          section,
                          preferences.order(section),
                          !preferences.descending(section),
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final order in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color:
                          preferences.order(section) == order
                              ? c.primary.withValues(alpha: .18)
                              : c.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        title: Text(switch (order) {
                          LibraryOrder.name => AppStrings.librarySortName,
                          LibraryOrder.newest => AppStrings.librarySortAdded,
                          LibraryOrder.duration => AppStrings.duration,
                          LibraryOrder.count => AppStrings.librarySortCount,
                        }, style: TextStyle(color: c.textPrimary)),
                        trailing: Icon(
                          preferences.order(section) == order
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: c.primary,
                        ),
                        onTap:
                            () => preferences.setSort(
                              section,
                              order,
                              preferences.descending(section),
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

class LibraryScrollbar extends StatelessWidget {
  const LibraryScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });
  final ScrollController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) => RawScrollbar(
    controller: controller,
    thumbVisibility: true,
    trackVisibility: true,
    interactive: true,
    thickness: 6,
    radius: const Radius.circular(8),
    minThumbLength: 40,
    thumbColor: context.appColors.primary,
    trackColor: context.appColors.primary.withValues(alpha: .12),
    trackBorderColor: Colors.transparent,
    crossAxisMargin: 6,
    child: child,
  );
}

Route<T> libraryDetailRoute<T>(BuildContext context, Widget child) =>
    MaterialPageRoute<T>(builder: (_) => child);

class LibraryDetailHeader extends StatelessWidget {
  const LibraryDetailHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artworkId,
    required this.type,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final int? artworkId;
  final ArtworkType type;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ColoredBox(
      color: c.primary.withValues(alpha: .08),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 72, 20, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    type == ArtworkType.ARTIST ? 50 : 28,
                  ),
                  child: QueryArtworkWidget(
                    id: artworkId ?? 0,
                    type: type,
                    artworkWidth: 100,
                    artworkHeight: 100,
                    artworkBorder: BorderRadius.zero,
                    keepOldArtwork: true,
                    nullArtworkWidget: ColoredBox(
                      color: c.primary.withValues(alpha: .14),
                      child: Icon(icon, color: c.primary, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 27,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LibraryDetailAction extends StatelessWidget {
  const LibraryDetailAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: (primary ? c.primary : c.tertiary).withValues(
          alpha: .2,
        ),
        foregroundColor: c.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }
}
