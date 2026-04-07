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
class ThemeSelectorSheet extends StatefulWidget {
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
  State<ThemeSelectorSheet> createState() => _ThemeSelectorSheetState();
}

class _ThemeSelectorSheetState extends State<ThemeSelectorSheet> {
  late AppThemeMode _previewMode;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _previewMode = context.read<ThemeProvider>().mode;
  }

  Future<void> _apply() async {
    final provider = context.read<ThemeProvider>();
    if (provider.mode == _previewMode) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isApplying = true);
    HapticFeedback.mediumImpact();

    // Đóng sheet trước, rồi apply theme — tránh sheet animate ra trong lúc theme bật
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 180));
    await provider.setTheme(_previewMode);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final currentMode = context.watch<ThemeProvider>().mode;

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giao diện',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      'Chọn bộ màu sắc cho ứng dụng',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Nút Áp dụng — chỉ active khi chọn khác mode hiện tại
              AnimatedOpacity(
                opacity: _previewMode != currentMode ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: _previewMode != currentMode ? _apply : null,
                  style: TextButton.styleFrom(
                    backgroundColor: c.primary.withOpacity(0.12),
                    foregroundColor: c.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: _isApplying
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.primary,
                    ),
                  )
                      : Text(
                    'Áp dụng',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Theme options — tap để preview, không apply ngay
          ...AppThemeMode.values.map(
                (mode) => _ThemeOption(
              mode: mode,
              isSelected: _previewMode == mode,
              isCurrentlyActive: currentMode == mode,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _previewMode = mode);
              },
            ),
          ),

          // Hint text
          if (_previewMode != currentMode) ...[
            const SizedBox(height: 8),
            Text(
              'Nhấn "Áp dụng" để chuyển sang giao diện ${_previewMode.label}',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: c.textTertiary,
              ),
            ),
          ],
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
    required this.isCurrentlyActive,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool isSelected;      // đang preview/chọn
  final bool isCurrentlyActive; // đang dùng thực tế
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
                  Row(
                    children: [
                      Text(
                        mode.label,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? c.primary : c.textPrimary,
                        ),
                      ),
                      if (isCurrentlyActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Hiện tại',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: c.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
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
            AnimatedScale(
              scale: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(
                Icons.check_circle_rounded,
                color: c.primary,
                size: 22,
              ),
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
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Stack(
        children: [
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