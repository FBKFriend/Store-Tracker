import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/units.dart';
import '../app_database.dart';
import '../models/customer.dart';
import '../models/ledger_entry.dart';

class CustomerRepository extends ChangeNotifier {
  CustomerRepository(this._db);
  final AppDatabase _db;

  List<Customer> _customers = [];
  List<Customer> get customers => List.unmodifiable(_customers);

  /// Everything customers currently owe, in centavos.
  int get totalOwed =>
      _customers.fold(0, (sum, c) => c.balance > 0 ? sum + c.balance : sum);

  Customer? byId(int id) {
    for (final c in _customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> load() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT c.id, c.name,
        COALESCE((SELECT SUM(d.amount) FROM debt_ledger d
                  WHERE d.customer_id = c.id), 0) AS balance
      FROM customers c
      ORDER BY c.name COLLATE NOCASE
    ''');
    _customers = rows.map(Customer.fromMap).toList();
    notifyListeners();
  }

  Future<Customer> add(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw DataException('Customer name can\'t be empty.');
    final db = await _db.database;
    final dup = await db.query(
      'customers',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [clean],
      limit: 1,
    );
    if (dup.isNotEmpty) {
      throw DataException('A customer named "$clean" already exists.');
    }
    final id = await db.insert('customers', {
      'name': clean,
      'created_at': DateTime.now().toIso8601String(),
    });
    await load();
    return _customers.firstWhere((c) => c.id == id);
  }

  Future<void> rename(int id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw DataException('Customer name can\'t be empty.');
    final db = await _db.database;
    final dup = await db.query(
      'customers',
      where: 'name = ? COLLATE NOCASE AND id != ?',
      whereArgs: [clean, id],
      limit: 1,
    );
    if (dup.isNotEmpty) {
      throw DataException('A customer named "$clean" already exists.');
    }
    await db.update(
      'customers',
      {'name': clean},
      where: 'id = ?',
      whereArgs: [id],
    );
    await load();
  }

  /// Only customers with no utang history can be deleted.
  Future<void> delete(int id) async {
    final db = await _db.database;
    final ledger =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM debt_ledger WHERE customer_id = ?',
            [id],
          ),
        ) ??
        0;
    final sales =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sales WHERE customer_id = ?',
            [id],
          ),
        ) ??
        0;
    if (ledger > 0 || sales > 0) {
      throw DataException(
        'This customer has utang history, so they can\'t be deleted.',
      );
    }
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  /// Newest first.
  Future<List<LedgerEntry>> ledgerFor(int customerId) async {
    final db = await _db.database;
    final rows = await db.query(
      'debt_ledger',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'id DESC',
    );
    return rows.map(LedgerEntry.fromMap).toList();
  }

  Future<int> _balance(DatabaseExecutor db, int customerId) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS balance FROM debt_ledger WHERE customer_id = ?',
      [customerId],
    );
    return rows.first['balance'] as int;
  }

  String? _cleanNote(String? note) {
    final text = note?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// The customer pays some or all of what they owe.
  Future<void> recordPayment({
    required int customerId,
    required int amount,
    String? note,
  }) async {
    if (amount <= 0) throw DataException('Enter an amount more than zero.');
    final db = await _db.database;
    await db.transaction((txn) async {
      final owed = await _balance(txn, customerId);
      if (owed <= 0)
        // ignore: curly_braces_in_flow_control_structures
        throw DataException('This customer doesn\'t owe anything.');
      if (amount > owed) {
        throw DataException(
          'That\'s more than they owe (${Money.format(owed)}).',
        );
      }
      await txn.insert('debt_ledger', {
        'customer_id': customerId,
        'type': 'payment',
        'amount': -amount,
        'note': _cleanNote(note),
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    await load();
  }

  /// Manual fix by the owner. [amount] is signed: positive adds to what they
  /// owe, negative reduces it. A reason is required.
  Future<void> recordAdjustment({
    required int customerId,
    required int amount,
    required String note,
  }) async {
    if (amount == 0) throw DataException('Enter an amount more than zero.');
    final reason = note.trim();
    if (reason.isEmpty) {
      throw DataException('Please write a reason for the adjustment.');
    }
    final db = await _db.database;
    await db.transaction((txn) async {
      final owed = await _balance(txn, customerId);
      if (owed + amount < 0) {
        throw DataException('That would make the balance negative.');
      }
      await txn.insert('debt_ledger', {
        'customer_id': customerId,
        'type': 'adjustment',
        'amount': amount,
        'note': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    await load();
  }
}
