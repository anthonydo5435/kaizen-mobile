import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/widgets/app_confirmation_dialog.dart';
import 'package:sparrowkaizen/core/widgets/app_overlay_close_button.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/repositories/seat_profile_repository.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/training/data/models/training_library_module_model.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_module.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_page.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/usecases/get_training_library_modules_usecase.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_content.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_lesson_actions.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_lesson_actions_sheet.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_module_card.dart';

import '../../fixtures/training_library_fixtures.dart';

void main() {
  late _LibraryRepository library;
  late _AuditRepository audit;
  late TrainingLibraryController controller;
  late bool canManage;
  late int detailOpened;
  SeatDescriptionTrainingRoute? openedLesson;

  setUp(() async {
    library = _LibraryRepository();
    audit = _AuditRepository(library);
    canManage = true;
    detailOpened = 0;
    openedLesson = null;
    controller = TrainingLibraryController(
      GetTrainingLibraryModulesUseCase(library),
      getSeatProfilesUseCase: GetSeatProfilesUseCase(_SeatRepository()),
      auditRepository: audit,
      canManageSeatTraining: (seatId) =>
          canManage && seatId == _module().seat.id,
    );
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  Widget host() => ChangeNotifierProvider<AppManager>.value(
    value: AppManager.instance,
    child: MaterialApp(
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => TrainingLibraryContent(
          controller: controller,
          onOpenLesson: (route) async {
            detailOpened++;
            openedLesson = route;
          },
          onModuleActions: (module) => controller.openModuleActions(
            module,
            showActions: (actions, lesson) => showTrainingLibraryLessonActions(
              context,
              controller: actions,
              lesson: lesson,
            ),
          ),
          onSelectSeat: () {},
          onCreate: () {},
        ),
      ),
    ),
  );

  Future<void> openActions(WidgetTester tester) async {
    await tester.longPress(find.byType(TrainingLibraryModuleCard));
    await tester.pumpAndSettle();
    expect(find.byType(TrainingLibraryLessonActionsSheet), findsOneWidget);
    expect(detailOpened, 0);
  }

  for (final view in TrainingLibraryViewMode.values) {
    testWidgets(
      '${view.name} cards open actions on long-press and the selected lesson on tap',
      (tester) async {
        await controller.changeViewMode(view);
        await tester.pumpWidget(host());
        final requests = library.requests;
        await openActions(tester);
        expect(find.text(AppStrings.visibilityLabel), findsOneWidget);
        expect(find.text(AppStrings.trainingEditAssignment), findsNothing);
        expect(
          find.text(AppStrings.trainingDeleteModuleAction),
          findsOneWidget,
        );
        await tester.tap(find.byType(AppOverlayCloseButton));
        await tester.pumpAndSettle();
        expect(library.requests, requests);
        await tester.tap(find.byType(TrainingLibraryModuleCard));
        await tester.pumpAndSettle();
        expect(detailOpened, 1);
        expect(openedLesson?.initialModuleId, library.module!.id);
        expect(
          openedLesson?.description,
          library.module!.trainingDescriptionId,
        );
        expect(openedLesson?.job, library.module!.seat.id);
        expect(openedLesson?.category, library.module!.category.id);
        expect(library.requests, requests + 1);
        expect(audit.deletedIds, isEmpty);
      },
    );
  }

  testWidgets('card deletion confirms and refreshes the main listing', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final moduleId = library.module!.id;
    await openActions(tester);
    await tester.tap(find.text(AppStrings.trainingDeleteModuleAction));
    await tester.pumpAndSettle();
    expect(find.byType(AppConfirmationDialog), findsOneWidget);
    expect(audit.deletedIds, isEmpty);
    await tester.tap(find.text(AppStrings.trainingDeleteModuleAction));
    await tester.pumpAndSettle();
    expect(audit.deletedIds, [moduleId]);
    expect(find.byType(TrainingLibraryModuleCard), findsNothing);
    expect(controller.items, isEmpty);
    expect(library.requests, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled deletion does not write or refresh the listing', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await openActions(tester);
    await tester.tap(find.text(AppStrings.trainingDeleteModuleAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.trainingCancel));
    await tester.pumpAndSettle();
    expect(audit.deletedIds, isEmpty);
    expect(library.requests, 1);
    expect(find.byType(TrainingLibraryModuleCard), findsOneWidget);
  });

  testWidgets(
    'visibility saves the selected lesson and reopening reads the new value',
    (tester) async {
      await tester.pumpWidget(host());
      final moduleId = library.module!.id;
      await openActions(tester);
      await tester.tap(find.text(AppStrings.visibilityLabel));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(AppStrings.trainingLibraryRestrictedVisibility),
      );
      await tester.pumpAndSettle();
      expect(audit.visibilityIds, [moduleId]);
      expect(
        controller.items.single.lessons.single.isPubliclyAvailable,
        isFalse,
      );
      expect(library.requests, 2);
      await openActions(tester);
      expect(
        tester
            .widget<TrainingLibraryLessonActionsSheet>(
              find.byType(TrainingLibraryLessonActionsSheet),
            )
            .isPubliclyAvailable,
        isFalse,
      );
      await tester.tap(find.byType(AppOverlayCloseButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'read-only cards expose no actions and permission is rechecked before writing',
    (tester) async {
      canManage = false;
      await tester.pumpWidget(host());
      expect(
        tester
            .widget<TrainingLibraryModuleCard>(
              find.byType(TrainingLibraryModuleCard),
            )
            .onLongPress,
        isNull,
      );
      await controller.openModuleActions(
        controller.items.single,
        showActions: (_, __) async =>
            fail('Read-only accounts must not open actions.'),
      );
      expect(audit.deletedIds, isEmpty);
      await tester.tap(find.byType(TrainingLibraryModuleCard));
      await tester.pumpAndSettle();
      expect(openedLesson?.initialModuleId, library.module!.id);
      expect(detailOpened, 1);
      expect(library.requests, 1);
      detailOpened = 0;

      canManage = true;
      await controller.refresh();
      await tester.pumpAndSettle();
      await openActions(tester);
      canManage = false;
      await tester.tap(find.text(AppStrings.trainingDeleteModuleAction));
      await tester.pumpAndSettle();
      expect(find.byType(AppConfirmationDialog), findsNothing);
      expect(audit.deletedIds, isEmpty);
      expect(audit.visibilityIds, isEmpty);
      expect(controller.items, hasLength(1));
    },
  );

  testWidgets(
    'failed deletion preserves the card and reports the API failure',
    (tester) async {
      audit.failDelete = true;
      await tester.pumpWidget(host());
      await openActions(tester);
      await tester.tap(find.text(AppStrings.trainingDeleteModuleAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.trainingDeleteModuleAction));
      await tester.pumpAndSettle();
      expect(find.byType(TrainingLibraryModuleCard), findsOneWidget);
      expect(find.text('Exception: Delete failed'), findsOneWidget);
      expect(library.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

TrainingLibraryModule _module({bool isPublic = true}) =>
    TrainingLibraryModuleModel.fromApiJson({
      ...lessonListingJson(),
      'thumbnail_link': null,
      'is_publicly_available': isPublic,
    });

class _SeatRepository extends Fake implements SeatProfileRepository {}

class _LibraryRepository extends Fake implements TrainingLibraryRepository {
  TrainingLibraryModule? module = _module();
  int requests = 0;

  @override
  Future<TrainingLibraryPage> getTrainingLibraryModules({
    required String view,
    required int page,
    int pageSize = 10,
    String searchType = 'category',
    String searchText = '',
    String? departmentId,
    String? jobId,
    String? jobCategoryId,
    String? jobCategoryDescriptionId,
    bool forceRefresh = false,
  }) async {
    requests++;
    return TrainingLibraryPage(
      items: [if (module != null) module!],
      hasNextPage: false,
    );
  }
}

class _AuditRepository extends Fake implements AuditRepository {
  _AuditRepository(this.library);

  final _LibraryRepository library;
  final List<String> deletedIds = [];
  final List<String> visibilityIds = [];
  bool failDelete = false;

  @override
  Future<void> deleteSeatDescriptionTrainingModule({
    required String moduleId,
  }) async {
    if (failDelete) throw Exception('Delete failed');
    deletedIds.add(moduleId);
    library.module = null;
  }

  @override
  Future<void> updateSeatDescriptionTrainingModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) async {
    visibilityIds.add(moduleId);
    library.module = _module(isPublic: isPubliclyAvailable);
  }
}
