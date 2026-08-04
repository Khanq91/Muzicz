import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MusicVisualMode {
  normal('normal', 'Bình thường'),
  fancy('fancy', 'Xịn xò');

  const MusicVisualMode(this.key, this.label);

  final String key;
  final String label;

  bool get enablesReactiveVisual => this == MusicVisualMode.fancy;
}

class VisualModeProvider extends ChangeNotifier {
  VisualModeProvider() {
    _loadSaved();
  }

  static const _prefKey = 'music_visual_mode';

  MusicVisualMode _mode = MusicVisualMode.normal;
  MusicVisualMode get mode => _mode;

  Future<void> setMode(MusicVisualMode mode) async {
    if (_mode == mode) return;

    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.key);
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == null) return;

    final found =
        MusicVisualMode.values.where((mode) => mode.key == saved).firstOrNull;
    if (found == null || found == _mode) return;

    _mode = found;
    notifyListeners();
  }
}
