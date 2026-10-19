import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/sales_repository.dart';
import 'sale_detail_screen.dart';

enum _Range {
  today('Today'),
  week('7 days'),
  month('30 days'),
  all('All time');

  const _Range(this.label);
  final String label;
}

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  static const _limit = 300;

  _Range _range = _Range.today;
  late Future<List<SaleSummary>> _future;

  DateTime? get _from {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.today:
        return today;
      case _Range.week:
        return today.subtract(const Duration(days: 6));
      case _Range.month:
        return today.subtract(const Duration(days: 29));
      case _Range.all:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SaleSummary>> _load() =>
      context.read<SalesRepository>().salesList(from: _from, limit: _limit);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  List<Widget> _buildRows(List<SaleSummary> sales) {
    String keyOf(DateTime d) => '${d.year}-${d.month}-${d.day}';

    // Each day's total counts only sales that weren't voided
    final totals = <String, int>{};
    for (final s in sales) {
      if (s.isVoided) continue;
      final key = keyOf(s.createdAt);
      totals[key] = (totals[key] ?? 0) + s.total;
    }

    final rows = <Widget>[];
    String? lastKey;
    for (final s in sales) {
      final key = keyOf(s.createdAt);
      if (key != lastKey) {
        lastKey = key;
        rows.add(
          _DayHeader(label: Fmt.dayLabel(s.createdAt), total: totals[key] ?? 0),
        );
      }
      rows.add(
        _SaleTile(
          sale: s,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: s.id)),
            );
            if (mounted) _reload();
          },
        ),
      );
    }
    if (sales.length >= _limit) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Showing the latest 300 sales.')),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction history')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final r in _Range.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: _range == r,
                      onSelected: (_) {
                        setState(() {
                          _range = r;
                          _future = _load();
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SaleSummary>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sales = snapshot.data!;
                if (sales.isEmpty) {
                  return const Center(child: Text('No sales in this period.'));
                }
                return ListView(children: _buildRows(sales));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  final int total;
  const _DayHeader({required this.label, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '${Money.format(total)} in sales',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final SaleSummary sale;
  final VoidCallback onTap;
  const _SaleTile({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voided = sale.isVoided;
    final strike = voided ? TextDecoration.lineThrough : null;
    final parts = [
      Fmt.time(sale.createdAt),
      if (sale.utangAmount > 0)
        'Utang ${Money.format(sale.utangAmount)}'
            '${sale.customerName != null ? ' (${sale.customerName})' : ''}',
      if (voided) 'Voided',
    ];
    return ListTile(
      leading: Icon(
        voided ? Icons.block : Icons.receipt_long_outlined,
        color: voided ? theme.colorScheme.error : null,
      ),
      title: Text('Sale #${sale.id}', style: TextStyle(decoration: strike)),
      subtitle: Text(parts.join(' · ')),
      trailing: Text(
        Money.format(sale.total),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          decoration: strike,
        ),
      ),
      onTap: onTap,
    );
  }
}
