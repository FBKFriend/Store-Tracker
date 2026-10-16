import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/units.dart';
import '../../data/app_database.dart';
import '../../data/models/item.dart';
import '../../data/repositories/item_repository.dart';

Future<void> showRestockSheet(BuildContext context, Item item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _RestockSheet(item: item),
  );
}

class _RestockSheet extends StatefulWidget {
  final Item item;
  const _RestockSheet({required this.item});

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  late final TextEditingController _buying = TextEditingController(
    text: Money.plain(widget.item.latestBuyingPrice),
  );
  late final TextEditingController _selling = TextEditingController(
    text: Money.plain(widget.item.latestSellingPrice),
  );

  bool _applyToExisting = false;
  bool _saving = false;

  static final _numberFilter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.,]'),
  );
  static const _decimalKeyboard = TextInputType.numberWithOptions(
    decimal: true,
  );

  @override
  void dispose() {
    _qty.dispose();
    _buying.dispose();
    _selling.dispose();
    super.dispose();
  }

  int? get _newSelling {
    final p = Money.parse(_selling.text);
    return (p != null && p > 0) ? p : null;
  }

  // The checkbox only matters when there is stock on the shelf that would
  // otherwise keep its old price.
  bool get _showApply =>
      widget.item.inStock &&
      _newSelling != null &&
      _newSelling != widget.item.sellingPrice;

  String? _validateQty(String? v) {
    final milli = Qty.parse(v ?? '');
    if (milli == null) return 'Enter a quantity';
    if (milli == 0) return 'Must be more than 0';
    if (!widget.item.unit.allowsDecimal && milli % 1000 != 0) {
      return 'Whole numbers only for ${widget.item.unit.label}';
    }
    return null;
  }

  String? _validateMoney(String? v, {bool allowZero = false}) {
    final cents = Money.parse(v ?? '');
    if (cents == null) return 'Enter an amount';
    if (!allowZero && cents == 0) return 'Must be more than 0';
    return null;
  }

  InputDecoration _dec(String label, {String? prefix, String? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final items = context.read<ItemRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final item = widget.item;
    final qty = Qty.parse(_qty.text)!;
    try {
      await items.restock(
        itemId: item.id,
        qty: qty,
        buyingPrice: Money.parse(_buying.text)!,
        sellingPrice: Money.parse(_selling.text)!,
        applyPriceToExistingStock: _showApply && _applyToExisting,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Added ${Qty.format(qty, item.unit)} to ${item.name}'),
        ),
      );
    } on DataException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final qty = Qty.parse(_qty.text) ?? 0;
    final buying = Money.parse(_buying.text) ?? 0;
    final total = Money.lineTotal(qty, buying);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add stock', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${item.name} · ${Qty.format(item.quantity, item.unit)} in stock now',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _qty,
                  autofocus: true,
                  keyboardType: _decimalKeyboard,
                  inputFormatters: [_numberFilter],
                  decoration: _dec('Quantity bought', suffix: item.unit.label),
                  validator: _validateQty,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buying,
                        keyboardType: _decimalKeyboard,
                        inputFormatters: [_numberFilter],
                        decoration: _dec(
                          'Buying price',
                          prefix: '₱ ',
                          suffix: '/ ${item.unit.label}',
                        ),
                        validator: (v) => _validateMoney(v, allowZero: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _selling,
                        keyboardType: _decimalKeyboard,
                        inputFormatters: [_numberFilter],
                        decoration: _dec(
                          'Selling price',
                          prefix: '₱ ',
                          suffix: '/ ${item.unit.label}',
                        ),
                        validator: _validateMoney,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'This purchase: ${Money.format(total)} (recorded as an expense)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (_showApply)
                  CheckboxListTile(
                    value: _applyToExisting,
                    onChanged: (v) =>
                        setState(() => _applyToExisting = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Apply new price to existing stock too'),
                    subtitle: Text(
                      _applyToExisting
                          ? 'All stock, including what\'s on the shelf now, sells at ${Money.format(_newSelling!)} right away.'
                          : 'Current stock stays at ${Money.format(item.sellingPrice)}. The new price starts after it sells out.',
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Add stock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
