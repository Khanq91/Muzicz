import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/providers/theme_provider.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/widgets/app_bottom_navigation.dart';
import 'package:muziczz/core/app_strings.dart';

void main() {
  for (final style in BottomNavStyle.values) {
    testWidgets('dock reveals a full height player without overflow: $style', (
      tester,
    ) async {
      var showPlayer = false;
      late StateSetter rebuild;
      const playerKey = ValueKey('test-mini-player');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(AppColorPresets.dark),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                bottomNavigationBar: AppBottomNavigation(
                  currentIndex: 1,
                  onTap: _ignoreTap,
                  style: style,
                  miniPlayer:
                      showPlayer
                          ? const SizedBox(
                            key: playerKey,
                            height: 56,
                            child: Column(children: [SizedBox(height: 56)]),
                          )
                          : null,
                ),
              );
            },
          ),
        ),
      );
      final nav = find.byKey(const ValueKey('navigation-row'));
      final initialBottom = tester.getBottomLeft(nav).dy;
      rebuild(() => showPlayer = true);
      await tester.pump();
      for (var frame = 0; frame < 22; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(playerKey)).height, 56);
        expect(tester.getBottomLeft(nav).dy, closeTo(initialBottom, 0.01));
      }
      rebuild(() => showPlayer = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      // Reopening during collapse must reverse cleanly.
      rebuild(() => showPlayer = true);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(playerKey)).height, 56);
      rebuild(() => showPlayer = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      final bounce = tester.widget<Transform>(
        find.byKey(const ValueKey('dock-collapse-bounce')),
      );
      expect(bounce.transform.entry(0, 0), lessThan(1));
      expect(bounce.transform.entry(1, 1), lessThan(1));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('dock-collapse-bounce')),
            )
            .transform
            .entry(0, 0),
        1,
      );
      expect(find.byKey(playerKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('normal style shows an icon-only floating navigation', (
    tester,
  ) async {
    int? selectedIndex;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(AppColorPresets.dark),
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: 1,
            onTap: (index) => selectedIndex = index,
            style: BottomNavStyle.normal,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('normal-bottom-navigation')), findsOne);
    expect(find.text(AppStrings.tabHome), findsNothing);
    expect(find.text('Trực tuyến'), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.library_music_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    expect(selectedIndex, 2);
  });

  testWidgets('fancy style shows the same icon-only navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(AppColorPresets.dark),
        home: const Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: 1,
            onTap: _ignoreTap,
            style: BottomNavStyle.fancy,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('premium-glass-bottom-navigation')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('liquid-glass-bottom-dock')), findsOne);
    expect(find.text(AppStrings.tabHome), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.library_music_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });
}

void _ignoreTap(int _) {}
