import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/backup/auto_backup_service.dart';
import '../../core/backup/backup_models.dart';
import '../../core/backup/backup_service.dart';
import '../../core/backup/local_backup_file.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/google_sign_in_button.dart';
import 'cloud_check.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late Future<BackupSummary> _local;
  late Future<(bool, LocalBackupInfo?)> _localFile;
  Future<List<CloudBackup>>? _backups;

  @override
  void initState() {
    super.initState();
    _local = context.read<BackupService>().localSummary();
    _localFile = _loadLocalFile();
    _backups = _fetchBackups();
  }

  Future<(bool, LocalBackupInfo?)> _loadLocalFile() async {
    if (!await LocalBackupFile.hasAccess()) return (false, null);
    return (true, await LocalBackupFile.info());
  }

  Future<List<CloudBackup>>? _fetchBackups() {
    final auth = context.read<GoogleAuthService>();
    if (!auth.isSignedIn || !auth.hasSession) return null;
    return context.read<BackupService>().listBackups();
  }

  void _refresh() {
    setState(() {
      _local = context.read<BackupService>().localSummary();
      _localFile = _loadLocalFile();
      _backups = _fetchBackups();
    });
  }

  String _describe(BackupSummary s) =>
      '${s.items} items · ${s.sales} sales (${Money.format(s.salesTotal)}) · '
      '${s.customers} customers';

  // ---- Google ----

  Future<void> _signIn() async {
    final auth = context.read<GoogleAuthService>();
    final result = await auth.signIn();
    if (!mounted) return;
    if (result.ok) {
      await resolveCloudData(context);
      if (mounted) _refresh();
    } else if (!result.cancelled) {
      await showErrorDialog(context, result.message ?? 'Sign-in failed.');
    }
  }

  Future<void> _reconnect() async {
    final auth = context.read<GoogleAuthService>();
    final autoBackup = context.read<AutoBackupService>();
    final result = await auth.reconnect();
    if (!mounted) return;
    if (result.ok) {
      autoBackup.retryNow();
      _refresh();
    } else if (!result.cancelled) {
      await showErrorDialog(context, result.message ?? 'Could not reconnect.');
    }
  }

  Future<void> _backUp() async {
    final service = context.read<BackupService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.backUpNow();
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup saved to your Google Drive.')),
      );
    } on BackupException catch (e) {
      if (mounted) await showErrorDialog(context, e.message);
    }
    if (mounted) _refresh();
  }

  Future<void> _restore(CloudBackup backup) async {
    final service = context.read<BackupService>();
    final messenger = ScaffoldMessenger.of(context);
    final local = await service.localSummary();
    if (!mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Restore this backup?',
      message:
          'This replaces everything on this phone (items, stock, sales, '
          'customers, utang, store name and settings) with the backup from '
          '${Fmt.dateTime(backup.modifiedAt)}.\n\n'
          'Backup: ${_describe(backup.summary)}\n'
          'This phone now: ${_describe(local)}\n\n'
          'A copy of your current data is saved first, as "Saved before your '
          'last restore", so you can undo this. Your PIN is not affected.',
      confirmLabel: 'Restore',
    );
    if (!ok || !mounted) return;
    try {
      await service.restore(backup);
      messenger.showSnackBar(const SnackBar(content: Text('Backup restored.')));
    } on BackupException catch (e) {
      if (mounted) await showErrorDialog(context, e.message);
    }
    if (mounted) _refresh();
  }

  // ---- File on this phone ----

  Future<bool> _ensureStorageAccess() async {
    if (await LocalBackupFile.hasAccess()) return true;
    if (!mounted) return false;
    final ok = await showConfirmDialog(
      context,
      title: 'Allow file access?',
      message:
          'To save and find your backup file in the Documents folder, '
          'Android needs you to allow file access for this app. On the next '
          'screen, switch on "Allow access to manage all files", then come '
          'back.',
      confirmLabel: 'Continue',
    );
    if (!ok) return false;
    final granted = await LocalBackupFile.requestAccess();
    if (!granted && mounted) {
      await showErrorDialog(
        context,
        'File access was not allowed, so the backup file can\'t be used. '
        'You can allow it in Android Settings → Apps → My Sari-Sari Store.',
      );
    }
    return granted;
  }

  Future<void> _backUpLocally() async {
    final service = context.read<BackupService>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await _ensureStorageAccess()) {
      if (mounted) _refresh();
      return;
    }
    try {
      await LocalBackupFile.write(await service.exportJson());
      messenger.showSnackBar(
        SnackBar(content: Text('Saved to ${LocalBackupFile.shortPath}')),
      );
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Could not save the file: $e');
      }
    }
    if (mounted) _refresh();
  }

  Future<void> _restoreFromFile() async {
    final service = context.read<BackupService>();
    final auth = context.read<GoogleAuthService>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await _ensureStorageAccess()) {
      if (mounted) _refresh();
      return;
    }
    final info = await LocalBackupFile.info();
    if (!mounted) return;
    if (info == null) {
      await showErrorDialog(
        context,
        'No backup file was found in ${LocalBackupFile.shortPath}.',
      );
      return;
    }
    final current = await service.localSummary();
    if (!mounted) return;
    final canUndo = auth.isSignedIn && auth.hasSession;
    final ok = await showConfirmDialog(
      context,
      title: 'Restore from the file?',
      message:
          'This replaces everything on this phone with the file saved '
          '${Fmt.dateTime(info.savedAt)}.\n\n'
          'File: ${_describe(info.summary)}\n'
          'This phone now: ${_describe(current)}\n\n'
          '${canUndo ? 'A copy of your current data is saved to Google Drive first, so you can undo this.' : 'This can\'t be undone, so anything newer than the file will be lost.'}',
      confirmLabel: 'Restore',
    );
    if (!ok || !mounted) return;
    try {
      final text = await LocalBackupFile.read();
      if (text == null) throw BackupException('The file could not be read.');
      await service.restoreFromText(text, safetyCopy: canUndo);
      messenger.showSnackBar(
        const SnackBar(content: Text('Restored from the backup file.')),
      );
    } on BackupException catch (e) {
      if (mounted) await showErrorDialog(context, e.message);
    }
    if (mounted) _refresh();
  }

  String _label(CloudBackup b, bool isLatest) {
    if (b.isBeforeRestore) return 'Saved before your last restore';
    if (isLatest) return 'Latest';
    return b.isDaily ? 'Daily backup' : 'Earlier backup';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<GoogleAuthService>();
    final service = context.watch<BackupService>();
    final auto = context.watch<AutoBackupService>();
    final busy = service.busy;
    final last = service.lastBackupAt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: busy ? null : _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (!auth.isSignedIn)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_off, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text(
                          'Not backed up online',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You\'re using the app as a guest, so your data is only '
                      'on this phone. It could be lost if the phone is lost or '
                      'damaged, or the app is deleted. Sign in with Google to '
                      'back up to your own Google Drive, or save a backup '
                      'file on this phone below.',
                    ),
                    const SizedBox(height: 12),
                    GoogleSignInButton(onPressed: _signIn),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.email, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      last == null
                          ? 'No backup made from this phone yet.'
                          : 'Last backup: ${Fmt.dateTime(last)} '
                                '(${Fmt.timeAgo(last)})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (auto.statusText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          auto.statusText,
                          style: TextStyle(
                            color: auto.hasProblem
                                ? theme.colorScheme.error
                                : null,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: auth.hasSession
                          ? FilledButton.icon(
                              onPressed: busy ? null : _backUp,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Back up now'),
                            )
                          : FilledButton.icon(
                              onPressed: _reconnect,
                              icon: const Icon(Icons.link),
                              label: const Text('Reconnect to Google'),
                            ),
                    ),
                    if (!auth.hasSession)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'If asked, choose ${auth.email}.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Automatic backup'),
                    subtitle: const Text(
                      'Backs up about a minute after you make changes',
                    ),
                    value: auto.enabled,
                    onChanged: auto.setEnabled,
                  ),
                  SwitchListTile(
                    title: const Text('Wi-Fi only'),
                    subtitle: const Text('Don\'t use mobile data for backups'),
                    value: auto.wifiOnly,
                    onChanged: auto.enabled ? auto.setWifiOnly : null,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('On this phone'),
              subtitle: FutureBuilder<BackupSummary>(
                future: _local,
                builder: (context, snapshot) =>
                    Text(snapshot.hasData ? _describe(snapshot.data!) : '...'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined),
                      const SizedBox(width: 8),
                      Text(
                        'Backup file on this phone',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<(bool, LocalBackupInfo?)>(
                    future: _localFile,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Text('...');
                      final (access, info) = snapshot.data!;
                      if (!access) {
                        return const Text(
                          'File access isn\'t allowed yet. It will be asked '
                          'when you use the buttons below.',
                        );
                      }
                      if (info == null) {
                        return const Text('No backup file yet.');
                      }
                      return Text(
                        'Saved ${Fmt.dateTime(info.savedAt)} '
                        '(${Fmt.timeAgo(info.savedAt)})\n'
                        '${_describe(info.summary)}',
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LocalBackupFile.shortPath,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: busy ? null : _backUpLocally,
                          child: const Text('Back up locally'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : _restoreFromFile,
                          child: const Text('Restore from file'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anyone who can open your phone\'s files can read this file. '
                    'The PIN lock does not protect it.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (auth.isSignedIn && auth.hasSession) ...[
            const SizedBox(height: 20),
            Text(
              'Backups in your Google Drive',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'One per day, the newest ${BackupService.keepSnapshots} days are kept.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<CloudBackup>>(
              future: _backups,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final backups = snapshot.data ?? const <CloudBackup>[];
                if (backups.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No backups yet. Tap "Back up now".'),
                  );
                }
                final latestIndex = backups.indexWhere(
                  (b) => !b.isBeforeRestore,
                );
                return Column(
                  children: [
                    for (var i = 0; i < backups.length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          isThreeLine: true,
                          leading: Icon(
                            backups[i].isBeforeRestore
                                ? Icons.undo
                                : Icons.cloud_done_outlined,
                          ),
                          title: Text(Fmt.dateTime(backups[i].modifiedAt)),
                          subtitle: Text(
                            '${_label(backups[i], i == latestIndex)} · '
                            '${Fmt.timeAgo(backups[i].modifiedAt)}\n'
                            '${_describe(backups[i].summary)}',
                          ),
                          trailing: TextButton(
                            onPressed: busy ? null : () => _restore(backups[i]),
                            child: const Text('Restore'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Restoring replaces everything on this phone. Your PIN is not '
              'part of a backup.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
