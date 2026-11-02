import 'package:flutter/material.dart';

import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_logo.dart';
import '../auth/login_screen.dart';
import '../shell/start_flow.dart';
import 'legal_content.dart';

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
                      children: const [LegalContent()],
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
