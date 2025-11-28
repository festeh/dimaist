import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DynamicCalendarIcon extends StatelessWidget {
  const DynamicCalendarIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().day;
    return Stack(
      alignment: Alignment.center,
      children: [
        PhosphorIcon(PhosphorIcons.calendarBlank(), size: 24),
        Positioned(
          top: 6,
          child: Text(
            day.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ],
    );
  }
}
