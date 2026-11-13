import 'dart:async';

import 'package:flutter/widgets.dart';

import '../controllers/training_tab_navigation_controller.dart';

/// Lets Flutter own dragging and snapping so a tab cannot remain partly visible.
class TrainingTabView extends StatefulWidget {
  const TrainingTabView({
    super.key,
    required this.navigation,
    required this.maxTabIndex,
    required this.pageBuilder,
    this.pagePaddingBuilder,
    this.onPageApproaching,
    this.isSwipeEnabled = true,
  }) : assert(maxTabIndex >= 0),
       assert(maxTabIndex < TrainingTabNavigationController.tabCount);

  final TrainingTabNavigationController navigation;
  final int maxTabIndex;
  final IndexedWidgetBuilder pageBuilder;
  final EdgeInsetsGeometry Function(int index)? pagePaddingBuilder;
  final ValueChanged<int>? onPageApproaching;
  final bool isSwipeEnabled;

  @override
  State<TrainingTabView> createState() => _TrainingTabViewState();
}

class _TrainingTabViewState extends State<TrainingTabView> {
  late final PageController _pageController;
  bool _isReportingPage = false;
  int? _lastApproachingIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.navigation.selectedIndex.clamp(0, widget.maxTabIndex),
      keepPage: false,
    )..addListener(_handlePageMovement);
    widget.navigation.addListener(_handleTabSelection);
  }

  @override
  void didUpdateWidget(covariant TrainingTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSwipeEnabled && !widget.isSwipeEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.isSwipeEnabled && _pageController.hasClients) {
          // Cancel a drag that started before fullscreen was entered.
          _pageController.jumpToPage(
            widget.navigation.selectedIndex.clamp(0, widget.maxTabIndex),
          );
        }
      });
    }
    if (oldWidget.navigation != widget.navigation) {
      oldWidget.navigation.removeListener(_handleTabSelection);
      widget.navigation.addListener(_handleTabSelection);
    }
    if (oldWidget.navigation != widget.navigation ||
        oldWidget.maxTabIndex != widget.maxTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (widget.navigation.selectedIndex > widget.maxTabIndex) {
          widget.navigation.selectTab(widget.maxTabIndex);
        } else {
          _handleTabSelection();
        }
      });
    }
  }

  void _handleTabSelection() {
    if (_isReportingPage || !_pageController.hasClients) {
      return;
    }
    unawaited(
      _pageController.animateToPage(
        widget.navigation.selectedIndex.clamp(0, widget.maxTabIndex),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _handlePageMovement() {
    if (!widget.isSwipeEnabled) return;
    final page = _pageController.page;
    if (page == null || page == widget.navigation.selectedIndex) {
      return;
    }
    final index =
        (page > widget.navigation.selectedIndex ? page.ceil() : page.floor())
            .clamp(0, widget.maxTabIndex);
    if (index == _lastApproachingIndex ||
        index == widget.navigation.selectedIndex) {
      return;
    }
    _lastApproachingIndex = index;
    // Scroll positions may change during layout; fetch before the next frame.
    scheduleMicrotask(() {
      if (mounted && widget.isSwipeEnabled && index <= widget.maxTabIndex) {
        widget.onPageApproaching?.call(index);
      }
    });
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (!widget.isSwipeEnabled ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal ||
        !_pageController.hasClients) {
      return false;
    }
    final index = _pageController.page!.round().clamp(0, widget.maxTabIndex);
    _lastApproachingIndex = null;
    if (index != widget.navigation.selectedIndex) {
      _isReportingPage = true;
      try {
        widget.navigation.selectTab(index);
      } finally {
        _isReportingPage = false;
      }
    }
    return false;
  }

  @override
  void dispose() {
    widget.navigation.removeListener(_handleTabSelection);
    _pageController.removeListener(_handlePageMovement);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pager = NotificationListener<ScrollEndNotification>(
      onNotification: _handleScrollEnd,
      child: PageView.custom(
        controller: _pageController,
        physics: widget.isSwipeEnabled
            ? const PageScrollPhysics(parent: ClampingScrollPhysics())
            : const NeverScrollableScrollPhysics(),
        childrenDelegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            key: ValueKey<int>(index),
            padding:
                widget.pagePaddingBuilder?.call(index) ??
                const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRect(child: widget.pageBuilder(context, index)),
          ),
          childCount: widget.maxTabIndex + 1,
          // Dispose offscreen players; draft text lives in the feature controller.
          addAutomaticKeepAlives: false,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? pager
          : SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.75,
              child: pager,
            ),
    );
  }
}
