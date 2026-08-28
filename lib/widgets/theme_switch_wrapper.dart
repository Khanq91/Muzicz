import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class ThemeSwitchWrapper extends StatefulWidget {
  const ThemeSwitchWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<ThemeSwitchWrapper> createState() => _ThemeSwitchWrapperState();
}

class _ThemeSwitchWrapperState extends State<ThemeSwitchWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _barrierOpacity;
  int? _lastVisualRevision;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _barrierOpacity = Tween<double>(begin: 0, end: 0.45).animate(_opacity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = context.read<ThemeProvider>();
    final currentVisualRevision = themeProvider.visualRevision;

    // Khi một lựa chọn đồ họa thay đổi → chạy flash overlay
    if (_lastVisualRevision != null &&
        _lastVisualRevision != currentVisualRevision) {
      _runFlash();
    }
    _lastVisualRevision = currentVisualRevision;
  }

  Future<void> _runFlash() async {
    await _ctrl.forward();
    await _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ThemeProvider để trigger didChangeDependencies
    context.watch<ThemeProvider>();

    return Stack(
      children: [
        widget.child,
        // Overlay đen mờ fade-in/out khi switch theme.
        // FadeTransition animates an OpacityLayer on the compositor instead of
        // rebuilding an Opacity widget (full-screen saveLayer) every tick while
        // the whole tree is already rebuilding for the theme change. The
        // AnimatedBuilder only toggles hit-testing so the barrier is present
        // exactly while the flash is visible, as before.
        AnimatedBuilder(
          animation: _ctrl,
          child: FadeTransition(
            opacity: _barrierOpacity,
            child: const ModalBarrier(color: Colors.black),
          ),
          builder:
              (_, child) =>
                  IgnorePointer(ignoring: _ctrl.value == 0, child: child),
        ),
      ],
    );
  }
}
