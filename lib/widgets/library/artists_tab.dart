import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../providers/music_provider.dart';
import '../../screens/artist_detail_screen.dart';
import 'package:muziczz/core/app_strings.dart';
import 'library_empty_state.dart';

class ArtistsTab extends StatelessWidget {
  const ArtistsTab({super.key, required this.onScanTap});
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final artists = music.sortedArtistGroups;
    final c = context.appColors;
    if (artists.isEmpty) {
      return LibraryEmptyState(
        icon: Icons.person_rounded,
        message: AppStrings.noArtists,
        onScanTap: onScanTap,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final entry = artists[i];
        final songs = entry.value;
        final artistId = songs.first.artistId;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: SizedBox(
            width: 48,
            height: 48,
            child: ClipOval(
              child: QueryArtworkWidget(
                id: artistId,
                type: ArtworkType.ARTIST,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.zero,
                keepOldArtwork: true,
                nullArtworkWidget: Container(
                  color: c.surfaceElevated,
                  child: Center(
                    child: Text(
                      entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
            AppStrings.songCount(songs.length),
            style: GoogleFonts.outfit(fontSize: 12, color: c.textTertiary),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: c.textDisabled,
            size: 20,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) =>
                        ArtistDetailScreen(artistName: entry.key, songs: songs),
              ),
            );
          },
        );
      },
    );
  }
}
