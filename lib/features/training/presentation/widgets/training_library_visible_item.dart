import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports cards inside the painted viewport, excluding the offscreen cache.
class TrainingLibraryVisibleItem extends StatefulWidget {
  const TrainingLibraryVisibleItem({
    super.key,
    required this.onVisible,
    required this.child,
  });

  final VoidCallback onVisible;
  final Widget child;

  @override
  State<TrainingLibraryVisibleItem> createState() =>
      _TrainingLibraryVisibleItemState();
}

class _TrainingLibraryVisibleItemState
    extends State<TrainingLibraryVisibleItem> {
  ScrollPosition? _position;
  bool _isReportScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.of(context).position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleReport);
      _position = position..addListener(_scheduleReport);
    }
    _scheduleReport();
  }

  @override
  void didUpdateWidget(TrainingLibraryVisibleItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleReport();
  }

  void _scheduleReport() {
    if (_isReportScheduled) return;
    _isReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isReportScheduled = false;
      if (!mounted || _position?.hasContentDimensions != true) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final position = _position!;
      if (top < position.pixels + position.viewportDimension &&
          top + box.size.height > position.pixels) {
        widget.onVisible();
      }
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleReport);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
