import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_tab.dart';

class UtangScreen extends StatelessWidget {
  const UtangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderTab(
      icon: Icons.people_outline,
      title: 'Utang',
      subtitle: 'Customer debts will go here.',
    );
  }
}
