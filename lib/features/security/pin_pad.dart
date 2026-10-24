import 'package:flutter/material.dart';

class PinDots extends StatelessWidget {
  final int filled;
  final int length;
  const PinDots({super.key, required this.filled, this.length = 4});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
          ),
      ],
    );
  }
}

class PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Shown at the bottom left (the fingerprint button on the lock screen).
  final Widget? bottomLeft;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.bottomLeft,
  });

  Widget _key({required Widget child, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 72,
        height: 72,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _digit(BuildContext context, String d) {
    return _key(
      onTap: () => onDigit(d),
      child: Text(d, style: Theme.of(context).textTheme.headlineMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _digit(context, d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _key(child: bottomLeft ?? const SizedBox.shrink()),
            _digit(context, '0'),
            _key(
              onTap: onBackspace,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
