import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/backup/backup_models.dart';
import '../../core/backup/backup_service.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late Future<BackupSummary> _local;
  Future<List<CloudBackup>>? _backups;

  @override
  void initState() {
    super.initState();
    _local = context.read<BackupService>().localSummary();
    _backups = _fetchBackups();
  }

  Future<List<CloudBackup>>? _fetchBackups() {
    if (!context.read<GoogleAuthService>().isSignedIn) return null;
    return context.read<BackupService>().listBackups();
  }

  void _refresh() {
    setState(() {
      _local = context.read<BackupService>().localSummary();
      _backups = _fetchBackups();
    });
  }

  String _describe(BackupSummary s) =>
      '${s.items} items · ${s.sales} sales (${Money.format(s.salesTotal)}) · '
      '${s.customers} customers';

  Future<void> _signIn() async {
    final auth = context.read<GoogleAuthService>();
    final result = await auth.signIn();
    if (!mounted) return;
    if (result.ok) {
      _refresh();
    } else if (!result.cancelled) {
      await showErrorDialog(context, result.message ?? 'Sign-in failed.');
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
          '${Fmt.dateTime(backup.createdAt)}.\n\n'
          'Backup: ${_describe(backup.summary)}\n'
          'This phone now: ${_describe(local)}\n\n'
          'If your current data is newer, tap Cancel and use "Back up now" '
          'first. Your PIN is not affected.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<GoogleAuthService>();
    final service = context.watch<BackupService>();
    final busy = service.busy;
    final last = service.lastBackupAt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup'),
        actions: [
          if (auth.isSignedIn)
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
                          'Not backed up',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You\'re using the app as a guest, so your data is only '
                      'on this phone. It could be lost if the phone is lost or '
                      'damaged, or the app is deleted. Sign in with Google to '
                      'back up to your own Google Drive.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _signIn,
                        child: const Text('Sign in with Google'),
                      ),
                    ),
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: busy ? null : _backUp,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Back up now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('On this phone'),
                subtitle: FutureBuilder<BackupSummary>(
                  future: _local,
                  builder: (context, snapshot) => Text(
                    snapshot.hasData ? _describe(snapshot.data!) : '...',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Backups in your Google Drive',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'The latest ${BackupService.keepCount} are kept.',
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
                return Column(
                  children: [
                    for (var i = 0; i < backups.length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          isThreeLine: true,
                          leading: const Icon(Icons.cloud_done_outlined),
                          title: Text(
                            '${Fmt.dateTime(backups[i].createdAt)}'
                            '${i == 0 ? '  ·  Latest' : ''}',
                          ),
                          subtitle: Text(
                            '${Fmt.timeAgo(backups[i].createdAt)}\n'
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
