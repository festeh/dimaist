import 'package:dimaist/widgets/recording_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LongPressFab extends StatefulWidget {
  final VoidCallback onPressed;
  final Function(String) onMenuItemSelected;

  const LongPressFab({
    super.key,
    required this.onPressed,
    required this.onMenuItemSelected,
  });

  @override
  State<LongPressFab> createState() => _LongPressFabState();
}

class _LongPressFabState extends State<LongPressFab>
    with TickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  String? _selectedValue;
  final GlobalKey _menuKey = GlobalKey();

  void _showMenu() {
    // Add haptic feedback for better UX on mobile
    HapticFeedback.mediumImpact();

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;

    const menuWidth = 220.0;
    final screenWidth = overlay.size.width;

    double leftPosition = buttonPosition.dx;
    if (leftPosition + menuWidth > screenWidth) {
      leftPosition = buttonPosition.dx + buttonSize.width - menuWidth;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _MenuOverlay(
        leftPosition: leftPosition,
        bottomPosition: overlay.size.height - buttonPosition.dy + 10,
        menuWidth: menuWidth,
        selectedValue: _selectedValue,
        menuKey: _menuKey,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _updateSelection(Offset globalPosition) {
    if (_overlayEntry == null) return;

    final RenderBox? menuBox =
        _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (menuBox == null) return;

    final menuPosition = menuBox.localToGlobal(Offset.zero);
    final menuSize = menuBox.size;

    if (globalPosition.dx >= menuPosition.dx &&
        globalPosition.dx <= menuPosition.dx + menuSize.width &&
        globalPosition.dy >= menuPosition.dy &&
        globalPosition.dy <= menuPosition.dy + menuSize.height) {
      final localY = globalPosition.dy - menuPosition.dy;
      final itemHeight = menuSize.height / 2;

      String? newSelection;
      if (localY < itemHeight) {
        newSelection = 'Text AI';
      } else {
        newSelection = 'Voice AI';
      }

      if (_selectedValue != newSelection) {
        HapticFeedback.lightImpact(); // Light feedback when selection changes
        setState(() {
          _selectedValue = newSelection;
        });
        _updateOverlay();
      }
    } else {
      if (_selectedValue != null) {
        setState(() {
          _selectedValue = null;
        });
        _updateOverlay();
      }
    }
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showRecordingDialog() {
    showDialog(context: context, builder: (context) => const RecordingDialog());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _showMenu();
      },
      onLongPressMoveUpdate: (details) {
        _updateSelection(details.globalPosition);
      },
      onLongPressEnd: (_) {
        if (_selectedValue != null) {
          HapticFeedback.mediumImpact(); // Feedback on selection
          if (_selectedValue == 'Voice AI') {
            _showRecordingDialog();
          } else {
            widget.onMenuItemSelected(_selectedValue!);
          }
        }
        _hideMenu();
        setState(() {
          _selectedValue = null;
        });
      },
      onLongPressCancel: () {
        _hideMenu();
        setState(() {
          _selectedValue = null;
        });
      },
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        tooltip:
            null, // Remove tooltip to prevent interference with long press on Android
        child: PhosphorIcon(PhosphorIcons.plus()),
      ),
    );
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }
}

class _MenuOverlay extends StatelessWidget {
  final double leftPosition;
  final double bottomPosition;
  final double menuWidth;
  final String? selectedValue;
  final GlobalKey menuKey;

  const _MenuOverlay({
    required this.leftPosition,
    required this.bottomPosition,
    required this.menuWidth,
    required this.selectedValue,
    required this.menuKey,
  });

  Widget _buildMenuItem(String value, BuildContext context) {
    final isSelected = selectedValue == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isSelected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: Text(
        value,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w400 : FontWeight.normal,
          fontSize: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: leftPosition,
      bottom: bottomPosition,
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: menuKey,
          width: menuWidth,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem('Text AI', context),
              _buildMenuItem('Voice AI', context),
            ],
          ),
        ),
      ),
    );
  }
}
