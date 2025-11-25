import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import 'dynamic_calendar_icon.dart';

enum BuiltInViewType {
  today('Today', Icons.today),
  upcoming('Upcoming', Icons.calendar_today),
  next('Next', Icons.arrow_forward);

  const BuiltInViewType(this.displayName, this.icon);

  final String displayName;
  final IconData icon;
}

class CustomView {
  final BuiltInViewType type;

  const CustomView(this.type);

  String get name => type.displayName;
  IconData get icon => type.icon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CustomView && other.type == type;

  @override
  int get hashCode => type.hashCode;
}

class CustomViewWidget extends StatelessWidget {
  static final List<CustomView> customViews = [
    const CustomView(BuiltInViewType.today),
    const CustomView(BuiltInViewType.upcoming),
    const CustomView(BuiltInViewType.next),
  ];

  final String? selectedView;
  final Function(String) onSelected;

  const CustomViewWidget({
    super.key,
    required this.selectedView,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: customViews.map((view) {
        final isSelected = selectedView == view.name;
        return Container(
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: InkWell(
            onTap: () => onSelected(view.name),
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md,
              ),
              child: Row(
                children: [
                  if (view.type == BuiltInViewType.today)
                    const DynamicCalendarIcon()
                  else
                    Icon(view.icon, size: Sizes.iconMd),
                  const SizedBox(width: Spacing.lg),
                  Expanded(
                    child: Text(
                      view.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
