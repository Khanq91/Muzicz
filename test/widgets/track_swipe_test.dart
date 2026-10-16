import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/widgets/dock_motion.dart';
import 'package:muziczz/widgets/track_swipe.dart';

void main() {
  testWidgets(
    'dock follows swipe, canceled drag keeps track, committed drag changes once',
    (tester) async {
      var next = 0;
      var previous = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 120,
                child: DockMotion(
                  expanded: true,
                  child: TrackSwipe(
                    onNext: () async {
                      next++;
                    },
                    onPrevious: () async {
                      previous++;
                    },
                    child: const ColoredBox(
                      color: Colors.blue,
                      child: Center(child: Text('track')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      double scale() =>
          tester
              .widget<Transform>(
                find.byKey(const ValueKey('dock-interaction-scale')),
              )
              .transform
              .storage[0];
      final small = await tester.startGesture(
        tester.getCenter(find.text('track')),
      );
      await small.moveBy(const Offset(-20, 0));
      await small.moveBy(const Offset(-25, 0));
      await tester.pump();
      expect(scale(), lessThan(1));
      await tester.pump(const Duration(milliseconds: 200));
      await small.up();
      await tester.pumpAndSettle();
      expect(next, 0);
      expect(previous, 0);
      expect(scale(), closeTo(1, 0.001));
      final large = await tester.startGesture(
        tester.getCenter(find.text('track')),
      );
      await large.moveBy(const Offset(-20, 0));
      await large.moveBy(const Offset(-110, 0));
      await tester.pump();
      expect(scale(), lessThan(0.98));
      await large.up();
      await tester.pumpAndSettle();
      expect(next, 1);
      expect(previous, 0);
      expect(scale(), closeTo(1, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('removing a swipe during settling disposes cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 56,
            child: TrackSwipe(
              onNext: () async {},
              onPrevious: () async {},
              child: const Text('track'),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.text('track'), const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
