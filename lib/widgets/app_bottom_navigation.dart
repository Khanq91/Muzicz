import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors_data.dart';
import 'package:muziczz/core/app_strings.dart';

class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.style,
    this.miniPlayer,
  });

  static const double _barHeight = 64;
  static const double _miniPlayerHeight = 56;
  static const double _dividerHeight = 1;
  static const double _bottomMargin = 12;
  static const double _topMargin = 8;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final BottomNavStyle style;
  final Widget? miniPlayer;

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();

  static double bottomOverlayExtent(
    BuildContext context, {
    bool hasMiniPlayer = false,
  }) =>
      MediaQuery.viewPaddingOf(context).bottom +
      _bottomMargin +
      _topMargin +
      _barHeight +
      (hasMiniPlayer ? _miniPlayerHeight + _dividerHeight : 0);

  /// Scroll space needed to bring the last row above the floating dock.
  static double scrollBottomPadding(
    BuildContext context, {
    bool hasMiniPlayer = false,
  }) => bottomOverlayExtent(context, hasMiniPlayer: hasMiniPlayer) + 12;

  static double floatingActionBottom(
    BuildContext context, {
    bool hasMiniPlayer = false,
  }) => scrollBottomPadding(context, hasMiniPlayer: hasMiniPlayer) + 12;
}

class _AppBottomNavigationState extends State<AppBottomNavigation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  Widget? _miniPlayerDuringCollapse;

  @override
  void initState() {
    super.initState();
    _miniPlayerDuringCollapse = widget.miniPlayer;
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.miniPlayer == null ? 0 : 1,
    )..addStatusListener(_onExpansionStatusChanged);
  }

  @override
  void didUpdateWidget(covariant AppBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.miniPlayer != null) {
      _miniPlayerDuringCollapse = widget.miniPlayer;
      if (oldWidget.miniPlayer == null) _expandController.forward();
    } else if (oldWidget.miniPlayer != null) {
      _expandController.reverse();
    }
  }

  void _onExpansionStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && widget.miniPlayer == null) {
      setState(() => _miniPlayerDuringCollapse = null);
    }
  }

  @override
  void dispose() {
    _expandController
      ..removeStatusListener(_onExpansionStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expandController,
      builder: (context, _) {
        final progress = Curves.easeOutCubic.transform(_expandController.value);
        final expandedExtent =
            (AppBottomNavigation._miniPlayerHeight +
                AppBottomNavigation._dividerHeight) *
            progress;
        final miniPlayerHeight =
            expandedExtent
                .clamp(0.0, AppBottomNavigation._miniPlayerHeight)
                .toDouble();
        final dividerHeight =
            (expandedExtent - AppBottomNavigation._miniPlayerHeight)
                .clamp(0.0, AppBottomNavigation._dividerHeight)
                .toDouble();
        final dockHeight = AppBottomNavigation._barHeight + expandedExtent;
        final isFancy = widget.style == BottomNavStyle.fancy;
        final miniPlayer = widget.miniPlayer ?? _miniPlayerDuringCollapse;
        final collapsedExtent = AppBottomNavigation.bottomOverlayExtent(
          context,
        );

        return SizedBox(
          key: ValueKey(
            isFancy
                ? 'premium-glass-bottom-navigation'
                : 'normal-bottom-navigation',
          ),
          height: collapsedExtent + expandedExtent,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              AppBottomNavigation._topMargin,
              16,
              AppBottomNavigation._bottomMargin +
                  MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final collapsedWidth =
                      constraints.maxWidth.clamp(0.0, 232.0).toDouble();
                  final dockWidth =
                      collapsedWidth +
                      (constraints.maxWidth - collapsedWidth) * progress;
                  final dock = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (miniPlayer != null && miniPlayerHeight > 0)
                        SizedBox(
                          width: double.infinity,
                          height: miniPlayerHeight,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.bottomCenter,
                              minHeight: AppBottomNavigation._miniPlayerHeight,
                              maxHeight: AppBottomNavigation._miniPlayerHeight,
                              child: SizedBox(
                                height: AppBottomNavigation._miniPlayerHeight,
                                child: Opacity(
                                  opacity: progress,
                                  child: miniPlayer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (dividerHeight > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Container(
                            height: dividerHeight,
                            color: context.appColors.divider,
                          ),
                        ),
                      SizedBox(
                        key: const ValueKey('navigation-row'),
                        height: AppBottomNavigation._barHeight,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 232),
                            child: SizedBox(
                              width: double.infinity,
                              height: AppBottomNavigation._barHeight,
                              child: _FloatingNavigationPill(
                                currentIndex: widget.currentIndex,
                                onTap: widget.onTap,
                                isFancy: isFancy,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );

                  return SizedBox(
                    width: dockWidth,
                    height: dockHeight,
                    child: _DockSurface(
                      isFancy: isFancy,
                      height: dockHeight,
                      child: dock,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DockSurface extends StatelessWidget {
  const _DockSurface({
    required this.child,
    required this.isFancy,
    required this.height,
  });

  final Widget child;
  final bool isFancy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final borderRadius = BorderRadius.circular(30);
    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: c.isDark ? (isFancy ? 0.25 : 0.18) : (isFancy ? 0.09 : 0.06),
        ),
        blurRadius: isFancy ? 26 : 20,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: c.primary.withValues(
          alpha: c.isDark ? (isFancy ? 0.12 : 0.06) : 0.04,
        ),
        blurRadius: 22,
        offset: const Offset(0, 2),
      ),
    ];

    if (isFancy) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadow,
        ),
        child: GlassCard(
          key: const ValueKey('liquid-glass-bottom-dock'),
          height: height,
          padding: EdgeInsets.zero,
          useOwnLayer: true,
          quality: GlassQuality.premium,
          shape: const LiquidRoundedSuperellipse(borderRadius: 30),
          clipBehavior: Clip.antiAlias,
          settings: LiquidGlassSettings(
            glassColor:
                c.isDark
                    ? c.glassBg.withValues(alpha: 0.04)
                    : c.surface.withValues(alpha: 0.78),
            thickness: 34,
            blur: 2,
            lightIntensity: c.isDark ? 0.52 : 0.25,
            chromaticAberration: 0.025,
            ambientStrength: 0.14,
            ambientRim: 0.16,
            refractiveIndex: 1.28,
            saturation: 1.4,
            glowIntensity: c.isDark ? 0.9 : 0.2,
          ),
          child: child,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: c.card.withValues(alpha: c.isDark ? 0.62 : 0.9),
              borderRadius: borderRadius,
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: c.glassBorder.withValues(alpha: c.isDark ? 0.48 : 0.16),
                width: 0.7,
              ),
            ),
            child: child,
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
    final tabs = [
      (Icons.library_music_rounded, AppStrings.library),
      (Icons.home_rounded, AppStrings.tabHome),
      (Icons.settings_rounded, AppStrings.settings),
    ];

    return Padding(
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
