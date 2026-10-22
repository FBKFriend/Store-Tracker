import 'package:flutter/material.dart';

import 'end_of_day_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportTile(
            icon: Icons.summarize_outlined,
            title: 'End-of-day report',
            subtitle: 'Sales, profit, utang and cash for any day',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EndOfDayReportScreen()),
            ),
          ),
          _ReportTile(
            icon: Icons.inventory_2_outlined,
            title: 'Inventory list',
            subtitle: 'Printable A4 PDF (coming soon)',
            onTap: () => _comingSoon(context),
          ),
          _ReportTile(
            icon: Icons.shopping_cart_checkout,
            title: 'Low-stock shopping list',
            subtitle: 'Printable A4 PDF (coming soon)',
            onTap: () => _comingSoon(context),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
