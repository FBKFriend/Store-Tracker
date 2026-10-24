import 'package:flutter/material.dart';

class Recovery {
  final String question;
  final String answer;
  const Recovery(this.question, this.answer);
}

/// Picks a recovery question and answer. Returns a [Recovery] with
/// Navigator.pop, or null if the user backs out.
class RecoverySetupScreen extends StatefulWidget {
  const RecoverySetupScreen({super.key});

  @override
  State<RecoverySetupScreen> createState() => _RecoverySetupScreenState();
}

class _RecoverySetupScreenState extends State<RecoverySetupScreen> {
  static const _custom = 'Write my own question';
  static const _presets = [
    'What was the name of your first pet?',
    'What is your mother\'s maiden name?',
    'What street did you grow up on?',
    'What was the name of your elementary school?',
    'What is your favorite food?',
  ];

  String _choice = _presets.first;
  final _customQuestion = TextEditingController();
  final _answer = TextEditingController();

  @override
  void dispose() {
    _customQuestion.dispose();
    _answer.dispose();
    super.dispose();
  }

  bool get _isCustom => _choice == _custom;
  String get _question => _isCustom ? _customQuestion.text.trim() : _choice;
  bool get _valid => _question.isNotEmpty && _answer.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery question')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'If you forget your PIN, answering this question lets you set a '
            'new one. Choose something only you know.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _choice,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Question',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final q in [..._presets, _custom])
                DropdownMenuItem<String>(
                  value: q,
                  child: Text(q, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _choice = v ?? _choice),
          ),
          if (_isCustom) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customQuestion,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Your question',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _answer,
            decoration: const InputDecoration(
              labelText: 'Your answer',
              helperText: 'Capital letters don\'t matter',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _valid
                  ? () =>
                        Navigator.of(context)
                            .pop(Recovery(_question, _answer.text))
                  : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
