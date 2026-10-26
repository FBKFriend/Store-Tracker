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
  static const _kStoreName = 'store_name';
  static const _kStoreNameAsked = 'store_name_asked';
  static const _kGoogleEmail = 'google_email';
  static const _kGoogleName = 'google_name';
  static const _kLastBackup = 'last_backup_at';

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

  /// The underlying storage, for the PIN controller.
  SharedPreferences get raw => _prefs;

  // Settings. Light mode is the default.
  bool get isDark => _prefs.getBool(_kDarkMode) ?? false;
  Future<void> setDark(bool value) => _prefs.setBool(_kDarkMode, value);

  /// In thousandths, so 5000 means "5".
  int get lowStockDefault => _prefs.getInt(_kLowStock) ?? 5000;
  Future<void> setLowStockDefault(int milli) =>
      _prefs.setInt(_kLowStock, milli);

  String get storeName => _prefs.getString(_kStoreName) ?? '';
  Future<void> setStoreName(String name) => _prefs.setString(_kStoreName, name);

  /// True once the user has seen the "name your store" question.
  bool get storeNameAsked => _prefs.getBool(_kStoreNameAsked) ?? false;
  Future<void> markStoreNameAsked() => _prefs.setBool(_kStoreNameAsked, true);

  String get googleEmail => _prefs.getString(_kGoogleEmail) ?? '';
  String get googleName => _prefs.getString(_kGoogleName) ?? '';

  Future<void> setGoogleAccount({
    required String email,
    required String name,
  }) async {
    await _prefs.setString(_kGoogleEmail, email);
    await _prefs.setString(_kGoogleName, name);
  }

  Future<void> clearGoogleAccount() async {
    await _prefs.remove(_kGoogleEmail);
    await _prefs.remove(_kGoogleName);
  }

  DateTime? get lastBackupAt {
    final text = _prefs.getString(_kLastBackup);
    return text == null ? null : DateTime.tryParse(text);
  }

  Future<void> setLastBackupAt(DateTime time) =>
      _prefs.setString(_kLastBackup, time.toIso8601String());

  // TEMPORARY: for testing the first-run flow, remove later
  Future<void> resetForTesting() => _prefs.clear();
}
