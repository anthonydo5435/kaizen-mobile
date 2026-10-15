import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/shared_lesson_details_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

import '../../fixtures/tiptap_sop_fixture.dart';

void main() {
  testWidgets('the SOP heading and white panel keep their bounds across every response state', (
    tester,
  ) async {
    final fixture = TiptapSopFixture();
    Future<void> mount({
      bool isLoading = false,
      String? error,
      SeatDescriptionTrainingDocument? document,
    }) => tester.pumpWidget(
      Provider<TrainingSopEditorFactory>.value(
        value: fixture.create,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 480,
                child: TrainingReadOnlySopTab(
                  isLoading: isLoading,
                  errorMessage: error,
                  document: document,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final panel = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == Colors.white,
    );
    await mount(isLoading: true);
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.trainingNoSopAvailable), findsNothing);
    final panelBounds = tester.getRect(panel);
    final headingBounds = tester.getRect(find.text(AppStrings.trainingSopTab));

    void expectStablePanel() {
      expect(tester.getRect(panel), panelBounds);
      expect(tester.getRect(find.text(AppStrings.trainingSopTab)), headingBounds);
      expect(tester.takeException(), isNull);
    }

    await mount(document: const SeatDescriptionTrainingDocument(uuid: '', text: null));
    expectStablePanel();
    expect(find.byType(FastCircularProgressIndicator), findsNothing);
    expect(find.text(AppStrings.trainingNoSopAvailable), findsOneWidget);

    await mount(error: 'Unable to load SOP');
    expectStablePanel();
    expect(find.text('Unable to load SOP'), findsOneWidget);
    expect(find.text(AppStrings.trainingNoSopAvailable), findsNothing);

    await mount(isLoading: true);
    expectStablePanel();
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);

    await mount(
      document: const SeatDescriptionTrainingDocument(uuid: 'document', text: '<p>Procedure</p>'),
    );
    expectStablePanel();
    expect(find.text(AppStrings.trainingNoSopAvailable), findsNothing);
    // Content still shows the loader while the A4 engine initializes.
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
    await tester.pump();
    expect(find.byType(FastCircularProgressIndicator), findsNothing);
    expect(find.textContaining('Procedure', findRichText: true), findsWidgets);
    expect(fixture.editors.single.editable, isFalse);
    expectStablePanel();
  });
}
