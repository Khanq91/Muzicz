import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors_data.dart';
import 'package:muziczz/core/app_strings.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.style,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final BottomNavStyle style;

  @override
  Widget build(BuildContext context) => switch (style) {
    BottomNavStyle.normal => _NormalBottomNavigation(
      currentIndex: currentIndex,
      onTap: onTap,
    ),
    BottomNavStyle.fancy => _PremiumGlassBottomNavigation(
      currentIndex: currentIndex,
      onTap: onTap,
    ),
  };
}

class _PremiumGlassBottomNavigation extends StatelessWidget {
  const _PremiumGlassBottomNavigation({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final selectedStyle = GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    return GlassTabBar.bottom(
      key: const ValueKey('premium-glass-bottom-navigation'),
      selectedIndex: currentIndex,
      onTabSelected: onTap,
      quality: GlassQuality.premium,
      maskingQuality: MaskingQuality.high,
      horizontalPadding: 20,
      verticalPadding: 12,
      barHeight: 64,
      barBorderRadius: 26,
      iconLabelSpacing: 7,
      selectedIconColor: c.primary,
      unselectedIconColor: c.textTertiary,
      selectedLabelColor: c.primary,
      unselectedLabelColor: c.textTertiary,
      selectedLabelStyle: selectedStyle,
      unselectedLabelStyle: selectedStyle,
      indicatorColor: c.primary.withValues(alpha: 0.14),
      interactionGlowColor: c.primary,
      tabs: [
        _glassTab(
          index: 0,
          icon: Icons.home_rounded,
          label: AppStrings.tabHome,
          glowColor: c.primary,
        ),
        _glassTab(
          index: 1,
          icon: Icons.language_rounded,
          label: AppStrings.online,
          glowColor: c.secondary,
        ),
        _glassTab(
          index: 2,
          icon: Icons.library_music_rounded,
          label: AppStrings.library,
          glowColor: c.tertiary,
        ),
      ],
    );
  }

  GlassTab _glassTab({
    required int index,
    required IconData icon,
    required String label,
    required Color glowColor,
  }) => GlassTab(
    icon: Icon(icon),
    label: currentIndex == index ? label : null,
    semanticLabel: label,
    glowColor: glowColor,
  );
}

class _NormalBottomNavigation extends StatelessWidget {
  const _NormalBottomNavigation({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final c = context.appColors;
    return Padding(
      key: const ValueKey('normal-bottom-navigation'),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: c.primary.withValues(alpha: 0.06),
              blurRadius: 32,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NormalNavItem(
              icon: Icons.home_rounded,
              label: AppStrings.tabHome,
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NormalNavItem(
              icon: Icons.language_rounded,
              label: AppStrings.online,
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NormalNavItem(
              icon: Icons.library_music_rounded,
              label: AppStrings.library,
              active: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NormalNavItem extends StatelessWidget {
  const _NormalNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: active ? 16 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color:
                active ? c.primary.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  color: active ? c.primary : c.textTertiary,
                  size: 22,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child:
                    active
                        ? Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: ExcludeSemantics(
                            child: Text(
                              label,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.primary,
                              ),
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
