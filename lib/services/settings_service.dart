import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _regionKey = 'default_region';
  static const String _defaultRegion = 'CM';

  static const String _csvThresholdKey = 'csv_threshold';
  static const int _defaultCsvThreshold = 2500;

  static Future<String> getDefaultRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_regionKey) ?? _defaultRegion;
  }

  static Future<void> setDefaultRegion(String region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regionKey, region);
  }

  static Future<int> getCsvThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_csvThresholdKey) ?? _defaultCsvThreshold;
  }

  static Future<void> setCsvThreshold(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_csvThresholdKey, value);
  }
}
