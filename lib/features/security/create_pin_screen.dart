import 'package:flutter/material.dart';

import 'pin_pad.dart';

/// Asks for a new PIN twice. Returns it with Navigator.pop, or null if the
/// user backs out.
class CreatePinScreen extends StatefulWidget {
  final String title;
  const CreatePinScreen({super.key, this.title = 'Choose a PIN'});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String? _first;
  String _entered = '';
  String? _error;

  void _onDigit(String d) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length < 4) return;

    if (_first == null) {
      // A short pause so the fourth dot shows before moving on
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() {
          _first = _entered;
          _entered = '';
        });
      });
    } else if (_entered == _first) {
      Navigator.of(context).pop(_entered);
    } else {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() {
          _first = null;
          _entered = '';
          _error = 'The PINs didn\'t match. Start again.';
        });
      });
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _first == null
                      ? 'Enter a 4-digit PIN'
                      : 'Enter it again to confirm',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                PinDots(filled: _entered.length),
                SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(
                      _error ?? '',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
                PinPad(onDigit: _onDigit, onBackspace: _onBackspace),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
