import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../features/music_visual/widgets/reactive_cover_art_transform.dart';
import '../../models/song_item.dart';
import '../../providers/player_provider.dart';
import 'package:muziczz/core/app_strings.dart';

// ════════════════════════════════════════════════════════════════════════════
// AlbumArtSection — now tappable
// ════════════════════════════════════════════════════════════════════════════

class AlbumArtSection extends StatelessWidget {
  const AlbumArtSection({
    super.key,
    required this.song,
    required this.player,
    required this.rotateCtrl,
    required this.onTap,
  });

  final SongItem song;
  final PlayerProvider player;
  final AnimationController rotateCtrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.70;
    final c = context.appColors;
    return Semantics(
      button: true,
      label: AppStrings.albumArtHint,
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          // The two blurred shadows stay outside the rotating subtree so they
          // are painted once, and the RepaintBoundary keeps the 60fps rotation
          // in its own layer instead of invalidating the whole screen.
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.3),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: RepaintBoundary(
              child: ReactiveCoverArtTransform(
                song: song,
                player: player,
                normalRotation: rotateCtrl,
                child: ClipOval(
                  child: QueryArtworkWidget(
                    id: song.albumId,
                    type: ArtworkType.ALBUM,
                    artworkFit: BoxFit.cover,
                    artworkBorder: BorderRadius.zero,
                    keepOldArtwork: true,
                    nullArtworkWidget: Container(
                      decoration: BoxDecoration(gradient: c.primaryGradient),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: c.onPlayerLow,
                        size: 80,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FlipCard — 3D flip animation between front and back
// ════════════════════════════════════════════════════════════════════════════

class FlipCard extends StatelessWidget {
  const FlipCard({
    super.key,
    required this.flipAnim,
    required this.front,
    required this.back,
  });

  final Animation<double> flipAnim;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flipAnim,
      builder: (context, child) {
        final angle = flipAnim.value * pi;
        final showBack = flipAnim.value >= 0.5;

        return Transform(
          alignment: Alignment.center,
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(angle),
          child:
              showBack
                  ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: back,
                  )
                  : front,
        );
      },
    );
  }
}

class BlurredBackground extends StatelessWidget {
  const BlurredBackground({super.key, required this.albumId});
  final int albumId;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // Blur the static artwork itself in its own layer. The previous
    // full-screen BackdropFilter had to read back and re-blur the backdrop
    // every frame the cover disc rotated.
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: BoxDecoration(gradient: c.backgroundGradient)),
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 40,
              sigmaY: 40,
              tileMode: TileMode.clamp,
            ),
            child: QueryArtworkWidget(
              id: albumId,
              type: ArtworkType.ALBUM,
              artworkFit: BoxFit.cover,
              artworkBorder: BorderRadius.zero,
              keepOldArtwork: true,
              nullArtworkWidget: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
