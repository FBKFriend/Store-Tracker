import 'package:shared_preferences/shared_preferences.dart';

enum AuthMode { none, guest, google }

class AppPrefs {
  AppPrefs._(this._prefs);
  final SharedPreferences _prefs;

  static const currentTermsVersion = 1;
  static const _kTermsVersion = 'terms_accepted_version';
  static const _kAuthMode = 'auth_mode';

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

  // TEMPORARY: for testing the first-run flow, remove later
  Future<void> resetForTesting() => _prefs.clear();
}
