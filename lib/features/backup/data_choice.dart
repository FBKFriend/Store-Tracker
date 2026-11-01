import 'package:flutter/material.dart';

import '../../core/backup/backup_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/units.dart';

enum DataSource { phone, cloud, file }

/// One copy of the user's data that they can choose to keep.
class DataOption {
  final DataSource source;
  final String title;
  final String timeLabel;
  final DateTime? time;
  final BackupSummary summary;
  final CloudBackup? cloud;
  final String buttonLabel;

  const DataOption({
    required this.source,
    required this.title,
    required this.timeLabel,
    required this.time,
    required this.summary,
    required this.buttonLabel,
    this.cloud,
  });
}

/// The boxes, one per copy. The newest one gets a "Newer" badge.
class DataChoiceView extends StatelessWidget {
  final List<DataOption> options;
  final ValueChanged<DataOption> onChoose;

  const DataChoiceView({
    super.key,
    required this.options,
    required this.onChoose,
  });

  IconData _icon(DataSource source) {
    switch (source) {
      case DataSource.phone:
        return Icons.phone_android;
      case DataSource.cloud:
        return Icons.cloud_outlined;
      case DataSource.file:
        return Icons.folder_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    DateTime? newest;
    for (final o in options) {
      final t = o.time;
      if (t != null && (newest == null || t.isAfter(newest))) newest = t;
    }
    final showBadge = options.length > 1;

    return Column(
      children: [
        for (final o in options)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_icon(o.source)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (showBadge && o.time != null && o.time == newest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Newer',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    o.time == null
                        ? '${o.timeLabel}: unknown'
                        : '${o.timeLabel}: ${Fmt.dateTime(o.time!)} '
                              '(${Fmt.timeAgo(o.time!)})',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${o.summary.items} items · ${o.summary.sales} sales '
                    '(${Money.format(o.summary.salesTotal)}) · '
                    '${o.summary.customers} customers',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => onChoose(o),
                      child: Text(o.buttonLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A full screen for choosing. The back button is blocked on purpose, so the
/// question can't be skipped by accident. Pops the chosen [DataOption], or
/// null if the user picked the "start fresh" button.
class DataChoiceScreen extends StatelessWidget {
  final String heading;
  final String message;
  final List<DataOption> options;
  final String? freshLabel;

  const DataChoiceScreen({
    super.key,
    required this.heading,
    required this.message,
    required this.options,
    this.freshLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Choose your data'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(heading, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            DataChoiceView(
              options: options,
              onChoose: (o) => Navigator.of(context).pop(o),
            ),
            if (freshLabel != null)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(freshLabel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
