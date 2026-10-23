import 'package:flutter/material.dart';

import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_logo.dart';
import '../auth/login_screen.dart';
import '../shell/start_flow.dart';
import 'legal_text.dart';

class TermsScreen extends StatefulWidget {
  final AppPrefs prefs;
  const TermsScreen({super.key, required this.prefs});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;

  Future<void> _continue() async {
    await widget.prefs.acceptTerms();
    if (!mounted) return;
    final next = widget.prefs.authMode == AuthMode.none
        ? LoginScreen(prefs: widget.prefs)
        : homeScreenFor(widget.prefs);
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  Widget _section(ThemeData theme, String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(p, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: AppLogo(size: 72)),
              const SizedBox(height: 12),
              Text('Before you start', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Please read how this app handles your data.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  child: Scrollbar(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _section(theme, 'Privacy', LegalText.privacyPoints),
                        const SizedBox(height: 16),
                        _section(theme, 'Terms of use', LegalText.termsPoints),
                        const SizedBox(height: 8),
                        Text(
                          'Last updated: ${LegalText.lastUpdated}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'I have read and agree to the Privacy and Terms of use',
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _agreed ? _continue : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
