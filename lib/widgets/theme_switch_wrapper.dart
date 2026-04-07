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
  AppThemeMode? _lastMode;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = context.read<ThemeProvider>();
    final currentMode = themeProvider.mode;

    // Khi mode thay đổi → chạy flash overlay
    if (_lastMode != null && _lastMode != currentMode) {
      _runFlash();
    }
    _lastMode = currentMode;
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
        // Overlay đen mờ fade-in/out khi switch theme
        AnimatedBuilder(
          animation: _opacity,
          builder: (_, __) => _opacity.value > 0
              ? Opacity(
            opacity: _opacity.value * 0.45,
            child: const ModalBarrier(color: Colors.black),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}