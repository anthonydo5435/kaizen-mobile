import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_tab_navigation_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/models/view_training_tab_access.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_swipe_delete_action.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_tab_view.dart';

void main() {
  late _PreviewController controller;

  setUp(() => controller = _PreviewController());
  tearDown(() => controller.dispose());

  Future<void> mount(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );

  for (final readOnly in [false, true]) {
    testWidgets('lesson title stays in its field and respects read-only access: $readOnly', (
      tester,
    ) async {
      var edits = 0;
      await mount(
        tester,
        TrainingLessonTitleField(
          valueText: 'Lesson title',
          hintText: AppStrings.trainingLessonTitleHint,
          isReadOnly: readOnly,
          onTap: () => edits++,
        ),
      );
      expect(find.text('Lesson title'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), readOnly ? findsNothing : findsOneWidget);
      await tester.tap(find.text('Lesson title'));
      await tester.pumpAndSettle();
      expect(edits, readOnly ? 0 : 1);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Quiz and Assignment look disabled and reject taps and swipes without viewing access',
    (tester) async {
      final navigation = TrainingTabNavigationController();
      addTearDown(navigation.dispose);
      final maxTabIndex = maxTrainingTabIndex(
        hasSelectedModule: true,
        canViewQuizAndAssignment: false,
      );
      await mount(
        tester,
        Column(
          children: [
            Expanded(
              child: TrainingTabView(
                navigation: navigation,
                maxTabIndex: maxTabIndex,
                pageBuilder: (_, index) => Center(child: Text('Tab $index')),
              ),
            ),
            TrainingTabs(navigation: navigation, maxTabIndex: maxTabIndex),
          ],
        ),
      );
      for (final label in [AppStrings.trainingQuizTab, AppStrings.trainingAssignmentTab]) {
        final tab = find.text(label);
        final opacity = find.ancestor(of: tab, matching: find.byType(Opacity));
        expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));
        final semantics = find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        );
        expect(tester.widget<Semantics>(semantics).properties.enabled, isFalse);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(navigation.selectedIndex, 0);
      }
      await tester.tap(find.text(AppStrings.trainingSopTab));
      await tester.pumpAndSettle();
      expect(navigation.selectedIndex, 1);
      await tester.fling(find.byType(PageView), const Offset(-350, 0), 1000);
      await tester.pumpAndSettle();
      expect(navigation.selectedIndex, 1);
      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2', skipOffstage: false), findsNothing);
      expect(find.text('Tab 3', skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('video and quiz previews never expose editing actions, including for managers', (
    tester,
  ) async {
    expect(controller.canManageTraining, isTrue);
    await mount(
      tester,
      SingleChildScrollView(
        child: Column(
          children: [
            TrainingReadOnlyVideoTab(controller: controller),
            TrainingReadOnlyQuizTab(controller: controller),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Which answer is correct?'), findsOneWidget);
    expect(find.text(AppStrings.trainingQuestionBadge(1)), findsOneWidget);
    expect(find.text(AppStrings.trainingNoVideoAvailable), findsOneWidget);
    expect(find.text(AppStrings.trainingAddNewQuestion), findsNothing);
    expect(find.text(AppStrings.trainingCreateWithAi), findsNothing);
    expect(find.byTooltip(AppStrings.trainingQuestionActions), findsNothing);
    expect(find.byTooltip(AppStrings.trainingReUploadVideoAction), findsNothing);
    expect(find.byTooltip(AppStrings.trainingThumbnailAction), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the viewer lesson selector can select lessons without create or delete actions', (
    tester,
  ) async {
    String? selected;
    await mount(
      tester,
      TrainingLessonSelector(
        controller: controller,
        onModuleSelected: (moduleId) async => selected = moduleId,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.trainingNewLesson), findsNothing);

    await tester.tap(find.byTooltip(AppStrings.trainingAllLessons));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.trainingAllLessons), findsOneWidget);
    expect(find.text(AppStrings.trainingAddNewLesson), findsNothing);
    await tester.drag(find.byType(TrainingSwipeDeleteAction), const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.trainingDeleteModuleAction).hitTestable(), findsNothing);
    expect(selected, isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(TrainingSwipeDeleteAction),
        matching: find.text('Read-only lesson'),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, 'module');
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(360, 520), Size(320, 200)]) {
    testWidgets('an empty quiz fills the available ${size.width} by ${size.height} tab viewport', (
      tester,
    ) async {
      final emptyController = _EmptyQuizController();
      final navigation = TrainingTabNavigationController()..selectTab(2);
      addTearDown(emptyController.dispose);
      addTearDown(navigation.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: size,
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(800, 600),
                    textScaler: TextScaler.linear(2),
                  ),
                  child: TrainingTabView(
                    navigation: navigation,
                    maxTabIndex: 3,
                    pagePaddingBuilder: (_) => EdgeInsets.zero,
                    pageBuilder: (_, index) => index == 2
                        ? TrainingReadOnlyQuizTab(controller: emptyController)
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final message = find.text(AppStrings.trainingNoQuizQuestionsAvailable);
      final panel = find.ancestor(of: message, matching: find.byType(Container)).first;
      final viewport = tester.getRect(find.byType(TrainingTabView));
      expect(tester.getRect(panel), viewport);
      expect(tester.getCenter(message), viewport.center);
      expect(find.text(AppStrings.trainingCreateWithAi), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shared navigation respects the viewer tab limit and updates when access changes', (
    tester,
  ) async {
    final navigation = TrainingTabNavigationController();
    addTearDown(navigation.dispose);
    await mount(tester, TrainingTabs(navigation: navigation, maxTabIndex: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.trainingQuizTab));
    expect(navigation.selectedIndex, 0);
    await tester.tap(find.text(AppStrings.trainingSopTab));
    await tester.pumpAndSettle();
    expect(navigation.selectedIndex, 1);

    await mount(tester, TrainingTabs(navigation: navigation, maxTabIndex: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.trainingAssignmentTab));
    await tester.pumpAndSettle();
    expect(navigation.selectedIndex, 3);
    expect(tester.takeException(), isNull);
  });
}

class _PreviewController extends TrainingModuleController {
  _PreviewController() : super(_UnusedRepository(), canManageTraining: true);

  static const _module = SeatDescriptionTrainingModule(
    uuid: 'module',
    actualId: 'module',
    title: 'Read-only lesson',
    thumbnailLink: null,
    isPubliclyAvailable: false,
  );

  @override
  List<SeatDescriptionTrainingModule> get modules => const [_module];

  @override
  SeatDescriptionTrainingModule? get selectedModule => _module;

  @override
  String get selectedModuleId => _module.uuid;

  @override
  String get selectedModuleTitle => _module.title;

  @override
  List<SeatDescriptionTrainingQuestion> get selectedModuleQuestions => const [
    SeatDescriptionTrainingQuestion(
      uuid: 'question',
      question: 'Which answer is correct?',
      options: [
        SeatDescriptionTrainingQuestionOption(uuid: 'a', text: 'First answer'),
        SeatDescriptionTrainingQuestionOption(uuid: 'b', text: 'Second answer'),
      ],
      selectedOptionUuid: 'b',
      imageUrl: null,
    ),
  ];
}

class _UnusedRepository extends Fake implements TrainingLibraryRepository {}

class _EmptyQuizController extends _PreviewController {
  @override
  List<SeatDescriptionTrainingQuestion> get selectedModuleQuestions => const [];
}
