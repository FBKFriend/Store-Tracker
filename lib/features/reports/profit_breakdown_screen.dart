import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/units.dart';
import '../../data/models/report.dart';
import '../../data/repositories/reports_repository.dart';

class ProfitBreakdownScreen extends StatefulWidget {
  final ReportPeriod period;
  const ProfitBreakdownScreen({super.key, required this.period});

  @override
  State<ProfitBreakdownScreen> createState() => _ProfitBreakdownScreenState();
}

class _ProfitBreakdownScreenState extends State<ProfitBreakdownScreen> {
  late Future<List<ProfitRow>> _future;

  @override
  void initState() {
    super.initState();
    final (from, to) = widget.period.range;
    _future = context.read<ReportsRepository>().profitBreakdown(
      from: from,
      to: to,
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int cents, {
    bool bold = false,
  }) {
    final style = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(Money.format(cents), style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Profit · ${widget.period.label}')),
      body: FutureBuilder<List<ProfitRow>>(
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
            return const Center(child: Text('No sales in this period.'));
          }
          final revenue = rows.fold<int>(0, (sum, r) => sum + r.revenue);
          final cost = rows.fold<int>(0, (sum, r) => sum + r.cost);
          final profit = revenue - cost;

          return ListView(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row(context, 'Sales', revenue),
                      _row(context, 'Cost of items sold', cost),
                      const Divider(height: 20),
                      _row(context, 'Profit', profit, bold: true),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('By item', style: theme.textTheme.titleMedium),
              ),
              for (final r in rows)
                ListTile(
                  title: Text(r.itemName),
                  subtitle: Text(
                    '${Qty.format(r.qty, r.unit)} sold\n'
                    'Sales ${Money.format(r.revenue)} · Cost ${Money.format(r.cost)}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Money.format(r.profit),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: r.profit < 0
                              ? theme.colorScheme.error
                              : AppColors.success,
                        ),
                      ),
                      Text(
                        '${r.revenue > 0 ? (r.profit * 100 / r.revenue).round() : 0}% margin',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
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
