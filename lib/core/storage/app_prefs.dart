import 'package:shared_preferences/shared_preferences.dart';

enum AuthMode { none, guest, google }

class AppPrefs {
  AppPrefs._(this._prefs);
  final SharedPreferences _prefs;

  static const currentTermsVersion = 1;
  static const _kTermsVersion = 'terms_accepted_version';
  static const _kAuthMode = 'auth_mode';
  static const _kDarkMode = 'dark_mode';
  static const _kLowStock = 'low_stock_default';

  static Future<AppPrefs> load() async =>
      AppPrefs._(await SharedPreferences.getInstance());

  bool get termsAccepted =>
      (_prefs.getInt(_kTermsVersion) ?? 0) >= currentTermsVersion;

  Future<void> acceptTerms() =>
      _prefs.setInt(_kTermsVersion, currentTermsVersion);

  AuthMode get authMode {
    switch (_prefs.getString(_kAuthMode)) {
      case 'guest':
        return AuthMode.guest;
      case 'google':
        return AuthMode.google;
      default:
        return AuthMode.none;
    }
  }

  Future<void> setAuthMode(AuthMode mode) =>
      _prefs.setString(_kAuthMode, mode.name);

  // Settings. Light mode is the default.
  bool get isDark => _prefs.getBool(_kDarkMode) ?? false;
  Future<void> setDark(bool value) => _prefs.setBool(_kDarkMode, value);

  /// In thousandths, so 5000 means "5".
  int get lowStockDefault => _prefs.getInt(_kLowStock) ?? 5000;
  Future<void> setLowStockDefault(int milli) =>
      _prefs.setInt(_kLowStock, milli);

  // TEMPORARY: for testing the first-run flow, remove later
  Future<void> resetForTesting() => _prefs.clear();
}
