import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_colors_data.dart';

class HiddenSongsScreen extends StatelessWidget {
  const HiddenSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final music = context.watch<MusicProvider>();
    final hidden = music.hiddenSongs; // Map<int, Map<String,String>>
    final entries = hidden.entries.toList();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bài hát đã ẩn',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ),
      body: entries.isEmpty
          ? _EmptyState(c: c)
          : ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final id   = entries[i].key;
          final meta = entries[i].value;
          return _HiddenTile(
            songId: id,
            title:  meta['title']  ?? 'Unknown',
            artist: meta['artist'] ?? 'Unknown',
            onRestore: () => _confirmRestore(context, id, meta['title'] ?? '', c),
          );
        },
      ),
    );
  }

  void _confirmRestore(
      BuildContext context,
      int songId,
      String title,
      AppColorsData c,
      ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Khôi phục bài hát?',
          style: GoogleFonts.outfit(
              color: c.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '"$title" sẽ xuất hiện lại trong thư viện.',
          style: GoogleFonts.outfit(color: c.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy',
                style: GoogleFonts.outfit(color: c.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<MusicProvider>().unhideSong(songId);
            },
            child: Text(
              'Khôi phục',
              style: GoogleFonts.outfit(
                  color: c.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c});
  final AppColorsData c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_rounded, color: c.textDisabled, size: 52),
          const SizedBox(height: 14),
          Text(
            'Không có bài hát nào bị ẩn',
            style: GoogleFonts.outfit(
                color: c.textTertiary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _HiddenTile extends StatelessWidget {
  const _HiddenTile({
    required this.songId,
    required this.title,
    required this.artist,
    required this.onRestore,
  });
  final int songId;
  final String title;
  final String artist;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: c.surfaceElevated,
        ),
        child: Icon(Icons.music_note_rounded,
            color: c.textDisabled, size: 22),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.textPrimary),
      ),
      subtitle: Text(
        artist,
        maxLines: 1,
        style: GoogleFonts.outfit(
            fontSize: 12, color: c.textTertiary),
      ),
      trailing: TextButton.icon(
        onPressed: onRestore,
        icon: Icon(Icons.restore_rounded, size: 16, color: c.primary),
        label: Text(
          'Khôi phục',
          style: GoogleFonts.outfit(
              fontSize: 13,
              color: c.primary,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}