import 'package:flutter/material.dart';

import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_logo.dart';
import '../legal/terms_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppPrefs prefs;
  const HomeScreen({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 140),
            const SizedBox(height: 16),
            Text(
              'My Sari-Sari Store',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Mode: ${prefs.authMode.name}'),
            const SizedBox(height: 32),
            // TEMPORARY: remove later
            TextButton(
              onPressed: () async {
                await prefs.resetForTesting();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => TermsScreen(prefs: prefs)),
                );
              },
              child: const Text('Reset first-run (testing only)'),
            ),
          ],
        ),
      ),
    );
  }
}
