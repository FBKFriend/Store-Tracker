import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/backup/backup_models.dart';
import '../../core/backup/backup_service.dart';
import '../../core/backup/local_backup_file.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_logo.dart';
import '../backup/data_choice.dart';
import 'start_flow.dart';

enum _Phase { checking, needsAccess, denied, choose, restoring }

/// On first open, if the phone has no data, looks for saved data: a backup in
/// Google Drive (when signed in) and the backup file in the Documents folder.
class DataCheckScreen extends StatefulWidget {
  final AppPrefs prefs;
  const DataCheckScreen({super.key, required this.prefs});

  @override
  State<DataCheckScreen> createState() => _DataCheckScreenState();
}

class _DataCheckScreenState extends State<DataCheckScreen> {
  _Phase _phase = _Phase.checking;
  final List<DataOption> _options = [];
  bool _cloudChecked = false; // Google Drive was looked at without errors
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final summary = await context.read<BackupService>().localSummary();
    if (!mounted) return;
    if (!summary.isEmpty) {
      await _finish(); // already has data: nothing to look for
      return;
    }

    final cloud = await _findCloud();
    if (!mounted) return;
    if (cloud != null) {
      _options.add(
        DataOption(
          source: DataSource.cloud,
          title: 'Google Drive copy',
          timeLabel: 'Last backed up',
          time: cloud.modifiedAt,
          summary: cloud.summary,
          cloud: cloud,
          buttonLabel: 'Use the Google Drive copy',
        ),
      );
    }

    if (await LocalBackupFile.hasAccess()) {
      await _addFileOption();
    } else if (cloud == null) {
      // Only ask for file access when Drive had nothing to offer
      if (mounted) setState(() => _phase = _Phase.needsAccess);
      return;
    }
    await _showResult();
  }

  Future<CloudBackup?> _findCloud() async {
    final auth = context.read<GoogleAuthService>();
    if (!auth.isSignedIn || !auth.hasSession) return null;
    try {
      final all = await context.read<BackupService>().listBackups();
      _cloudChecked = true;
      for (final b in all) {
        if (!b.isBeforeRestore) return b;
      }
    } on BackupException {
      // Offline: the question is asked again later, from inside the app
    }
    return null;
  }

  Future<void> _addFileOption() async {
    try {
      final info = await LocalBackupFile.info();
      if (info != null) {
        _options.add(
          DataOption(
            source: DataSource.file,
            title: 'Backup file on this phone',
            timeLabel: 'Last saved',
            time: info.savedAt,
            summary: info.summary,
            buttonLabel: 'Use the backup file',
          ),
        );
      }
    } catch (_) {
      // An unreadable file is the same as no file
    }
  }

  Future<void> _allowAndCheck() async {
    final granted = await LocalBackupFile.requestAccess();
    if (!mounted) return;
    if (!granted) {
      setState(() => _phase = _Phase.denied);
      return;
    }
    setState(() => _phase = _Phase.checking);
    await _addFileOption();
    await _showResult();
  }

  Future<void> _showResult() async {
    if (_options.isEmpty) {
      await _resolvePending();
      await _finish();
      return;
    }
    if (mounted) setState(() => _phase = _Phase.choose);
  }

  // The question about Google Drive is settled once Drive was really checked
  Future<void> _resolvePending() async {
    if (_cloudChecked) await widget.prefs.setCloudCheckPending(false);
  }

  Future<void> _choose(DataOption option) async {
    final backup = context.read<BackupService>();
    setState(() {
      _phase = _Phase.restoring;
      _error = null;
    });
    try {
      if (option.source == DataSource.cloud) {
        await backup.restore(option.cloud!);
      } else {
        final text = await LocalBackupFile.read();
        if (text == null) throw BackupException('The file could not be read.');
        await backup.restoreFromText(text, safetyCopy: false);
      }
      await _resolvePending();
      await _finish();
    } on BackupException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _phase = _Phase.choose;
        });
      }
    }
  }

  Future<void> _startFresh() async {
    await _resolvePending();
    await _finish();
  }

  Future<void> _finish() async {
    await widget.prefs.markDataCheckDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => homeScreenFor(widget.prefs)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget body;
    switch (_phase) {
      case _Phase.checking:
      case _Phase.restoring:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _phase == _Phase.restoring
                  ? 'Restoring your data...'
                  : 'Looking for saved data...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        );
      case _Phase.needsAccess:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Look for saved data?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text(
              'If you used this app before (for example, you reinstalled it), '
              'your data may be saved in a backup file in your Documents '
              'folder. To look for it, Android needs you to allow file access.\n\n'
              'On the next screen, switch on "Allow access to manage all '
              'files" for My Sari-Sari Store, then come back.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _allowAndCheck,
                child: const Text('Allow and check'),
              ),
            ),
            TextButton(
              onPressed: _startFresh,
              child: const Text('Skip, start fresh'),
            ),
          ],
        );
      case _Phase.denied:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'File access not allowed',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Without it, the app can\'t look for a saved backup on this '
              'phone. You can allow it in Android Settings, or look again '
              'later from More → Backup.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: LocalBackupFile.openSettings,
                child: const Text('Open settings'),
              ),
            ),
            TextButton(
              onPressed: _startFresh,
              child: const Text('Continue without it'),
            ),
          ],
        );
      case _Phase.choose:
        final many = _options.length > 1;
        final hasCloud = _options.any((o) => o.source == DataSource.cloud);
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              many ? 'Two copies found' : 'Saved data found',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              many
                  ? 'Pick the one you want to continue with.'
                        '${hasCloud ? ' Your next backup will update Google Drive with it.' : ''}'
                  : 'Restore it to this phone?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DataChoiceView(options: _options, onChoose: _choose),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            TextButton(
              onPressed: _startFresh,
              child: const Text('Start fresh'),
            ),
          ],
        );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 80),
                const SizedBox(height: 24),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
