import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _regionKey = 'default_region';
  static const String _defaultRegion = 'CM';

  static Future<String> getDefaultRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_regionKey) ?? _defaultRegion;
  }

  static Future<void> setDefaultRegion(String region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regionKey, region);
  }
}
