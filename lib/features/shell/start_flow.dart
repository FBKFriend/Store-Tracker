import 'package:flutter/material.dart';

import '../../core/storage/app_prefs.dart';
import 'main_shell.dart';
import 'store_name_screen.dart';

/// Where to go once the user has chosen guest or Google: the store-name
/// question the first time, the main screen after that.
Widget homeScreenFor(AppPrefs prefs) {
  // TODO (backup step): skip the question when a saved file is restored
  return prefs.storeNameAsked
      ? MainShell(prefs: prefs)
      : StoreNameScreen(prefs: prefs);
}
