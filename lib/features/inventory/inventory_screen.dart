import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_tab.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderTab(
      icon: Icons.inventory_2_outlined,
      title: 'Inventory',
      subtitle: 'Items and categories will go here.',
    );
  }
}
