import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/app_database.dart';
import '../../data/models/item.dart';
import '../../data/models/report.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/reports_repository.dart';
import '../debug/debug_data_screen.dart';
import '../legal/terms_screen.dart';
import '../reports/expenses_breakdown_screen.dart';
import '../reports/profit_breakdown_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppPrefs prefs;
  const HomeScreen({super.key, required this.prefs});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ReportPeriod _period = ReportPeriod.today;

  // ---- TEMPORARY testing helpers (remove later) ----

  Future<void> _resetFirstRun() async {
    final navigator = Navigator.of(context);
    await widget.prefs.resetForTesting();
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => TermsScreen(prefs: widget.prefs)),
    );
  }

  Future<void> _selfTest() async {
    final messenger = ScaffoldMessenger.of(context);
    final categories = context.read<CategoryRepository>();
    final items = context.read<ItemRepository>();
    try {
      final defaultCategory = categories.categories.firstWhere(
        (c) => c.isDefault,
      );
      final id = await items.addItem(
        name: 'Test Coffee ${DateTime.now().millisecondsSinceEpoch % 10000}',
        categoryId: defaultCategory.id,
        unit: ItemUnit.pcs,
        buyingPrice: Money.fromDouble(10),
        sellingPrice: Money.fromDouble(12),
        startingQty: Qty.fromDouble(10),
      );
      await items.restock(
        itemId: id,
        qty: Qty.fromDouble(10),
        buyingPrice: Money.fromDouble(11),
        sellingPrice: Money.fromDouble(13),
      );
      final item = items.items.firstWhere((i) => i.id == id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${item.name}: ${Qty.format(item.quantity, item.unit)} in stock, '
            'selling at ${Money.format(item.sellingPrice)}, '
            'next price ${Money.format(item.latestSellingPrice)}',
          ),
        ),
      );
    } on DataException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Self-test failed: $e')));
    }
  }

  Future<void> _wipeDatabase() async {
    final messenger = ScaffoldMessenger.of(context);
    await AppDatabase.instance.deleteForTesting();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Database wiped. Fully close and reopen the app.'),
      ),
    );
  }

  // ---- Dashboard ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = context.watch<ItemRepository>().items;
    final customers = context.watch<CustomerRepository>();
    final lowDefault = context.watch<SettingsController>().lowStockDefault;
    final (from, to) = _period.range;
    // Asked again on every rebuild, so numbers refresh after any sale,
    // restock, payment or void (the old numbers stay on screen meanwhile)
    final summaryFuture = context.read<ReportsRepository>().summary(
      from: from,
      to: to,
    );

    final lowItems =
        items.where((i) => !i.inStock || i.isLowStock(lowDefault)).toList()
          ..sort((a, b) {
            if (a.inStock != b.inStock) return a.inStock ? 1 : -1;
            return a.quantity.compareTo(b.quantity);
          });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 8),
            const Text('My Sari-Sari Store'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in ReportPeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.label),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<PeriodSummary>(
            future: summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              final s = snapshot.data;
              if (s == null) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                children: [
                  _SalesCard(periodLabel: _period.label, summary: s),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _MetricTile(
                            title: 'Profit',
                            value: Money.format(s.profit),
                            subtitle: 'Sales minus cost of items sold',
                            color: s.profit < 0
                                ? theme.colorScheme.error
                                : AppColors.success,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfitBreakdownScreen(period: _period),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            title: 'Expenses',
                            value: Money.format(s.expenses),
                            subtitle: 'Spent on stock',
                            color: theme.colorScheme.error,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExpensesBreakdownScreen(period: _period),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Profit and expenses are not subtracted from each other: '
                      'profit already counts what the sold items cost you.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _UtangCard(
                    collected: s.utangCollected,
                    newUtang: s.newUtang,
                    totalOwed: customers.totalOwed,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _LowStockCard(items: lowItems),
          const SizedBox(height: 12),
          // TEMPORARY: remove later
          ExpansionTile(
            title: const Text('Testing tools'),
            children: [
              TextButton(
                onPressed: _resetFirstRun,
                child: const Text('Reset first-run'),
              ),
              TextButton(
                onPressed: _selfTest,
                child: const Text('DB self-test'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugDataScreen()),
                ),
                child: const Text('Sales & stock data'),
              ),
              TextButton(
                onPressed: _wipeDatabase,
                child: const Text('Wipe database'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  final String periodLabel;
  final PeriodSummary summary;
  const _SalesCard({required this.periodLabel, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales · $periodLabel',
                    style: theme.textTheme.labelLarge,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money.format(summary.salesTotal),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${summary.salesCount}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  summary.salesCount == 1 ? 'sale' : 'sales',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: theme.textTheme.labelLarge),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _amountRow(
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

class _UtangCard extends StatelessWidget {
  final int collected;
  final int newUtang;
  final int totalOwed;

  const _UtangCard({
    required this.collected,
    required this.newUtang,
    required this.totalOwed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Utang',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _amountRow(context, 'Collected from customers', collected),
            _amountRow(context, 'New utang given', newUtang),
            const Divider(height: 20),
            _amountRow(context, 'Owed to you right now', totalOwed, bold: true),
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  final List<Item> items;
  const _LowStockCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const maxShown = 5;
    final shown = items.take(maxShown).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  items.isEmpty
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: items.isEmpty ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  items.isEmpty
                      ? 'Stock looks good'
                      : 'Low stock (${items.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No items are running low.'),
              ),
            for (final i in shown)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      i.inStock
                          ? '${Qty.format(i.quantity, i.unit)} left'
                          : 'Out of stock',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: i.inStock ? null : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            if (items.length > maxShown)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'and ${items.length - maxShown} more',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
