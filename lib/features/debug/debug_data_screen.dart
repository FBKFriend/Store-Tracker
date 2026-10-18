import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/sales_repository.dart';

// TEMPORARY: remove later
class DebugDataScreen extends StatelessWidget {
  const DebugDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales & stock data (testing)')),
      body: FutureBuilder<String>(
        future: context.read<SalesRepository>().debugDump(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snapshot.data!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}
