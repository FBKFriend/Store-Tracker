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
  static const _kBackupHash = 'backup_hash';
  static const _kAutoBackup = 'auto_backup';
  static const _kWifiOnly = 'backup_wifi_only';
  static const _kDataCheckDone = 'data_check_done';

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

  /// Fingerprint of the data last uploaded to Drive.
  String get backupHash => _prefs.getString(_kBackupHash) ?? '';
  Future<void> setBackupHash(String hash) =>
      _prefs.setString(_kBackupHash, hash);

  bool get autoBackupEnabled => _prefs.getBool(_kAutoBackup) ?? true;
  Future<void> setAutoBackupEnabled(bool value) =>
      _prefs.setBool(_kAutoBackup, value);

  bool get backupWifiOnly => _prefs.getBool(_kWifiOnly) ?? false;
  Future<void> setBackupWifiOnly(bool value) =>
      _prefs.setBool(_kWifiOnly, value);

  /// True once the first-open check for saved data has run.
  bool get dataCheckDone => _prefs.getBool(_kDataCheckDone) ?? false;
  Future<void> markDataCheckDone() => _prefs.setBool(_kDataCheckDone, true);

  // TEMPORARY: for testing the first-run flow, remove later
  Future<void> resetForTesting() => _prefs.clear();
}
