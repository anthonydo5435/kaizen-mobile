import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Dismisses the focused input when the user taps elsewhere in its sheet.
class AppBottomSheetKeyboardDismissal extends StatefulWidget {
  const AppBottomSheetKeyboardDismissal({super.key, required this.child});

  final Widget child;

  @override
  State<AppBottomSheetKeyboardDismissal> createState() =>
      _AppBottomSheetKeyboardDismissalState();
}

class _AppBottomSheetKeyboardDismissalState
    extends State<AppBottomSheetKeyboardDismissal> {
  final _tapAction = _BottomSheetInputTapAction();

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: _tapAction.handlePointerMove,
      onPointerCancel: _tapAction.handlePointerCancel,
      child: Actions(
        actions: {
          EditableTextTapOutsideIntent: _tapAction,
          EditableTextTapUpOutsideIntent:
              CallbackAction<EditableTextTapUpOutsideIntent>(
                onInvoke: _tapAction.handleTapUp,
              ),
        },
        child: widget.child,
      ),
    );
  }
}

class _BottomSheetInputTapAction extends Action<EditableTextTapOutsideIntent> {
  PointerDownEvent? _tapDown;

  @override
  void invoke(EditableTextTapOutsideIntent intent) {
    final event = intent.pointerDownEvent;
    _tapDown = null;
    if (event.buttons == kPrimaryButton &&
        _isInsideSheet(intent.focusNode, event.position)) {
      _tapDown = event;
      return;
    }

    callingAction?.invoke(intent);
  }

  void handleTapUp(EditableTextTapUpOutsideIntent intent) {
    final event = intent.pointerUpEvent;
    final down = _tapDown;
    if (down == null || down.pointer != event.pointer) return;
    _tapDown = null;

    final focus = intent.focusNode;
    if (focus.hasPrimaryFocus &&
        !_movedBeyondTap(down, event) &&
        _isInsideSheet(focus, event.position)) {
      focus.unfocus();
    }
  }

  void handlePointerMove(PointerMoveEvent event) {
    final down = _tapDown;
    if (down != null &&
        down.pointer == event.pointer &&
        _movedBeyondTap(down, event)) {
      _tapDown = null;
    }
  }

  void handlePointerCancel(PointerCancelEvent event) {
    if (_tapDown?.pointer == event.pointer) _tapDown = null;
  }

  bool _movedBeyondTap(PointerDownEvent down, PointerEvent event) =>
      (down.position - event.position).distanceSquared >=
      kTouchSlop * kTouchSlop;

  bool _isInsideSheet(FocusNode focus, Offset position) {
    final context = focus.context;
    if (context == null ||
        !context.mounted ||
        ModalRoute.isCurrentOf(context) == false) {
      return false;
    }

    final sheet = context.findAncestorStateOfType<State<BottomSheet>>();
    final box = sheet?.context.findRenderObject();
    return box is RenderBox &&
        box.hasSize &&
        (Offset.zero & box.size).contains(box.globalToLocal(position));
  }
}
