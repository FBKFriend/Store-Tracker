import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Thrown for problems the user can fix (duplicate names, bad quantities...)
class DataException implements Exception {
  final String message;
  DataException(this.message);

  @override
  String toString() => message;
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'sarisari_store.db';
  static const _dbVersion = 3;

  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL REFERENCES categories(id),
        unit TEXT NOT NULL DEFAULT 'pcs',
        buying_price INTEGER NOT NULL DEFAULT 0,
        selling_price INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_lots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL REFERENCES items(id),
        qty_received INTEGER NOT NULL,
        qty_remaining INTEGER NOT NULL,
        buying_price INTEGER NOT NULL,
        selling_price INTEGER NOT NULL,
        counts_as_expense INTEGER NOT NULL DEFAULT 1,
        received_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL REFERENCES items(id),
        lot_id INTEGER REFERENCES stock_lots(id),
        type TEXT NOT NULL,
        qty_change INTEGER NOT NULL,
        unit_cost INTEGER,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_items_category ON items(category_id)');
    await db.execute('CREATE INDEX idx_lots_item ON stock_lots(item_id)');
    await db.execute('CREATE INDEX idx_moves_item ON stock_movements(item_id)');

    await db.insert('categories', {
      'name': 'Uncategorized',
      'sort_order': 0,
      'is_default': 1,
    });

    await _createSalesTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Version 2 added customers, sales and utang. Version 3 runs that same
    // step again, safely (IF NOT EXISTS), for databases that were saved as
    // version 2 without those tables.
    if (oldVersion < 3) await _createSalesTables(db);
  }

  // Customers, sales and utang
  Future<void> _createSalesTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        total INTEGER NOT NULL,
        cash_received INTEGER NOT NULL,
        change_given INTEGER NOT NULL,
        utang_amount INTEGER NOT NULL DEFAULT 0,
        customer_id INTEGER REFERENCES customers(id),
        status TEXT NOT NULL DEFAULT 'completed',
        void_reason TEXT,
        voided_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id),
        item_id INTEGER NOT NULL REFERENCES items(id),
        lot_id INTEGER NOT NULL REFERENCES stock_lots(id),
        item_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        qty INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        unit_cost INTEGER NOT NULL,
        line_total INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        sale_id INTEGER REFERENCES sales(id),
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_created ON sales(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ledger_customer ON debt_ledger(customer_id)',
    );
  }

  // TEMPORARY: wipes everything, for testing only
  Future<void> deleteForTesting() async {
    if (_opening != null) {
      await (await _opening!).close();
      _opening = null;
    }
    await deleteDatabase(p.join(await getDatabasesPath(), _dbName));
  }
}
