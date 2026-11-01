// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../auth/google_auth_service.dart';
import '../storage/app_prefs.dart';
import 'backup_models.dart';
import 'backup_service.dart';

/// Decides *when* to back up: shortly after changes, when leaving the app,
/// when the internet comes back, and again after a failure.
class AutoBackupService extends ChangeNotifier with WidgetsBindingObserver {
  AutoBackupService({
    required BackupService backup,
    required GoogleAuthService auth,
    required AppPrefs prefs,
    required List<Listenable> watch,
  }) : _backup = backup,
       _auth = auth,
       _prefs = prefs,
       _watch = watch;

  final BackupService _backup;
  final GoogleAuthService _auth;
  final AppPrefs _prefs;
  final List<Listenable> _watch;

  static const _quietTime = Duration(seconds: 60);
  static const _retryMinutes = [2, 5, 15, 30];

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connection;
  bool _started = false;
  bool _running = false;
  int _failures = 0;
  String _status = '';
  bool _problem = false;

  bool get enabled => _prefs.autoBackupEnabled;
  bool get wifiOnly => _prefs.backupWifiOnly;

  /// Empty when everything is fine; otherwise why a backup is waiting or failed.
  String get statusText => _status;
  bool get hasProblem => _problem;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    for (final source in _watch) {
      source.addListener(_onDataChanged);
    }
    _auth.addListener(() => _schedule(const Duration(seconds: 5)));
    _connection = Connectivity().onConnectivityChanged.listen((_) {
      _failures = 0;
      _schedule(const Duration(seconds: 5));
    });
    _schedule(const Duration(seconds: 10));
  }

  void _onDataChanged() => _schedule(_quietTime);

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _schedule(const Duration(seconds: 3)); // leaving the app: back up soon
    } else if (state == AppLifecycleState.resumed) {
      _schedule(const Duration(seconds: 5));
    }
  }

  Future<void> setEnabled(bool value) async {
    await _prefs.setAutoBackupEnabled(value);
    _setStatus('', false);
    if (value) _schedule(const Duration(seconds: 2));
    notifyListeners();
  }

  Future<void> setWifiOnly(bool value) async {
    await _prefs.setBackupWifiOnly(value);
    _setStatus('', false);
    _schedule(const Duration(seconds: 2));
    notifyListeners();
  }

  void retryNow() {
    _failures = 0;
    _schedule(const Duration(seconds: 1));
  }

  void _setStatus(String text, bool problem) {
    if (_status == text && _problem == problem) return;
    _status = text;
    _problem = problem;
    notifyListeners();
  }

  Future<void> _run() async {
    if (_running) return;
    if (!enabled || !_auth.isSignedIn) {
      _setStatus('', false);
      return;
    }
    _running = true;
    try {
      if (_prefs.cloudCheckPending) {
        _setStatus('Waiting for you to choose which data to keep.', false);
        return;
      }
      if (!_auth.hasSession) {
        if (_auth.sessionChecked) {
          _setStatus(
            'Backup paused. Open More → Backup and tap Reconnect.',
            true,
          );
        } else {
          _setStatus('Reconnecting to Google...', false);
        }
        return;
      }
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online) {
        _setStatus(
          'Waiting for internet. It will back up when you\'re online.',
          false,
        );
        return;
      }
      final onWifi =
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      if (wifiOnly && !onWifi) {
        _setStatus('Waiting for Wi-Fi.', false);
        return;
      }
      await _backup.sync();
      _failures = 0;
      _setStatus('', false);
    } on BackupException catch (e) {
      _failures++;
      _setStatus('Last attempt failed: ${e.message}', true);
      final index = _failures > _retryMinutes.length
          ? _retryMinutes.length - 1
          : _failures - 1;
      _schedule(Duration(minutes: _retryMinutes[index]));
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connection?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final source in _watch) {
      source.removeListener(_onDataChanged);
    }
    super.dispose();
  }
}
