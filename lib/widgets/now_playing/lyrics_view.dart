import 'package:flutter/material.dart' hide RepeatMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/audio_handler.dart';
import 'package:muziczz/core/app_strings.dart';

// ════════════════════════════════════════════════════════════════════════════
// LyricsView
// ════════════════════════════════════════════════════════════════════════════

class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.player,
    required this.scrollCtrl,
    required this.onScrollToLine,
    required this.onTap,
  });

  final PlayerProvider player;
  final ScrollController scrollCtrl;
  final void Function(int index) onScrollToLine;
  final VoidCallback onTap;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  int _lastScrolledIndex = -1;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.70;
    final c = context.appColors;
    // Subscribed here (not at NowPlayingScreen) so a lyric line change only
    // rebuilds the lyrics card.
    final lp = context.watch<LyricsProvider>();

    return GestureDetector(
      onTap: widget.onTap,
      child: Semantics(
        button: true,
        label: AppStrings.lyricsHint,
        explicitChildNodes: true,
        child: SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
              decoration: BoxDecoration(
                color: c.scrimStrong,
                shape: BoxShape.circle,
              ),
              child: _buildContent(context, lp, c, size),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext ctx,
    LyricsProvider lp,
    AppColorsData c,
    double size,
  ) {
    // Loading
    if (lp.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.lyricsLoading,
              style: GoogleFonts.outfit(fontSize: 12, color: c.onPlayerLow),
            ),
          ],
        ),
      );
    }

    // Not found / error
    if (lp.status == LyricsStatus.notFound ||
        lp.status == LyricsStatus.error ||
        lp.status == LyricsStatus.idle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              lp.status == LyricsStatus.error
                  ? Icons.wifi_off_rounded
                  : Icons.lyrics_rounded,
              color: c.onPlayerSubtle,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              lp.status == LyricsStatus.error
                  ? AppStrings.lyricsError
                  : AppStrings.lyricsNone,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, color: c.onPlayerSubtle),
            ),
          ],
        ),
      );
    }

    // Has lyrics — synced or plain
    return LyricsListView(
      lyricsProvider: lp,
      player: widget.player,
      scrollCtrl: widget.scrollCtrl,
      onScrollToLine: (index) {
        if (index != _lastScrolledIndex) {
          _lastScrolledIndex = index;
          widget.onScrollToLine(index);
        }
      },
      circleSize: size,
    );
  }
}

// ── Lyrics list với position sync ────────────────────────────────────────────

class LyricsListView extends StatelessWidget {
  const LyricsListView({
    super.key,
    required this.lyricsProvider,
    required this.player,
    required this.scrollCtrl,
    required this.onScrollToLine,
    required this.circleSize,
  });

  final LyricsProvider lyricsProvider;
  final PlayerProvider player;
  final ScrollController scrollCtrl;
  final void Function(int) onScrollToLine;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    if (lyricsProvider.isSynced) {
      return StreamBuilder<PositionData>(
        stream: player.positionDataStream,
        builder: (context, snap) {
          if (snap.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              lyricsProvider.updatePosition(snap.data!.position);
              onScrollToLine(lyricsProvider.currentIndex);
            });
          }
          return _buildList(context, c);
        },
      );
    }

    return _buildList(context, c);
  }

  Widget _buildList(BuildContext context, AppColorsData c) {
    final lines = lyricsProvider.lines;
    final currentIdx = lyricsProvider.currentIndex;
    final padding = circleSize * 0.18;

    return ListView.builder(
      controller: scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: circleSize * 0.25,
      ),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isActive = lyricsProvider.isSynced && i == currentIdx;
        final isPast = lyricsProvider.isSynced && i < currentIdx;

        // Dòng trống = instrumental break
        if (line.text.isEmpty) {
          return SizedBox(
            height: 28,
            child:
                isActive
                    ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? c.primary : c.onPlayerMinimal,
                            ),
                          ),
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          );
        }

        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          style: GoogleFonts.outfit(
            fontSize: isActive ? 15 : 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color:
                isActive
                    ? c.onPlayer
                    : isPast
                    ? c.onPlayerSubtle
                    : c.onPlayerMedium,
            height: 1.5,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(line.text, textAlign: TextAlign.center),
          ),
        );
      },
    );
  }
}
