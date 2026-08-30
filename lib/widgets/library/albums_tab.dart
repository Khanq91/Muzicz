import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../providers/music_provider.dart';
import '../../screens/album_detail_screen.dart';
import 'package:muziczz/core/app_strings.dart';
import 'library_empty_state.dart';

class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key, required this.onScanTap});
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final albums = music.sortedAlbumGroups;
    final c = context.appColors;

    if (albums.isEmpty) {
      return LibraryEmptyState(
        icon: Icons.album_rounded,
        message: AppStrings.noAlbums,
        onScanTap: onScanTap,
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final entry = albums[i];
        final songs = entry.value;
        final albumId = songs.first.albumId;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) =>
                        AlbumDetailScreen(albumName: entry.key, songs: songs),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: c.surfaceElevated,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: QueryArtworkWidget(
                      id: albumId,
                      type: ArtworkType.ALBUM,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.zero,
                      keepOldArtwork: true,
                      artworkQuality: FilterQuality.low,
                      nullArtworkWidget: Container(
                        color: c.surfaceElevated,
                        child: Icon(
                          Icons.album_rounded,
                          color: c.textDisabled,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              Text(
                AppStrings.songCountShort(songs.length),
                style: GoogleFonts.outfit(fontSize: 11, color: c.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }
}
