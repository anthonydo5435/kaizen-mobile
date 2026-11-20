import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_module.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_lesson_grid.dart';

void main() {
  testWidgets(
    'cards alternate heights, align after four lessons, and open the tapped lesson',
    (tester) async {
      tester.view.physicalSize = const Size(398, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TrainingLibraryLesson? selectedLesson;

      await tester.pumpWidget(
        _host(
          lessons: _lessons(6),
          onTap: (lesson) async {
            selectedLesson = lesson;
          },
        ),
      );

      final cards = List.generate(
        5,
        (index) => tester.getRect(_card('Lesson $index')),
      );
      expect(cards[0].top, cards[1].top);
      expect(cards[0].height, closeTo(179 * 1.85, 0.01));
      expect(cards[0].height, greaterThan(cards[1].height));
      expect(cards[2].top, closeTo(cards[0].bottom + 8, 0.01));
      expect(cards[3].top, closeTo(cards[1].bottom + 8, 0.01));
      expect(cards[2].bottom, closeTo(cards[3].bottom, 0.01));
      expect(cards[4].top, closeTo(cards[2].bottom + 8, 0.01));
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);

      await tester.tap(_card('Lesson 1'));
      expect(selectedLesson?.id, '1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long press highlights the card until its actions close without opening the lesson',
    (tester) async {
      TrainingLibraryLesson? actionLesson;
      var openedLesson = false;
      final actionsClosed = Completer<void>();
      await tester.pumpWidget(
        _host(
          lessons: _lessons(1),
          onTap: (_) async {
            openedLesson = true;
          },
          onActions: (lesson) async {
            actionLesson = lesson;
            await actionsClosed.future;
          },
        ),
      );

      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      await tester.longPress(_card('Lesson 0'));
      await tester.pump();

      expect(actionLesson?.id, '0');
      expect(openedLesson, isFalse);
      expect(
        tester.widget<Semantics>(_card('Lesson 0')).properties.selected,
        isTrue,
      );

      actionsClosed.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(_card('Lesson 0')).properties.selected,
        isFalse,
      );
    },
  );

  testWidgets(
    'read-only cards have no actions gesture or hint and still open the viewer',
    (tester) async {
      var openedLesson = false;
      await tester.pumpWidget(
        _host(
          lessons: _lessons(1),
          onTap: (_) async {
            openedLesson = true;
          },
        ),
      );

      final card = _card('Lesson 0');
      final gesture = find.descendant(of: card, matching: find.byType(InkWell));
      expect(tester.widget<InkWell>(gesture).onLongPress, isNull);
      expect(
        tester.widget<Semantics>(card).properties.hint,
        isNot(AppStrings.trainingLibraryLessonActionsHint),
      );

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(openedLesson, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a cancelled press clears the highlight without opening actions',
    (tester) async {
      var openedActions = false;
      await tester.pumpWidget(
        _host(
          lessons: _lessons(1),
          onActions: (_) async {
            openedActions = true;
          },
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(_card('Lesson 0')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<Semantics>(_card('Lesson 0')).properties.selected,
        isTrue,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(_card('Lesson 0')).properties.selected,
        isFalse,
      );
      expect(openedActions, isFalse);
    },
  );

  testWidgets('lesson cards stay compact on iPad', (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(lessons: _lessons(4)));

    final tall = tester.getRect(_card('Lesson 0'));
    final short = tester.getRect(_card('Lesson 1'));
    expect(tall.width, greaterThan(450));
    expect(tall.height, lessThan(420));
    expect(short.height, lessThan(290));
    expect(tall.height, greaterThan(short.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screens and large text keep cards within their bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(lessons: _lessons(4), textScaler: const TextScaler.linear(3)),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getRect(_card('Lesson 0')).left, 16);
    expect(tester.getRect(_card('Lesson 1')).right, 304);
  });
}

Finder _card(String title) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      widget.properties.label == title,
);

Widget _host({
  required List<TrainingLibraryLesson> lessons,
  TextScaler textScaler = TextScaler.noScaling,
  Future<void> Function(TrainingLibraryLesson)? onTap,
  Future<void> Function(TrainingLibraryLesson)? onActions,
}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TrainingLibraryLessonGrid(
            lessons: lessons,
            onLessonTap: onTap ?? (_) async {},
            onLessonActions: onActions,
          ),
        ),
      ),
    ),
  ),
);

List<TrainingLibraryLesson> _lessons(int count) => List.generate(
  count,
  (index) => TrainingLibraryLesson(
    id: '$index',
    title: 'Lesson $index',
    description:
        'An exhaustive look into layout constraints, auto-layout paradigms and patient care.',
    thumbnailLink: null,
    isPubliclyAvailable: false,
  ),
);
