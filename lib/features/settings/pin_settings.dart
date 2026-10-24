import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/security/pin_controller.dart';
import '../security/create_pin_screen.dart';
import '../security/lock_screen.dart';
import '../security/recovery_setup_screen.dart';

/// The PIN lock switches and buttons inside Settings.
class PinSettingsSection extends StatefulWidget {
  const PinSettingsSection({super.key});

  @override
  State<PinSettingsSection> createState() => _PinSettingsSectionState();
}

class _PinSettingsSectionState extends State<PinSettingsSection> {
  bool _fingerprintAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkFingerprint();
  }

  Future<void> _checkFingerprint() async {
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final types = await auth.getAvailableBiometrics();
      if (mounted) {
        setState(() => _fingerprintAvailable = supported && types.isNotEmpty);
      }
    } catch (_) {
      // No fingerprint option on this phone
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Asks for the current PIN. True if it was entered correctly.
  Future<bool> _confirmCurrentPin() async {
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const VerifyPinScreen()));
    return ok == true && mounted;
  }

  Future<void> _enable() async {
    final pin = context.read<PinController>();
    final navigator = Navigator.of(context);
    final newPin = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const CreatePinScreen()),
    );
    if (newPin == null || !mounted) return;
    final recovery = await navigator.push<Recovery>(
      MaterialPageRoute(builder: (_) => const RecoverySetupScreen()),
    );
    if (recovery == null || !mounted) return;
    await pin.setUp(
      pin: newPin,
      question: recovery.question,
      answer: recovery.answer,
    );
    if (mounted)
      // ignore: curly_braces_in_flow_control_structures
      _snack('PIN lock is on. It will be asked each time you open the app.');
  }

  Future<void> _disable() async {
    final pin = context.read<PinController>();
    if (!await _confirmCurrentPin()) return;
    await pin.turnOff();
    if (mounted) _snack('PIN lock is off.');
  }

  Future<void> _changePin() async {
    final pin = context.read<PinController>();
    final navigator = Navigator.of(context);
    if (!await _confirmCurrentPin()) return;
    final newPin = await navigator.push<String>(
      MaterialPageRoute(
        builder: (_) => const CreatePinScreen(title: 'Choose a new PIN'),
      ),
    );
    if (newPin == null) return;
    await pin.changePin(newPin);
    if (mounted) _snack('PIN changed.');
  }

  Future<void> _changeRecovery() async {
    final pin = context.read<PinController>();
    final navigator = Navigator.of(context);
    if (!await _confirmCurrentPin()) return;
    final recovery = await navigator.push<Recovery>(
      MaterialPageRoute(builder: (_) => const RecoverySetupScreen()),
    );
    if (recovery == null) return;
    await pin.updateRecovery(
      question: recovery.question,
      answer: recovery.answer,
    );
    if (mounted) _snack('Recovery question updated.');
  }

  Future<void> _toggleFingerprint(bool value) async {
    final pin = context.read<PinController>();
    final messenger = ScaffoldMessenger.of(context);
    if (!value) {
      await pin.setBiometric(false);
      return;
    }
    try {
      // Try it once, so we know it works before relying on it
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Confirm your fingerprint',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok) await pin.setBiometric(true);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not use the fingerprint sensor.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = context.watch<PinController>();
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: const Text('PIN lock'),
          subtitle: Text(
            pin.isEnabled ? 'Asked every time you open the app' : 'Off',
          ),
          value: pin.isEnabled,
          onChanged: (on) => on ? _enable() : _disable(),
        ),
        if (pin.isEnabled) ...[
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Change PIN'),
            onTap: _changePin,
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Recovery question'),
            subtitle: Text(pin.question),
            onTap: _changeRecovery,
          ),
          if (_fingerprintAvailable)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Fingerprint unlock'),
              subtitle: const Text(
                'Use your fingerprint instead of typing the PIN',
              ),
              value: pin.biometricEnabled,
              onChanged: _toggleFingerprint,
            ),
        ],
      ],
    );
  }
}
