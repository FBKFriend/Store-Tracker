import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/app_database.dart';
import '../../data/models/item.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/item_repository.dart';
import 'category_manager.dart';

class EditItemScreen extends StatefulWidget {
  final Item item;
  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.item.name,
  );
  late final TextEditingController _selling = TextEditingController(
    text: Money.plain(widget.item.latestSellingPrice),
  );
  late final TextEditingController _lowStock = TextEditingController(
    text: widget.item.lowStockThreshold == null
        ? ''
        : Qty.plain(widget.item.lowStockThreshold!),
  );

  late ItemUnit _unit = widget.item.unit;
  late int _categoryId = widget.item.categoryId;
  bool _applyToCurrentStock = false;
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
    _selling.dispose();
    _lowStock.dispose();
    super.dispose();
  }

  int? get _newPrice {
    final p = Money.parse(_selling.text);
    return (p != null && p > 0) ? p : null;
  }

  bool get _showApply =>
      widget.item.inStock &&
      _newPrice != null &&
      _newPrice != widget.item.sellingPrice;

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
    helperMaxLines: 2,
    border: const OutlineInputBorder(),
  );

  String? _validateSelling(String? v) {
    final cents = Money.parse(v ?? '');
    if (cents == null) return 'Enter an amount';
    if (cents == 0) return 'Must be more than 0';
    return null;
  }

  String? _validateLowStock(String? v) {
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
    final item = widget.item;
    final newPrice = _newPrice!;
    final apply = _showApply && _applyToCurrentStock;
    final name = _name.text.trim();
    try {
      await items.updateItem(
        id: item.id,
        name: name,
        categoryId: _categoryId,
        unit: _unit,
        lowStockThreshold: _lowStock.text.trim().isEmpty
            ? null
            : Qty.parse(_lowStock.text),
      );
      if (newPrice != item.latestSellingPrice || apply) {
        await items.changeSellingPrice(
          itemId: item.id,
          newPrice: newPrice,
          applyToExistingStock: apply,
        );
      }
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Saved "$name"')));
    } on DataException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Archive "${widget.item.name}"?',
      message:
          'It will be hidden from Inventory and the POS. '
          'Past sales keep their records.',
      confirmLabel: 'Archive',
    );
    if (!ok || !mounted) return;
    await context.read<ItemRepository>().archiveItem(widget.item.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final categories = context.watch<CategoryRepository>().categories;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(
                  'In stock: ${Qty.format(item.quantity, item.unit)}',
                ),
                subtitle: const Text(
                  'To add stock, use the + button on the item list.',
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                    onChanged: (v) {
                      if (v != null) setState(() => _categoryId = v);
                    },
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
                'The unit can\'t be changed once the item has had stock.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _selling,
              keyboardType: _decimalKeyboard,
              inputFormatters: [_numberFilter],
              decoration: _dec(
                'Selling price',
                prefix: '₱ ',
                suffix: '/ ${_unit.label}',
                helper: item.inStock
                    ? 'Customers pay ${Money.format(item.sellingPrice)} right now.'
                    : null,
              ),
              validator: _validateSelling,
              onChanged: (_) => setState(() {}),
            ),
            if (_showApply)
              CheckboxListTile(
                value: _applyToCurrentStock,
                onChanged: (v) =>
                    setState(() => _applyToCurrentStock = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('Apply to current stock too'),
                subtitle: Text(
                  _applyToCurrentStock
                      ? 'Everything on the shelf sells at ${Money.format(_newPrice!)} right away.'
                      : 'Current stock stays at ${Money.format(item.sellingPrice)}. The new price starts after it sells out.',
                ),
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
              validator: _validateLowStock,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save changes'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _archive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive item'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
