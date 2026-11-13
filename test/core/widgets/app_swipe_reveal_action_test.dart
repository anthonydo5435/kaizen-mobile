import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/widgets/app_swipe_reveal_action.dart';

void main() {
  testWidgets('existing single action closes on selection and ignores right swipes', (
    tester,
  ) async {
    var actionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSwipeRevealAction(
            actionChild: const ColoredBox(
              color: Colors.red,
              child: Center(child: Text('Delete')),
            ),
            onActionTap: () => actionCount++,
            child: const SizedBox(
              width: double.infinity,
              height: 100,
              child: ColoredBox(
                color: Colors.black,
                child: Center(child: Text('Card')),
              ),
            ),
          ),
        ),
      ),
    );
    final card = find.byType(AppSwipeRevealAction);
    await tester.drag(card, const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    await tester.drag(card, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete').hitTestable(), findsOneWidget);
    expect(actionCount, 0);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(actionCount, 1);
    expect(find.text('Delete'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reverse flick closes a revealed action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppSwipeRevealAction(
            actionWidth: 140,
            actionChild: ColoredBox(
              color: Colors.red,
              child: Center(child: Text('Delete')),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 100,
              child: ColoredBox(
                color: Colors.black,
                child: Center(child: Text('Card')),
              ),
            ),
          ),
        ),
      ),
    );
    final card = find.byType(AppSwipeRevealAction);
    await tester.drag(card, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete').hitTestable(), findsOneWidget);
    await tester.timedDrag(card, const Offset(60, 0), const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
