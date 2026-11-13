import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_detail.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/repositories/seat_profile_repository.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_module.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_page.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/usecases/get_training_library_modules_usecase.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_content.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_filter_tags.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_department_filter_strip.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_module_card.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_result_area.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_search_bar.dart';

void main() {
  late TrainingLibraryController controller;
  late _LibraryRepository repository;

  setUp(() async {
    repository = _LibraryRepository();
    controller = TrainingLibraryController(
      GetTrainingLibraryModulesUseCase(repository),
      getSeatProfilesUseCase: GetSeatProfilesUseCase(_SeatRepository()),
    );
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  testWidgets('failed removal restores the last tag and reports the failure', (
    tester,
  ) async {
    await controller.selectSeat(
      const TrainingLibrarySeat(id: 'seat', title: _seatLabel),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.appliedFilterTags.isEmpty
                ? const SizedBox.shrink()
                : TrainingLibraryFilterTags(controller: controller),
          ),
        ),
      ),
    );
    final response = Completer<TrainingLibraryPage>();
    repository.response = response.future;
    await tester.tap(
      find.byTooltip(AppStrings.trainingLibraryRemoveFilter(_seatLabel)),
    );
    await tester.pump();
    expect(find.byType(TrainingLibraryFilterTags), findsNothing);
    response.completeError(Exception('API unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(TrainingLibraryFilterTags), findsOneWidget);
    expect(
      find.text(AppStrings.trainingLibraryUnableToApplyFilter),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'applied tags wrap below search and each cross removes its filter',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppManager>.value(
          value: AppManager.instance,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => TrainingLibraryContent(
                controller: controller,
                onOpenLesson: (_) async {},
                onSelectSeat: () {},
                onCreate: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TrainingLibraryFilterTags), findsNothing);
      await controller.openSeatSelection();
      controller.updatePendingSeatSelection(controller.seatOptions.single);
      controller.updatePendingCategorySelection(
        controller.categoryOptions.single,
      );
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.single,
      );
      await tester.pump();
      expect(find.byType(TrainingLibraryFilterTags), findsNothing);
      await controller.applyPendingSeatSelection();
      controller.closeSeatSelection();
      await tester.pumpAndSettle();

      final tags = find.byType(TrainingLibraryFilterTags);
      expect(
        tester.getTopLeft(tags).dy,
        greaterThan(
          tester.getBottomLeft(find.byType(TrainingLibrarySearchBar)).dy,
        ),
      );
      expect(
        find.descendant(of: tags, matching: find.byIcon(Icons.close_outlined)),
        findsNWidgets(3),
      );
      final seatTag = find.byTooltip(
        AppStrings.trainingLibraryRemoveFilter(_seatLabel),
      );
      final categoryTag = find.byTooltip(
        AppStrings.trainingLibraryRemoveFilter(_categoryLabel),
      );
      final descriptionTag = find.byTooltip(
        AppStrings.trainingLibraryRemoveFilter(_descriptionLabel),
      );
      expect(tester.getTopLeft(seatTag).dy, tester.getTopLeft(categoryTag).dy);
      expect(
        tester.getTopLeft(descriptionTag).dy,
        greaterThan(tester.getTopLeft(seatTag).dy),
      );
      for (final label in [_descriptionLabel, _categoryLabel, _seatLabel]) {
        expect(
          find.descendant(of: tags, matching: find.textContaining(label)),
          findsOneWidget,
        );
        await tester.tap(
          find.byTooltip(AppStrings.trainingLibraryRemoveFilter(label)),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: tags, matching: find.textContaining(label)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      expect(tags, findsNothing);
    },
  );

  testWidgets(
    'search keeps its height with a clear cross and one filter button',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var openedSeats = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => TrainingLibrarySearchBar(
                  controller: controller,
                  onSelectSeat: () => openedSeats++,
                ),
              ),
            ),
          ),
        ),
      );
      final height = tester
          .getSize(find.byType(TrainingLibrarySearchBar))
          .height;
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      expect(openedSeats, 1);
      await tester.enterText(find.byType(TextField), 'Seat');
      await tester.pump();
      expect(controller.searchQuery, 'Seat');
      expect(
        tester.getSize(find.byType(TrainingLibrarySearchBar)).height,
        height,
      );
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byTooltip(AppStrings.clearSearch));
      await tester.pumpAndSettle();
      expect(controller.searchQuery, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(openedSeats, 1);
      expect(
        tester.getSize(find.byType(TrainingLibrarySearchBar)).height,
        height,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'LMS omits the department strip and keeps filters and module actions',
    (tester) async {
      var openedSeats = false;
      SeatDescriptionTrainingRoute? openedLesson;
      await tester.pumpWidget(
        ChangeNotifierProvider<AppManager>.value(
          value: AppManager.instance,
          child: MaterialApp(
            home: TrainingLibraryContent(
              controller: controller,
              onOpenLesson: (route) async {
                openedLesson = route;
              },
              onSelectSeat: () => openedSeats = true,
              onCreate: () {},
            ),
          ),
        ),
      );
      expect(find.byType(TrainingLibraryDepartmentFilterStrip), findsNothing);
      expect(find.text(AppStrings.seeAllAction), findsNothing);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      expect(openedSeats, isTrue);
      await tester.tap(find.byType(TrainingLibraryModuleCard));
      expect(openedLesson?.initialModuleId, controller.items.single.id);
      expect(openedLesson?.description, 'module-description');
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewMode in TrainingLibraryViewMode.values) {
    testWidgets(
      'the ${viewMode.name} listing shows a footer while loading more',
      (tester) async {
        repository.response = Future.value(
          TrainingLibraryPage(items: controller.items, hasNextPage: true),
        );
        if (viewMode == TrainingLibraryViewMode.grid) {
          await controller.changeViewMode(viewMode);
        } else {
          await controller.refresh();
        }

        final nextPage = Completer<TrainingLibraryPage>();
        repository.response = nextPage.future;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 500,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => TrainingLibraryResultArea(
                    controller: controller,
                    items: controller.visibleItems,
                    scrollController: controller.scrollController,
                    onModuleTap: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(controller.isLoadingMore, isTrue);

        final footer = find.byType(FastCircularProgressIndicator);
        expect(footer, findsOneWidget);
        expect(
          tester.getTopLeft(footer).dy,
          greaterThan(
            tester.getBottomLeft(find.byType(TrainingLibraryModuleCard)).dy,
          ),
        );

        nextPage.complete(
          TrainingLibraryPage(items: controller.items, hasNextPage: false),
        );
        await tester.pump();
        expect(footer, findsNothing);
      },
    );
  }
}

const _seatLabel = 'Administration and financial operations controller';
const _categoryLabel = 'Financial management and reporting procedures';
const _descriptionLabel = 'Controls financial records across all departments';

class _SeatRepository extends Fake implements SeatProfileRepository {
  @override
  Future<List<SeatProfileDetail>> seatProfileCategoryTrainings() async =>
      const [
        SeatProfileDetail(
          id: 'seat',
          actualId: 'seat',
          title: _seatLabel,
          department: null,
          paygradeUnit: '',
          categories: [
            SeatProfileCategory(
              id: 'category',
              title: _categoryLabel,
              weightPercent: 0,
              descriptions: [
                SeatProfileDescription(
                  id: 'module-description',
                  actualId: 'module-description',
                  name: _descriptionLabel,
                  auditSpecifics: '',
                  auditFactorType: '',
                  milestoneDays: '',
                ),
              ],
            ),
          ],
        ),
      ];
}

class _LibraryRepository extends Fake implements TrainingLibraryRepository {
  Future<TrainingLibraryPage>? response;
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
  }) async =>
      response ??
      TrainingLibraryPage(
        items: const [
          TrainingLibraryModule(
            id: 'module',
            descriptionId: 'module-description',
            title: 'Module',
            description: '',
            department: TrainingLibraryDepartment(
              id: 'department',
              name: 'Department',
            ),
            totalDuration: 60,
            seat: TrainingLibrarySeat(id: 'seat', title: 'Seat'),
            lessons: [],
            thumbnailLink: null,
            category: TrainingLibraryCategory(
              id: 'category',
              title: 'Category',
            ),
          ),
        ],
        hasNextPage: false,
      );
}
