import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/units.dart';
import '../../data/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/item_repository.dart';
import 'category_manager.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _buying = TextEditingController();
  final _selling = TextEditingController();
  final _qty = TextEditingController();
  final _lowStock = TextEditingController();

  ItemUnit _unit = ItemUnit.pcs;
  int? _categoryId;
  bool _saving = false;

  static final _numberFilter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.,]'),
  );
  static const _decimalKeyboard = TextInputType.numberWithOptions(
    decimal: true,
  );

  @override
  void dispose() {
    _name.dispose();
    _buying.dispose();
    _selling.dispose();
    _qty.dispose();
    _lowStock.dispose();
    super.dispose();
  }

  InputDecoration _dec(
    String label, {
    String? prefix,
    String? suffix,
    String? helper,
  }) => InputDecoration(
    labelText: label,
    prefixText: prefix,
    suffixText: suffix,
    helperText: helper,
    border: const OutlineInputBorder(),
  );

  String? _validateMoney(String? v, {bool allowZero = false}) {
    final cents = Money.parse(v ?? '');
    if (cents == null) return 'Enter an amount';
    if (!allowZero && cents == 0) return 'Must be more than 0';
    return null;
  }

  String? _validateQty(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null; // optional
    final milli = Qty.parse(text);
    if (milli == null) return 'Enter a valid number';
    if (!_unit.allowsDecimal && milli % 1000 != 0) {
      return 'Whole numbers only for ${_unit.label}';
    }
    return null;
  }

  Future<void> _addCategory() async {
    final name = await askCategoryName(context);
    if (name == null || !mounted) return;
    try {
      final created = await context.read<CategoryRepository>().add(name);
      setState(() => _categoryId = created.id);
    } on DataException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final items = context.read<ItemRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    try {
      await items.addItem(
        name: name,
        categoryId: _categoryId!,
        unit: _unit,
        buyingPrice: Money.parse(_buying.text)!,
        sellingPrice: Money.parse(_selling.text)!,
        startingQty: _qty.text.trim().isEmpty ? 0 : Qty.parse(_qty.text)!,
        lowStockThreshold: _lowStock.text.trim().isEmpty
            ? null
            : Qty.parse(_lowStock.text),
      );
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Added "$name"')));
    } on DataException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.watch<CategoryRepository>().categories;

    if (categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add item')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _categoryId ??= categories
        .firstWhere((c) => c.isDefault, orElse: () => categories.first)
        .id;

    return Scaffold(
      appBar: AppBar(title: const Text('Add item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Item name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_categoryId),
                    initialValue: _categoryId,
                    decoration: _dec('Category'),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filledTonal(
                    tooltip: 'New category',
                    icon: const Icon(Icons.add),
                    onPressed: _addCategory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Sold by', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ItemUnit>(
              segments: [
                for (final u in ItemUnit.values)
                  ButtonSegment<ItemUnit>(value: u, label: Text(u.label)),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _unit.allowsDecimal
                    ? 'Quantities can have decimals, like 0.25 kg.'
                    : 'Quantities are whole numbers.',
                style: theme.textTheme.bodySmall,
              ),
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
                      helper: 'per ${_unit.label}',
                    ),
                    validator: (v) => _validateMoney(v, allowZero: true),
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
                      helper: 'per ${_unit.label}',
                    ),
                    validator: _validateMoney,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qty,
              keyboardType: _decimalKeyboard,
              inputFormatters: [_numberFilter],
              decoration: _dec(
                'Starting quantity (optional)',
                suffix: _unit.label,
                helper: 'Counts as an expense (buying price × quantity)',
              ),
              validator: _validateQty,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lowStock,
              keyboardType: _decimalKeyboard,
              inputFormatters: [_numberFilter],
              decoration: _dec(
                'Low-stock alert (optional)',
                suffix: _unit.label,
                helper: 'Alert when stock is at or below this. Blank = app default.',
              ),
              validator: _validateQty,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
