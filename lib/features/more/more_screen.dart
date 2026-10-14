import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_tab.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderTab(
      icon: Icons.menu,
      title: 'More',
      subtitle: 'History, reports, backup, and settings will go here.',
    );
  }
}
