import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'bottom navigation style defaults to normal and persists changes',
    () async {
      final provider = ThemeProvider();

      expect(provider.bottomNavStyle, BottomNavStyle.normal);
      expect(provider.bottomNavStyle.usesLiquidGlass, isFalse);

      await provider.setBottomNavStyle(BottomNavStyle.fancy);

      final prefs = await SharedPreferences.getInstance();
      expect(provider.bottomNavStyle, BottomNavStyle.fancy);
      expect(provider.bottomNavStyle.usesLiquidGlass, isTrue);
      expect(provider.visualRevision, 1);
      expect(prefs.getString('bottom_nav_style'), 'fancy');
    },
  );

  test('saved bottom navigation style is restored', () async {
    SharedPreferences.setMockInitialValues({'bottom_nav_style': 'fancy'});
    final provider = ThemeProvider();
    final loaded = Completer<void>();
    provider.addListener(() {
      if (provider.bottomNavStyle == BottomNavStyle.fancy &&
          !loaded.isCompleted) {
        loaded.complete();
      }
    });

    await loaded.future.timeout(const Duration(seconds: 1));

    expect(provider.bottomNavStyle, BottomNavStyle.fancy);
    expect(provider.visualRevision, 0);
  });
}
