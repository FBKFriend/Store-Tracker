import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_auth_service.dart';
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

/// Reset the PIN by answering the recovery question, or by choosing the Google
/// account again. Pops true when done.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _answer = TextEditingController();
  String? _error;
  String? _googleError;
  bool _busy = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  // Choose a new PIN, save it, and finish
  Future<void> _chooseNewPin() async {
    final pin = context.read<PinController>();
    final navigator = Navigator.of(context);
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

  Future<void> _submitAnswer() async {
    final pin = context.read<PinController>();
    setState(() {
      _busy = true;
      _error = null;
      _googleError = null;
    });
    final result = await pin.checkAnswer(_answer.text);
    if (!mounted) return;
    switch (result) {
      case PinResult.ok:
        await _chooseNewPin();
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

  Future<void> _resetWithGoogle() async {
    final auth = context.read<GoogleAuthService>();
    setState(() {
      _busy = true;
      _error = null;
      _googleError = null;
    });
    final result = await auth.verifyIdentity();
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _googleError = result.cancelled ? null : result.message;
      });
      return;
    }
    await _chooseNewPin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = context.read<PinController>().question;
    final auth = context.watch<GoogleAuthService>();
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
            decoration: InputDecoration(
              labelText: 'Your answer',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submitAnswer(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _submitAnswer,
              child: const Text('Continue'),
            ),
          ),
          if (auth.isSignedIn) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: theme.textTheme.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _resetWithGoogle,
              icon: const Icon(Icons.account_circle_outlined),
              label: Text('Reset with Google (${auth.email})'),
            ),
            if (_googleError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _googleError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
