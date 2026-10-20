import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/widgets/depth_page_transition.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('page push/pop retains background; reduced=$reduced', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                for (final platform in TargetPlatform.values)
                  platform: const DepthPageTransitionsBuilder(),
              },
            ),
          ),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: child!,
              ),
          home: const Scaffold(body: Center(child: Text('Root page'))),
        ),
      );
      final initial = tester.getCenter(find.text('Root page'));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder:
              (_) => const Scaffold(body: Center(child: Text('Detail page'))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      if (!reduced) {
        expect(
          tester.getCenter(find.text('Root page')).dx,
          lessThan(initial.dx),
        );
        expect(
          tester.getCenter(find.text('Detail page')).dx,
          greaterThan(initial.dx),
        );
      } else {
        expect(tester.getCenter(find.text('Detail page')).dx, initial.dx);
      }
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Root page'), findsOneWidget);
      expect(find.text('Detail page'), findsNothing);
      expect(tester.getCenter(find.text('Root page')), initial);
    });
  }
}
