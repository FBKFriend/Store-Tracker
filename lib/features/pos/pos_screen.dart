import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_tab.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderTab(
      icon: Icons.point_of_sale,
      title: 'POS',
      subtitle: 'The point of sale will go here.',
    );
  }
}
