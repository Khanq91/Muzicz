import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import '../../../models/song_item.dart';
import 'package:muziczz/core/app_strings.dart';

/// Mở sheet "Thông tin bài hát" cho [song].
void showSongInfoSheet(BuildContext context, SongItem song) {
  final c = context.appColors;
  showModalBottomSheet(
    context: context,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SongInfoSheet(song: song),
  );
}

class SongInfoSheet extends StatelessWidget {
  const SongInfoSheet({super.key, required this.song});
  final SongItem song;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.songInfo,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _infoRow(context, AppStrings.fieldTitle, song.title),
          _infoRow(context, AppStrings.artist, song.artist),
          _infoRow(context, AppStrings.album, song.album),
          _infoRow(context, AppStrings.duration, song.durationFormatted),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.outfit(color: c.textTertiary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
