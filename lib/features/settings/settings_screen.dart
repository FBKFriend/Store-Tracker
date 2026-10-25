import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import 'pin_settings.dart';
import 'account_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editLowStock(
    BuildContext context,
    SettingsController settings,
  ) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _LowStockDialog(current: settings.lowStockDefault),
    );
    if (value != null) await settings.setLowStockDefault(value);
  }

  Future<void> _editStoreName(
    BuildContext context,
    SettingsController settings,
  ) async {
    final name = await showTextInputDialog(
      context,
      title: 'Store name',
      label: 'Store name',
      initial: settings.storeName,
    );
    if (name != null) await settings.setStoreName(name);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          const AccountSettingsSection(),
          const _SectionHeader('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark mode'),
            subtitle: const Text(
              'Only this setting counts, not your phone\'s.',
            ),
            value: settings.isDark,
            onChanged: settings.setDark,
          ),
          const _SectionHeader('Store'),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Store name'),
            subtitle: Text(
              settings.storeName.trim().isEmpty
                  ? 'Not set'
                  : settings.storeName,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editStoreName(context, settings),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Low-stock alert level'),
            subtitle: Text(
              settings.lowStockDefault == 0
                  ? 'Off (set a level on each item instead)'
                  : 'Alert at ${Qty.plain(settings.lowStockDefault)} or less',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editLowStock(context, settings),
          ),
          const _SectionHeader('Security'),
          const PinSettingsSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _LowStockDialog extends StatefulWidget {
  final int current;
  const _LowStockDialog({required this.current});

  @override
  State<_LowStockDialog> createState() => _LowStockDialogState();
}

class _LowStockDialogState extends State<_LowStockDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: Qty.plain(widget.current),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final milli = Qty.parse(_controller.text);
    if (milli == null) {
      setState(() => _error = 'Enter a number');
      return;
    }
    Navigator.pop(context, milli);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Low-stock alert level'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items at or below this amount are marked as low on stock. '
            'You can set a different level for any item when editing it. '
            'Use 0 to turn the default off.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Alert level',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
