import 'package:flutter/material.dart' hide RepeatMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../../providers/player_provider.dart';
import 'package:muziczz/core/app_strings.dart';

class SpeedSheet extends StatelessWidget {
  const SpeedSheet({super.key});
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                AppStrings.playbackSpeed,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              if (player.speed != 1.0)
                TextButton(
                  onPressed: () {
                    player.setSpeed(1.0);
                    Navigator.pop(context);
                  },
                  child: Text(
                    AppStrings.reset,
                    style: GoogleFonts.outfit(color: c.primary, fontSize: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _speeds.map((s) {
                  final active = player.speed == s;
                  return GestureDetector(
                    onTap: () {
                      player.setSpeed(s);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 72,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            active
                                ? c.primary.withValues(alpha: 0.18)
                                : c.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? c.primary : c.border,
                          width: active ? 1.5 : 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          s == 1.0
                              ? AppStrings.speedNormal
                              : AppStrings.speedMultiplier('$s'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: s == 1.0 ? 10 : 15,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400,
                            color: active ? c.primary : c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
