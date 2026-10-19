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

  Future<void> setDark(bool value) async {
    await _prefs.setDark(value);
    notifyListeners();
  }

  Future<void> setLowStockDefault(int milli) async {
    await _prefs.setLowStockDefault(milli);
    notifyListeners();
  }
}
