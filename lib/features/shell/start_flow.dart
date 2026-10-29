import 'package:flutter/material.dart';

import '../../core/storage/app_prefs.dart';
import 'data_check_screen.dart';
import 'main_shell.dart';
import 'store_name_screen.dart';

/// Where to go once the user has chosen guest or Google: first the check for
/// saved data (first open only), then the store-name question, then the app.
Widget homeScreenFor(AppPrefs prefs) {
  if (!prefs.dataCheckDone) return DataCheckScreen(prefs: prefs);
  return prefs.storeNameAsked
      ? MainShell(prefs: prefs)
      : StoreNameScreen(prefs: prefs);
}
