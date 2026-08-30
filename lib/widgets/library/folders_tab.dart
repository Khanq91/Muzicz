import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../providers/music_provider.dart';
import '../../providers/player_provider.dart';
import 'package:muziczz/core/app_strings.dart';
import 'library_empty_state.dart';
import 'player_route.dart';

class FoldersTab extends StatelessWidget {
  const FoldersTab({super.key, required this.onScanTap});
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final music = context.watch<MusicProvider>();
    final folders = music.sortedFolderGroups;

    if (folders.isEmpty) {
      return LibraryEmptyState(
        icon: Icons.folder_rounded,
        message: AppStrings.noFolders,
        onScanTap: onScanTap,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: folders.length,
      itemBuilder: (_, i) {
        final entry = folders[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: c.primary.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.folder_rounded, color: c.primary, size: 24),
          ),
          title: Text(
            entry.key,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
            ),
          ),
          subtitle: Text(
            AppStrings.songCount(entry.value.length),
            style: GoogleFonts.outfit(fontSize: 12, color: c.textTertiary),
          ),
          onTap: () {
            context.read<PlayerProvider>().playSongs(entry.value);
            Navigator.of(context).push(playerRoute());
          },
        );
      },
    );
  }
}
