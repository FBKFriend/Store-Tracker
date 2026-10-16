import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/category.dart';
import '../../data/models/item.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/item_repository.dart';
import 'cart_controller.dart';
import 'cart_sheet.dart';
import 'pos_widgets.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  int? _categoryId; // null = All
  String _query = '';

  Future<void> _onTapProduct(Item item) async {
    final cart = context.read<CartController>();
    if (item.unit.allowsDecimal) {
      // kg items: choose how much (0.25, 0.5, 1...)
      final result = await showQuantityDialog(
        context,
        item: item,
        current: cart.qtyOf(item.id),
      );
      if (result != null) cart.setQty(item, result);
    } else {
      cart.add(item, 1000);
    }
  }

  Future<void> _confirmClear() async {
    final cart = context.read<CartController>();
    final ok = await showConfirmDialog(
      context,
      title: 'Clear the cart?',
      message: 'All items will be removed.',
      confirmLabel: 'Clear',
    );
    if (ok) cart.clear();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryRepository>().categories;
    final allItems = context.watch<ItemRepository>().items;
    final cart = context.watch<CartController>();

    // Show a one-time notice if stock changed under the cart
    final notice = cart.notice;
    if (notice != null) {
      cart.clearNotice();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(notice)));
      });
    }

    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    final q = _query.trim().toLowerCase();
    final matching = allItems.where((i) {
      final inCategory = _categoryId == null || i.categoryId == _categoryId;
      final matches = q.isEmpty || i.name.toLowerCase().contains(q);
      return inCategory && matches;
    }).toList();
    // Items you can sell first, out-of-stock ones at the end
    final items = [
      ...matching.where((i) => i.inStock),
      ...matching.where((i) => !i.inStock),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of sale'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'Clear cart',
              icon: const Icon(Icons.remove_shopping_cart_outlined),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: Row(
        children: [
          _CategoryRail(
            categories: categories,
            selectedId: _categoryId,
            onSelected: (id) => setState(() => _categoryId = id),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              allItems.isEmpty
                                  ? 'No items yet.\nAdd some in the Inventory tab.'
                                  : 'No items match.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                mainAxisExtent: 140,
                              ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final inCart = cart.qtyOf(item.id);
                            return _ProductTile(
                              item: item,
                              qtyInCart: inCart,
                              onTap: () => _onTapProduct(item),
                              onQtyChanged: (qty) => cart.setQty(item, qty),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _CartBar(
        cart: cart,
        onReview: () => showCartSheet(context),
        onCharge: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment is built in the next step (3B).'),
          ),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  final List<ItemCategory> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _CategoryRail({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        children: [
          _RailButton(
            label: 'All',
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final c in categories)
            _RailButton(
              label: c.name,
              selected: selectedId == c.id,
              onTap: () => onSelected(c.id),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : null,
          border: Border(
            left: BorderSide(
              color: selected ? color : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? color : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Item item;
  final int qtyInCart;
  final VoidCallback onTap;
  final ValueChanged<int> onQtyChanged;

  const _ProductTile({
    required this.item,
    required this.qtyInCart,
    required this.onTap,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final out = !item.inStock;
    final inCart = qtyInCart > 0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: inCart ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: out ? null : onTap,
        child: Opacity(
          opacity: out ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Money.format(item.sellingPrice)} / ${item.unit.label}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  out
                      ? 'Out of stock'
                      : '${Qty.format(item.quantity - qtyInCart, item.unit)} left',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: out ? theme.colorScheme.error : null,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 32,
                  child: inCart
                      ? QtyStepper(
                          item: item,
                          qty: qtyInCart,
                          onChanged: onQtyChanged,
                        )
                      : out
                      ? null
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.add_circle_outline,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final CartController cart;
  final VoidCallback onReview;
  final VoidCallback onCharge;

  const _CartBar({
    required this.cart,
    required this.onReview,
    required this.onCharge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = cart.isEmpty;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: empty ? null : onReview,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        empty
                            ? 'Cart is empty'
                            : '${cart.lineCount} item${cart.lineCount == 1 ? '' : 's'} · tap to review',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        Money.format(cart.total),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: empty ? null : onCharge,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                child: const Text('Charge'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
