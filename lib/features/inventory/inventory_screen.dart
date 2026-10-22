import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/utils/units.dart';
import '../../data/models/item.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/item_repository.dart';
import 'add_item_screen.dart';
import 'category_manager.dart';
import 'edit_item_screen.dart';
import 'restock_sheet.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int? _categoryId; // null = All
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.watch<CategoryRepository>().categories;
    final allItems = context.watch<ItemRepository>().items;
    final lowStockDefault = context.watch<SettingsController>().lowStockDefault;

    // If the selected category was just deleted, go back to "All"
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    final q = _query.trim().toLowerCase();
    final items = allItems.where((i) {
      final inCategory = _categoryId == null || i.categoryId == _categoryId;
      final matches = q.isEmpty || i.name.toLowerCase().contains(q);
      return inCategory && matches;
    }).toList();
    final categoryNames = {for (final c in categories) c.id: c.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Manage categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => showCategoryManager(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AddItemScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search items',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        allItems.isEmpty
                            ? 'No items yet.\nTap "Add item" to get started.'
                            : 'No items match.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) => _ItemTile(
                      item: items[index],
                      categoryName:
                          categoryNames[items[index].categoryId] ?? '',
                      globalLowStock: lowStockDefault,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  final String categoryName;
  final int globalLowStock;

  const _ItemTile({
    required this.item,
    required this.categoryName,
    required this.globalLowStock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final out = !item.inStock;
    final low = item.isLowStock(globalLowStock);

    final Color stockColor;
    final String? status;
    if (out) {
      stockColor = theme.colorScheme.error;
      status = 'Out of stock';
    } else if (low) {
      stockColor = AppColors.warning;
      status = 'Low stock';
    } else {
      stockColor = theme.colorScheme.onSurface;
      status = null;
    }

    final lines = [
      '$categoryName · ${Money.format(item.sellingPrice)} / ${item.unit.label}',
      if (item.priceChangePending)
        'New price ${Money.format(item.latestSellingPrice)} after current stock',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => EditItemScreen(item: item))),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(lines.join('\n')),
        isThreeLine: lines.length > 1,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Qty.format(item.quantity, item.unit),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: stockColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (status != null)
                  Text(
                    status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: stockColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'Add stock',
              icon: const Icon(Icons.add),
              onPressed: () => showRestockSheet(context, item),
            ),
          ],
        ),
      ),
    );
  }
}
