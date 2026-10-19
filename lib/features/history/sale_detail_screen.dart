import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/app_database.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/sales_repository.dart';

class SaleDetailScreen extends StatefulWidget {
  final int saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late Future<SaleDetail?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<SalesRepository>().saleDetail(widget.saleId);
  }

  void _reload() {
    setState(() {
      _future = context.read<SalesRepository>().saleDetail(widget.saleId);
    });
  }

  Future<void> _void() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _VoidDialog(),
    );
    if (reason == null || !mounted) return;
    final sales = context.read<SalesRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sales.voidSale(saleId: widget.saleId, reason: reason);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Sale #${widget.saleId} voided')),
      );
      _reload();
    } on DataException catch (e) {
      if (mounted) await showErrorDialog(context, e.message);
    }
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Sale #${widget.saleId}')),
      body: FutureBuilder<SaleDetail?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('Sale not found.'));
          }
          final s = detail.sale;
          final profit = detail.lines.fold<int>(
            0,
            (sum, l) => sum + l.lineTotal - Money.lineTotal(l.qty, l.unitCost),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                Fmt.dateTime(s.createdAt),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (s.isVoided)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.error),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOIDED',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      if (s.voidReason != null) Text('Reason: ${s.voidReason}'),
                      if (s.voidedAt != null)
                        Text(
                          Fmt.dateTime(s.voidedAt!),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final l in detail.lines)
                      ListTile(
                        title: Text(l.itemName),
                        subtitle: Text(
                          '${Qty.format(l.qty, l.unit)} × ${Money.format(l.unitPrice)}',
                        ),
                        trailing: Text(
                          Money.format(l.lineTotal),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row(context, 'Total', Money.format(s.total), bold: true),
                      _row(context, 'Received', Money.format(s.cashReceived)),
                      if (s.changeGiven > 0)
                        _row(context, 'Change', Money.format(s.changeGiven)),
                      if (s.utangAmount > 0)
                        _row(
                          context,
                          s.customerName != null
                              ? 'Utang (${s.customerName})'
                              : 'Utang',
                          Money.format(s.utangAmount),
                        ),
                      const Divider(height: 20),
                      _row(
                        context,
                        'Profit on this sale',
                        Money.format(profit),
                      ),
                    ],
                  ),
                ),
              ),
              if (!s.isVoided) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _void,
                  icon: const Icon(Icons.block),
                  label: const Text('Void this sale'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _VoidDialog extends StatefulWidget {
  const _VoidDialog();

  @override
  State<_VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends State<_VoidDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canVoid = _reason.text.trim().isNotEmpty;
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: const Text('Void this sale?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The items go back to stock and any utang from this sale is '
            'reversed. The sale stays in the history, marked as voided.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason (required)',
              helperText: 'e.g. "Wrong quantity entered"',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canVoid
              ? () => Navigator.pop(context, _reason.text.trim())
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: const Text('Void sale'),
        ),
      ],
    );
  }
}
