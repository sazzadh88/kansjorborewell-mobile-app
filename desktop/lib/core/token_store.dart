import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web/cross-platform token store using SharedPreferences
class SharedPreferencesTokenStore implements TokenStore {
  const SharedPreferencesTokenStore();

  @override
  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
