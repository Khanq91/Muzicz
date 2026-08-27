// Auditz screenshot capture — copy to test/auditz_screens_test.dart and edit `screens`.
//
// Renders each registered screen at 3 sizes x light/dark x textScale 1.0/1.3
// as golden PNGs, headless (no device, works in CI).
//
// Generate:  flutter test --update-goldens test/auditz_screens_test.dart
// Audit:     python auditz.py visual test/goldens/auditz --path .
//
// Notes:
// - Wrap providers/mocks your screens need inside `wrap` below.
// - Screens doing real network calls should get fake repositories here;
//   goldens must be deterministic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1) EDIT: your app's themes.
final ThemeData _light = ThemeData.light(useMaterial3: true);
final ThemeData _dark = ThemeData.dark(useMaterial3: true);

// 2) EDIT: register the screens to audit.
final Map<String, WidgetBuilder> screens = {
  // 'home': (_) => const HomeScreen(),
  // 'settings': (_) => const SettingsScreen(),
};

// 3) EDIT if needed: global wrapper (ProviderScope, localization, mocks...).
Widget wrap(Widget child, {required Brightness brightness, required double textScale}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _light,
    darkTheme: _dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: c!,
    ),
    home: child,
  );
}

const _sizes = [Size(360, 640), Size(430, 932), Size(834, 1194)];
const _scales = [1.0, 1.3];

void main() {
  for (final entry in screens.entries) {
    for (final size in _sizes) {
      for (final brightness in Brightness.values) {
        for (final scale in _scales) {
          final b = brightness == Brightness.dark ? 'dark' : 'light';
          final name =
              '${entry.key}__${size.width.toInt()}x${size.height.toInt()}_${b}_ts$scale';
          testWidgets(name, (tester) async {
            tester.view.physicalSize = size * tester.view.devicePixelRatio;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              wrap(Builder(builder: entry.value),
                  brightness: brightness, textScale: scale),
            );
            await tester.pumpAndSettle();
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/auditz/$name.png'),
            );
          });
        }
      }
    }
  }
}
