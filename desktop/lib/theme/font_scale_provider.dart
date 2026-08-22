import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final fontScaleProvider = NotifierProvider<FontScaleNotifier, double>(
  FontScaleNotifier.new,
);

class FontScaleNotifier extends Notifier<double> {
  static const _key = 'app_font_scale';
  static const min = 0.8;
  static const max = 1.4;

  @override
  double build() {
    _loadFromPrefs();
    return 1.0;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_key);
      if (saved != null && saved >= min && saved <= max) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setScale(double scale) async {
    state = scale.clamp(min, max);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, state);
    } catch (_) {}
  }
}
