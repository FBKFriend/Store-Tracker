import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/app_database.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import 'customer_detail_screen.dart';

class UtangScreen extends StatefulWidget {
  const UtangScreen({super.key});

  @override
  State<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends State<UtangScreen> {
  String _query = '';

  Future<void> _addCustomer() async {
    final repo = context.read<CustomerRepository>();
    final name = await showTextInputDialog(
      context,
      title: 'New customer',
      label: 'Customer name',
    );
    if (name == null || !mounted) return;
    try {
      await repo.add(name);
    } on DataException catch (e) {
      if (mounted) await showErrorDialog(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<CustomerRepository>();
    final all = repo.customers;
    final owingCount = all.where((c) => c.balance > 0).length;

    final q = _query.trim().toLowerCase();
    final customers =
        all.where((c) => q.isEmpty || c.name.toLowerCase().contains(q)).toList()
          ..sort((a, b) {
            final aOwes = a.balance > 0;
            final bOwes = b.balance > 0;
            if (aOwes != bOwes) return aOwes ? -1 : 1;
            if (aOwes) {
              final byBalance = b.balance.compareTo(a.balance);
              if (byBalance != 0) return byBalance;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    return Scaffold(
      appBar: AppBar(title: const Text('Utang')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add customer'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total owed to you',
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          Money.format(repo.totalOwed),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    owingCount == 0
                        ? 'Nobody owes'
                        : '$owingCount customer${owingCount == 1 ? '' : 's'} owe',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search customers',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        all.isEmpty
                            ? 'No customers yet.\nThey\'re added when you charge a sale to utang, or tap "Add customer".'
                            : 'No customers match.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: customers.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _CustomerTile(customer: customers[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owes = customer.balance > 0;
    return ListTile(
      leading: CircleAvatar(
        child: Text(customer.name.characters.first.toUpperCase()),
      ),
      title: Text(customer.name),
      subtitle: Text(owes ? 'Owes' : 'Paid up'),
      trailing: owes
          ? Text(
              Money.format(customer.balance),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.error,
              ),
            )
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(customerId: customer.id),
        ),
      ),
    );
  }
}
