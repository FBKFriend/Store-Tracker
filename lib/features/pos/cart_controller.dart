import 'package:flutter/foundation.dart';

import '../../core/utils/units.dart';
import '../../data/models/item.dart';
import '../../data/repositories/item_repository.dart';

class CartEntry {
  final Item item;
  final int qty; // thousandths
  const CartEntry({required this.item, required this.qty});

  int get total => item.totalFor(qty);

  /// e.g. "10 pcs × ₱12.00  +  2 pcs × ₱13.00"
  String get breakdown {
    final groups = <PriceLine>[];
    for (final line in item.priceLines(qty)) {
      if (groups.isNotEmpty && groups.last.price == line.price) {
        groups[groups.length - 1] = PriceLine(
          qty: groups.last.qty + line.qty,
          price: line.price,
        );
      } else {
        groups.add(line);
      }
    }
    return groups
        .map(
          (g) => '${Qty.format(g.qty, item.unit)} × ${Money.format(g.price)}',
        )
        .join('  +  ');
  }
}

class CartController extends ChangeNotifier {
  CartController(this._repo) {
    _repo.addListener(_onInventoryChanged);
  }

  final ItemRepository _repo;
  final Map<int, int> _qty = {}; // item id -> quantity (thousandths)
  String? _notice;

  /// A message for the POS screen to show once (stock changed, etc.).
  String? get notice => _notice;
  void clearNotice() => _notice = null;

  bool get isEmpty => _qty.isEmpty;
  int get lineCount => _qty.length;
  int qtyOf(int itemId) => _qty[itemId] ?? 0;

  /// Cart lines in the order they were added, using the latest stock info.
  List<CartEntry> get entries {
    final byId = {for (final i in _repo.items) i.id: i};
    final out = <CartEntry>[];
    _qty.forEach((id, qty) {
      final item = byId[id];
      if (item != null) out.add(CartEntry(item: item, qty: qty));
    });
    return out;
  }

  int get total => entries.fold(0, (sum, e) => sum + e.total);

  /// Sets the quantity, limited to what's in stock. Zero or less removes it.
  void setQty(Item item, int qty) {
    final clamped = qty > item.quantity ? item.quantity : qty;
    if (clamped <= 0) {
      _qty.remove(item.id);
    } else {
      _qty[item.id] = clamped;
    }
    notifyListeners();
  }

  void add(Item item, int step) => setQty(item, qtyOf(item.id) + step);

  void remove(int itemId) {
    if (_qty.remove(itemId) != null) notifyListeners();
  }

  void clear() {
    if (_qty.isEmpty) return;
    _qty.clear();
    notifyListeners();
  }

  // Keeps the cart honest when inventory changes while the POS tab is open.
  void _onInventoryChanged() {
    final byId = {for (final i in _repo.items) i.id: i};
    final notes = <String>[];
    for (final id in _qty.keys.toList()) {
      final item = byId[id];
      final qty = _qty[id]!;
      if (item == null || !item.inStock) {
        _qty.remove(id);
        notes.add(
          '${item?.name ?? 'An item'} is no longer available and was removed from the cart.',
        );
      } else if (qty > item.quantity) {
        _qty[id] = item.quantity;
        notes.add(
          '${item.name} was reduced to ${Qty.format(item.quantity, item.unit)} because stock changed.',
        );
      }
    }
    if (notes.isNotEmpty) _notice = notes.join('\n');
    notifyListeners(); // prices may have changed too
  }

  @override
  void dispose() {
    _repo.removeListener(_onInventoryChanged);
    super.dispose();
  }
}
