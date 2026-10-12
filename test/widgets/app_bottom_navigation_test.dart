import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/providers/theme_provider.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/widgets/app_bottom_navigation.dart';
import 'package:muziczz/core/app_strings.dart';

void main() {
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
