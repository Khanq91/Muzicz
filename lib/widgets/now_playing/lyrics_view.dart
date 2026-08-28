import 'package:flutter/material.dart' hide RepeatMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/audio_handler.dart';

// ════════════════════════════════════════════════════════════════════════════
// LyricsView
// ════════════════════════════════════════════════════════════════════════════

class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.lyricsProvider,
    required this.player,
    required this.scrollCtrl,
    required this.onScrollToLine,
    required this.onTap,
  });

  final LyricsProvider lyricsProvider;
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
    final lp = widget.lyricsProvider;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: _buildContent(context, lp, c, size),
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
              'Đang tải lời bài hát…',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
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
              color: Colors.white30,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              lp.status == LyricsStatus.error
                  ? 'Không thể tải lời bài hát'
                  : 'Không có lời bài hát',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
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
                              color: isActive ? c.primary : Colors.white24,
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
                    ? Colors.white
                    : isPast
                    ? Colors.white38
                    : Colors.white60,
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
