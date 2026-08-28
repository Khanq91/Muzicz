import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:muziczz/providers/theme_provider.dart';
import 'package:muziczz/theme/app_theme.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/widgets/app_bottom_navigation.dart';
import 'package:muziczz/core/app_strings.dart';

void main() {
  testWidgets('normal style keeps the existing navigation behavior', (
    tester,
  ) async {
    int? selectedIndex;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(AppColorPresets.dark),
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: 0,
            onTap: (index) => selectedIndex = index,
            style: BottomNavStyle.normal,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('normal-bottom-navigation')), findsOne);
    expect(find.text(AppStrings.tabHome), findsOneWidget);
    expect(find.text('Trực tuyến'), findsNothing);

    await tester.tap(find.byIcon(Icons.language_rounded));
    expect(selectedIndex, 1);
  });

  testWidgets('fancy style uses the premium liquid glass tab bar', (
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

    final glassTabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(
      find.byKey(const ValueKey('premium-glass-bottom-navigation')),
      findsOne,
    );
    expect(glassTabBar.quality, GlassQuality.premium);
    expect(glassTabBar.maskingQuality, MaskingQuality.high);
    expect(glassTabBar.tabs[0].label, isNull);
    expect(glassTabBar.tabs[1].label, 'Trực tuyến');
    expect(glassTabBar.tabs[2].label, isNull);
  });
}

void _ignoreTap(int _) {}
