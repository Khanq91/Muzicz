import 'package:flutter/material.dart';

class FadeTabBarView extends StatefulWidget {
  const FadeTabBarView({
    super.key,
    required this.controller,
    required this.children,
  });
  final TabController controller;
  final List<Widget> children;

  @override
  State<FadeTabBarView> createState() => _FadeTabBarViewState();
}

class _FadeTabBarViewState extends State<FadeTabBarView> {
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _idx = widget.controller.index;
    widget.controller.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (!widget.controller.indexIsChanging) return;
    setState(() => _idx = widget.controller.index);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder:
          (child, anim) => FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(key: ValueKey(_idx), child: widget.children[_idx]),
    );
  }
}
