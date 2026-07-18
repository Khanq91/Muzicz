import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors_data.dart';
import '../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════════════════
// AppThemeMode — enum đại diện cho từng preset theme
// ════════════════════════════════════════════════════════════════════════════
enum AppThemeMode {
  dark('dark', 'Dark'),
  amoled('amoled', 'AMOLED'),
  light('light', 'Light');

  const AppThemeMode(this.key, this.label);
  final String key;
  final String label;

  AppColorsData get colors => switch (this) {
    AppThemeMode.dark => AppColorPresets.dark,
    AppThemeMode.amoled => AppColorPresets.amoled,
    AppThemeMode.light => AppColorPresets.light,
  };

  IconData get icon => switch (this) {
    AppThemeMode.dark => Icons.nights_stay_rounded,
    AppThemeMode.amoled => Icons.dark_mode_rounded,
    AppThemeMode.light => Icons.wb_sunny_rounded,
  };

  bool get isDark => this != AppThemeMode.light;
}

enum BottomNavStyle {
  normal('normal', 'Bình thường'),
  fancy('fancy', 'Xịn xò');

  const BottomNavStyle(this.key, this.label);
  final String key;
  final String label;
}

// ════════════════════════════════════════════════════════════════════════════
// ThemeProvider — quản lý theme hiện tại + persist vào SharedPreferences
// ════════════════════════════════════════════════════════════════════════════
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'app_theme_mode';
  static const _bottomNavStylePrefKey = 'bottom_nav_style';

  ThemeProvider() {
    _loadSaved();
  }

  AppThemeMode _mode = AppThemeMode.dark;
  AppThemeMode get mode => _mode;

  BottomNavStyle _bottomNavStyle = BottomNavStyle.normal;
  BottomNavStyle get bottomNavStyle => _bottomNavStyle;

  int _visualRevision = 0;
  int get visualRevision => _visualRevision;

  bool _isSwitching = false;
  bool get isSwitching => _isSwitching;

  AppColorsData get colors => _mode.colors;

  ThemeData get themeData => AppTheme.buildTheme(_mode.colors);

  /// Đổi theme: set cờ isSwitching để UI có thể dùng skeleton/fade,
  /// sau đó apply theme và sync SystemUI overlay style.
  Future<void> setTheme(AppThemeMode mode) async {
    if (_mode == mode) return;

    _isSwitching = true;
    notifyListeners();

    // Nhường frame để overlay kịp render trước khi theme bật
    await Future.delayed(const Duration(milliseconds: 16));

    _mode = mode;
    _visualRevision++;
    _syncSystemUI(mode);
    notifyListeners();

    // Chờ animation xong rồi bỏ cờ
    await Future.delayed(const Duration(milliseconds: 320));
    _isSwitching = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.key);
  }

  Future<void> setBottomNavStyle(BottomNavStyle style) async {
    if (_bottomNavStyle == style) return;

    _isSwitching = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 16));

    _bottomNavStyle = style;
    _visualRevision++;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 320));
    _isSwitching = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bottomNavStylePrefKey, style.key);
  }

  /// Toggle nhanh qua 3 mode
  Future<void> cycleTheme() async {
    final next =
        AppThemeMode.values[(_mode.index + 1) % AppThemeMode.values.length];
    await setTheme(next);
  }

  /// Đồng bộ thanh status bar / navigation bar với theme mới
  void _syncSystemUI(AppThemeMode mode) {
    final isDark = mode.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final found =
          AppThemeMode.values.where((m) => m.key == saved).firstOrNull;
      if (found != null && found != _mode) {
        _mode = found;
        _syncSystemUI(_mode);
        notifyListeners();
      }
    }

    final savedBottomNavStyle = prefs.getString(_bottomNavStylePrefKey);
    if (savedBottomNavStyle != null) {
      final found =
          BottomNavStyle.values
              .where((style) => style.key == savedBottomNavStyle)
              .firstOrNull;
      if (found != null && found != _bottomNavStyle) {
        _bottomNavStyle = found;
        notifyListeners();
      }
    }
  }
}
