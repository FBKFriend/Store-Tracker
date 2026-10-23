import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_controller.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/item_repository.dart';
import 'end_of_day_report_screen.dart';
import 'pdf_reports.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _printInventory(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final items = context.read<ItemRepository>().items;
    final categories = context.read<CategoryRepository>().categories;
    final storeName = context.read<SettingsController>().displayStoreName;
    if (items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('There are no items to print yet.')),
      );
      return;
    }
    try {
      final bytes = await PdfReports.inventoryList(
        items: items,
        categories: categories,
        storeName: storeName,
      );
      await Printing.layoutPdf(
        name: 'Inventory list',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create the PDF: $e')),
      );
    }
  }

  Future<void> _printShoppingList(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final items = context.read<ItemRepository>().items;
    final categories = context.read<CategoryRepository>().categories;
    final settings = context.read<SettingsController>();
    final lowDefault = settings.lowStockDefault;
    final anyLow = items.any((i) => !i.inStock || i.isLowStock(lowDefault));
    if (!anyLow) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing is running low right now.')),
      );
      return;
    }
    try {
      final bytes = await PdfReports.shoppingList(
        items: items,
        categories: categories,
        lowStockDefault: lowDefault,
        storeName: settings.displayStoreName,
      );
      await Printing.layoutPdf(
        name: 'Shopping list',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create the PDF: $e')),
      );
    }
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
            subtitle: 'Print or save an A4 PDF of all items',
            onTap: () => _printInventory(context),
          ),
          _ReportTile(
            icon: Icons.shopping_cart_checkout,
            title: 'Low-stock shopping list',
            subtitle: 'Print or save an A4 PDF to take shopping',
            onTap: () => _printShoppingList(context),
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
