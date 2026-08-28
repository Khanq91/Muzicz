import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors_data.dart';
import 'package:muziczz/core/app_strings.dart';

class BottomNavStyleSelectorSheet extends StatefulWidget {
  const BottomNavStyleSelectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => ChangeNotifierProvider.value(
            value: context.read<ThemeProvider>(),
            child: const BottomNavStyleSelectorSheet(),
          ),
    );
  }

  @override
  State<BottomNavStyleSelectorSheet> createState() =>
      _BottomNavStyleSelectorSheetState();
}

class _BottomNavStyleSelectorSheetState
    extends State<BottomNavStyleSelectorSheet> {
  late BottomNavStyle _selectedStyle;

  @override
  void initState() {
    super.initState();
    _selectedStyle = context.read<ThemeProvider>().bottomNavStyle;
  }

  Future<void> _apply() async {
    final provider = context.read<ThemeProvider>();
    if (provider.bottomNavStyle == _selectedStyle) {
      Navigator.pop(context);
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 180));
    await provider.setBottomNavStyle(_selectedStyle);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final currentStyle = context.watch<ThemeProvider>().bottomNavStyle;
    final hasChange = currentStyle != _selectedStyle;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.graphics,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      AppStrings.bottomNavStyleSubtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: hasChange ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: hasChange ? _apply : null,
                  style: TextButton.styleFrom(
                    backgroundColor: c.primary.withValues(alpha: 0.12),
                    foregroundColor: c.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    AppStrings.apply,
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
          for (final style in BottomNavStyle.values)
            _BottomNavStyleOption(
              style: style,
              isSelected: _selectedStyle == style,
              isCurrentlyActive: currentStyle == style,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedStyle = style);
              },
            ),
        ],
      ),
    );
  }
}

class _BottomNavStyleOption extends StatelessWidget {
  const _BottomNavStyleOption({
    required this.style,
    required this.isSelected,
    required this.isCurrentlyActive,
    required this.onTap,
  });

  final BottomNavStyle style;
  final bool isSelected;
  final bool isCurrentlyActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? c.primary.withValues(alpha: 0.10)
                    : c.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? c.primary : c.border,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.glassBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.glassBorder),
                ),
                child: Icon(
                  style == BottomNavStyle.fancy
                      ? Icons.auto_awesome_rounded
                      : Icons.view_compact_alt_rounded,
                  color: c.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          style.label,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? c.primary : c.textPrimary,
                          ),
                        ),
                        if (isCurrentlyActive) ...[
                          const SizedBox(width: 8),
                          _CurrentBadge(colors: c),
                        ],
                      ],
                    ),
                    Text(
                      style == BottomNavStyle.fancy
                          ? AppStrings.bottomNavFancyDesc
                          : AppStrings.bottomNavNormalDesc,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedScale(
                scale: isSelected ? 1 : 0,
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
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.colors});

  final AppColorsData colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      AppStrings.current,
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: colors.primary,
      ),
    ),
  );
}
