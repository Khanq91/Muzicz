import 'package:flutter/material.dart' hide RepeatMode;
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import 'sheets/sleep_timer_sheet.dart';
import 'sheets/speed_sheet.dart';

// ════════════════════════════════════════════════════════════════════════════
// _ExtraActions — thêm lyrics button
// ════════════════════════════════════════════════════════════════════════════

class ExpandablePillBar extends StatefulWidget {
  const ExpandablePillBar({
    super.key,
    required this.player,
    required this.lyricsProvider,
    required this.onQueueTap,
    required this.onLyricsTap,
    required this.showingLyrics,
    required this.queueVisible,
  });

  final PlayerProvider player;
  final LyricsProvider lyricsProvider;
  final VoidCallback onQueueTap;
  final VoidCallback onLyricsTap;
  final bool showingLyrics;
  final bool queueVisible;

  @override
  State<ExpandablePillBar> createState() => _ExpandablePillBarState();
}

class _ExpandablePillBarState extends State<ExpandablePillBar> {
  bool _isExpanded = false;

  void _showSpeedSheet(BuildContext context, PlayerProvider player) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => ChangeNotifierProvider.value(
            value: player,
            child: const SpeedSheet(),
          ),
    );
  }

  void _showSleepTimerSheet(BuildContext context, PlayerProvider player) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => ChangeNotifierProvider.value(
            value: player,
            child: const SleepTimerSheet(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    final lyricsActive = widget.showingLyrics;
    final queueActive = widget.queueVisible;
    final speedActive = widget.player.speed != 1.0;
    final timerActive = widget.player.sleepTimerActive;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: 52,
        width: _isExpanded ? 280 : 64,
        decoration: BoxDecoration(
          color:
              _isExpanded
                  ? c.surfaceElevated.withValues(alpha: 0.9)
                  : c.onPlayerGhostBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color:
                _isExpanded ? c.border.withValues(alpha: 0.3) : c.onPlayerGhost,
          ),
          boxShadow:
              _isExpanded
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                  : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isExpanded ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isExpanded,
                  child: Material(
                    color: Colors.transparent,
                    child: Semantics(
                      button: true,
                      label: 'Tùy chọn phát',
                      child: InkWell(
                        onTap: () => setState(() => _isExpanded = true),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isExpanded,
                  child: OverflowBox(
                    maxWidth: 280,
                    minWidth: 280,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionIcon(
                          icon: Icons.lyrics_rounded,
                          label: 'Lời bài hát',
                          isActive: lyricsActive,
                          c: c,
                          onTap: widget.onLyricsTap,
                        ),
                        _buildActionIcon(
                          icon: Icons.queue_music_rounded,
                          label: 'Hàng chờ phát',
                          isActive: queueActive,
                          c: c,
                          onTap: widget.onQueueTap,
                        ),
                        _buildActionIcon(
                          icon: Icons.speed_rounded,
                          label: 'Tốc độ phát',
                          isActive: speedActive,
                          c: c,
                          onTap: () => _showSpeedSheet(context, widget.player),
                        ),
                        _buildActionIcon(
                          icon: Icons.bedtime_rounded,
                          label: 'Hẹn giờ ngủ',
                          isActive: timerActive,
                          c: c,
                          onTap:
                              () =>
                                  _showSleepTimerSheet(context, widget.player),
                        ),
                        Semantics(
                          button: true,
                          label: 'Thu gọn tùy chọn',
                          child: GestureDetector(
                            onTap: () => setState(() => _isExpanded = false),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white12,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String label,
    required bool isActive,
    required AppColorsData c,
    required VoidCallback onTap,
  }) {
    return Transform.scale(
      scale: _isExpanded ? 1.0 : 0.8,
      child: Semantics(
        button: true,
        label: label,
        selected: isActive,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive
                      ? c.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? c.primary : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
