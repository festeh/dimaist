import 'package:flutter/material.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final List<String> _aiModels = [
    'chutes/deepseek-ai/DeepSeek-R1',
    'chutes/Qwen/Qwen3-235B-A22B',
    'chutes/openai/gpt-oss-120b',
    'deepseek-ai/DeepSeek-V3.1',
  ];

  String _selectedModel = 'chutes/deepseek-ai/DeepSeek-V3.1';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy),
                const SizedBox(width: 16),
                const Text(
                  'AI Model:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedModel,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedModel = newValue;
                        });
                      }
                    },
                    items: _aiModels.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
