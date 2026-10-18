import 'package:flutter/foundation.dart';

import '../../core/utils/units.dart';
import '../app_database.dart';
import 'customer_repository.dart';
import 'item_repository.dart';

class SaleLine {
  final int itemId;
  final int qty; // thousandths
  const SaleLine({required this.itemId, required this.qty});
}

class SaleResult {
  final int saleId;
  final DateTime time;
  final int total;
  final int cashReceived;
  final int change;
  final int utang;
  final String? customerName;

  const SaleResult({
    required this.saleId,
    required this.time,
    required this.total,
    required this.cashReceived,
    required this.change,
    required this.utang,
    required this.customerName,
  });
}

// One slice of a sale: a quantity taken from one stock lot
class _Take {
  final int itemId;
  final String itemName;
  final String unit;
  final int lotId;
  final int qty;
  final int price;
  final int cost;
  final int total;

  const _Take({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.lotId,
    required this.qty,
    required this.price,
    required this.cost,
    required this.total,
  });
}

class SalesRepository {
  SalesRepository(this._db, this._items, this._customers);
  final AppDatabase _db;
  final ItemRepository _items;
  final CustomerRepository _customers;

  /// Saves a sale in one all-or-nothing step: takes stock from the oldest
  /// lots first, records the lines with their prices, and puts anything
  /// not paid on the customer's utang.
  Future<SaleResult> completeSale({
    required List<SaleLine> lines,
    required int expectedTotal,
    required int cashReceived,
    int? customerId,
    VoidCallback? afterCommit,
  }) async {
    if (lines.isEmpty) throw DataException('The cart is empty.');
    if (cashReceived < 0) {
      throw DataException('Amount received can\'t be negative.');
    }

    final db = await _db.database;
    final now = DateTime.now();
    final nowText = now.toIso8601String();

    final result = await db.transaction<SaleResult>((txn) async {
      // 1. Plan which lots each item is taken from (oldest first)
      final takes = <_Take>[];
      for (final line in lines) {
        final itemRows = await txn.query(
          'items',
          where: 'id = ?',
          whereArgs: [line.itemId],
          limit: 1,
        );
        if (itemRows.isEmpty) {
          throw DataException('An item in the cart no longer exists.');
        }
        final name = itemRows.first['name'] as String;
        final unit = itemRows.first['unit'] as String;
        final lots = await txn.query(
          'stock_lots',
          where: 'item_id = ? AND qty_remaining > 0',
          whereArgs: [line.itemId],
          orderBy: 'id',
        );
        var left = line.qty;
        for (final lot in lots) {
          if (left <= 0) break;
          final remaining = lot['qty_remaining'] as int;
          final take = left < remaining ? left : remaining;
          final price = lot['selling_price'] as int;
          takes.add(
            _Take(
              itemId: line.itemId,
              itemName: name,
              unit: unit,
              lotId: lot['id'] as int,
              qty: take,
              price: price,
              cost: lot['buying_price'] as int,
              total: Money.lineTotal(take, price),
            ),
          );
          left -= take;
        }
        if (left > 0) throw DataException('Not enough stock for $name.');
      }

      final total = takes.fold<int>(0, (sum, t) => sum + t.total);
      if (total != expectedTotal) {
        throw DataException(
          'Prices or stock changed while checking out. Please review the cart and try again.',
        );
      }

      // 2. Change or utang
      final change = cashReceived > total ? cashReceived - total : 0;
      final utang = cashReceived < total ? total - cashReceived : 0;
      String? customerName;
      if (utang > 0) {
        if (customerId == null) {
          throw DataException(
            'Choose a customer to charge ${Money.format(utang)} to.',
          );
        }
        final rows = await txn.query(
          'customers',
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw DataException('That customer no longer exists.');
        }
        customerName = rows.first['name'] as String;
      }

      // 3. Save everything
      final saleId = await txn.insert('sales', {
        'created_at': nowText,
        'total': total,
        'cash_received': cashReceived,
        'change_given': change,
        'utang_amount': utang,
        'customer_id': utang > 0 ? customerId : null,
        'status': 'completed',
      });
      for (final t in takes) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'item_id': t.itemId,
          'lot_id': t.lotId,
          'item_name': t.itemName,
          'unit': t.unit,
          'qty': t.qty,
          'unit_price': t.price,
          'unit_cost': t.cost,
          'line_total': t.total,
        });
        await txn.rawUpdate(
          'UPDATE stock_lots SET qty_remaining = qty_remaining - ? WHERE id = ?',
          [t.qty, t.lotId],
        );
        await txn.insert('stock_movements', {
          'item_id': t.itemId,
          'lot_id': t.lotId,
          'type': 'sale',
          'qty_change': -t.qty,
          'unit_cost': t.cost,
          'created_at': nowText,
        });
      }
      if (utang > 0) {
        await txn.insert('debt_ledger', {
          'customer_id': customerId,
          'sale_id': saleId,
          'type': 'charge',
          'amount': utang,
          'created_at': nowText,
        });
      }

      return SaleResult(
        saleId: saleId,
        time: now,
        total: total,
        cashReceived: cashReceived,
        change: change,
        utang: utang,
        customerName: customerName,
      );
    });

    afterCommit?.call(); // the cart is cleared before the stock reloads
    await _items.load();
    await _customers.load();
    return result;
  }

  // TEMPORARY: a plain-text look at what was saved, for testing
  Future<String> debugDump() async {
    final db = await _db.database;
    String m(Object? v) => Money.format(v as int);
    final buf = StringBuffer();

    buf.writeln('SALES (latest 10)');
    final sales = await db.query('sales', orderBy: 'id DESC', limit: 10);
    if (sales.isEmpty) buf.writeln('  none yet');
    for (final s in sales) {
      buf.writeln('#${s['id']}  ${s['created_at']}  ${s['status']}');
      buf.writeln(
        '  total ${m(s['total'])}  received ${m(s['cash_received'])}'
        '  change ${m(s['change_given'])}  utang ${m(s['utang_amount'])}'
        '  customer id: ${s['customer_id']}',
      );
      final lines = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [s['id']],
        orderBy: 'id',
      );
      for (final l in lines) {
        final unit = ItemUnit.fromName(l['unit'] as String);
        buf.writeln(
          '    ${l['item_name']}: ${Qty.format(l['qty'] as int, unit)}'
          ' x ${m(l['unit_price'])} (cost ${m(l['unit_cost'])})'
          ' = ${m(l['line_total'])}  [lot ${l['lot_id']}]',
        );
      }
    }

    buf.writeln('\nCUSTOMERS (what they owe)');
    final customers = await db.rawQuery('''
      SELECT c.name, COALESCE(SUM(d.amount), 0) AS balance
      FROM customers c LEFT JOIN debt_ledger d ON d.customer_id = c.id
      GROUP BY c.id ORDER BY c.name COLLATE NOCASE
    ''');
    if (customers.isEmpty) buf.writeln('  none yet');
    for (final c in customers) {
      buf.writeln('  ${c['name']}: ${m(c['balance'])}');
    }

    buf.writeln('\nSTOCK LOTS');
    final lots = await db.rawQuery('''
      SELECT l.id, i.name, l.qty_received, l.qty_remaining,
             l.buying_price, l.selling_price
      FROM stock_lots l JOIN items i ON i.id = l.item_id
      ORDER BY l.id
    ''');
    for (final l in lots) {
      buf.writeln(
        '  lot ${l['id']}  ${l['name']}: '
        '${Qty.plain(l['qty_remaining'] as int)} left of '
        '${Qty.plain(l['qty_received'] as int)}  '
        'buy ${m(l['buying_price'])}  sell ${m(l['selling_price'])}',
      );
    }
    return buf.toString();
  }
}
