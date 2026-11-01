
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferences {
  static const String _themeKey = 'is_dark_mode';

  static Future<bool> loadIsDark() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getBool(_themeKey) ?? false;
  }

  static Future<void> saveIsDark(bool isDark) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(_themeKey, isDark);
  }
}
