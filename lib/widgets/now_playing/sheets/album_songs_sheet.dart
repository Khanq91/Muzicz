import 'package:flutter/material.dart' hide RepeatMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../models/song_item.dart';
import '../../../providers/music_provider.dart';
import '../../../providers/player_provider.dart';

/// Mở sheet liệt kê các bài cùng album với [song]. Không làm gì nếu album
/// không có bài nào trong thư viện.
void showAlbumSongsSheet(
  BuildContext context,
  MusicProvider music,
  SongItem song,
) {
  final albumSongs = music.albumMap[song.album] ?? [];
  if (albumSongs.isEmpty) return;
  final c = context.appColors;
  showModalBottomSheet(
    context: context,
    backgroundColor: c.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AlbumSongsSheet(song: song, albumSongs: albumSongs),
  );
}

class AlbumSongsSheet extends StatelessWidget {
  const AlbumSongsSheet({
    super.key,
    required this.song,
    required this.albumSongs,
  });

  final SongItem song;
  final List<SongItem> albumSongs;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final music = context.read<MusicProvider>();
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder:
          (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: QueryArtworkWidget(
                          id: song.albumId,
                          type: ArtworkType.ALBUM,
                          artworkFit: BoxFit.cover,
                          artworkBorder: BorderRadius.zero,
                          keepOldArtwork: true,
                          nullArtworkWidget: Container(
                            color: c.surfaceElevated,
                            child: Icon(
                              Icons.album_rounded,
                              color: c.textDisabled,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.album,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            '${albumSongs.length} bài hát',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: c.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: c.divider),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: albumSongs.length,
                  itemBuilder: (_, i) {
                    final s = albumSongs[i];
                    final isCurrentSong = s.id == song.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading:
                          isCurrentSong
                              ? Icon(
                                Icons.equalizer_rounded,
                                color: c.primary,
                                size: 24,
                              )
                              : Text(
                                '${i + 1}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: c.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      title: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: isCurrentSong ? c.primary : c.textPrimary,
                          fontWeight:
                              isCurrentSong ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        s.durationFormatted,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: c.textTertiary,
                        ),
                      ),
                      onTap: () {
                        final player = context.read<PlayerProvider>();
                        player.playSongs(albumSongs, specificSong: s);
                        music.onSongPlayed(s.id);
                        Navigator.pop(context);
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
