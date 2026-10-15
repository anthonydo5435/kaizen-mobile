import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_overlay_close_button.dart';
import 'package:sparrowkaizen/core/widgets/app_gradient_action_button.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/lms_public_link.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_share_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/shared_lesson_details_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_share_dialogue.dart';

import '../../fixtures/training_share_fixture.dart';

void main() {
  late ShareRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(User(uuid: 'owner', isOwner: true));
    repository = ShareRepository();
  });
  tearDown(() => AppManager.instance.resetSessionState());

  testWidgets(
    'existing link can revoke, retry a failure, and create a new link',
    (tester) async {
      repository.existingLink = LmsPublicLink(
        url: createdLmsLink,
        trainingModuleUuids: ['lesson-1'],
      );
      final pending = Completer<void>();
      repository.pendingDelete = pending.future;
      await tester.pumpWidget(_dialogApp(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.shareRevokeLinkAction), findsOneWidget);
      await tester.tap(find.text(AppStrings.shareRevokeLinkAction));
      await tester.pump();
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      expect(find.text(createdLmsLink), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.copy_outlined),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text(AppStrings.shareRevokeLinkAction));
      expect(repository.deleteRequests, ['description-id']);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.shareRevokeLinkFailed), findsOneWidget);
      expect(find.text(createdLmsLink), findsOneWidget);
      repository.pendingDelete = null;
      await tester.tap(find.text(AppStrings.shareRevokeLinkAction));
      await tester.pumpAndSettle();
      expect(find.text(createdLmsLink), findsNothing);
      expect(find.text(AppStrings.shareRevokeLinkAction), findsNothing);
      expect(find.text('3 of 3 selected'), findsOneWidget);
      expect(find.text(AppStrings.shareCreateLinkAction), findsOneWidget);
      await tester.tap(find.byType(AppOverlayCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 selected'), findsOneWidget);
      await tester.tap(find.text(AppStrings.shareCreateLinkAction));
      await tester.pumpAndSettle();
      expect(find.text(createdLmsLink), findsOneWidget);
      expect(find.text(AppStrings.shareRevokeLinkAction), findsOneWidget);
      expect(repository.requests.single.ids, [
        'lesson-0',
        'lesson-1',
        'lesson-2',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending screen lookup survives closing and shows the existing Public Link',
    (tester) async {
      final lookup = Completer<LmsPublicLink?>();
      repository.pendingLoad = lookup.future;
      await tester.pumpWidget(_dialogApp(repository));
      expect(repository.loadRequests, ['description-id']);
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.text(AppStrings.shareLoadingLink), findsOneWidget);
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text(AppStrings.shareCreateLinkAction), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(AppOverlayCloseButton));
      await tester.pumpAndSettle();
      lookup.complete(
        LmsPublicLink(url: createdLmsLink, trainingModuleUuids: ['lesson-1']),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.sharePublicLinkTitle), findsOneWidget);
      expect(find.text(createdLmsLink), findsOneWidget);
      expect(find.byTooltip(AppStrings.shareCopyLinkAction), findsOneWidget);
      expect(find.text(AppStrings.shareCreateLinkAction), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(repository.loadRequests, ['description-id']);
      expect(repository.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed screen lookup offers retry before lesson selection', (
    tester,
  ) async {
    repository.loadFailure = StateError('offline');
    await tester.pumpWidget(_dialogApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.shareLoadLinkFailed), findsOneWidget);
    expect(find.text(AppStrings.actionRetry), findsOneWidget);
    expect(find.text(AppStrings.shareCreateLinkAction), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    repository.loadFailure = null;
    await tester.tap(find.text(AppStrings.actionRetry));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 selected'), findsOneWidget);
    expect(find.text(AppStrings.shareCreateLinkAction), findsOneWidget);
    expect(repository.loadRequests, ['description-id', 'description-id']);
    expect(repository.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'viewer shares selected siblings using the description ID and copies the result',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingLessonViewerScreen(
            trainingRoute: const SeatDescriptionTrainingRoute(
              job: 'job-id',
              category: 'category-id',
              description: 'description-id',
              initialModuleId: 'lesson-1',
            ),
            auditRepository: _AuditRepository(),
            trainingLibraryRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byIcon(Icons.share_outlined)).dx,
        greaterThan(
          tester.getTopRight(find.text(AppStrings.training).first).dx,
        ),
      );
      await tester.tap(find.byTooltip(AppStrings.shareAction));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.shareLessonsTitle), findsOneWidget);
      expect(find.text('3 of 3 selected'), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((box) => box.value == true),
        isTrue,
      );
      await tester.tap(find.text('Lesson 0'));
      await tester.pump();
      expect(find.text('2 of 3 selected'), findsOneWidget);
      await tester.tap(find.text(AppStrings.shareCreateLinkAction));
      await tester.pumpAndSettle();
      expect(repository.requests.single.descriptionId, 'description-id');
      expect(repository.requests.single.ids, ['lesson-1', 'lesson-2']);
      expect(find.text(createdLmsLink), findsOneWidget);
      await tester.tap(find.byTooltip(AppStrings.shareCopyLinkAction));
      await tester.pumpAndSettle();
      expect(copied, createdLmsLink);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('three lessons fit, more lessons grow to 70 percent and scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_dialogApp(repository, count: 3));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final shortHeight = _dialogHeight(tester);
    expect(shortHeight, lessThan(844 * .7));
    final shortScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(shortScroll.position.maxScrollExtent, 0);
    expect(find.text('Lesson 2').hitTestable(), findsOneWidget);
    await tester.tap(find.byType(AppOverlayCloseButton));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_dialogApp(repository, count: 12));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(_dialogHeight(tester), greaterThan(shortHeight));
    expect(_dialogHeight(tester), closeTo(844 * .7, 1));
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lesson 11').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text stays inside a narrow dialog and close makes no request',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_dialogApp(repository, count: 6, textScale: 2));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(_dialogHeight(tester), lessThanOrEqualTo(568 * .7 + 1));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(AppOverlayCloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(TrainingShareDialogue), findsNothing);
      expect(repository.requests, isEmpty);
    },
  );

  testWidgets(
    'select all can clear and restore selection; failed POST can retry',
    (tester) async {
      await tester.pumpWidget(_dialogApp(repository));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('0 of 3 selected'), findsOneWidget);
      await tester.tap(find.text(AppStrings.shareCreateLinkAction));
      expect(repository.requests, isEmpty);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      repository.failure = StateError('offline');
      await tester.tap(find.text(AppStrings.shareCreateLinkAction));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.shareCreateLinkFailed), findsOneWidget);
      repository.failure = null;
      await tester.tap(find.text(AppStrings.shareCreateLinkAction));
      await tester.pumpAndSettle();
      expect(find.text(createdLmsLink), findsOneWidget);
      expect(repository.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending creation disables selection and closing', (
    tester,
  ) async {
    final pending = Completer<LmsPublicLink>();
    repository.pending = pending.future;
    await tester.pumpWidget(_dialogApp(repository));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final createButton = find.byType(AppGradientActionButton);
    final createButtonSize = tester.getSize(createButton);
    await tester.tap(find.text(AppStrings.shareCreateLinkAction));
    await tester.pump();
    expect(tester.getSize(createButton), createButtonSize);
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<AppOverlayCloseButton>(find.byType(AppOverlayCloseButton))
          .onTap,
      isNull,
    );
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((box) => box.onChanged == null),
      isTrue,
    );
    pending.complete(
      LmsPublicLink(
        url: createdLmsLink,
        trainingModuleUuids: ['lesson-0', 'lesson-1', 'lesson-2'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(createdLmsLink), findsOneWidget);
  });

  testWidgets('role-only owners do not get a share action or fetch a link', (
    tester,
  ) async {
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', isOwner: false, roles: ['owner', 'csuite']),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingLessonViewerScreen(
          trainingRoute: const SeatDescriptionTrainingRoute(
            job: 'job-id',
            category: 'category-id',
            description: 'description-id',
          ),
          auditRepository: _AuditRepository(),
          trainingLibraryRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip(AppStrings.shareAction), findsNothing);
    expect(repository.requests, isEmpty);
    expect(repository.loadRequests, isEmpty);
  });
}

double _dialogHeight(WidgetTester tester) => tester
    .getSize(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    )
    .height;

Widget _dialogApp(
  ShareRepository repository, {
  int count = 3,
  double textScale = 1,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: ChangeNotifierProvider(
    lazy: false,
    create: (_) => TrainingShareController(
      repository,
      seatProfileId: 'job-id',
      descriptionId: 'description-id',
    )..loadLink(),
    child: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showTrainingShareDialogue(
            context,
            controller: context.read<TrainingShareController>(),
            lessons: shareLessons(count),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

class _AuditRepository extends Fake implements AuditRepository {
  @override
  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  }) async => shareLessons();

  @override
  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) async =>
      SeatDescriptionTrainingModuleDetail(
        uuid: moduleId,
        actualId: 'parent',
        title: 'Selected lesson',
        thumbnails: [],
        description: null,
        assignmentTitle: null,
        assignmentInstructions: null,
        questions: [],
        thumbnailLink: null,
        trainingVideo: null,
        isPubliclyAvailable: false,
        learningTrackCount: 0,
      );

  @override
  Future<SeatDescriptionTrainingDocument>
  getSeatDescriptionTrainingModuleDocument({required String moduleId}) async =>
      const SeatDescriptionTrainingDocument(uuid: 'document', text: null);
}
