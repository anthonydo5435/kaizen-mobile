import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/department.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_detail.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/repositories/seat_profile_repository.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/training/data/models/training_library_module_model.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_module.dart';
import 'package:sparrowkaizen/features/training/domain/entities/training_library_page.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/usecases/get_training_library_modules_usecase.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/models/training_library_filter_tag.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_module_card.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_result_area.dart';

import '../../fixtures/training_library_fixtures.dart';

void main() {
  late _LibraryRepository repository;
  late _SeatRepository seatRepository;
  late TrainingLibraryController controller;
  late bool canCreateTraining;
  late bool canManageTraining;

  setUp(() async {
    repository = _LibraryRepository();
    seatRepository = _SeatRepository();
    canCreateTraining = false;
    canManageTraining = false;
    controller = TrainingLibraryController(
      GetTrainingLibraryModulesUseCase(repository),
      getSeatProfilesUseCase: GetSeatProfilesUseCase(seatRepository),
      canCreateTraining: () => canCreateTraining,
      canManageSeatTraining: (_) => canManageTraining,
    );
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  Future<void> applyHierarchy() async {
    await controller.openSeatSelection();
    controller.updatePendingSeatSelection(controller.seatOptions.first);
    controller.updatePendingCategorySelection(controller.categoryOptions.first);
    controller.updatePendingDescriptionSelection(
      controller.descriptionOptions.last,
    );
    expect(await controller.applyPendingSeatSelection(), isTrue);
    controller.closeSeatSelection();
  }

  TrainingLibraryPage pageOfLessons(int page) => TrainingLibraryPage(
    items: List.generate(
      25,
      (index) =>
          _module('lesson-${(page - 1) * 25 + index}', _seatA, 'operations'),
    ),
    hasNextPage: page < 3,
  );

  testWidgets(
    'prefetches each 25-item page at item 16 without duplicate requests',
    (tester) async {
      repository.respond = () async =>
          pageOfLessons(repository.requestedPages.last);
      await controller.refresh();
      repository.requestedPages.clear();
      final nextPage = Completer<TrainingLibraryPage>();
      repository.respond = () => nextPage.future;

      controller.onItemVisible('lesson-14');
      expect(repository.requestedPages, isEmpty);
      controller.onItemVisible('lesson-15');
      controller.onItemVisible('lesson-16');
      controller.onItemVisible('lesson-15');
      expect(repository.requestedPages, [2]);
      expect(controller.isLoadingMore, isTrue);
      nextPage.complete(pageOfLessons(2));
      await tester.pump();
      expect(controller.items, hasLength(50));

      repository.respond = () async =>
          pageOfLessons(repository.requestedPages.last);
      controller.onItemVisible('lesson-0');
      controller.onItemVisible('lesson-39');
      expect(repository.requestedPages, [2]);
      controller.onItemVisible('lesson-40');
      await tester.pump();
      expect(repository.requestedPages, [2, 3]);
      expect(repository.requestedPageSizes, everyElement(25));
      expect(controller.items, hasLength(75));
      controller.onItemVisible('lesson-74');
      expect(repository.requestedPages, [2, 3]);
    },
  );

  testWidgets('failed prefetch keeps cards and waits for an explicit retry', (
    tester,
  ) async {
    repository.respond = () async => pageOfLessons(1);
    await controller.refresh();
    repository.requestedPages.clear();
    repository.respond = () async => throw Exception('offline');
    controller.onItemVisible('lesson-15');
    await tester.pump();
    expect(controller.items, hasLength(25));
    expect(controller.isLoadingMore, isFalse);
    expect(
      controller.loadMoreErrorMessage,
      AppStrings.trainingLibraryUnableToLoadMore,
    );
    controller.onItemVisible('lesson-16');
    controller.onItemVisible('lesson-24');
    expect(repository.requestedPages, [2]);

    repository.respond = () async => pageOfLessons(2);
    await controller.loadNextPage();
    expect(repository.requestedPages, [2, 2]);
    expect(controller.items, hasLength(50));
    expect(controller.loadMoreErrorMessage, isNull);
  });

  testWidgets('refresh discards the previous listing prefetch response', (
    tester,
  ) async {
    repository.respond = () async => pageOfLessons(1);
    await controller.refresh();
    final nextPage = Completer<TrainingLibraryPage>();
    repository.respond = () => nextPage.future;
    controller.onItemVisible('lesson-15');
    repository.respond = () async => TrainingLibraryPage(
      items: [_module('refreshed', _seatA, 'operations')],
      hasNextPage: false,
    );
    await controller.refresh();
    nextPage.complete(pageOfLessons(2));
    await tester.pump();
    expect(controller.items.map((item) => item.id), ['refreshed']);
    expect(controller.isLoadingMore, isFalse);
  });

  for (final mode in TrainingLibraryViewMode.values) {
    testWidgets(
      '${mode.name} prefetch uses the visible card, excluding cached offscreen cards',
      (tester) async {
        repository.respond = () async =>
            pageOfLessons(repository.requestedPages.last);
        await controller.changeViewMode(mode);
        await controller.refresh();
        repository.requestedPages.clear();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 300,
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
          ),
        );
        await tester.pumpAndSettle();
        final cardHeight = tester
            .getSize(find.byType(TrainingLibraryModuleCard).first)
            .height;
        final sixteenthCardTop = 15 * (cardHeight + 16);
        controller.scrollController.jumpTo(sixteenthCardTop - 301);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('lesson-15'), skipOffstage: false),
          findsOneWidget,
        );
        expect(repository.requestedPages, isEmpty);

        controller.scrollController.jumpTo(sixteenthCardTop - 299);
        await tester.pumpAndSettle();
        expect(repository.requestedPages, [2]);
        expect(controller.items, hasLength(50));
        controller.scrollController.jumpTo(0);
        await tester.pumpAndSettle();
        expect(repository.requestedPages, [2]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'draft names become applied tags only on Done and IDs reach every page',
    () async {
      await controller.openSeatSelection();
      controller.updatePendingSeatSelection(controller.seatOptions.first);
      controller.updatePendingCategorySelection(
        controller.categoryOptions.first,
      );
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.last,
      );
      expect(controller.appliedFilterTags, isEmpty);
      expect(repository.requests, 1);

      repository.respond = () async => TrainingLibraryPage(
        items: [_module('two', _seatA, 'operations')],
        hasNextPage: true,
      );
      expect(await controller.applyPendingSeatSelection(), isTrue);
      controller.closeSeatSelection();
      expect(controller.appliedFilterTags.map((tag) => tag.label), [
        'Manager',
        'Category',
        'Same description title',
      ]);
      expect(repository.filterRequests.last, (
        jobId: 'a',
        categoryId: 'category',
        descriptionId: 'two',
        searchText: '',
        page: 1,
      ));
      await controller.loadNextPage();
      expect(repository.filterRequests.last, (
        jobId: 'a',
        categoryId: 'category',
        descriptionId: 'two',
        searchText: '',
        page: 2,
      ));
      await controller.refresh();
      expect(repository.filterRequests.last.page, 1);
    },
  );

  test(
    'removing each tag clears only that selection and its descendants',
    () async {
      for (final filter in TrainingLibraryFilter.values) {
        await applyHierarchy();
        expect(await controller.removeFilter(filter), isTrue);
        final request = repository.filterRequests.last;
        expect(request.page, 1);
        expect(
          request.jobId,
          filter == TrainingLibraryFilter.seat ? null : 'a',
        );
        expect(
          request.categoryId,
          filter == TrainingLibraryFilter.description ? 'category' : null,
        );
        expect(request.descriptionId, isNull);
        expect(controller.appliedFilterTags.length, filter.index);
        await controller.openSeatSelection();
        expect(controller.pendingSeatSelectionId, request.jobId);
        expect(controller.pendingCategorySelection?.id, request.categoryId);
        expect(controller.pendingDescriptionSelection, isNull);
        controller.closeSeatSelection();
      }
    },
  );

  test(
    'failed tag removal restores filters and results and allows retry',
    () async {
      await applyHierarchy();
      final tags = controller.appliedFilterTags;
      final items = controller.visibleItems;
      final response = Completer<TrainingLibraryPage>();
      repository.respond = () => response.future;
      final removal = controller.removeFilter(TrainingLibraryFilter.category);
      expect(controller.isInlineLoading, isTrue);
      expect(controller.canApplySelection, isFalse);
      expect(
        await controller.removeFilter(TrainingLibraryFilter.seat),
        isFalse,
      );
      response.completeError(Exception('API failure'));
      expect(await removal, isFalse);
      expect(controller.appliedFilterTags, tags);
      expect(controller.visibleItems, items);
      expect(
        controller.selectionErrorMessage,
        AppStrings.trainingLibraryUnableToApplyFilter,
      );
      expect(controller.isInlineLoading, isFalse);
      repository.respond = null;
      expect(
        await controller.removeFilter(TrainingLibraryFilter.category),
        isTrue,
      );
      expect(
        controller.appliedFilterTags.single.type,
        TrainingLibraryFilter.seat,
      );
    },
  );

  test(
    'opening a lesson passes its own UUID and related IDs directly to details',
    () async {
      await controller.changeViewMode(TrainingLibraryViewMode.grid);
      final requestsBeforeOpening = repository.requests;
      for (final lessonId in ['first-lesson', 'second-lesson']) {
        final module = TrainingLibraryModuleModel.fromApiJson(
          lessonListingJson(id: lessonId),
        );
        await controller.openLesson(
          module,
          openDetails: (route) async {
            expect(route.initialModuleId, lessonId);
            expect(route.description, '53a7288c-576d-45e4-a7b4-a0398336bb6c');
            expect(route.job, module.seat.id);
            expect(route.category, module.category.id);
          },
        );
      }
      expect(repository.requests, requestsBeforeOpening);
    },
  );

  test(
    'returning from editable lesson details refreshes the filtered listing',
    () async {
      canManageTraining = true;
      await applyHierarchy();
      final requestsBeforeOpening = repository.requests;
      final closed = Completer<void>();
      final opening = controller.openLesson(
        TrainingLibraryModuleModel.fromApiJson(lessonListingJson()),
        openDetails: (_) => closed.future,
      );
      expect(repository.requests, requestsBeforeOpening);
      closed.complete();
      await opening;
      expect(repository.requests, requestsBeforeOpening + 1);
      expect(repository.filterRequests.last, (
        jobId: 'a',
        categoryId: 'category',
        descriptionId: 'two',
        searchText: '',
        page: 1,
      ));

      canManageTraining = false;
      await controller.openLesson(
        TrainingLibraryModuleModel.fromApiJson(lessonListingJson()),
        openDetails: (_) async {},
      );
      expect(repository.requests, requestsBeforeOpening + 1);
    },
  );

  testWidgets(
    'returning from a later lesson keeps the list at its scroll position',
    (tester) async {
      final firstPage = List.generate(
        10,
        (index) => TrainingLibraryModuleModel.fromApiJson(
          lessonListingJson(id: 'lesson-$index'),
        ),
      );
      final secondPage = List.generate(
        10,
        (index) => TrainingLibraryModuleModel.fromApiJson(
          lessonListingJson(id: 'lesson-${index + 10}'),
        ),
      );
      TrainingLibraryPage pageFor(int page) => TrainingLibraryPage(
        items: page == 1 ? firstPage : secondPage,
        hasNextPage: page == 1,
      );
      repository.respond = () async => pageFor(repository.requestedPages.last);
      await controller.refresh();
      await controller.loadNextPage();
      canManageTraining = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 360,
              child: AnimatedBuilder(
                animation: controller,
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
      controller.scrollController.jumpTo(2800);
      await tester.pump();
      final openedAt = controller.scrollController.offset;

      final refreshedFirstPage = Completer<TrainingLibraryPage>();
      final refreshedSecondPage = Completer<TrainingLibraryPage>();
      repository.respond = () => repository.requestedPages.last == 1
          ? refreshedFirstPage.future
          : refreshedSecondPage.future;
      final opening = controller.openLesson(
        secondPage[2],
        openDetails: (_) async {},
      );
      await tester.pump();

      expect(controller.isRefreshing, isTrue);
      expect(controller.isInlineLoading, isFalse);
      expect(controller.scrollController.offset, openedAt);
      expect(controller.visibleItems.length, 20);

      refreshedFirstPage.complete(pageFor(1));
      await tester.pump();
      expect(controller.isRefreshing, isTrue);
      expect(controller.visibleItems.length, 20);
      expect(controller.scrollController.offset, openedAt);

      refreshedSecondPage.complete(pageFor(2));
      await opening;
      await tester.pump();

      expect(
        repository.requestedPages.sublist(repository.requestedPages.length - 2),
        [1, 2],
      );
      expect(controller.visibleItems.length, 20);
      expect(controller.scrollController.offset, openedAt);
    },
  );

  test(
    'details cannot be opened after disposal or without a lesson and description ID',
    () async {
      for (final json in [
        {...lessonListingJson(), 'uuid': ''},
        {...lessonListingJson(), 'description': null},
      ]) {
        await controller.openLesson(
          TrainingLibraryModuleModel.fromApiJson(json),
          openDetails: (_) async => fail('Invalid IDs must not open details.'),
        );
      }
      final detached = TrainingLibraryController(
        GetTrainingLibraryModulesUseCase(repository),
        getSeatProfilesUseCase: GetSeatProfilesUseCase(seatRepository),
      );
      detached.dispose();
      await detached.openLesson(
        TrainingLibraryModuleModel.fromApiJson(lessonListingJson()),
        openDetails: (_) async =>
            fail('Disposed controllers must not navigate.'),
      );
    },
  );

  test('create rechecks the current shared permission before opening', () {
    var opened = 0;
    controller.openCreateFlow(onOpen: () => opened++);
    expect(opened, 0);
    canCreateTraining = true;
    expect(controller.canCreateTraining, isTrue);
    controller.openCreateFlow(onOpen: () => opened++);
    expect(opened, 1);
    canCreateTraining = false;
    controller.openCreateFlow(onOpen: () => opened++);
    expect(opened, 1);
  });

  test(
    'selecting All keeps departments visible until the refresh finishes',
    () async {
      await controller.selectDepartment('sales');
      final response = Completer<TrainingLibraryPage>();
      repository.respond = () => response.future;

      final refresh = controller.selectDepartment('all');

      expect(controller.selectedDepartmentId, 'all');
      expect(controller.isRefreshing, isTrue);
      expect(controller.departments.map((department) => department.id), [
        'operations',
        'sales',
      ]);
      expect(controller.departmentOptions, controller.departments);

      response.complete(
        TrainingLibraryPage(
          items: [_module('new', _seatC, 'support')],
          hasNextPage: false,
        ),
      );
      await refresh;

      expect(controller.isRefreshing, isFalse);
      expect(controller.departments.map((department) => department.id), [
        'support',
      ]);
      expect(controller.visibleItems.map((module) => module.id), ['new']);
    },
  );

  test(
    'a failed All refresh preserves the available department choices',
    () async {
      await controller.selectDepartment('sales');
      final response = Completer<TrainingLibraryPage>();
      repository.respond = () => response.future;

      final refresh = controller.selectDepartment('all');
      response.completeError(Exception('API failure'));
      await refresh;

      expect(controller.selectedDepartmentId, 'all');
      expect(controller.isRefreshing, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.departments.map((department) => department.id), [
        'operations',
        'sales',
      ]);
    },
  );

  test('department search leaves the applied LMS filter unchanged', () async {
    await controller.selectDepartment('sales');

    controller.updateDepartmentSearchQuery('  OPER  ');

    expect(controller.departmentOptions.map((department) => department.id), [
      'operations',
    ]);
    expect(controller.selectedDepartmentId, 'sales');
    expect(controller.visibleItems.map((module) => module.id), ['four']);

    controller.updateDepartmentSearchQuery('missing');
    expect(controller.departmentOptions, isEmpty);

    controller.updateDepartmentSearchQuery('');
    expect(controller.departmentOptions.map((department) => department.id), [
      'operations',
      'sales',
    ]);
  });

  test(
    'loads the same complete hierarchy as Create Training for view users',
    () async {
      expect(seatRepository.requests, 0);
      expect(controller.canCreateTraining, isFalse);
      await controller.openSeatSelection();
      expect(seatRepository.requests, 1);
      expect(controller.seatOptions.map((seat) => seat.id), [
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(controller.categoryOptions, isEmpty);
      expect(controller.descriptionOptions, isEmpty);
      expect(controller.isLoadingSeatOptions, isFalse);
    },
  );

  test('hierarchy seats respect the selected department', () async {
    await controller.selectDepartment('operations');
    await controller.openSeatSelection();
    expect(controller.seatOptions.map((seat) => seat.id), ['a', 'b']);
  });

  test('closing discards a late hierarchy response', () async {
    final response = Completer<List<SeatProfileDetail>>();
    seatRepository.respond = () => response.future;
    final opening = controller.openSeatSelection();
    controller.closeSeatSelection();
    response.complete([_profile('a', 'Manager', 'operations')]);
    await opening;
    expect(controller.seatOptions, isEmpty);
    expect(controller.isLoadingSeatOptions, isFalse);
  });

  test('an older hierarchy response cannot replace a newer load', () async {
    final response = Completer<List<SeatProfileDetail>>();
    seatRepository.respond = () => response.future;
    final opening = controller.openSeatSelection();
    seatRepository.respond = null;
    await controller.loadSeatOptions();
    response.complete([]);
    await opening;
    expect(controller.seatOptions, hasLength(4));
  });

  test('failed hierarchy loads can be retried', () async {
    seatRepository.respond = () => Future.error(Exception('API failure'));
    await controller.openSeatSelection();
    expect(
      controller.seatOptionsError,
      AppStrings.trainingLibraryUnableToLoadSeats,
    );
    expect(controller.isLoadingSeatOptions, isFalse);
    seatRepository.respond = null;
    await controller.loadSeatOptions();
    expect(controller.seatOptionsError, isNull);
    expect(controller.seatOptions, hasLength(4));
  });

  test(
    'parent selections unlock and reset only their dependent drafts',
    () async {
      await controller.openSeatSelection();
      controller.updatePendingSeatSelection(controller.seatOptions.first);
      expect(controller.categoryOptions.map((item) => item.id), [
        'category',
        'other',
      ]);
      expect(controller.descriptionOptions, isEmpty);
      controller.updatePendingCategorySelection(
        controller.categoryOptions.first,
      );
      expect(controller.descriptionOptions.map((item) => item.id), [
        'one',
        'two',
      ]);
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.first,
      );
      controller.updatePendingSeatSelection(controller.seatOptions.first);
      expect(controller.pendingDescriptionSelection?.id, 'one');
      controller.updatePendingCategorySelection(
        controller.categoryOptions.last,
      );
      expect(controller.pendingDescriptionSelection, isNull);
      expect(controller.descriptionOptions.single.id, 'other-description');
      controller.updatePendingDescriptionSelection(_description('one'));
      expect(controller.pendingDescriptionSelection, isNull);
      controller.updatePendingSeatSelection(controller.seatOptions[1]);
      expect(controller.pendingCategorySelection, isNull);
      expect(controller.pendingDescriptionSelection, isNull);
      expect(controller.descriptionOptions, isEmpty);
      expect(controller.selectedSeatId, isNull);
      expect(repository.requests, 1);
    },
  );

  test(
    'Done applies exact hierarchy IDs and reopening preserves the draft',
    () async {
      await controller.openSeatSelection();
      controller.updatePendingSeatSelection(controller.seatOptions.first);
      controller.updatePendingCategorySelection(
        controller.categoryOptions.first,
      );
      expect(await controller.applyPendingSeatSelection(), isTrue);
      expect(controller.visibleItems.map((module) => module.id), [
        'one',
        'two',
      ]);
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.last,
      );
      expect(controller.visibleItems, hasLength(2));
      expect(await controller.applyPendingSeatSelection(), isTrue);
      expect(controller.visibleItems.single.id, 'two');
      controller.closeSeatSelection();
      await controller.changeViewMode(TrainingLibraryViewMode.grid);
      await controller.refresh();
      expect(controller.visibleItems.single.id, 'two');
      await controller.openSeatSelection();
      expect(controller.pendingSeatSelectionId, 'a');
      expect(controller.pendingCategorySelection?.id, 'category');
      expect(controller.pendingDescriptionSelection?.id, 'two');
      controller.updatePendingSeatSelection(null);
      controller.closeSeatSelection();
      expect(controller.visibleItems.single.id, 'two');
      expect(controller.selectedCategoryId, 'category');
      expect(controller.selectedDescriptionId, 'two');
    },
  );

  test(
    'failed apply restores every active filter and retains the new draft',
    () async {
      await controller.openSeatSelection();
      controller.updatePendingSeatSelection(controller.seatOptions.first);
      controller.updatePendingCategorySelection(
        controller.categoryOptions.first,
      );
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.first,
      );
      await controller.applyPendingSeatSelection();
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.last,
      );
      repository.respond = () => Future.error(Exception('API failure'));
      expect(await controller.applyPendingSeatSelection(), isFalse);
      expect(controller.selectedSeatId, 'a');
      expect(controller.selectedCategoryId, 'category');
      expect(controller.selectedDescriptionId, 'one');
      expect(controller.visibleItems.single.id, 'one');
      expect(controller.pendingDescriptionSelection?.id, 'two');
      repository.respond = null;
      expect(await controller.applyPendingSeatSelection(), isTrue);
      expect(controller.visibleItems.single.id, 'two');
    },
  );

  test(
    'filters flat lessons by description and keeps distinct lessons across pages',
    () async {
      TrainingLibraryModule lesson(String id, String descriptionId) =>
          TrainingLibraryModuleModel.fromApiJson({
            ...lessonListingJson(id: id, descriptionId: descriptionId),
            'job': {'uuid': 'a', 'title': 'Manager'},
            'category': {'uuid': 'category', 'title': 'Category'},
          });
      var responsePage = 0;
      repository.requestedPages.clear();
      repository.respond = () async => TrainingLibraryPage(
        items: ++responsePage == 1
            ? [lesson('lesson-a', 'two'), lesson('unrelated', 'one')]
            : [lesson('lesson-b', 'two')],
        hasNextPage: responsePage == 1,
      );
      await controller.openSeatSelection();
      controller.updatePendingSeatSelection(controller.seatOptions.first);
      controller.updatePendingCategorySelection(
        controller.categoryOptions.first,
      );
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.last,
      );

      expect(await controller.applyPendingSeatSelection(), isTrue);
      expect(controller.visibleItems.map((item) => item.id), ['lesson-a']);
      expect(controller.visibleItems.single.totalDuration, 706);
      expect(controller.visibleItems.single.lessonsCount, 1);

      await controller.loadNextPage();
      expect(controller.visibleItems.map((item) => item.id), [
        'lesson-a',
        'lesson-b',
      ]);
      expect(controller.items, hasLength(3));
      expect(repository.requestedPages, [1, 2]);

      await controller.loadNextPage();
      expect(repository.requestedPages, [1, 2]);
    },
  );

  test(
    'exact filters continue loading when the match is on a later page',
    () async {
      await controller.openSeatSelection();
      controller.updatePendingSeatSelection(controller.seatOptions.first);
      controller.updatePendingCategorySelection(
        controller.categoryOptions.first,
      );
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.last,
      );
      var page = 0;
      repository.respond = () async => TrainingLibraryPage(
        items: [
          ++page == 1
              ? _module('one', _seatA, 'operations')
              : _module('two', _seatA, 'operations'),
        ],
        hasNextPage: page == 1,
      );
      expect(await controller.applyPendingSeatSelection(), isTrue);
      expect(page, 2);
      expect(controller.visibleItems.single.id, 'two');
    },
  );

  test('repeated pages stop loading when no description matches', () async {
    await controller.openSeatSelection();
    controller.updatePendingSeatSelection(controller.seatOptions.first);
    controller.updatePendingCategorySelection(controller.categoryOptions.first);
    controller.updatePendingDescriptionSelection(
      controller.descriptionOptions.last,
    );
    var page = 0;
    repository.respond = () async {
      page++;
      if (page > 2) throw StateError('Repeated page loop');
      return TrainingLibraryPage(
        items: [_module('one', _seatA, 'operations')],
        hasNextPage: true,
      );
    };
    expect(await controller.applyPendingSeatSelection(), isTrue);
    expect(page, 2);
    expect(controller.visibleItems, isEmpty);
    expect(controller.items, hasLength(1));
  });

  test('reset and department changes clear dependent filters', () async {
    for (final reset in [
      () => controller.selectSeat(null),
      () => controller.selectDepartment('sales'),
    ]) {
      await controller.selectDepartment('all');
      await controller.openSeatSelection();
      controller.updatePendingSeatSelection(controller.seatOptions.first);
      controller.updatePendingCategorySelection(
        controller.categoryOptions.first,
      );
      controller.updatePendingDescriptionSelection(
        controller.descriptionOptions.first,
      );
      await controller.applyPendingSeatSelection();
      await reset();
      expect(controller.selectedSeatId, isNull);
      expect(controller.selectedCategoryId, isNull);
      expect(controller.selectedDescriptionId, isNull);
    }
  });

  test(
    'a selected API seat filters the LMS by UUID even with duplicate titles',
    () async {
      await controller.openSeatSelection();
      await controller.selectSeat(controller.seatOptions.first);

      expect(repository.lastSearchType, 'seat');
      expect(controller.searchQuery, isEmpty);
      expect(repository.filterRequests.last.jobId, 'a');
      expect(repository.filterRequests.last.searchText, isEmpty);
      expect(controller.appliedFilterTags.single.label, 'Manager');
      expect(controller.visibleItems.map((module) => module.id), [
        'one',
        'two',
        'other-description',
      ]);
      expect(controller.selectedSeatId, 'a');
    },
  );

  test(
    'All Seats clears the seat filter while preserving the department',
    () async {
      await controller.selectDepartment('operations');
      await controller.selectSeat(_seatA);

      await controller.selectSeat(null);

      expect(controller.selectedSeatId, isNull);
      expect(controller.searchQuery, isEmpty);
      expect(controller.selectedDepartmentId, 'operations');
      expect(controller.visibleItems, hasLength(4));
    },
  );

  test('changing departments clears the previous seat selection', () async {
    await controller.selectSeat(_seatA);

    await controller.selectDepartment('sales');

    expect(controller.selectedSeatId, isNull);
    expect(controller.searchQuery, isEmpty);
    expect(controller.visibleItems.map((module) => module.id), ['four']);
    await controller.openSeatSelection();
    expect(controller.seatOptions.map((seat) => seat.id), ['c']);
  });

  test(
    'typing and clearing search preserves the applied filter tags',
    () async {
      await controller.selectSeat(_seatA);

      controller.updateSearchQuery('Sales');

      expect(controller.selectedSeatId, 'a');
      expect(controller.searchQuery, 'Sales');
      expect(controller.appliedFilterTags.single.label, 'Manager');
      await controller.clearSearch();
      expect(controller.selectedSeatId, 'a');
      expect(controller.searchQuery, isEmpty);
      expect(repository.filterRequests.last.jobId, 'a');
      expect(repository.filterRequests.last.searchText, isEmpty);
    },
  );

  testWidgets(
    'debounces the latest search and keeps filter IDs for every page',
    (tester) async {
      await applyHierarchy();
      repository.respond = () async => TrainingLibraryPage(
        items: [_module('two', _seatA, 'operations')],
        hasNextPage: true,
      );
      final requestsBeforeTyping = repository.requests;
      controller.updateSearchQuery('L');
      await tester.pump(const Duration(milliseconds: 300));
      controller.updateSearchQuery(' Lesson ');
      await tester.pump(const Duration(milliseconds: 399));
      expect(repository.requests, requestsBeforeTyping);

      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.requests, requestsBeforeTyping + 1);
      expect(repository.filterRequests.last, (
        jobId: 'a',
        categoryId: 'category',
        descriptionId: 'two',
        searchText: 'Lesson',
        page: 1,
      ));
      expect(controller.appliedFilterTags, hasLength(3));
      await controller.loadNextPage();
      expect(repository.filterRequests.last, (
        jobId: 'a',
        categoryId: 'category',
        descriptionId: 'two',
        searchText: 'Lesson',
        page: 2,
      ));

      await controller.clearSearch();
      expect(repository.filterRequests.last, (
        jobId: 'a',
        categoryId: 'category',
        descriptionId: 'two',
        searchText: '',
        page: 1,
      ));
      expect(controller.appliedFilterTags, hasLength(3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.requests, requestsBeforeTyping + 3);
    },
  );
}

const _seatA = TrainingLibrarySeat(id: 'a', title: 'Manager');
const _seatB = TrainingLibrarySeat(id: 'b', title: 'Manager');
const _seatC = TrainingLibrarySeat(id: 'c', title: 'Sales Lead');

class _SeatRepository extends Fake implements SeatProfileRepository {
  int requests = 0;
  Future<List<SeatProfileDetail>> Function()? respond;

  @override
  Future<List<SeatProfileDetail>> seatProfileCategoryTrainings() async {
    requests++;
    return respond?.call() ??
        [
          _profile('a', 'Manager', 'operations'),
          _profile('b', 'Manager', 'operations'),
          _profile('c', 'Sales Lead', 'sales'),
          _profile('d', 'Remote Seat', 'remote'),
        ];
  }
}

SeatProfileDetail _profile(String id, String title, String departmentId) =>
    SeatProfileDetail(
      id: id,
      actualId: 'actual-$id',
      title: title,
      department: Department(id: departmentId, name: departmentId),
      paygradeUnit: '',
      categories: [
        SeatProfileCategory(
          id: 'category',
          title: 'Category',
          weightPercent: 0,
          descriptions: [_description('one'), _description('two')],
        ),
        SeatProfileCategory(
          id: 'other',
          title: 'Category',
          weightPercent: 0,
          descriptions: [_description('other-description')],
        ),
      ],
    );

SeatProfileDescription _description(String id) => SeatProfileDescription(
  id: id,
  actualId: id,
  name: 'Same description title',
  auditSpecifics: '',
  auditFactorType: '',
  milestoneDays: '',
);

class _LibraryRepository extends Fake implements TrainingLibraryRepository {
  int requests = 0;
  final List<int> requestedPages = [];
  final List<int> requestedPageSizes = [];
  final List<
    ({
      String? jobId,
      String? categoryId,
      String? descriptionId,
      String searchText,
      int page,
    })
  >
  filterRequests = [];
  final List<TrainingLibraryModule> _modules = [
    _module('one', _seatA, 'operations'),
    _module('two', _seatA, 'operations'),
    _module('other-description', _seatA, 'operations', categoryId: 'other'),
    _module('three', _seatB, 'operations'),
    _module('four', _seatC, 'sales'),
  ];

  String? lastSearchType;
  Future<TrainingLibraryPage> Function()? respond;

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
    requestedPages.add(page);
    requestedPageSizes.add(pageSize);
    filterRequests.add((
      jobId: jobId,
      categoryId: jobCategoryId,
      descriptionId: jobCategoryDescriptionId,
      searchText: searchText,
      page: page,
    ));
    lastSearchType = searchType;
    final response = respond;
    if (response != null) {
      return response();
    }
    return TrainingLibraryPage(
      items: _modules.where((module) {
        return (departmentId == null || module.department.id == departmentId) &&
            module.seat.title.toLowerCase().contains(searchText.toLowerCase());
      }).toList(),
      hasNextPage: false,
    );
  }
}

TrainingLibraryModule _module(
  String id,
  TrainingLibrarySeat seat,
  String departmentId, {
  String categoryId = 'category',
}) {
  return TrainingLibraryModule(
    id: id,
    title: id,
    description: '',
    department: TrainingLibraryDepartment(id: departmentId, name: departmentId),
    totalDuration: 60,
    seat: seat,
    lessons: const [],
    thumbnailLink: null,
    category: TrainingLibraryCategory(id: categoryId, title: 'Category'),
  );
}
