// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../settings/settings_controller.dart';
import '../storage/app_prefs.dart';
import 'backup_models.dart';
import 'drive_backup_client.dart';

class BackupService extends ChangeNotifier {
  BackupService({
    required this._db,
    required AppPrefs prefs,
    required this._drive,
    required this._settings,
    required this._items,
    required this._categories,
    required this._customers,
    required this._clearCart,
  }) : _prefs = prefs;

  final AppDatabase _db;
  final AppPrefs _prefs;
  final DriveBackupClient _drive;
  final SettingsController _settings;
  final ItemRepository _items;
  final CategoryRepository _categories;
  final CustomerRepository _customers;
  final VoidCallback _clearCart;

  static const keepCount = 5;
  static const _format = 'my-sari-sari-store-backup';

  // Parents before children, so every row finds what it points to
  static const _tables = [
    'categories',
    'customers',
    'items',
    'stock_lots',
    'stock_movements',
    'sales',
    'sale_items',
    'debt_ledger',
  ];

  bool _busy = false;
  bool get busy => _busy;
  DateTime? get lastBackupAt => _prefs.lastBackupAt;

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  BackupException _friendly(Object e) {
    if (e is BackupException) return e;
    final text = e.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException') ||
        text.contains('Connection')) {
      return BackupException(
        'No internet connection. Try again when you\'re online.',
      );
    }
    return BackupException('Something went wrong: $text');
  }

  String _stamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}_'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  /// Headline numbers for the data on this phone.
  Future<BackupSummary> localSummary() async {
    final database = await _db.database;
    Future<int> count(String sql) async =>
        Sqflite.firstIntValue(await database.rawQuery(sql)) ?? 0;
    return BackupSummary(
      items: await count('SELECT COUNT(*) FROM items WHERE is_archived = 0'),
      sales: await count(
        "SELECT COUNT(*) FROM sales WHERE status = 'completed'",
      ),
      salesTotal: await count(
        "SELECT COALESCE(SUM(total), 0) FROM sales WHERE status = 'completed'",
      ),
      customers: await count('SELECT COUNT(*) FROM customers'),
    );
  }

  Future<List<CloudBackup>> listBackups() async {
    try {
      return await _drive.list();
    } catch (e) {
      throw _friendly(e);
    }
  }

  Future<(String, BackupSummary)> _buildBackup() async {
    final database = await _db.database;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      tables[table] = await database.query(table, orderBy: 'id');
    }
    final summary = await localSummary();
    final data = {
      'format': _format,
      'version': 1,
      'dbVersion': AppDatabase.version,
      'createdAt': DateTime.now().toIso8601String(),
      'summary': summary.toJson(),
      // The PIN and recovery answer are left out on purpose
      'settings': {
        'storeName': _settings.storeName,
        'darkMode': _settings.isDark,
        'lowStockDefault': _settings.lowStockDefault,
      },
      'tables': tables,
    };
    return (jsonEncode(data), summary);
  }

  /// Saves a backup to Google Drive and keeps only the newest [keepCount].
  Future<void> backUpNow() async {
    if (_busy) throw BackupException('A backup or restore is already running.');
    _setBusy(true);
    try {
      final (json, summary) = await _buildBackup();
      final now = DateTime.now();
      await _drive.upload(
        name: 'backup-${_stamp(now)}.json',
        json: json,
        summary: summary,
      );
      await _prefs.setLastBackupAt(now);
      await _trim();
    } catch (e) {
      throw _friendly(e);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _trim() async {
    try {
      final all = await _drive.list(); // newest first
      for (final old in all.skip(keepCount)) {
        await _drive.delete(old.id);
      }
    } catch (_) {
      // A failed clean-up never fails the backup itself
    }
  }

  /// Replaces everything on this phone with the chosen backup.
  Future<void> restore(CloudBackup backup) async {
    if (_busy) throw BackupException('A backup or restore is already running.');
    _setBusy(true);
    try {
      final text = await _drive.download(backup.id);
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic> || data['format'] != _format) {
        throw BackupException('That file is not a My Sari-Sari Store backup.');
      }
      final fileVersion = (data['dbVersion'] as num?)?.toInt() ?? 0;
      if (fileVersion > AppDatabase.version) {
        throw BackupException(
          'This backup was made by a newer version of the app. Update the app first.',
        );
      }
      final tables = data['tables'];
      if (tables is! Map<String, dynamic>) {
        throw BackupException(
          'This backup looks incomplete, so nothing was changed.',
        );
      }
      final categoryRows = tables['categories'];
      if (categoryRows is! List || categoryRows.isEmpty) {
        throw BackupException(
          'This backup looks incomplete, so nothing was changed.',
        );
      }

      // All or nothing: if anything fails, the phone keeps its current data
      final database = await _db.database;
      await database.transaction((txn) async {
        for (final table in _tables.reversed) {
          await txn.delete(table);
        }
        await txn.delete('sqlite_sequence');
        final batch = txn.batch();
        for (final table in _tables) {
          final rows = tables[table];
          if (rows is! List) continue;
          for (final row in rows) {
            batch.insert(table, Map<String, Object?>.from(row as Map));
          }
        }
        await batch.commit(noResult: true);
      });

      final settings = data['settings'];
      if (settings is Map<String, dynamic>) {
        final storeName = settings['storeName'];
        final darkMode = settings['darkMode'];
        final lowStock = settings['lowStockDefault'];
        if (storeName is String) await _settings.setStoreName(storeName);
        if (darkMode is bool) await _settings.setDark(darkMode);
        if (lowStock is int) await _settings.setLowStockDefault(lowStock);
      }

      _clearCart();
      await _categories.load();
      await _customers.load();
      await _items.load();
    } catch (e) {
      throw _friendly(e);
    } finally {
      _setBusy(false);
    }
  }
}
