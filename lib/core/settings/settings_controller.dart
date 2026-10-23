import 'package:flutter/material.dart';

import '../storage/app_prefs.dart';

/// App-wide settings. Screens watch this, so changes show up straight away.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  final AppPrefs _prefs;

  bool get isDark => _prefs.isDark;
  ThemeMode get themeMode => isDark ? ThemeMode.dark : ThemeMode.light;

  /// Thousandths: 5000 means "5".
  int get lowStockDefault => _prefs.lowStockDefault;

  String get storeName => _prefs.storeName;

  /// The name for printouts and the dashboard title.
  String get displayStoreName =>
      storeName.trim().isEmpty ? 'My Sari-Sari Store' : storeName.trim();

  bool get storeNameAsked => _prefs.storeNameAsked;

  Future<void> setDark(bool value) async {
    await _prefs.setDark(value);
    notifyListeners();
  }

  Future<void> setLowStockDefault(int milli) async {
    await _prefs.setLowStockDefault(milli);
    notifyListeners();
  }

  Future<void> setStoreName(String name) async {
    await _prefs.setStoreName(name.trim());
    await _prefs.markStoreNameAsked();
    notifyListeners();
  }

  Future<void> skipStoreName() async {
    await _prefs.markStoreNameAsked();
    notifyListeners();
  }
}
