import 'package:flutter/material.dart';

import 'legal_content.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Terms')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: LegalContent(),
      ),
    );
  }
}
