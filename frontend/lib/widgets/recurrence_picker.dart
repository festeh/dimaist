import 'package:flutter/material.dart';
import '../config/design_tokens.dart';

/// Flat recurrence picker - presets as chips, custom interval inline
class RecurrencePicker extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;

  const RecurrencePicker({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  static const _presets = ['daily', 'weekly', 'monthly', 'yearly'];

  String? _selected;
  int _customInterval = 2;
  String _customUnit = 'days';

  @override
  void initState() {
    super.initState();
    _parseInitialValue();
  }

  void _parseInitialValue() {
    final value = widget.initialValue?.toLowerCase().trim();
    if (value == null || value.isEmpty) return;

    if (_presets.contains(value)) {
      _selected = value;
      return;
    }

    // Parse "every N unit" pattern
    final match = RegExp(r'^every\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)s?$')
        .firstMatch(value);
    if (match != null) {
      _selected = 'custom';
      _customInterval = int.tryParse(match.group(1)!) ?? 2;
      var unit = match.group(2)!;
      if (!unit.endsWith('s')) unit = '${unit}s';
      _customUnit = unit;
    }
  }

  void _select(String? value) {
    setState(() {
      _selected = _selected == value ? null : value;
      if (_selected == null) {
        widget.onChanged(null);
      } else if (_selected == 'custom') {
        widget.onChanged('every $_customInterval $_customUnit');
      } else {
        widget.onChanged(_selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset chips + custom toggle
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            ..._presets.map((p) => FilterChip(
                  label: Text(_cap(p)),
                  selected: _selected == p,
                  onSelected: (_) => _select(p),
                )),
            FilterChip(
              label: const Text('Custom'),
              selected: _selected == 'custom',
              onSelected: (_) => _select('custom'),
            ),
          ],
        ),

        // Custom interval controls (separate row)
        if (_selected == 'custom') ...[
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Text('Every ', style: theme.textTheme.bodyMedium),
              SizedBox(
                width: 48,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                  ),
                  controller: TextEditingController(text: '$_customInterval'),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      _customInterval = n;
                      widget.onChanged('every $_customInterval $_customUnit');
                    }
                  },
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: DropdownButton<String>(
                  value: _customUnit,
                  underline: const SizedBox.shrink(),
                  items: ['days', 'weeks', 'months', 'years']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (u) {
                    if (u != null) {
                      setState(() => _customUnit = u);
                      widget.onChanged('every $_customInterval $_customUnit');
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}
