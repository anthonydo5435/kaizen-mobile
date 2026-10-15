import 'package:flutter/material.dart';

class AppSwipeRevealAction extends StatefulWidget {
  const AppSwipeRevealAction({
    super.key,
    required this.child,
    this.actionChild,
    this.actionBuilder,
    this.onActionTap,
    this.leadingActionChild,
    this.onLeadingActionTap,
    this.leadingActionWidth = 64,
    this.isEnabled = true,
    this.borderRadius = 12,
    this.actionWidth = 64,
    this.actionGap = 10,
    this.openVelocityThreshold = -160,
    this.revealThreshold = 0.45,
  }) : assert(
         actionChild != null ||
             actionBuilder != null ||
             leadingActionChild != null,
       ),
       assert(actionChild == null || actionBuilder == null);

  final Widget child;
  final Widget? actionChild;

  /// Builds multiple trailing actions that can close the reveal before acting.
  final Widget Function(BuildContext context, VoidCallback close)?
  actionBuilder;
  final VoidCallback? onActionTap;
  final Widget? leadingActionChild;
  final VoidCallback? onLeadingActionTap;
  final double leadingActionWidth;
  final bool isEnabled;
  final double borderRadius;
  final double actionWidth;
  final double actionGap;
  final double openVelocityThreshold;
  final double revealThreshold;

  @override
  State<AppSwipeRevealAction> createState() => _AppSwipeRevealActionState();
}

class _AppSwipeRevealActionState extends State<AppSwipeRevealAction> {
  late final ValueNotifier<double> _swipeOffsetNotifier;

  double get _revealWidth =>
      widget.actionChild != null || widget.actionBuilder != null
      ? widget.actionWidth + widget.actionGap
      : 0;
  double get _leadingRevealWidth => widget.leadingActionChild != null
      ? widget.leadingActionWidth + widget.actionGap
      : 0;

  @override
  void initState() {
    super.initState();
    _swipeOffsetNotifier = ValueNotifier<double>(0);
  }

  @override
  void didUpdateWidget(covariant AppSwipeRevealAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _swipeOffsetNotifier.value = widget.isEnabled
        ? _swipeOffsetNotifier.value.clamp(-_revealWidth, _leadingRevealWidth)
        : 0;
  }

  @override
  void dispose() {
    _swipeOffsetNotifier.dispose();
    super.dispose();
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.isEnabled) {
      return;
    }

    final nextOffset = (_swipeOffsetNotifier.value + details.delta.dx).clamp(
      -_revealWidth,
      _leadingRevealWidth,
    );
    if (nextOffset == _swipeOffsetNotifier.value) {
      return;
    }

    _swipeOffsetNotifier.value = nextOffset;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!widget.isEnabled) {
      return;
    }

    final resolvedVelocity = details.primaryVelocity ?? 0;
    final offset = _swipeOffsetNotifier.value;
    final velocityThreshold = widget.openVelocityThreshold.abs();
    if (resolvedVelocity.abs() > velocityThreshold) {
      _swipeOffsetNotifier.value = resolvedVelocity < 0 && offset <= 0
          ? -_revealWidth
          : resolvedVelocity > 0 && offset >= 0
          ? _leadingRevealWidth
          : 0;
    } else if (offset < 0) {
      _swipeOffsetNotifier.value =
          offset.abs() >= _revealWidth * widget.revealThreshold
          ? -_revealWidth
          : 0;
    } else {
      _swipeOffsetNotifier.value =
          offset >= _leadingRevealWidth * widget.revealThreshold
          ? _leadingRevealWidth
          : 0;
    }
  }

  void _closeActions() {
    _swipeOffsetNotifier.value = 0;
  }

  void _handleActionTap() {
    _closeActions();
    widget.onActionTap?.call();
  }

  void _handleLeadingActionTap() {
    _closeActions();
    widget.onLeadingActionTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _swipeOffsetNotifier,
      builder: (context, swipeOffset, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: widget.isEnabled
            ? _handleHorizontalDragUpdate
            : null,
        onHorizontalDragEnd: widget.isEnabled ? _handleHorizontalDragEnd : null,
        onHorizontalDragCancel: widget.isEnabled ? _closeActions : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              if (swipeOffset > 0 && widget.leadingActionChild != null)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.isEnabled ? _handleLeadingActionTap : null,
                      child: SizedBox(
                        width: widget.leadingActionWidth,
                        child: widget.leadingActionChild,
                      ),
                    ),
                  ),
                ),
              if (swipeOffset < 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.isEnabled && widget.actionBuilder == null
                          ? _handleActionTap
                          : null,
                      child: SizedBox(
                        width: widget.actionWidth,
                        child:
                            widget.actionBuilder?.call(
                              context,
                              _closeActions,
                            ) ??
                            widget.actionChild,
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(swipeOffset, 0),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
