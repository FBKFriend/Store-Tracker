import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';
import '../../data/models/report.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/reports_repository.dart';

class _DayData {
  final PeriodSummary summary;
  final int voidedCount;
  final int voidedTotal;
  final List<UtangActivityRow> activity;
  final List<ProfitRow> topItems;

  const _DayData({
    required this.summary,
    required this.voidedCount,
    required this.voidedTotal,
    required this.activity,
    required this.topItems,
  });
}

class EndOfDayReportScreen extends StatefulWidget {
  const EndOfDayReportScreen({super.key});

  @override
  State<EndOfDayReportScreen> createState() => _EndOfDayReportScreenState();
}

class _EndOfDayReportScreenState extends State<EndOfDayReportScreen> {
  late DateTime _day;
  late Future<_DayData> _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _future = _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  Future<_DayData> _load() async {
    final reports = context.read<ReportsRepository>();
    final from = _day;
    final to = DateTime(_day.year, _day.month, _day.day + 1);
    final summary = await reports.summary(from: from, to: to);
    final (voidedCount, voidedTotal) = await reports.voidedSales(
      from: from,
      to: to,
    );
    final activity = await reports.utangActivity(from: from, to: to);
    final profit = await reports.profitBreakdown(from: from, to: to);
    return _DayData(
      summary: summary,
      voidedCount: voidedCount,
      voidedTotal: voidedTotal,
      activity: activity,
      topItems: profit.take(5).toList(),
    );
  }

  void _setDay(DateTime d) {
    setState(() {
      _day = DateTime(d.year, d.month, d.day);
      _future = _load();
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) _setDay(picked);
  }

  Widget _line(
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = context.watch<ItemRepository>().items;
    final lowDefault = context.watch<SettingsController>().lowStockDefault;
    final restockNow = items
        .where((i) => !i.inStock || i.isLowStock(lowDefault))
        .take(8)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('End-of-day report'),
        actions: [
          IconButton(
            tooltip: 'Pick a date',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _pickDay,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      _setDay(DateTime(_day.year, _day.month, _day.day - 1)),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickDay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Text(
                            Fmt.dayLabel(_day),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            Fmt.date(_day),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next day',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isToday
                      ? null
                      : () => _setDay(
                          DateTime(_day.year, _day.month, _day.day + 1),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<_DayData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final s = data.summary;
                final margin = s.salesTotal > 0
                    ? (s.profit * 100 / s.salesTotal).round()
                    : 0;
                final cashFromSales = s.salesTotal - s.newUtang;
                final net = cashFromSales + s.utangCollected - s.expenses;
                final payments = data.activity
                    .where((a) => a.type == 'payment')
                    .toList();
                final adjustments = data.activity
                    .where((a) => a.type == 'adjustment')
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Section(
                      title: 'Sales',
                      children: [
                        _line(
                          context,
                          'Sales (${s.salesCount})',
                          Money.format(s.salesTotal),
                          bold: true,
                        ),
                        _line(
                          context,
                          'Cost of items sold',
                          Money.format(s.cost),
                        ),
                        const Divider(height: 20),
                        _line(
                          context,
                          'Profit ($margin% margin)',
                          Money.format(s.profit),
                          bold: true,
                          color: s.profit < 0
                              ? theme.colorScheme.error
                              : AppColors.success,
                        ),
                        if (data.voidedCount > 0) ...[
                          const SizedBox(height: 8),
                          _line(
                            context,
                            'Voided sales (${data.voidedCount}), not counted',
                            Money.format(data.voidedTotal),
                          ),
                        ],
                      ],
                    ),
                    _Section(
                      title: 'Utang',
                      children: [
                        _line(
                          context,
                          'New utang given',
                          Money.format(s.newUtang),
                        ),
                        _line(
                          context,
                          'Collected from customers',
                          Money.format(s.utangCollected),
                          bold: true,
                        ),
                        if (payments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'No payments recorded.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        for (final p in payments)
                          _line(
                            context,
                            '${p.customerName} · ${Fmt.time(p.createdAt)}'
                            '${p.note != null ? '\n${p.note}' : ''}',
                            Money.format(-p.amount),
                          ),
                        if (adjustments.isNotEmpty) ...[
                          const Divider(height: 20),
                          Text(
                            'Manual adjustments (not cash)',
                            style: theme.textTheme.labelLarge,
                          ),
                          for (final a in adjustments)
                            _line(
                              context,
                              '${a.customerName} · ${Fmt.time(a.createdAt)}'
                                  '${a.note != null ? '\n${a.note}' : ''}',
                              '${a.amount > 0 ? '+' : '−'}${Money.format(a.amount.abs())}',
                            ),
                        ],
                      ],
                    ),
                    _Section(
                      title: 'Stock',
                      children: [
                        _line(
                          context,
                          'Spent on stock',
                          Money.format(s.expenses),
                          bold: true,
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Cash movement',
                      children: [
                        _line(
                          context,
                          'Cash from sales',
                          Money.format(cashFromSales),
                        ),
                        _line(
                          context,
                          'Utang collected',
                          '+ ${Money.format(s.utangCollected)}',
                        ),
                        _line(
                          context,
                          'Stock bought',
                          '− ${Money.format(s.expenses)}',
                        ),
                        const Divider(height: 20),
                        _line(
                          context,
                          'Net cash change',
                          Money.format(net),
                          bold: true,
                          color: net < 0
                              ? theme.colorScheme.error
                              : AppColors.success,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Assumes stock was paid for in cash. Utang given '
                            'only counts as cash once the customer pays.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    if (data.topItems.isNotEmpty)
                      _Section(
                        title: 'Top items',
                        children: [
                          for (final r in data.topItems)
                            _line(
                              context,
                              '${r.itemName} · ${Qty.format(r.qty, r.unit)}',
                              Money.format(r.profit),
                            ),
                        ],
                      ),
                    if (_isToday)
                      _Section(
                        title: 'Needs restocking now',
                        children: [
                          if (restockNow.isEmpty)
                            const Text('Nothing is running low.'),
                          for (final i in restockNow)
                            _line(
                              context,
                              i.name,
                              i.inStock
                                  ? '${Qty.format(i.quantity, i.unit)} left'
                                  : 'Out of stock',
                              color: i.inStock ? null : theme.colorScheme.error,
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
