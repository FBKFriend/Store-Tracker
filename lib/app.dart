import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/security/pin_controller.dart';
import 'core/settings/settings_controller.dart';
import 'core/storage/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/legal/terms_screen.dart';
import 'features/security/lock_screen.dart';
import 'features/shell/start_flow.dart';
import 'features/splash/splash_screen.dart';

class StoreApp extends StatelessWidget {
  final AppPrefs prefs;
  const StoreApp({super.key, required this.prefs});

  Widget _startScreen(BuildContext context) {
    if (!prefs.termsAccepted) return TermsScreen(prefs: prefs);
    if (prefs.authMode == AuthMode.none) return LoginScreen(prefs: prefs);
    if (context.read<PinController>().isEnabled) {
      return LockScreen(prefs: prefs);
    }
    return homeScreenFor(prefs);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      title: 'My Sari-Sari Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      home: SplashScreen(next: _startScreen(context)),
    );
  }
}
