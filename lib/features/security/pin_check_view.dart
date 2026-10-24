import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/security/pin_controller.dart';
import 'pin_pad.dart';

/// The dots and keypad that check an entered PIN. Used by the lock screen
/// and by the "confirm your PIN" screen in Settings.
class PinCheckView extends StatefulWidget {
  final VoidCallback onSuccess;
  final bool allowBiometric;
  final VoidCallback? onForgot;

  const PinCheckView({
    super.key,
    required this.onSuccess,
    this.allowBiometric = false,
    this.onForgot,
  });

  @override
  State<PinCheckView> createState() => _PinCheckViewState();
}

class _PinCheckViewState extends State<PinCheckView> {
  final _auth = LocalAuthentication();
  String _entered = '';
  String? _message;
  bool _checking = false;
  bool _askingBiometric = false;
  Duration _lockLeft = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdownIfLocked();
    if (widget.allowBiometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdownIfLocked() {
    _timer?.cancel();
    final remaining = context.read<PinController>().lockoutRemaining;
    if (remaining <= Duration.zero) {
      _lockLeft = Duration.zero;
      return;
    }
    _lockLeft = remaining;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = context.read<PinController>().lockoutRemaining;
      setState(() => _lockLeft = left);
      if (left <= Duration.zero) t.cancel();
    });
  }

  Future<void> _tryBiometric() async {
    if (!mounted || _askingBiometric) return;
    if (!context.read<PinController>().biometricEnabled) return;
    _askingBiometric = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock My Sari-Sari Store',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) widget.onSuccess();
    } catch (_) {
      // Cancelled or not available: the PIN still works.
    } finally {
      _askingBiometric = false;
    }
  }

  Future<void> _onDigit(String d) async {
    if (_checking || _lockLeft > Duration.zero || _entered.length >= 4) return;
    setState(() {
      _entered += d;
      _message = null;
    });
    if (_entered.length == 4) await _submit();
  }

  void _onBackspace() {
    if (_checking || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    _checking = true;
    final result = await context.read<PinController>().checkPin(_entered);
    _checking = false;
    if (!mounted) return;
    switch (result) {
      case PinResult.ok:
        widget.onSuccess();
      case PinResult.wrong:
        setState(() {
          _entered = '';
          _message = 'Wrong PIN. Try again.';
        });
      case PinResult.lockedOut:
        setState(() {
          _entered = '';
          _startCountdownIfLocked();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = _lockLeft > Duration.zero;
    final seconds = (_lockLeft.inMilliseconds / 1000).ceil();
    final text = locked
        ? 'Too many tries. Try again in ${seconds}s.'
        : _message;
    final showFingerprint =
        widget.allowBiometric &&
        context.watch<PinController>().biometricEnabled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PinDots(filled: _entered.length),
        SizedBox(
          height: 36,
          child: Center(
            child: Text(
              text ?? '',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
        PinPad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          bottomLeft: showFingerprint
              ? IconButton(
                  tooltip: 'Use fingerprint',
                  icon: const Icon(Icons.fingerprint, size: 34),
                  onPressed: _tryBiometric,
                )
              : null,
        ),
        if (widget.onForgot != null)
          TextButton(
            onPressed: widget.onForgot,
            child: const Text('Forgot PIN?'),
          ),
      ],
    );
  }
}
