import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/widgets/now_playing/wavy_seek_bar.dart';

void main() {
  testWidgets('wave stops when paused, hidden, or reduced motion is enabled', (
    tester,
  ) async {
    Future<void> pump({
      bool playing = true,
      bool visible = true,
      bool reduced = false,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppColorPresets.light]),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: visible,
            child: Scaffold(
              body: WavySeekBar(
                value: .4,
                playing: playing,
                onChanged: (_) {},
                onChangeStart: (_) {},
                onChangeEnd: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await pump(playing: false);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await pump(visible: false);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await pump(reduced: true);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
