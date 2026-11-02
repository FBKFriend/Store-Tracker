import 'package:flutter/material.dart';

import 'legal_text.dart';

/// The privacy and terms text, shown on the first-run screen and in Settings.
class LegalContent extends StatelessWidget {
  const LegalContent({super.key});

  Widget _section(ThemeData theme, String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(p, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LegalText.intro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        _section(theme, 'Privacy', LegalText.privacyPoints),
        const SizedBox(height: 16),
        _section(theme, 'Terms of use', LegalText.termsPoints),
        const SizedBox(height: 16),
        Text('Contact', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('${LegalText.developerName}, ${LegalText.developerTitle}'),
        const SelectableText(LegalText.contactEmail),
        const SizedBox(height: 12),
        Text(
          'Last updated: ${LegalText.lastUpdated}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
