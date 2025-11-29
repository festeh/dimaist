import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../utils/icon_utils.dart';

class IconPickerDialog extends StatefulWidget {
  final Color iconColor;
  final String? selectedIcon;

  const IconPickerDialog({
    super.key,
    required this.iconColor,
    this.selectedIcon,
  });

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<MapEntry<String, PhosphorIconData>> _filteredIcons = [];

  @override
  void initState() {
    super.initState();
    _filteredIcons = allIcons;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredIcons = searchIcons(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 500,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose Icon',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (widget.selectedIcon != null)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search icons...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: Spacing.md),
              Expanded(
                child: _filteredIcons.isEmpty
                    ? Center(
                        child: Text(
                          'No icons found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: Spacing.xs,
                          crossAxisSpacing: Spacing.xs,
                        ),
                        itemCount: _filteredIcons.length,
                        itemBuilder: (context, index) {
                          final entry = _filteredIcons[index];
                          final isSelected =
                              widget.selectedIcon == entry.key;

                          return Tooltip(
                            message: entry.key,
                            child: InkWell(
                              onTap: () =>
                                  Navigator.of(context).pop(entry.key),
                              borderRadius: BorderRadius.circular(Radii.sm),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? widget.iconColor.withValues(alpha: 0.2)
                                      : null,
                                  borderRadius:
                                      BorderRadius.circular(Radii.sm),
                                  border: isSelected
                                      ? Border.all(
                                          color: widget.iconColor,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: PhosphorIcon(
                                    entry.value,
                                    color: widget.iconColor,
                                    size: Sizes.iconMd,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
