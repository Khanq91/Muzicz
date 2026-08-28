import 'package:flutter/material.dart' hide RepeatMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../../providers/player_provider.dart';
import 'package:muziczz/core/app_strings.dart';

class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});
  static final _presets = [
    (label: AppStrings.minutes(5), duration: Duration(minutes: 5)),
    (label: AppStrings.minutes(10), duration: Duration(minutes: 10)),
    (label: AppStrings.minutes(15), duration: Duration(minutes: 15)),
    (label: AppStrings.minutes(30), duration: Duration(minutes: 30)),
    (label: AppStrings.minutes(45), duration: Duration(minutes: 45)),
    (label: AppStrings.minutes(60), duration: Duration(hours: 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final c = context.appColors;
    final rem = player.sleepRemaining;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
                AppStrings.sleepTimerTitle,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              if (player.sleepTimerActive)
                TextButton(
                  onPressed: () {
                    player.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  child: Text(
                    AppStrings.cancelSleepTimer,
                    style: GoogleFonts.outfit(color: c.tertiary, fontSize: 14),
                  ),
                ),
            ],
          ),
          if (rem != null && rem > Duration.zero) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bedtime_rounded, color: c.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    AppStrings.stopAfterPrefix,
                    style: GoogleFonts.outfit(
                      color: c.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _formatRemaining(rem),
                    style: GoogleFonts.outfit(
                      color: c.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            AppStrings.chooseDuration,
            style: GoogleFonts.outfit(fontSize: 13, color: c.textTertiary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _presets
                    .map(
                      (p) => Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            player.setSleepTimer(p.duration);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: c.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.border, width: 0.5),
                            ),
                            child: Text(
                              p.label,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: c.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return AppStrings.seconds(s);
    if (s == 0) return AppStrings.minutes(m);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
