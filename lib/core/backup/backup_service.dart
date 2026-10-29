// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:crypto/crypto.dart';
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

// A backup ready to upload, with a fingerprint of what's in it
class _Built {
  final String json;
  final String hash;
  final BackupSummary summary;
  const _Built(this.json, this.hash, this.summary);
}

class BackupService extends ChangeNotifier {
  BackupService({
    required AppDatabase db,
    required AppPrefs prefs,
    required DriveBackupClient drive,
    required SettingsController settings,
    required ItemRepository items,
    required CategoryRepository categories,
    required CustomerRepository customers,
    required VoidCallback clearCart,
  }) : _db = db,
       _prefs = prefs,
       _drive = drive,
       _settings = settings,
       _items = items,
       _categories = categories,
       _customers = customers,
       _clearCart = clearCart;

  final AppDatabase _db;
  final AppPrefs _prefs;
  final DriveBackupClient _drive;
  final SettingsController _settings;
  final ItemRepository _items;
  final CategoryRepository _categories;
  final CustomerRepository _customers;
  final VoidCallback _clearCart;

  /// How many daily backups are kept.
  static const keepSnapshots = 5;
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

  String _dailyName(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'daily-${d.year}-${two(d.month)}-${two(d.day)}.json';
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

  Future<_Built> _build() async {
    final database = await _db.database;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      tables[table] = await database.query(table, orderBy: 'id');
    }
    final summary = await localSummary();
    // The PIN and recovery answer are left out on purpose
    final payload = {
      'settings': {
        'storeName': _settings.storeName,
        'darkMode': _settings.isDark,
        'lowStockDefault': _settings.lowStockDefault,
      },
      'tables': tables,
    };
    final hash = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    final json = jsonEncode({
      'format': _format,
      'version': 1,
      'dbVersion': AppDatabase.version,
      'createdAt': DateTime.now().toIso8601String(),
      'summary': summary.toJson(),
      ...payload,
    });
    return _Built(json, hash, summary);
  }

  /// The full backup as text, for saving to a file on the phone.
  Future<String> exportJson() async => (await _build()).json;

  // Creates the file in Drive, or updates it if it's already there
  Future<void> _write(String name, _Built built) async {
    final existing = (await _drive.list()).where((b) => b.name == name);
    if (existing.isEmpty) {
      await _drive.upload(name: name, json: built.json, summary: built.summary);
    } else {
      await _drive.update(
        id: existing.first.id,
        json: built.json,
        summary: built.summary,
      );
    }
  }

  /// Saves today's backup if something changed since the last one (or if
  /// [force] is true). Returns true if anything was uploaded.
  Future<bool> sync({bool force = false}) async {
    if (_busy) {
      if (force) {
        throw BackupException('A backup or restore is already running.');
      }
      return false;
    }
    _setBusy(true);
    try {
      final built = await _build();
      final now = DateTime.now();
      if (!force && built.hash == _prefs.backupHash) {
        // Drive already has exactly this data
        await _prefs.setLastBackupAt(now);
        return false;
      }
      await _write(_dailyName(now), built);
      await _prefs.setBackupHash(built.hash);
      await _prefs.setLastBackupAt(now);
      await _trim();
      return true;
    } catch (e) {
      throw _friendly(e);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> backUpNow() async {
    await sync(force: true);
  }

  // Keeps the newest few daily backups. The "before restore" copy is separate.
  Future<void> _trim() async {
    try {
      final snapshots = (await _drive.list())
          .where((b) => !b.isBeforeRestore)
          .toList();
      for (final old in snapshots.skip(keepSnapshots)) {
        await _drive.delete(old.id);
      }
    } catch (_) {
      // A failed clean-up never fails the backup itself
    }
  }

  /// Replaces everything on this phone with the chosen backup. A copy of the
  /// current data is saved to Drive first, so a restore can be undone.
  Future<void> restore(CloudBackup backup) =>
      _restoreFrom(() => _drive.download(backup.id), safetyCopy: true);

  /// Restores from the text of a backup file saved on this phone.
  /// [safetyCopy] saves the current data to Drive first (needs Google).
  Future<void> restoreFromText(String text, {required bool safetyCopy}) =>
      _restoreFrom(() async => text, safetyCopy: safetyCopy);

  Future<void> _restoreFrom(
    Future<String> Function() getText, {
    required bool safetyCopy,
  }) async {
    if (_busy) throw BackupException('A backup or restore is already running.');
    _setBusy(true);
    try {
      final text = await getText();
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
      final categoryRows = tables is Map<String, dynamic>
          ? tables['categories']
          : null;
      if (tables is! Map<String, dynamic> ||
          categoryRows is! List ||
          categoryRows.isEmpty) {
        throw BackupException(
          'This backup looks incomplete, so nothing was changed.',
        );
      }

      // Safety copy of what's on the phone now (skipped on an empty phone)
      final local = await localSummary();
      if (safetyCopy &&
          (local.items > 0 || local.sales > 0 || local.customers > 0)) {
        try {
          await _write(CloudBackup.beforeRestoreName, await _build());
        } catch (e) {
          throw BackupException(
            'Could not save a safety copy of your current data first, so '
            'nothing was changed. (${_friendly(e).message})',
          );
        }
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
