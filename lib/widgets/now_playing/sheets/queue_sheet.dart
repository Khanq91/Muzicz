import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../providers/player_provider.dart';
import 'package:muziczz/core/app_strings.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key, required this.onClose, required this.useBlur});
  final VoidCallback onClose;
  final bool useBlur;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // Queue order/active row must follow every queue notify; subscribing
    // here keeps that off the NowPlayingScreen root.
    final player = context.watch<PlayerProvider>();
    final sheetContent = Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: useBlur ? 0.75 : 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.queue,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        AppStrings.songCount(player.queue.length),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.collapseQueue,
                  onPressed: onClose,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: c.textTertiary,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: c.divider, height: 1),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: player.queue.length,
              onReorderItem: player.reorderQueue,
              itemBuilder: (_, i) {
                final song = player.queue[i];
                final isActive = player.currentSong?.id == song.id;
                return ListTile(
                  key: ValueKey(song.id),
                  tileColor:
                      isActive ? c.primary.withValues(alpha: 0.08) : null,
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: QueryArtworkWidget(
                        id: song.albumId,
                        type: ArtworkType.ALBUM,
                        artworkFit: BoxFit.cover,
                        artworkBorder: BorderRadius.zero,
                        keepOldArtwork: true,
                        nullArtworkWidget: Container(
                          color: c.surfaceElevated,
                          child: Icon(
                            Icons.music_note_rounded,
                            color: c.textDisabled,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? c.primary : c.textPrimary,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    style: TextStyle(color: c.textTertiary, fontSize: 12),
                  ),
                  trailing:
                      isActive
                          ? Icon(
                            Icons.equalizer_rounded,
                            color: c.primary,
                            size: 20,
                          )
                          : Semantics(
                            button: true,
                            label: AppStrings.removeFromQueue,
                            child: GestureDetector(
                              onTap: () => player.removeFromQueue(i),
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: c.textDisabled,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  onTap: () => player.skipToIndex(i),
                );
              },
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child:
          useBlur
              ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: sheetContent,
              )
              : sheetContent,
    );
  }
}
