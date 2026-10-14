import 'package:flutter/material.dart';

class StoreBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const StoreBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const int posIndex = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _item(
                context,
                0,
                Icons.dashboard_outlined,
                Icons.dashboard,
                'Home',
              ),
              _item(
                context,
                1,
                Icons.inventory_2_outlined,
                Icons.inventory_2,
                'Inventory',
              ),
              _posItem(context),
              _item(context, 3, Icons.people_outline, Icons.people, 'Utang'),
              _item(context, 4, Icons.menu, Icons.menu, 'More'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final theme = Theme.of(context);
    final selected = currentIndex == index;
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posItem(BuildContext context) {
    final theme = Theme.of(context);
    final selected = currentIndex == posIndex;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(posIndex),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.secondary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.point_of_sale,
                color: theme.colorScheme.onPrimary,
                size: 26,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'POS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
