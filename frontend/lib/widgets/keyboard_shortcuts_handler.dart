import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/custom_view_widget.dart';
import '../providers/view_provider.dart';
import '../screens/task_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../widgets/recording_dialog.dart';

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
            final viewNotifier = ref.read(viewProvider.notifier);

            // if (event.logicalKey == LogicalKeyboardKey.keyN &&
            //     Platform.isLinux) {
            //   taskScreenKey?.currentState?.showAddTaskDialog();
            //   return KeyEventResult.handled;
            // }
            // if (event.logicalKey == LogicalKeyboardKey.keyA &&
            //     Platform.isLinux) {
            //   Navigator.of(context).push(
            //     MaterialPageRoute(builder: (context) => const AiChatScreen()),
            //   );
            //   return KeyEventResult.handled;
            // }
            // if (event.logicalKey == LogicalKeyboardKey.keyV &&
            //     Platform.isLinux) {
            //   showDialog(
            //     context: context,
            //     builder: (context) => const RecordingDialog(),
            //   );
            //   return KeyEventResult.handled;
            // }
            // if (event.logicalKey == LogicalKeyboardKey.keyT) {
            //   viewNotifier.selectCustomView(BuiltInViewType.today.displayName);
            //   return KeyEventResult.handled;
            // }
            // if (event.logicalKey == LogicalKeyboardKey.keyU) {
            //   viewNotifier.selectCustomView(
            //     BuiltInViewType.upcoming.displayName,
            //   );
            //   return KeyEventResult.handled;
            // }
            // if (event.logicalKey == LogicalKeyboardKey.keyE) {
            //   viewNotifier.selectCustomView(BuiltInViewType.next.displayName);
            //   return KeyEventResult.handled;
            // }
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
