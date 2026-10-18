import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/app_database.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/sales_repository.dart';
import 'cart_controller.dart';

Future<SaleResult?> showPaymentSheet(BuildContext context) {
  return showModalBottomSheet<SaleResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PaymentSheet(),
  );
}

Future<void> showReceiptDialog(BuildContext context, SaleResult r) {
  final theme = Theme.of(context);
  Widget row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.check_circle_outline,
        color: AppColors.success,
        size: 40,
      ),
      title: Text('Sale #${r.saleId} complete'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('Total', Money.format(r.total)),
            row('Received', Money.format(r.cashReceived)),
            if (r.utang > 0)
              row('Utang (${r.customerName})', Money.format(r.utang)),
            if (r.change > 0) ...[
              const Divider(height: 24),
              Text('Change', style: theme.textTheme.labelLarge),
              Text(
                Money.format(r.change),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('New sale'),
        ),
      ],
    ),
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet();

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _received = TextEditingController();
  int? _customerId;
  bool _saving = false;

  // Quick cash buttons in centavos (these will follow the chosen currency later)
  static const _quickAmounts = [2000, 5000, 10000, 20000, 50000, 100000];

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  int? get _receivedCents =>
      _received.text.trim().isEmpty ? null : Money.parse(_received.text);

  void _setReceived(int cents) {
    setState(() {
      _received.text = cents % 100 == 0
          ? '${cents ~/ 100}'
          : Money.plain(cents);
    });
  }

  Future<void> _addCustomer() async {
    final name = await showTextInputDialog(
      context,
      title: 'New customer',
      label: 'Customer name',
    );
    if (name == null || !mounted) return;
    try {
      final created = await context.read<CustomerRepository>().add(name);
      setState(() => _customerId = created.id);
    } on DataException catch (e) {
      if (mounted) await showErrorDialog(context, e.message);
    }
  }

  Future<void> _complete() async {
    final cents = _receivedCents;
    if (cents == null) return;
    setState(() => _saving = true);
    final cart = context.read<CartController>();
    final sales = context.read<SalesRepository>();
    final navigator = Navigator.of(context);
    try {
      final result = await sales.completeSale(
        lines: [
          for (final e in cart.entries) SaleLine(itemId: e.item.id, qty: e.qty),
        ],
        expectedTotal: cart.total,
        cashReceived: cents,
        customerId: _customerId,
        afterCommit: cart.clear,
      );
      navigator.pop(result);
    } on DataException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showErrorDialog(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartController>();
    final customers = context.watch<CustomerRepository>().customers;
    final total = cart.total;
    final received = _receivedCents;
    final change = (received != null && received >= total)
        ? received - total
        : 0;
    final utang = (received != null && received < total) ? total - received : 0;
    final needsCustomer = utang > 0;
    final canSubmit =
        !_saving &&
        total > 0 &&
        received != null &&
        (!needsCustomer || _customerId != null);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total to pay', style: theme.textTheme.labelLarge),
              Text(
                Money.format(total),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _received,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () => _setReceived(total),
                    child: const Text('Exact'),
                  ),
                  for (final a in _quickAmounts)
                    OutlinedButton(
                      onPressed: () => _setReceived(a),
                      child: Text('₱${a ~/ 100}'),
                    ),
                  OutlinedButton(
                    onPressed: () => _setReceived(0),
                    child: const Text('All utang'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (needsCustomer ? AppColors.warning : AppColors.success)
                      .withValues(alpha: received == null ? 0.0 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: received == null
                        ? theme.dividerColor
                        : (needsCustomer
                              ? AppColors.warning
                              : AppColors.success),
                  ),
                ),
                child: received == null
                    ? Text(
                        'Enter the amount received, or tap a button above.',
                        style: theme.textTheme.bodyMedium,
                      )
                    : needsCustomer
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remaining on utang',
                            style: theme.textTheme.labelLarge,
                          ),
                          Text(
                            Money.format(utang),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Change', style: theme.textTheme.labelLarge),
                          Text(
                            change == 0 ? 'No change' : Money.format(change),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
              if (needsCustomer) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_customerId),
                        initialValue: _customerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Charge remaining to',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final c in customers)
                            DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(
                                c.balance > 0
                                    ? '${c.name} (owes ${Money.format(c.balance)})'
                                    : c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _customerId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: IconButton.filledTonal(
                        tooltip: 'New customer',
                        icon: const Icon(Icons.person_add_alt_1),
                        onPressed: _addCustomer,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: canSubmit ? _complete : null,
                  child: Text(_saving ? 'Saving...' : 'Complete sale'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
