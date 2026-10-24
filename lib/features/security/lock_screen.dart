import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/security/pin_controller.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_logo.dart';
import '../shell/start_flow.dart';
import 'create_pin_screen.dart';
import 'pin_check_view.dart';

/// Shown every time the app is opened while the PIN lock is on.
class LockScreen extends StatelessWidget {
  final AppPrefs prefs;
  const LockScreen({super.key, required this.prefs});

  void _unlock(BuildContext context) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => homeScreenFor(prefs)));
  }

  Future<void> _forgot(BuildContext context) async {
    final reset = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const ForgotPinScreen()));
    if (reset == true && context.mounted) _unlock(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storeName = context.watch<SettingsController>().displayStoreName;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 80),
                const SizedBox(height: 12),
                Text(storeName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Enter your PIN', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                PinCheckView(
                  allowBiometric: true,
                  onSuccess: () => _unlock(context),
                  onForgot: () => _forgot(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Confirm your PIN" before changing security settings. Pops true on success.
class VerifyPinScreen extends StatelessWidget {
  const VerifyPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter your PIN')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: PinCheckView(
              onSuccess: () => Navigator.of(context).pop(true),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reset the PIN by answering the recovery question. Pops true when done.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _answer = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = context.read<PinController>();
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await pin.checkAnswer(_answer.text);
    if (!mounted) return;
    switch (result) {
      case PinResult.ok:
        {
          final newPin = await navigator.push<String>(
            MaterialPageRoute(
              builder: (_) => const CreatePinScreen(title: 'Choose a new PIN'),
            ),
          );
          if (newPin != null) {
            await pin.changePin(newPin);
            navigator.pop(true);
          } else if (mounted) {
            setState(() => _busy = false);
          }
        }
      case PinResult.wrong:
        setState(() {
          _busy = false;
          _error = 'That isn\'t the answer you saved.';
        });
      case PinResult.lockedOut:
        setState(() {
          _busy = false;
          _error = 'Too many tries. Wait a little and try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = context.read<PinController>().question;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot PIN')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Answer your recovery question:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(question, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _answer,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Your answer',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
