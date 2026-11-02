import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/widgets/dialogs.dart';

class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({super.key});

  Future<void> _signIn(BuildContext context) async {
    final auth = context.read<GoogleAuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await auth.signIn();
    if (result.ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Signed in as ${auth.email}')),
      );
    } else if (!result.cancelled && context.mounted) {
      await showErrorDialog(context, result.message ?? 'Sign-in failed.');
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<GoogleAuthService>();
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message:
          'This phone goes back to guest mode. Your data stays on this '
          'phone, and your backups stay in your Google Drive.',
      confirmLabel: 'Sign out',
    );
    if (ok) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<GoogleAuthService>();
    if (!auth.isSignedIn) {
      return ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: const Text('Guest'),
        subtitle: const Text(
          'Sign in with Google to back up your data (coming in the next steps).',
        ),
        trailing: FilledButton(
          onPressed: () => _signIn(context),
          child: const Text('Sign in'),
        ),
      );
    }
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle),
          title: Text(auth.name.isEmpty ? auth.email : auth.name),
          subtitle: Text(auth.email),
          trailing: TextButton(
            onPressed: () => _signOut(context),
            child: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}
