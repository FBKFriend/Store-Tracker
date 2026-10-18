import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/app_database.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';

final _amountFilter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
const _decimalKeyboard = TextInputType.numberWithOptions(decimal: true);

/// Returns true if a payment was saved.
Future<bool?> showReceivePaymentSheet(
  BuildContext context, {
  required Customer customer,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReceivePaymentSheet(customer: customer),
  );
}

/// Returns true if an adjustment was saved.
Future<bool?> showAdjustSheet(
  BuildContext context, {
  required Customer customer,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AdjustSheet(customer: customer),
  );
}

String _amountText(int cents) =>
    cents % 100 == 0 ? '${cents ~/ 100}' : Money.plain(cents);

class _ReceivePaymentSheet extends StatefulWidget {
  final Customer customer;
  const _ReceivePaymentSheet({required this.customer});

  @override
  State<_ReceivePaymentSheet> createState() => _ReceivePaymentSheetState();
}

class _ReceivePaymentSheetState extends State<_ReceivePaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  static const _quickAmounts = [5000, 10000, 20000];

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _cents =>
      _amount.text.trim().isEmpty ? null : Money.parse(_amount.text);

  Future<void> _save() async {
    final cents = _cents;
    if (cents == null) return;
    setState(() => _saving = true);
    final repo = context.read<CustomerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await repo.recordPayment(
        customerId: widget.customer.id,
        amount: cents,
        note: _note.text,
      );
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(content: Text('Payment of ${Money.format(cents)} recorded')),
      );
    } on DataException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showErrorDialog(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owed = widget.customer.balance;
    final cents = _cents;
    final tooMuch = cents != null && cents > owed;
    final remaining = (cents == null || tooMuch) ? null : owed - cents;
    final canSave = !_saving && cents != null && cents > 0 && !tooMuch;

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
              Text('Receive payment', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${widget.customer.name} owes ${Money.format(owed)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: _decimalKeyboard,
                inputFormatters: [_amountFilter],
                style: theme.textTheme.headlineSmall,
                decoration: InputDecoration(
                  labelText: 'Amount paid',
                  prefixText: '₱ ',
                  border: const OutlineInputBorder(),
                  errorText: tooMuch
                      ? 'More than they owe (${Money.format(owed)})'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () =>
                        setState(() => _amount.text = _amountText(owed)),
                    child: const Text('Pay in full'),
                  ),
                  for (final a in _quickAmounts)
                    if (a < owed)
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _amount.text = _amountText(a)),
                        child: Text('₱${a ~/ 100}'),
                      ),
                ],
              ),
              if (remaining != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    remaining == 0
                        ? 'Paid in full'
                        : 'Remaining after this payment: ${Money.format(remaining)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: remaining == 0 ? AppColors.success : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  child: Text(_saving ? 'Saving...' : 'Record payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustSheet extends StatefulWidget {
  final Customer customer;
  const _AdjustSheet({required this.customer});

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _increase = true;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _cents =>
      _amount.text.trim().isEmpty ? null : Money.parse(_amount.text);

  Future<void> _save() async {
    final cents = _cents;
    if (cents == null) return;
    setState(() => _saving = true);
    final repo = context.read<CustomerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await repo.recordAdjustment(
        customerId: widget.customer.id,
        amount: _increase ? cents : -cents,
        note: _note.text,
      );
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Adjustment recorded')),
      );
    } on DataException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showErrorDialog(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owed = widget.customer.balance;
    final cents = _cents;
    final newBalance = cents == null
        ? null
        : owed + (_increase ? cents : -cents);
    final negative = newBalance != null && newBalance < 0;
    final canSave =
        !_saving &&
        cents != null &&
        cents > 0 &&
        !negative &&
        _note.text.trim().isNotEmpty;

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
              Text('Adjust utang', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${widget.customer.name} currently owes ${Money.format(owed)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Add to utang')),
                    ButtonSegment(value: false, label: Text('Reduce utang')),
                  ],
                  selected: {_increase},
                  onSelectionChanged: (s) =>
                      setState(() => _increase = s.first),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: _decimalKeyboard,
                inputFormatters: [_amountFilter],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱ ',
                  border: const OutlineInputBorder(),
                  errorText: negative ? 'More than they owe' : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  helperText:
                      'e.g. "Wrong amount entered", "Forgave the balance"',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (newBalance != null && !negative)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'New balance: ${Money.format(newBalance)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  child: Text(_saving ? 'Saving...' : 'Save adjustment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
