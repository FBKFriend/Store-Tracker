import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';
import '../../data/models/report.dart';
import '../../data/repositories/reports_repository.dart';

class ExpensesBreakdownScreen extends StatefulWidget {
  final ReportPeriod period;
  const ExpensesBreakdownScreen({super.key, required this.period});

  @override
  State<ExpensesBreakdownScreen> createState() =>
      _ExpensesBreakdownScreenState();
}

class _ExpensesBreakdownScreenState extends State<ExpensesBreakdownScreen> {
  late Future<List<ExpenseRow>> _future;

  @override
  void initState() {
    super.initState();
    final (from, to) = widget.period.range;
    _future = context.read<ReportsRepository>().expenseBreakdown(
      from: from,
      to: to,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Expenses · ${widget.period.label}')),
      body: FutureBuilder<List<ExpenseRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No stock bought in this period.'));
          }
          final total = rows.fold<int>(0, (sum, r) => sum + r.total);

          return ListView(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total spent on stock',
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              Money.format(total),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${rows.length} purchase${rows.length == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ),
              ),
              for (final r in rows)
                ListTile(
                  title: Text(r.itemName),
                  subtitle: Text(
                    '${r.kind == 'initial' ? 'Starting stock' : 'Restock'} · '
                    '${Qty.format(r.qty, r.unit)} × ${Money.format(r.unitCost)}\n'
                    '${Fmt.dateTime(r.receivedAt)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    Money.format(r.total),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
