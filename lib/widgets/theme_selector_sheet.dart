import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors_data.dart';
import '../providers/theme_provider.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// ThemeSelectorSheet — bottom sheet chọn theme
///
/// Cách dùng:
///   ThemeSelectorSheet.show(context);
/// ════════════════════════════════════════════════════════════════════════════
class ThemeSelectorSheet extends StatelessWidget {
  const ThemeSelectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ThemeProvider>(),
        child: const ThemeSelectorSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final provider = context.watch<ThemeProvider>();

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
          Text(
            'Giao diện',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn bộ màu sắc cho ứng dụng',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 24),

          // Theme options
          ...AppThemeMode.values.map(
                (mode) => _ThemeOption(
              mode: mode,
              isSelected: provider.mode == mode,
              onTap: () async {
                HapticFeedback.selectionClick();
                await provider.setTheme(mode);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme option tile ─────────────────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final previewColors = mode.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? c.primary.withOpacity(0.10)
              : c.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? c.primary : c.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Preview swatch
            _ColorSwatch(colors: previewColors),
            const SizedBox(width: 16),
            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? c.primary : c.textPrimary,
                    ),
                  ),
                  Text(
                    _subtitle(mode),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Check icon
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.check_circle_rounded,
                  color: c.primary, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(AppThemeMode mode) => switch (mode) {
    AppThemeMode.dark   => 'Nền đen xám, dễ dùng ban đêm',
    AppThemeMode.amoled => 'Pure black, tiết kiệm pin OLED',
    AppThemeMode.light  => 'Nền sáng, dễ đọc ngoài trời',
  };
}

// ── Color swatch preview ──────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.colors});
  final AppColorsData colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.background,
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Background chip
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              width: 44,
              height: 14,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Primary dot
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: colors.primaryGradient,
              ),
            ),
          ),
          // Tertiary dot
          Positioned(
            top: 8,
            left: 28,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}