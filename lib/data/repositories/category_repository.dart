import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../models/category.dart';

class CategoryRepository extends ChangeNotifier {
  CategoryRepository(this._db);
  final AppDatabase _db;

  List<ItemCategory> _categories = [];
  List<ItemCategory> get categories => List.unmodifiable(_categories);

  Future<void> load() async {
    final db = await _db.database;
    final rows = await db.query(
      'categories',
      orderBy: 'is_default, sort_order, name COLLATE NOCASE',
    );
    _categories = rows.map(ItemCategory.fromMap).toList();
    notifyListeners();
  }

  Future<ItemCategory> add(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw DataException('Category name can\'t be empty.');
    final db = await _db.database;
    final exists = await db.query(
      'categories',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [clean],
      limit: 1,
    );
    if (exists.isNotEmpty) {
      throw DataException('A category named "$clean" already exists.');
    }
    final next = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 AS next FROM categories',
    );
    final id = await db.insert('categories', {
      'name': clean,
      'sort_order': next.first['next'],
      'is_default': 0,
    });
    await load();
    return _categories.firstWhere((c) => c.id == id);
  }

  Future<void> rename(int id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw DataException('Category name can\'t be empty.');
    final db = await _db.database;
    final rows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    if ((rows.first['is_default'] as int) == 1) {
      throw DataException('The Uncategorized category can\'t be renamed.');
    }
    final dup = await db.query(
      'categories',
      where: 'name = ? COLLATE NOCASE AND id != ?',
      whereArgs: [clean, id],
      limit: 1,
    );
    if (dup.isNotEmpty) {
      throw DataException('A category named "$clean" already exists.');
    }
    await db.update(
      'categories',
      {'name': clean},
      where: 'id = ?',
      whereArgs: [id],
    );
    await load();
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    if ((rows.first['is_default'] as int) == 1) {
      throw DataException('The Uncategorized category can\'t be deleted.');
    }
    final active =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM items WHERE category_id = ? AND is_archived = 0',
            [id],
          ),
        ) ??
        0;
    if (active > 0) {
      throw DataException(
        'This category still has $active item${active == 1 ? '' : 's'}. '
        'Move them to another category first.',
      );
    }
    await db.transaction((txn) async {
      // Archived items are hidden, so they quietly move to Uncategorized.
      final def = await txn.query(
        'categories',
        columns: ['id'],
        where: 'is_default = 1',
        limit: 1,
      );
      await txn.update(
        'items',
        {'category_id': def.first['id']},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
    await load();
  }
}
