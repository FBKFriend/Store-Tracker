import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/app_database.dart';
import '../../data/models/customer.dart';
import '../../data/models/ledger_entry.dart';
import '../../data/repositories/customer_repository.dart';
import 'utang_sheets.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<List<LedgerEntry>> _history;

  @override
  void initState() {
    super.initState();
    _history = context.read<CustomerRepository>().ledgerFor(widget.customerId);
  }

  void _refreshHistory() {
    setState(() {
      _history = context.read<CustomerRepository>().ledgerFor(
        widget.customerId,
      );
    });
  }

  Future<void> _receivePayment(Customer c) async {
    final saved = await showReceivePaymentSheet(context, customer: c);
    if (saved == true && mounted) _refreshHistory();
  }

  Future<void> _adjust(Customer c) async {
    final saved = await showAdjustSheet(context, customer: c);
    if (saved == true && mounted) _refreshHistory();
  }

  Future<void> _rename(Customer c) async {
    final repo = context.read<CustomerRepository>();
    final name = await showTextInputDialog(
      context,
      title: 'Rename customer',
      label: 'Customer name',
      initial: c.name,
    );
    if (name == null || !mounted) return;
    try {
      await repo.rename(c.id, name);
    } on DataException catch (e) {
      if (mounted) await showErrorDialog(context, e.message);
    }
  }

  Future<void> _delete(Customer c) async {
    final repo = context.read<CustomerRepository>();
    final navigator = Navigator.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${c.name}?',
      message: 'This can\'t be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await repo.delete(c.id);
      navigator.pop();
    } on DataException catch (e) {
      if (mounted) await showErrorDialog(context, e.message);
    }
  }

  String _title(LedgerEntry e) {
    switch (e.type) {
      case 'charge':
        return e.saleId != null ? 'Sale #${e.saleId} on utang' : 'Charge';
      case 'payment':
        return 'Payment received';
      default:
        return e.amount >= 0 ? 'Adjustment (added)' : 'Adjustment (reduced)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = context.watch<CustomerRepository>().byId(
      widget.customerId,
    );

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Customer not found.')),
      );
    }

    final owes = customer.balance > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) =>
                value == 'rename' ? _rename(customer) : _delete(customer),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owes ? 'Owes' : 'Status',
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    owes ? Money.format(customer.balance) : 'Paid up',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: owes ? theme.colorScheme.error : AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: owes
                              ? () => _receivePayment(customer)
                              : null,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Receive payment'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _adjust(customer),
                        child: const Text('Adjust'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('History', style: theme.textTheme.titleMedium),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FutureBuilder<List<LedgerEntry>>(
              future: _history,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return const Center(child: Text('No history yet.'));
                }
                // Newest first: the newest entry ends at the current balance,
                // and each older one ended at what came before it.
                var running = customer.balance;
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final balanceAfter = running;
                    running -= e.amount;
                    final increase = e.amount > 0;
                    return ListTile(
                      leading: Icon(
                        e.type == 'payment'
                            ? Icons.south_west
                            : e.type == 'charge'
                            ? Icons.north_east
                            : Icons.tune,
                        color: increase
                            ? theme.colorScheme.error
                            : AppColors.success,
                      ),
                      title: Text(_title(e)),
                      subtitle: Text(
                        [
                          if (e.note != null) e.note!,
                          Fmt.dateTime(e.createdAt),
                        ].join('\n'),
                      ),
                      isThreeLine: e.note != null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${increase ? '+' : '−'}${Money.format(e.amount.abs())}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: increase
                                  ? theme.colorScheme.error
                                  : AppColors.success,
                            ),
                          ),
                          Text(
                            'Balance ${Money.format(balanceAfter)}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
