import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/units.dart';
import '../../data/models/item.dart';

class RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool tonal;
  const RoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tonal = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      fixedSize: const Size(32, 32),
      shape: const CircleBorder(),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final child = Icon(icon, size: 18);
    return tonal
        ? FilledButton.tonal(style: style, onPressed: onPressed, child: child)
        : FilledButton(style: style, onPressed: onPressed, child: child);
  }
}

/// "–  3  +" control. Needs a bounded width from its parent.
/// Tapping the number lets you type an exact quantity.
class QtyStepper extends StatelessWidget {
  final Item item;
  final int qty;
  final ValueChanged<int> onChanged; // new quantity, 0 or less removes

  const QtyStepper({
    super.key,
    required this.item,
    required this.qty,
    required this.onChanged,
  });

  int get _step => item.unit.allowsDecimal ? 250 : 1000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        RoundButton(
          icon: Icons.remove,
          tonal: true,
          onPressed: () => onChanged(qty - _step),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final result = await showQuantityDialog(
                context,
                item: item,
                current: qty,
              );
              if (result != null) onChanged(result);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Text(
                  Qty.plain(qty),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        RoundButton(
          icon: Icons.add,
          onPressed: qty >= item.quantity ? null : () => onChanged(qty + _step),
        ),
      ],
    );
  }
}

/// Asks for an exact quantity. Returns thousandths, 0 to remove from the
/// cart, or null if cancelled.
Future<int?> showQuantityDialog(
  BuildContext context, {
  required Item item,
  int current = 0,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _QuantityDialog(item: item, current: current),
  );
}

class _QuantityDialog extends StatefulWidget {
  final Item item;
  final int current;
  const _QuantityDialog({required this.item, required this.current});

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current > 0 ? Qty.plain(widget.current) : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final item = widget.item;
    final milli = Qty.parse(_controller.text);
    String? error;
    if (milli == null || milli == 0) {
      error = 'Enter a quantity';
    } else if (!item.unit.allowsDecimal && milli % 1000 != 0) {
      error = 'Whole numbers only';
    } else if (milli > item.quantity) {
      error = 'Only ${Qty.format(item.quantity, item.unit)} available';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, milli);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final decimal = item.unit.allowsDecimal;
    return AlertDialog(
      title: Text(item.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${Qty.format(item.quantity, item.unit)} available'),
          if (decimal) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [250, 500, 1000, 2000])
                  ActionChip(
                    label: Text('${Qty.plain(m)} ${item.unit.label}'),
                    onPressed: () {
                      _controller.text = Qty.plain(m);
                      _submit();
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: [
              decimal
                  ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                  : FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: 'Quantity',
              suffixText: item.unit.label,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        if (widget.current > 0)
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Set')),
      ],
    );
  }
}
