import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/app_prefs.dart';
import 'pin_crypto.dart';

enum PinResult { ok, wrong, lockedOut }

class PinController extends ChangeNotifier {
  PinController(AppPrefs prefs) : _p = prefs.raw;
  final SharedPreferences _p;

  static const _kHash = 'pin_hash';
  static const _kSalt = 'pin_salt';
  static const _kQuestion = 'pin_question';
  static const _kAnswerHash = 'pin_answer_hash';
  static const _kAnswerSalt = 'pin_answer_salt';
  static const _kBiometric = 'pin_biometric';
  static const _kFailed = 'pin_failed';
  static const _kLockUntil = 'pin_lock_until';

  static const maxTries = 5;
  static const lockoutTime = Duration(seconds: 30);

  bool get isEnabled => (_p.getString(_kHash) ?? '').isNotEmpty;
  bool get biometricEnabled => isEnabled && (_p.getBool(_kBiometric) ?? false);
  String get question => _p.getString(_kQuestion) ?? '';

  /// How long the pad stays locked after too many wrong tries.
  Duration get lockoutRemaining {
    final until = _p.getInt(_kLockUntil) ?? 0;
    final left = until - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  String _normalize(String answer) => answer.trim().toLowerCase();

  Future<void> _storePin(String pin) async {
    final salt = PinCrypto.newSalt();
    await _p.setString(_kSalt, salt);
    await _p.setString(_kHash, PinCrypto.hash(pin, salt));
  }

  Future<void> _storeRecovery(String question, String answer) async {
    final salt = PinCrypto.newSalt();
    await _p.setString(_kQuestion, question.trim());
    await _p.setString(_kAnswerSalt, salt);
    await _p.setString(_kAnswerHash, PinCrypto.hash(_normalize(answer), salt));
  }

  Future<void> _clearFailures() async {
    await _p.remove(_kFailed);
    await _p.remove(_kLockUntil);
  }

  Future<void> setUp({
    required String pin,
    required String question,
    required String answer,
  }) async {
    await _storePin(pin);
    await _storeRecovery(question, answer);
    await _clearFailures();
    notifyListeners();
  }

  Future<void> changePin(String pin) async {
    await _storePin(pin);
    await _clearFailures();
    notifyListeners();
  }

  Future<void> updateRecovery({
    required String question,
    required String answer,
  }) async {
    await _storeRecovery(question, answer);
    notifyListeners();
  }

  Future<void> setBiometric(bool value) async {
    await _p.setBool(_kBiometric, value);
    notifyListeners();
  }

  Future<void> turnOff() async {
    for (final key in [
      _kHash,
      _kSalt,
      _kQuestion,
      _kAnswerHash,
      _kAnswerSalt,
      _kBiometric,
      _kFailed,
      _kLockUntil,
    ]) {
      await _p.remove(key);
    }
    notifyListeners();
  }

  // Counts wrong tries; every 5th wrong try locks the pad for 30 seconds.
  Future<PinResult> _attempt(bool correct) async {
    if (lockoutRemaining > Duration.zero) return PinResult.lockedOut;
    if (correct) {
      await _clearFailures();
      return PinResult.ok;
    }
    final failed = (_p.getInt(_kFailed) ?? 0) + 1;
    await _p.setInt(_kFailed, failed);
    if (failed % maxTries == 0) {
      final until = DateTime.now().add(lockoutTime).millisecondsSinceEpoch;
      await _p.setInt(_kLockUntil, until);
      return PinResult.lockedOut;
    }
    return PinResult.wrong;
  }

  Future<PinResult> checkPin(String pin) {
    final salt = _p.getString(_kSalt) ?? '';
    final stored = _p.getString(_kHash) ?? '';
    return _attempt(PinCrypto.hash(pin, salt) == stored);
  }

  Future<PinResult> checkAnswer(String answer) {
    final salt = _p.getString(_kAnswerSalt) ?? '';
    final stored = _p.getString(_kAnswerHash) ?? '';
    return _attempt(PinCrypto.hash(_normalize(answer), salt) == stored);
  }
}
