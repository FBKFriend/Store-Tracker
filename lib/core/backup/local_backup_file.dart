import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'backup_models.dart';

class LocalBackupInfo {
  final DateTime savedAt;
  final BackupSummary summary;
  final int sizeBytes;
  const LocalBackupInfo({
    required this.savedAt,
    required this.summary,
    required this.sizeBytes,
  });
}

/// The backup file kept in the phone's Documents folder.
class LocalBackupFile {
  LocalBackupFile._();

  static const folderPath = '/storage/emulated/0/Documents/MySariSariStore';
  static const fileName = 'MySariSariStore_BACKUP_DO_NOT_DELETE.json';
  static const readMeName = 'READ_ME_My_Sari-Sari_Store_backup.txt';
  static const shortPath = 'Documents/MySariSariStore/$fileName';

  static const _readMe =
      '''
MY SARI-SARI STORE - BACKUP FOLDER

The file "$fileName"
is a backup of your store's data: items, stock, sales, customers and utang.

PLEASE DO NOT DELETE OR RENAME IT.

If you reinstall the app or move to a new phone, My Sari-Sari Store can use
this file to bring your data back.

The file is updated each time you tap "Back up locally" in the app
(More > Backup). You can also copy it to a computer or another phone as an
extra safe copy.
''';

  static String get _filePath => '$folderPath/$fileName';

  // Android 11+ needs "All files access" to find a file left by an earlier
  // install. Android 10 and older use the normal storage permission.
  static Future<Permission> _permission() async {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    return sdk >= 30 ? Permission.manageExternalStorage : Permission.storage;
  }

  static Future<bool> hasAccess() async => (await _permission()).isGranted;

  static Future<bool> requestAccess() async {
    final status = await (await _permission()).request();
    return status.isGranted;
  }

  static Future<void> openSettings() => openAppSettings();

  static Future<void> write(String json) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    // Write to a temporary file first, so a failure can't ruin the old backup
    final temp = File('$folderPath/$fileName.tmp');
    await temp.writeAsString(json, flush: true);
    final target = File(_filePath);
    if (await target.exists()) await target.delete();
    await temp.rename(_filePath);
    await File('$folderPath/$readMeName').writeAsString(_readMe, flush: true);
  }

  /// Details of the saved file, or null if there isn't a valid one.
  static Future<LocalBackupInfo?> info() async {
    final file = File(_filePath);
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic> ||
          data['format'] != 'my-sari-sari-store-backup') {
        return null;
      }
      return LocalBackupInfo(
        savedAt:
            DateTime.tryParse('${data['createdAt']}') ??
            await file.lastModified(),
        summary: BackupSummary.fromProps(
          (data['summary'] as Map?)?.cast<String, dynamic>(),
        ),
        sizeBytes: await file.length(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> read() async {
    final file = File(_filePath);
    return await file.exists() ? file.readAsString() : null;
  }
}
