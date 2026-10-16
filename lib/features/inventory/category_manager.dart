import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/dialogs.dart';
import '../../data/app_database.dart';
import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/item_repository.dart';

/// Asks for a category name. Returns null if the user cancels.
Future<String?> askCategoryName(
  BuildContext context, {
  String title = 'New category',
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Category name'),
        onSubmitted: (value) => Navigator.pop(ctx, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showCategoryManager(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _CategoryManagerSheet(),
  );
}

class _CategoryManagerSheet extends StatelessWidget {
  const _CategoryManagerSheet();

  Future<void> _add(BuildContext context) async {
    final name = await askCategoryName(context);
    if (name == null || !context.mounted) return;
    try {
      await context.read<CategoryRepository>().add(name);
    } on DataException catch (e) {
      if (context.mounted) await showErrorDialog(context, e.message);
    }
  }

  Future<void> _rename(BuildContext context, ItemCategory c) async {
    final name = await askCategoryName(
      context,
      title: 'Rename category',
      initial: c.name,
    );
    if (name == null || !context.mounted) return;
    try {
      await context.read<CategoryRepository>().rename(c.id, name);
    } on DataException catch (e) {
      if (context.mounted) await showErrorDialog(context, e.message);
    }
  }

  Future<void> _delete(BuildContext context, ItemCategory c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete "${c.name}"?',
      message: 'This can\'t be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<CategoryRepository>().delete(c.id);
    } on DataException catch (e) {
      if (context.mounted) await showErrorDialog(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryRepository>().categories;
    final items = context.watch<ItemRepository>().items;
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Categories', style: theme.textTheme.titleLarge),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in categories)
                    ListTile(
                      title: Text(c.name),
                      subtitle: Text(() {
                        final n = items
                            .where((i) => i.categoryId == c.id)
                            .length;
                        return '$n item${n == 1 ? '' : 's'}';
                      }()),
                      trailing: c.isDefault
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Rename',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _rename(context, c),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(context, c),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add category'),
                  onPressed: () => _add(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
