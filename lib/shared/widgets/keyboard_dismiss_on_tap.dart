import 'package:flutter/material.dart';

/// Dismisses the active text-input keyboard when a tap lands outside
/// the currently focused editable field.
///
/// This is installed above the app Navigator so it also covers routes,
/// dialogs and modal bottom sheets.
class KeyboardDismissOnTap extends StatelessWidget {
  const KeyboardDismissOnTap({super.key, required this.child});

  final Widget child;

  void _handlePointerDown(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) return;

    final renderObject = focus.context?.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize) {
      final fieldBounds =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (fieldBounds.contains(event.position)) return;
    }

    focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: child,
    );
  }
}
