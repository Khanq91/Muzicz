import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

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

  static const double _barHeight = 64;
  static const double _bottomMargin = 12;
  static const double _topMargin = 8;
  static const double _miniPlayerHeight = 80;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final BottomNavStyle style;

  /// Space from the bottom of the body to the top of the floating navigation.
  static double bottomOverlayExtent(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom +
      _bottomMargin +
      _barHeight +
      _topMargin;

  /// Scroll space needed to bring the last row above the navigation and player.
  static double scrollBottomPadding(
    BuildContext context, {
    bool hasMiniPlayer = false,
  }) {
    final overlayExtent = bottomOverlayExtent(context);
    return hasMiniPlayer
        ? overlayExtent + 8 + _miniPlayerHeight + 12
        : overlayExtent + 12;
  }

  static double miniPlayerBottom(BuildContext context) =>
      bottomOverlayExtent(context) + 8;

  static double floatingActionBottom(
    BuildContext context, {
    bool hasMiniPlayer = false,
  }) => scrollBottomPadding(context, hasMiniPlayer: hasMiniPlayer) + 12;

  @override
  Widget build(BuildContext context) {
    final isFancy = style == BottomNavStyle.fancy;
    return Padding(
      key: ValueKey(
        isFancy
            ? 'premium-glass-bottom-navigation'
            : 'normal-bottom-navigation',
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        _topMargin,
        16,
        _bottomMargin + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 232),
          child: SizedBox(
            width: double.infinity,
            height: _barHeight,
            child: _FloatingNavigationPill(
              currentIndex: currentIndex,
              onTap: onTap,
              isFancy: isFancy,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavigationPill extends StatelessWidget {
  const _FloatingNavigationPill({
    required this.currentIndex,
    required this.onTap,
    required this.isFancy,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isFancy;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final borderRadius = BorderRadius.circular(32);
    final tabs = [
      (Icons.library_music_rounded, AppStrings.library),
      (Icons.home_rounded, AppStrings.tabHome),
      (Icons.settings_rounded, AppStrings.settings),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFancy ? 0.24 : 0.18),
            blurRadius: isFancy ? 26 : 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: c.primary.withValues(alpha: isFancy ? 0.10 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isFancy ? 18 : 12,
            sigmaY: isFancy ? 18 : 12,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.card.withValues(alpha: isFancy ? 0.48 : 0.62),
              borderRadius: borderRadius,
              border: Border.all(
                color: c.glassBorder.withValues(alpha: isFancy ? 0.72 : 0.48),
                width: 0.7,
              ),
            ),
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _NavigationItem(
                      icon: tabs[i].$1,
                      label: tabs[i].$2,
                      active: currentIndex == i,
                      isFancy: isFancy,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.isFancy,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool isFancy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 52,
              decoration: BoxDecoration(
                color:
                    active
                        ? c.textPrimary.withValues(alpha: isFancy ? 0.17 : 0.13)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: AnimatedScale(
                  scale: active ? 1.08 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    icon,
                    size: active ? 25 : 23,
                    color: active ? c.textPrimary : c.textTertiary,
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
