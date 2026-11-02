import 'package:flutter/foundation.dart';

import '../../core/utils/units.dart';
import '../app_database.dart';
import 'customer_repository.dart';
import 'item_repository.dart';
import '../models/sale.dart';

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

  /// Past sales, newest first. [from] limits how far back to look.
  Future<List<SaleSummary>> salesList({DateTime? from, int limit = 300}) async {
    final db = await _db.database;
    final args = <Object?>[];
    if (from != null) args.add(from.toIso8601String());
    final rows = await db.rawQuery('''
      SELECT s.*, c.name AS customer_name
      FROM sales s LEFT JOIN customers c ON c.id = s.customer_id
      ${from != null ? 'WHERE s.created_at >= ?' : ''}
      ORDER BY s.id DESC
      LIMIT $limit
    ''', args);
    return rows.map(SaleSummary.fromMap).toList();
  }

  Future<SaleDetail?> saleDetail(int saleId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT s.*, c.name AS customer_name
      FROM sales s LEFT JOIN customers c ON c.id = s.customer_id
      WHERE s.id = ?
    ''',
      [saleId],
    );
    if (rows.isEmpty) return null;
    final lines = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id',
    );
    return SaleDetail(
      sale: SaleSummary.fromMap(rows.first),
      lines: lines.map(SaleLineRow.fromMap).toList(),
    );
  }

  /// Cancels a sale but keeps it in the history with the reason. Stock goes
  /// back to the lots it came from, and any utang it created is reversed.
  Future<void> voidSale({required int saleId, required String reason}) async {
    final why = reason.trim();
    if (why.isEmpty) {
      throw DataException('Please write a reason for voiding this sale.');
    }
    final db = await _db.database;
    final nowText = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT s.*, c.name AS customer_name
        FROM sales s LEFT JOIN customers c ON c.id = s.customer_id
        WHERE s.id = ?
      ''',
        [saleId],
      );
      if (rows.isEmpty) throw DataException('Sale not found.');
      final sale = rows.first;
      if (sale['status'] == 'voided') {
        throw DataException('This sale is already voided.');
      }

      final utang = sale['utang_amount'] as int;
      final customerId = sale['customer_id'] as int?;
      final hasUtang = utang > 0 && customerId != null;

      // Only reverse up to what the customer still owes
      if (hasUtang) {
        final bal = await txn.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) AS balance FROM debt_ledger WHERE customer_id = ?',
          [customerId],
        );
        final owed = bal.first['balance'] as int;
        if (owed < utang) {
          throw DataException(
            '${sale['customer_name']} now owes ${Money.format(owed)}, which is '
            'less than the ${Money.format(utang)} this sale put on their utang, '
            'so they already paid part of it.\n\n'
            'Refund the difference (${Money.format(utang - owed)}) and record '
            'it in the Utang tab with Adjust, Add to utang, reason "refund". '
            'Then void this sale again.',
          );
        }
      }

      // Put the stock back in the lots it came from
      final lines = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      for (final l in lines) {
        await txn.rawUpdate(
          'UPDATE stock_lots SET qty_remaining = qty_remaining + ? WHERE id = ?',
          [l['qty'], l['lot_id']],
        );
        await txn.insert('stock_movements', {
          'item_id': l['item_id'],
          'lot_id': l['lot_id'],
          'type': 'void_return',
          'qty_change': l['qty'],
          'unit_cost': l['unit_cost'],
          'note': 'Voided sale #$saleId',
          'created_at': nowText,
        });
      }

      if (hasUtang) {
        await txn.insert('debt_ledger', {
          'customer_id': customerId,
          'sale_id': saleId,
          'type': 'void',
          'amount': -utang,
          'note': 'Sale #$saleId voided: $why',
          'created_at': nowText,
        });
      }

      await txn.update(
        'sales',
        {'status': 'voided', 'void_reason': why, 'voided_at': nowText},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });

    await _items.load();
    await _customers.load();
  }
}
