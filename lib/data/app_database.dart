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
  static const _dbVersion = 1;

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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Later steps add tables/columns here, one block per version number.
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
