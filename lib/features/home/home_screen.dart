import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/storage/app_prefs.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../legal/terms_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppPrefs prefs;
  const HomeScreen({super.key, required this.prefs});

  // TEMPORARY: checks that saving, restocking and price lots work
  Future<void> _selfTest(BuildContext context) async {
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
      debugPrint('LOTS: ${await items.debugLots(id)}');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${item.name}: ${Qty.format(item.quantity, item.unit)} in stock, '
            'selling at ${Money.format(item.sellingPrice)}, '
            'next price ${Money.format(item.latestSellingPrice)} '
            '(${items.items.length} items in database)',
          ),
        ),
      );
    } on DataException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Self-test failed: $e')));
    }
  }

  // TEMPORARY: deletes the whole database
  Future<void> _wipeDatabase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await AppDatabase.instance.deleteForTesting();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Database wiped. Fully close and reopen the app.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 140),
            const SizedBox(height: 16),
            Text(
              'My Sari-Sari Store',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Mode: ${prefs.authMode.name}'),
            const SizedBox(height: 32),
            // TEMPORARY: remove later
            TextButton(
              onPressed: () async {
                await prefs.resetForTesting();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => TermsScreen(prefs: prefs)),
                );
              },
              child: const Text('Reset first-run (testing only)'),
            ),
            TextButton(
              onPressed: () => _selfTest(context),
              child: const Text('DB self-test (testing only)'),
            ),
            TextButton(
              onPressed: () => _wipeDatabase(context),
              child: const Text('Wipe database (testing only)'),
            ),
          ],
        ),
      ),
    );
  }
}
