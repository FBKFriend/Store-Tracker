// ignore_for_file: prefer_initializing_formals
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/backup/auto_backup_service.dart';
import '../../core/backup/backup_models.dart';
import '../../core/backup/backup_service.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/widgets/dialogs.dart';
import 'data_choice.dart';

/// After signing in: looks for a backup in Google Drive and, if there is one,
/// lets the user choose between it and what's on this phone.
Future<void> resolveCloudData(BuildContext context) async {
  final auth = context.read<GoogleAuthService>();
  final backup = context.read<BackupService>();
  final autoBackup = context.read<AutoBackupService>();
  final prefs = context.read<AppPrefs>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  if (!auth.isSignedIn || !auth.hasSession) return;

  List<CloudBackup> all;
  try {
    all = await backup.listBackups();
  } on BackupException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Couldn\'t check Google Drive yet. It will try again '
          'next time you open the app.\n${e.message}',
        ),
      ),
    );
    return;
  }

  CloudBackup? found;
  for (final b in all) {
    if (!b.isBeforeRestore) {
      found = b;
      break;
    }
  }
  if (found == null) {
    // Nothing in Drive yet: this phone's data becomes the first backup
    await prefs.setCloudCheckPending(false);
    autoBackup.retryNow();
    return;
  }
  final cloud = found;

  final phone = await backup.localSummary();
  final phoneEmpty = phone.isEmpty;
  final activity = await backup.localLastActivity();

  final options = [
    DataOption(
      source: DataSource.cloud,
      title: 'Google Drive copy',
      timeLabel: 'Last backed up',
      time: cloud.modifiedAt,
      summary: cloud.summary,
      cloud: cloud,
      buttonLabel: phoneEmpty ? 'Restore it' : 'Use the Google Drive copy',
    ),
    if (!phoneEmpty)
      DataOption(
        source: DataSource.phone,
        title: 'This phone',
        timeLabel: 'Last activity',
        time: activity,
        summary: phone,
        buttonLabel: 'Keep this phone\'s data',
      ),
  ];

  while (true) {
    final chosen = await navigator.push<DataOption>(
      MaterialPageRoute(
        builder: (_) => DataChoiceScreen(
          heading: phoneEmpty ? 'We found a backup' : 'Two copies of your data',
          message: phoneEmpty
              ? 'Your Google Drive has a backup of your store. Restore it to '
                    'this phone?'
              : 'Google Drive already has a backup, and this phone has its '
                    'own data. Choose the one to keep using. It replaces the '
                    'other. Older daily backups in Drive are kept.',
          options: options,
          freshLabel: phoneEmpty ? 'Start fresh' : null,
        ),
      ),
    );

    if (chosen == null) {
      // Started fresh on an empty phone. Nothing uploads until there is data.
      await prefs.setCloudCheckPending(false);
      autoBackup.retryNow();
      return;
    }

    if (chosen.source == DataSource.phone) {
      await prefs.setCloudCheckPending(false);
      autoBackup.retryNow();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Keeping this phone\'s data. Your next backup will update Google Drive.',
          ),
        ),
      );
      return;
    }

    // The Google Drive copy was chosen
    if (!phoneEmpty) {
      final ok = await showConfirmDialog(
        // ignore: use_build_context_synchronously
        navigator.context,
        title: 'Replace this phone\'s data?',
        message:
            'This replaces everything on this phone with the Google '
            'Drive copy.\n\nA copy of your current data is saved to Google '
            'Drive first, as "Saved before your last restore", so you can '
            'undo this.',
        confirmLabel: 'Replace',
      );
      if (!ok) continue; // back to the choice
    }
    try {
      await backup.restore(cloud);
      await prefs.setCloudCheckPending(false);
      autoBackup.retryNow();
      messenger.showSnackBar(
        const SnackBar(content: Text('Restored from Google Drive.')),
      );
      return;
    } on BackupException catch (e) {
      // ignore: use_build_context_synchronously
      await showErrorDialog(navigator.context, e.message);
      continue;
    }
  }
}
