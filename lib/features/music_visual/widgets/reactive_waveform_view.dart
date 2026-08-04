import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/visual_feature_flag.dart';
import '../providers/visual_mode_provider.dart';

class ReactiveWaveformView extends StatelessWidget {
  const ReactiveWaveformView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kMusicVisualFeatureEnabled) return const SizedBox.shrink();

    final enabled = context.select<VisualModeProvider, bool>(
      (provider) => provider.mode.enablesReactiveVisual,
    );
    if (!enabled) return const SizedBox.shrink();

    // Empty Phase 0.5 placeholder. No ticker, controller, extraction, or painter.
    return const SizedBox(height: 48);
  }
}
