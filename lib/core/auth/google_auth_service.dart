import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../storage/app_prefs.dart';

class AuthResult {
  final bool ok;
  final bool cancelled;
  final String? message;

  const AuthResult.success() : ok = true, cancelled = false, message = null;
  const AuthResult.cancelled() : ok = false, cancelled = true, message = null;
  const AuthResult.failed(this.message) : ok = false, cancelled = false;
}

class GoogleAuthService extends ChangeNotifier {
  GoogleAuthService(this._prefs);
  final AppPrefs _prefs;

  /// The *Web application* client ID from Google Cloud (not the Android one).
  static const serverClientId =
      '587170301926-vp094fijiq2cbaqbmm4nbdkfkf515lib.apps.googleusercontent.com';

  /// Lets the app keep its own private backup files in the user's Drive.
  static const driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const _scopes = [driveAppDataScope];

  bool _initialized = false;
  GoogleSignInAccount? _account;
  bool _sessionChecked = false;

  /// True when the app is connected to the Google account right now.
  bool get hasSession => _account != null;

  /// True once the app has tried to reconnect since it was opened.
  bool get sessionChecked => _sessionChecked;

  bool get isSignedIn => _prefs.authMode == AuthMode.google;
  String get email => _prefs.googleEmail;
  String get name => _prefs.googleName;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  Future<AuthResult> signIn() async {
    if (serverClientId.startsWith('PASTE')) {
      return const AuthResult.failed(
        'The Web client ID has not been added to the app yet.',
      );
    }
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );
      // Ask for permission to use the app's private Drive folder
      final granted = await account.authorizationClient.authorizationForScopes(
        _scopes,
      );
      if (granted == null) {
        await account.authorizationClient.authorizeScopes(_scopes);
      }
      _account = account;
      _sessionChecked = true;
      await _prefs.setGoogleAccount(
        email: account.email,
        name: account.displayName ?? '',
      );
      await _prefs.setAuthMode(AuthMode.google);
      notifyListeners();
      return const AuthResult.success();
    } on GoogleSignInException catch (e) {
      if (e.code.name == 'canceled') return const AuthResult.cancelled();
      return AuthResult.failed(e.description ?? e.code.name);
    } catch (e) {
      return AuthResult.failed('$e');
    }
  }

  /// Back to guest mode. Local data stays; backups stay in the user's Drive.
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Signing out locally is what matters
    }
    _account = null;
    _sessionChecked = false;
    await _prefs.clearGoogleAccount();
    await _prefs.setAuthMode(AuthMode.guest);
    notifyListeners();
  }

  /// Reconnects after the app was reopened. Android may show an account
  /// chooser. Only the account this phone is signed in with is accepted.
  Future<bool> restoreSession() async {
    if (!isSignedIn) return false;
    if (_account != null) return true;
    var ok = false;
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      ok = _accept(account);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      _sessionChecked = true;
      notifyListeners();
    }
    return ok;
  }

  bool _accept(GoogleSignInAccount? account) {
    if (account == null) return false;
    if (account.email.toLowerCase() != _prefs.googleEmail.toLowerCase()) {
      return false; // a different Google account was chosen
    }
    _account = account;
    _sessionChecked = true;
    notifyListeners();
    return true;
  }

  /// Connects again by choosing the account (the Reconnect button).
  Future<AuthResult> reconnect() async {
    if (await restoreSession()) return const AuthResult.success();
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );
      if (!_accept(account)) {
        return AuthResult.failed(
          'Please choose ${_prefs.googleEmail}. That is the account this '
          'phone is signed in with.',
        );
      }
      final granted = await account.authorizationClient.authorizationForScopes(
        _scopes,
      );
      if (granted == null) {
        await account.authorizationClient.authorizeScopes(_scopes);
      }
      return const AuthResult.success();
    } on GoogleSignInException catch (e) {
      if (e.code.name == 'canceled') return const AuthResult.cancelled();
      return AuthResult.failed(e.description ?? e.code.name);
    } catch (e) {
      return AuthResult.failed('$e');
    }
  }

  /// Headers for calling the Drive API, or null if not connected.
  Future<Map<String, String>?> authHeaders() async {
    await restoreSession(); // does nothing if already connected
    final account = _account;
    if (account == null) return null;
    return account.authorizationClient.authorizationHeaders(_scopes);
  }

  // TEMPORARY: checks that the app can reach its private Drive folder
  Future<String> testDriveConnection() async {
    try {
      final headers = await authHeaders();
      if (headers == null) {
        return 'Not signed in, or Drive access was not granted.';
      }
      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files'
          '?spaces=appDataFolder&fields=files(id,name)',
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final files = (jsonDecode(response.body)['files'] as List).length;
        return 'Drive connection works.\nBackup files found: $files';
      }
      return 'Drive answered ${response.statusCode}:\n${response.body}';
    } catch (e) {
      return 'Failed: $e';
    }
  }
}
