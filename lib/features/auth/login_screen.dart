import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/dialogs.dart';
import '../shell/start_flow.dart';

class LoginScreen extends StatelessWidget {
  final AppPrefs prefs;
  const LoginScreen({super.key, required this.prefs});

  Future<void> _signInWithGoogle(BuildContext context) async {
    final auth = context.read<GoogleAuthService>();
    final navigator = Navigator.of(context);
    final result = await auth.signIn();
    if (result.ok) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => homeScreenFor(prefs)),
      );
    } else if (!result.cancelled && context.mounted) {
      await showErrorDialog(context, result.message ?? 'Sign-in failed.');
    }
  }

  Future<void> _continueAsGuest(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Continue as guest?'),
        content: const Text(
          'Your data will be stored only on this phone. If the app is '
          'deleted, or the phone is lost or damaged, your data can\'t be '
          'recovered.\n\nYou can sign in with Google later to turn on backups.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue as guest'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await prefs.setAuthMode(AuthMode.guest);
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => homeScreenFor(prefs)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const AppLogo(size: 120),
              const SizedBox(height: 16),
              Text('My Sari-Sari Store', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Manage your inventory, sales, and utang, even offline.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  onPressed: () => _signInWithGoogle(context),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _continueAsGuest(context),
                  child: const Text('Continue as guest'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
