import 'package:dimaist/widgets/dynamic_calendar_icon.dart';
import 'package:flutter/material.dart';

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
    return Column(
      children: customViews.map((view) {
        final isSelected = selectedView == view.name;
        return Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).highlightColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () => onSelected(view.name),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  if (view.type == BuiltInViewType.today)
                    const DynamicCalendarIcon()
                  else
                    Icon(view.icon, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      view.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
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
