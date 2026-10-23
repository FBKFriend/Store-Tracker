import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_logo.dart';
import 'main_shell.dart';

class StoreNameScreen extends StatefulWidget {
  final AppPrefs prefs;
  const StoreNameScreen({super.key, required this.prefs});

  @override
  State<StoreNameScreen> createState() => _StoreNameScreenState();
}

class _StoreNameScreenState extends State<StoreNameScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool skip}) async {
    setState(() => _saving = true);
    final settings = context.read<SettingsController>();
    final navigator = Navigator.of(context);
    if (skip) {
      await settings.skipStoreName();
    } else {
      await settings.setStoreName(_controller.text);
    }
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => MainShell(prefs: widget.prefs)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canContinue = !_saving && _controller.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            const Center(child: AppLogo(size: 100)),
            const SizedBox(height: 24),
            Text(
              'Name your store',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'It shows on your printed lists and reports. '
              'You can change it later in Settings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Store name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (canContinue) _finish(skip: false);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: canContinue ? () => _finish(skip: false) : null,
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => _finish(skip: true),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
