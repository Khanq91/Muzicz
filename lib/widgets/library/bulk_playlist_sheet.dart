import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../models/song_item.dart';
import '../../providers/music_provider.dart';
import 'package:muziczz/core/app_strings.dart';

class BulkPlaylistSheet extends StatelessWidget {
  const BulkPlaylistSheet({super.key, required this.songs});
  final List<SongItem> songs;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final c = context.appColors;
    final playlists = music.playlists;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.addToPlaylist,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        AppStrings.songCount(songs.length),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: c.textTertiary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: c.divider, height: 1),
          playlists.isEmpty
              ? Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.playlist_play_rounded,
                      color: c.textDisabled,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.noPlaylists,
                      style: GoogleFonts.outfit(
                        color: c.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
              : Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: playlists.length,
                  itemBuilder: (_, i) {
                    final pl = playlists[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [c.primary, c.secondary],
                          ),
                        ),
                        child: Icon(
                          Icons.playlist_play_rounded,
                          color: c.onPlayer,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        pl.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: c.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        AppStrings.songCount(pl.songCount),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: c.textTertiary,
                        ),
                      ),
                      trailing: Icon(Icons.add_rounded, color: c.primary),
                      onTap: () async {
                        await music.bulkAddToPlaylist(pl.id, songs);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppStrings.addedSongsToPlaylist(
                                songs.length,
                                pl.name,
                              ),
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: c.surfaceElevated,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}
