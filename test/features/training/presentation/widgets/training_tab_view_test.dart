import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_tab_navigation_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_tab_view.dart';

void main() {
  late TrainingTabNavigationController navigation;

  setUp(() => navigation = TrainingTabNavigationController());
  tearDown(() => navigation.dispose());

  Future<void> mountTabs(
    WidgetTester tester, {
    int maxTabIndex = 3,
    double width = 360,
    double height = 480,
    IndexedWidgetBuilder? pageBuilder,
    ValueChanged<int>? onPageApproaching,
    bool isSwipeEnabled = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: TrainingTabView(
              navigation: navigation,
              maxTabIndex: maxTabIndex,
              onPageApproaching: onPageApproaching,
              isSwipeEnabled: isSwipeEnabled,
              pageBuilder:
                  pageBuilder ??
                  (_, index) => SizedBox.expand(
                    key: ValueKey<String>('page-$index'),
                    child: ColoredBox(color: Colors.primaries[index]),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  PageController pageController(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  void expectSettled(WidgetTester tester, int index) {
    final viewport = tester.getRect(find.byType(PageView));
    expect(pageController(tester).page, closeTo(index.toDouble(), 0.0001));
    expect(navigation.selectedIndex, index);
    expect(pageController(tester).position.isScrollingNotifier.value, isFalse);
    for (var page = 0; page < 4; page++) {
      final finder = find.byKey(ValueKey<String>('page-$page'), skipOffstage: false);
      if (page == index) {
        expect(finder, findsOneWidget);
        expect(
          tester.getRect(finder),
          Rect.fromLTRB(viewport.left + 8, viewport.top, viewport.right - 8, viewport.bottom),
        );
      } else if (finder.evaluate().isNotEmpty) {
        expect(tester.getRect(finder).overlaps(viewport), isFalse);
      }
    }
    expect(tester.takeException(), isNull);
  }

  Future<TestGesture> beginSwipe(WidgetTester tester, double direction) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await gesture.moveBy(Offset(direction * 24, 0));
    await gesture.moveBy(Offset(direction * 120, 0));
    await tester.pump();
    return gesture;
  }

  testWidgets('all adjacent tabs follow the finger and snap to a complete page', (tester) async {
    await mountTabs(tester);
    for (final (source, target) in [(0, 1), (1, 0), (1, 2), (2, 1), (2, 3), (3, 2)]) {
      navigation.selectTab(source);
      await tester.pumpAndSettle();
      expectSettled(tester, source);

      final direction = target > source ? -1.0 : 1.0;
      final gesture = await beginSwipe(tester, direction);
      final viewport = tester.getRect(find.byType(PageView));
      final sourceRect = tester.getRect(find.byKey(ValueKey<String>('page-$source')));
      final targetRect = tester.getRect(find.byKey(ValueKey<String>('page-$target')));
      expect(sourceRect.width, viewport.width - 16);
      expect(targetRect.width, viewport.width - 16);
      expect(sourceRect.left, isNot(viewport.left));
      expect(sourceRect.overlaps(viewport), isTrue);
      expect(targetRect.overlaps(viewport), isTrue);
      expect(sourceRect.overlaps(targetRect), isFalse);
      final gap = target > source
          ? targetRect.left - sourceRect.right
          : sourceRect.left - targetRect.right;
      expect(gap, closeTo(16, 0.001));
      expect(navigation.selectedIndex, source);

      await gesture.moveBy(Offset(direction * 120, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expectSettled(tester, target);
    }
  });

  testWidgets('short and cancelled swipes settle on one full page for every tab', (tester) async {
    await mountTabs(tester);
    for (var index = 0; index < 4; index++) {
      for (final cancel in [false, true]) {
        navigation.selectTab(index);
        await tester.pumpAndSettle();
        final gesture = await beginSwipe(tester, index == 3 ? 1 : -1);
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expectSettled(tester, index);
      }
    }
  });

  testWidgets('disabling swipes cancels a live drag and restores swiping when enabled again', (
    tester,
  ) async {
    await mountTabs(tester);
    final controller = pageController(tester);
    final gesture = await beginSwipe(tester, -1);
    expect(controller.page, inExclusiveRange(0, 1));
    await mountTabs(tester, isSwipeEnabled: false);
    await tester.pumpAndSettle();
    expect(pageController(tester), same(controller));
    await gesture.moveBy(const Offset(-240, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expectSettled(tester, 0);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expectSettled(tester, 0);
    await mountTabs(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(pageController(tester), same(controller));
    expectSettled(tester, 1);
  });

  testWidgets('incoming SOP data can load before the swipe passes its midpoint', (tester) async {
    final approaching = <int>[];
    await mountTabs(tester, onPageApproaching: approaching.add);
    expect(approaching, isEmpty);

    final gesture = await beginSwipe(tester, -1);
    expect(pageController(tester).page, inExclusiveRange(0, 0.5));
    expect(navigation.selectedIndex, 0);
    expect(approaching, [1]);

    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(approaching, [1]);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expectSettled(tester, 0);
  });

  testWidgets('restricted pages never trigger incoming data requests', (tester) async {
    final approaching = <int>[];
    await mountTabs(tester, maxTabIndex: 1, onPageApproaching: approaching.add);
    navigation.selectTab(1);
    await tester.pumpAndSettle();
    approaching.clear();

    final gesture = await beginSwipe(tester, -1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(approaching, isEmpty);
    expectSettled(tester, 1);
  });

  testWidgets('tab taps interrupt swipes and settle every source and destination', (tester) async {
    await mountTabs(tester);
    for (var source = 0; source < 4; source++) {
      for (var target = 0; target < 4; target++) {
        navigation.selectTab(source);
        await tester.pumpAndSettle();
        final gesture = await beginSwipe(tester, source == 3 ? 1 : -1);

        navigation.selectTab(target);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();
        expectSettled(tester, target);
      }
    }
  });

  testWidgets('the last tab tap wins while a previous transition is still moving', (tester) async {
    await mountTabs(tester);
    navigation.selectTab(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    navigation.selectTab(1);
    await tester.pumpAndSettle();
    expectSettled(tester, 1);
  });

  testWidgets('rebuilding or resizing the content during a swipe preserves snapping', (
    tester,
  ) async {
    await mountTabs(tester);
    final controller = pageController(tester);
    final gesture = await beginSwipe(tester, -1);
    final page = controller.page!;
    expect(page, inExclusiveRange(0, 1));

    await mountTabs(tester, width: 420, height: 300);
    expect(pageController(tester), same(controller));
    expect(controller.page, closeTo(page, 0.001));
    await gesture.moveBy(const Offset(-140, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expectSettled(tester, 1);
  });

  testWidgets('restricted tabs cannot be reached by swiping', (tester) async {
    await mountTabs(tester, maxTabIndex: 0);
    final gesture = await beginSwipe(tester, -1);
    await gesture.moveBy(const Offset(-140, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expectSettled(tester, 0);
  });

  testWidgets('removing access while on another tab returns to the available page', (tester) async {
    await mountTabs(tester);
    navigation.selectTab(3);
    await tester.pumpAndSettle();
    await mountTabs(tester, maxTabIndex: 0);
    await tester.pumpAndSettle();
    expectSettled(tester, 0);
  });

  testWidgets('vertical content scrolls independently of the horizontal pager', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await mountTabs(
      tester,
      pageBuilder: (_, index) => SingleChildScrollView(
        key: ValueKey<String>('page-$index'),
        controller: index == 0 ? scrollController : null,
        child: const SizedBox(height: 1200, child: ColoredBox(color: Colors.purple)),
      ),
    );

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(0));
    expectSettled(tester, 0);
  });

  testWidgets('leaving a page disposes players even when a child requests keep-alive', (
    tester,
  ) async {
    final disposed = <int>[];
    await mountTabs(
      tester,
      pageBuilder: (_, index) => _KeepAlivePage(onDispose: () => disposed.add(index)),
    );
    navigation.selectTab(3);
    await tester.pumpAndSettle();
    expect(disposed, contains(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the pager during animation releases its listeners', (tester) async {
    await mountTabs(tester);
    navigation.selectTab(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    navigation.selectTab(1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.onDispose});

  final VoidCallback onDispose;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox.expand();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}
