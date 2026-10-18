import 'package:flutter/foundation.dart';

import '../app_database.dart';
import '../models/customer.dart';

class CustomerRepository extends ChangeNotifier {
  CustomerRepository(this._db);
  final AppDatabase _db;

  List<Customer> _customers = [];
  List<Customer> get customers => List.unmodifiable(_customers);

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
}
