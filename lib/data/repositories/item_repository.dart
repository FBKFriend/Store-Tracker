import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/units.dart';
import '../app_database.dart';
import '../models/item.dart';

class ItemRepository extends ChangeNotifier {
  ItemRepository(this._db);
  final AppDatabase _db;

  List<Item> _items = [];
  List<Item> get items => List.unmodifiable(_items);

  // Quantity = sum of all lots. The "current" price is the price of the
  // oldest lot that still has stock (falls back to the item's latest price).
  static const _selectSql = '''
    SELECT i.*,
      COALESCE((SELECT SUM(l.qty_remaining) FROM stock_lots l
                WHERE l.item_id = i.id), 0) AS quantity,
      COALESCE((SELECT l.selling_price FROM stock_lots l
                WHERE l.item_id = i.id AND l.qty_remaining > 0
                ORDER BY l.id LIMIT 1), i.selling_price) AS current_selling_price,
      COALESCE((SELECT l.buying_price FROM stock_lots l
                WHERE l.item_id = i.id AND l.qty_remaining > 0
                ORDER BY l.id LIMIT 1), i.buying_price) AS current_buying_price
    FROM items i
    WHERE i.is_archived = 0
    ORDER BY i.name COLLATE NOCASE
  ''';

  Future<void> load() async {
    final db = await _db.database;
    final rows = await db.rawQuery(_selectSql);
    final lotRows = await db.query(
      'stock_lots',
      columns: ['item_id', 'qty_remaining', 'selling_price'],
      where: 'qty_remaining > 0',
      orderBy: 'item_id, id',
    );
    final tiers = <int, List<StockTier>>{};
    for (final r in lotRows) {
      tiers
          .putIfAbsent(r['item_id'] as int, () => [])
          .add(
            StockTier(
              qty: r['qty_remaining'] as int,
              price: r['selling_price'] as int,
            ),
          );
    }
    _items = rows.map((r) {
      final item = Item.fromMap(r);
      return item.copyWithTiers(tiers[item.id] ?? const []);
    }).toList();
    notifyListeners();
  }

  String _now() => DateTime.now().toIso8601String();

  void _checkQty(ItemUnit unit, int milli) {
    if (!unit.allowsDecimal && milli % 1000 != 0) {
      throw DataException('${unit.label} items can only be whole numbers.');
    }
  }

  /// Adds an item. Starting stock becomes the first lot and counts as an
  /// expense (buying price x quantity).
  Future<int> addItem({
    required String name,
    required int categoryId,
    required ItemUnit unit,
    required int buyingPrice,
    required int sellingPrice,
    int? lowStockThreshold,
    int startingQty = 0,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw DataException('Item name can\'t be empty.');
    if (sellingPrice <= 0) {
      throw DataException('Selling price must be more than zero.');
    }
    if (buyingPrice < 0) {
      throw DataException('Buying price can\'t be negative.');
    }
    if (startingQty < 0) throw DataException('Quantity can\'t be negative.');
    if (lowStockThreshold != null && lowStockThreshold < 0) {
      throw DataException('The low-stock alert can\'t be negative.');
    }
    _checkQty(unit, startingQty);

    final db = await _db.database;
    final dup = await db.query(
      'items',
      where: 'name = ? COLLATE NOCASE AND is_archived = 0',
      whereArgs: [clean],
      limit: 1,
    );
    if (dup.isNotEmpty) {
      throw DataException('An item named "$clean" already exists.');
    }

    final now = _now();
    final id = await db.transaction<int>((txn) async {
      final itemId = await txn.insert('items', {
        'name': clean,
        'category_id': categoryId,
        'unit': unit.name,
        'buying_price': buyingPrice,
        'selling_price': sellingPrice,
        'low_stock_threshold': lowStockThreshold,
        'is_archived': 0,
        'created_at': now,
      });
      if (startingQty > 0) {
        final lotId = await txn.insert('stock_lots', {
          'item_id': itemId,
          'qty_received': startingQty,
          'qty_remaining': startingQty,
          'buying_price': buyingPrice,
          'selling_price': sellingPrice,
          'counts_as_expense': 1,
          'received_at': now,
        });
        await txn.insert('stock_movements', {
          'item_id': itemId,
          'lot_id': lotId,
          'type': 'initial',
          'qty_change': startingQty,
          'unit_cost': buyingPrice,
          'created_at': now,
        });
      }
      return itemId;
    });
    await load();
    return id;
  }

  /// Edits name, category, unit and low-stock alert. (Prices change through
  /// [restock] or [changeSellingPrice].)
  Future<void> updateItem({
    required int id,
    required String name,
    required int categoryId,
    required ItemUnit unit,
    int? lowStockThreshold,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw DataException('Item name can\'t be empty.');
    if (lowStockThreshold != null && lowStockThreshold < 0) {
      throw DataException('The low-stock alert can\'t be negative.');
    }
    final db = await _db.database;
    final rows = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw DataException('Item not found.');

    if (unit != ItemUnit.fromName(rows.first['unit'] as String)) {
      final lots =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM stock_lots WHERE item_id = ?',
              [id],
            ),
          ) ??
          0;
      if (lots > 0) {
        throw DataException(
          'The unit can\'t be changed once an item has stock history.',
        );
      }
    }
    final dup = await db.query(
      'items',
      where: 'name = ? COLLATE NOCASE AND is_archived = 0 AND id != ?',
      whereArgs: [clean, id],
      limit: 1,
    );
    if (dup.isNotEmpty) {
      throw DataException('An item named "$clean" already exists.');
    }
    await db.update(
      'items',
      {
        'name': clean,
        'category_id': categoryId,
        'unit': unit.name,
        'low_stock_threshold': lowStockThreshold,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await load();
  }

  /// Adds new stock as a new lot with its own prices. If
  /// [applyPriceToExistingStock] is true, the older stock switches to the new
  /// selling price right away; otherwise it keeps its old price until it runs
  /// out, and the new price takes over after.
  Future<void> restock({
    required int itemId,
    required int qty,
    required int buyingPrice,
    required int sellingPrice,
    bool applyPriceToExistingStock = false,
    String? note,
  }) async {
    if (qty <= 0) throw DataException('Quantity must be more than zero.');
    if (sellingPrice <= 0) {
      throw DataException('Selling price must be more than zero.');
    }
    if (buyingPrice < 0) {
      throw DataException('Buying price can\'t be negative.');
    }
    final db = await _db.database;
    final now = _now();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'items',
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (rows.isEmpty) throw DataException('Item not found.');
      _checkQty(ItemUnit.fromName(rows.first['unit'] as String), qty);

      final lotId = await txn.insert('stock_lots', {
        'item_id': itemId,
        'qty_received': qty,
        'qty_remaining': qty,
        'buying_price': buyingPrice,
        'selling_price': sellingPrice,
        'counts_as_expense': 1,
        'received_at': now,
      });
      await txn.insert('stock_movements', {
        'item_id': itemId,
        'lot_id': lotId,
        'type': 'restock',
        'qty_change': qty,
        'unit_cost': buyingPrice,
        'note': note,
        'created_at': now,
      });
      await txn.update(
        'items',
        {'buying_price': buyingPrice, 'selling_price': sellingPrice},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (applyPriceToExistingStock) {
        await txn.update(
          'stock_lots',
          {'selling_price': sellingPrice},
          where: 'item_id = ? AND qty_remaining > 0',
          whereArgs: [itemId],
        );
      }
    });
    await load();
  }

  /// Changes the selling price without restocking.
  Future<void> changeSellingPrice({
    required int itemId,
    required int newPrice,
    bool applyToExistingStock = false,
  }) async {
    if (newPrice <= 0) {
      throw DataException('Selling price must be more than zero.');
    }
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'items',
        {'selling_price': newPrice},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (applyToExistingStock) {
        await txn.update(
          'stock_lots',
          {'selling_price': newPrice},
          where: 'item_id = ? AND qty_remaining > 0',
          whereArgs: [itemId],
        );
      }
    });
    await load();
  }

  /// Hides an item from Inventory and the POS but keeps it in past records.
  Future<void> archiveItem(int id) async {
    final db = await _db.database;
    await db.update(
      'items',
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await load();
  }

  // TEMPORARY: for testing, remove later
  Future<List<Map<String, Object?>>> debugLots(int itemId) async {
    final db = await _db.database;
    return db.query(
      'stock_lots',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'id',
    );
  }
}
