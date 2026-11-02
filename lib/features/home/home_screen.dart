import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/auth/google_auth_service.dart';
import '../../core/backup/auto_backup_service.dart';
import '../../core/backup/backup_service.dart';
import '../../core/utils/date_format.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/models/item.dart';
import '../../data/models/report.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/reports_repository.dart';
import '../backup/backup_screen.dart';
import '../reports/expenses_breakdown_screen.dart';
import '../reports/end_of_day_report_screen.dart';
import '../reports/profit_breakdown_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppPrefs prefs;
  const HomeScreen({super.key, required this.prefs});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ReportPeriod _period = ReportPeriod.today;

  // ---- Dashboard ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = context.watch<ItemRepository>().items;
    final customers = context.watch<CustomerRepository>();
    final settings = context.watch<SettingsController>();
    final lowDefault = settings.lowStockDefault;
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
            Flexible(
              child: Text(
                settings.displayStoreName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'End-of-day report',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EndOfDayReportScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _BackupStatusRow(),
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

class _BackupStatusRow extends StatelessWidget {
  const _BackupStatusRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = context.watch<GoogleAuthService>().isSignedIn;
    final backup = context.watch<BackupService>();
    final auto = context.watch<AutoBackupService>();
    final last = backup.lastBackupAt;

    final IconData icon;
    final String text;
    final Color color;
    if (!signedIn) {
      icon = Icons.cloud_off;
      text = 'Not backed up. Your data is only on this phone.';
      color = AppColors.warning;
    } else if (backup.busy) {
      icon = Icons.cloud_sync_outlined;
      text = 'Backing up...';
      color = theme.colorScheme.primary;
    } else if (auto.hasProblem) {
      icon = Icons.error_outline;
      text = 'Backup problem. Tap for details.';
      color = theme.colorScheme.error;
    } else if (auto.statusText.isNotEmpty) {
      icon = Icons.cloud_queue;
      text = auto.statusText;
      color = AppColors.warning;
    } else if (last == null) {
      icon = Icons.cloud_queue;
      text = 'No backup yet.';
      color = AppColors.warning;
    } else {
      final stale = DateTime.now().difference(last) > const Duration(days: 2);
      icon = stale ? Icons.cloud_off : Icons.cloud_done_outlined;
      text = 'Backed up ${Fmt.timeAgo(last)}';
      color = stale ? AppColors.warning : AppColors.success;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color),
        title: Text(text),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BackupScreen())),
      ),
    );
  }
}
