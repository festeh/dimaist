import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/task_screen.dart';

class KeyboardShortcutsHandler extends ConsumerWidget {
  final Widget child;
  final GlobalKey<TaskScreenState>? taskScreenKey;

  const KeyboardShortcutsHandler({
    super.key,
    required this.child,
    this.taskScreenKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isControlPressed = HardwareKeyboard.instance.isControlPressed;
          final isAltPressed = HardwareKeyboard.instance.isAltPressed;
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;

          if (!isControlPressed &&
              !isAltPressed &&
              !isShiftPressed &&
              !isMetaPressed) {
            // Keyboard shortcuts currently disabled
            // TODO: Re-enable keyboard shortcuts if needed
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
