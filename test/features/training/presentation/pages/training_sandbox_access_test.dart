import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/models/company_billing_details.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/login/domain/entities/organization_hierarchy_job.dart';
import 'package:sparrowkaizen/features/login/domain/entities/organization_hierarchy_node.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user_hierarchy_membership.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/shared_lesson_details_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/training_library_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_module_card.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_tab_view.dart';

import '../../fixtures/tiptap_sop_fixture.dart';
import '../../fixtures/training_library_fixtures.dart';

void main() {
  final writes = <http.Request>[];
  var activeOrganizationType = 'parent';
  var includeGenerationSource = false;
  var emptyQuestions = false;
  String? videoProcessingStatus;
  Future<http.Response>? seatLookupResponse;
  // ApiCallExecutor retains its first HTTP client across widget tests.
  final client = _client(
    () => activeOrganizationType,
    () => includeGenerationSource,
    () => emptyQuestions,
    () => videoProcessingStatus,
    () => seatLookupResponse,
    writes,
  );
  tearDownAll(client.close);

  testWidgets(
    'EditTrainingScreen updates managed-seat viewing in a child organisation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final manager = AppManager.instance;
      SharedPreferences.setMockInitialValues({});
      await AppPreference.init();
      manager.resetSessionState();
      ApiCallExecutor.clearGetCache();
      addTearDown(manager.resetSessionState);
      addTearDown(ApiCallExecutor.clearGetCache);
      activeOrganizationType = 'child';
      writes.clear();
      final user = User(
        uuid: 'learner',
        organizationUuid: 'org-id',
        roles: const ['supervisor'],
        hasSandboxAccess: false,
      );
      final hierarchy = OrganizationHierarchyNode.fromJson({
        'uuid': 'supervisor-node',
        'role': 'supervisor',
        'profile': {'uuid': 'learner'},
        'children': [
          {
            'role': 'team_member',
            'job': {'uuid': 'seat'},
          },
        ],
      });

      await http.runWithClient(() async {
        await manager.fetchOrganizations(requireSuccess: true);
        manager.updateCurrentUser(user);
        await tester.pumpWidget(
          Provider<TrainingSopEditorFactory>.value(
            value: TiptapSopFixture().create,
            child: const MaterialApp(
              home: EditTrainingScreen(
                trainingRoute: SeatDescriptionTrainingRoute(
                  job: 'child-seat',
                  actualSeatProfileId: 'seat',
                  category: 'category',
                  description: 'description',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        TrainingTabs tabs() =>
            tester.widget<TrainingTabs>(find.byType(TrainingTabs));
        expect(manager.currentOrganization?.type, 'child');
        expect(tabs().maxTabIndex, 1);
        final pageView = find.byType(PageView);
        final pageController = tester.widget<PageView>(pageView).controller;

        manager.updateCurrentUser(
          user.copyWith(
            hierarchyMemberships: hierarchy.collectMembershipsForUser({
              'learner',
            }),
          ),
        );
        await tester.pumpAndSettle();
        expect(tabs().maxTabIndex, 3);
        expect(
          tester.widget<PageView>(pageView).controller,
          same(pageController),
        );

        await tester.tap(_tab(AppStrings.trainingQuizTab));
        await tester.pumpAndSettle();
        expect(tabs().navigation.selectedIndex, 2);
        expect(find.text('Training question?'), findsOneWidget);
        expect(
          find.byTooltip(AppStrings.trainingQuestionActions),
          findsNothing,
        );
        await tester.tap(_tab(AppStrings.trainingAssignmentTab));
        await tester.pumpAndSettle();
        expect(tabs().navigation.selectedIndex, 3);
        expect(find.text('Assignment instructions'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(writes, isEmpty);

        manager.updateCurrentUser(
          user.copyWith(
            roles: const ['team_lead'],
            hierarchyMemberships: const [
              UserHierarchyMembership(
                nodeUuid: 'supervisor-node',
                role: 'team_lead',
                manageableSeatProfileIds: ['seat'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.trainingGenerateAssignment),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsOneWidget);
        expect(tabs().navigation.selectedIndex, 3);

        manager.updateCurrentUser(user);
        await tester.pumpAndSettle();
        expect(tabs().maxTabIndex, 1);
        expect(tabs().navigation.selectedIndex, 1);
        expect(find.text('Assignment instructions'), findsNothing);
      }, () => client);
    },
  );

  for (final assignedToSeat in [false, true]) {
    testWidgets(
      'a user who ${assignedToSeat ? 'is assigned to' : 'manages'} the lesson seat can edit Summary and generate from LMS',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        await AppPreference.init();
        final manager = AppManager.instance;
        manager.resetSessionState();
        ApiCallExecutor.clearGetCache();
        addTearDown(manager.resetSessionState);
        addTearDown(ApiCallExecutor.clearGetCache);
        activeOrganizationType = 'child';
        includeGenerationSource = true;
        emptyQuestions = assignedToSeat;
        videoProcessingStatus = assignedToSeat ? 'completed' : 'failed';
        final seatLookup = Completer<http.Response>();
        seatLookupResponse = seatLookup.future;
        addTearDown(() {
          includeGenerationSource = false;
          emptyQuestions = false;
          videoProcessingStatus = null;
          seatLookupResponse = null;
        });
        writes.clear();

        await http.runWithClient(() async {
          await manager.fetchOrganizations(requireSuccess: true);
          final role = assignedToSeat ? 'team_member' : 'team_lead';
          final user = User(
            uuid: 'learner',
            organizationUuid: 'org-id',
            roles: [role],
            hierarchyMemberships: [
              UserHierarchyMembership(
                nodeUuid: 'learner-node',
                role: role,
                job: assignedToSeat
                    ? const OrganizationHierarchyJob(
                        uuid: 'seat',
                        title: 'Seat',
                      )
                    : null,
                manageableSeatProfileIds: assignedToSeat
                    ? const []
                    : const ['seat'],
              ),
            ],
          );
          manager.updateCurrentUser(user);
          manager.saveBillingDetails(
            CompanyBillingDetails.fromApiJson({'status': 'canceled'}),
          );
          manager.dismissBillingBanner();
          await tester.pumpWidget(
            Provider<TrainingSopEditorFactory>.value(
              value: TiptapSopFixture().create,
              child: const MaterialApp(home: TrainingLibraryScreen()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(TrainingLibraryModuleCard),
              matching: find.byType(InkWell),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(EditTrainingScreen), findsOneWidget);
          final pageView = find.byType(PageView);
          final pager = tester.widget<PageView>(pageView).controller;
          TrainingTabs tabs() => tester.widget<TrainingTabs>(find.byType(TrainingTabs));
          expect(tabs().maxTabIndex, 1);
          seatLookup.complete(
            http.Response('{"uuid":"child-seat","actual_id":"seat"}', 200),
          );
          await tester.pumpAndSettle();
          expect(tester.widget<PageView>(pageView).controller, same(pager));
          expect(tabs().maxTabIndex, 3);

          final summaryField = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText == AppStrings.trainingSummaryHint,
          );
          if (assignedToSeat) {
            expect(
              find.text(AppStrings.trainingGenerateSummaryAction),
              findsNothing,
            );
            expect(
              find.byTooltip(AppStrings.trainingReUploadVideoAction),
              findsNothing,
            );
          } else {
            expect(find.text(_nonRetryableVideoMessage), findsOneWidget);
            expect(
              find.text(AppStrings.trainingRetrySummaryGenerationAction),
              findsNothing,
            );
          }

          final summaryTarget = assignedToSeat
              ? find.text('Lesson summary')
              : find.text(AppStrings.trainingSummaryLabel);
          await tester.ensureVisible(summaryTarget);
          await tester.tap(summaryTarget);
          await tester.pump();

          final editor = tester.widget<EditableText>(
            find.descendant(
              of: summaryField,
              matching: find.byType(EditableText),
            ),
          );
          expect(editor.focusNode.hasFocus, isTrue);
          expect(editor.showCursor, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          await tester.enterText(summaryField, 'Manual summary');
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pumpAndSettle();
          expect(writes, hasLength(1));
          final summaryUpdate = writes.removeLast();
          expect(summaryUpdate.method, 'PATCH');
          expect(
            summaryUpdate.url.path,
            endsWith(ApiEndPoints.trainingModuleDetail('lesson')),
          );
          expect(jsonDecode(summaryUpdate.body), {
            'description': 'Manual summary',
          });

          if (assignedToSeat) {
            await tester.tap(_tab(AppStrings.trainingSopTab));
            await tester.pumpAndSettle();
            expect(find.text('Procedure'), findsOneWidget);
            await tester.tap(find.text(AppStrings.trainingCreateWithAi));
            await tester.pumpAndSettle();
            expect(
              find.text(AppStrings.paidFeaturesUnavailableMessage),
              findsOneWidget,
            );
            await tester.tap(find.text(AppStrings.paidFeaturesUnavailableOk));
            await tester.pumpAndSettle();
          }

          await tester.tap(_tab(AppStrings.trainingQuizTab));
          await tester.pumpAndSettle();
          if (assignedToSeat) {
            final message = find.text(AppStrings.trainingNoQuizQuestionsAvailable);
            final center = find
                .ancestor(of: message, matching: find.byType(Center))
                .first;
            expect(tester.getCenter(message), tester.getCenter(center));
            expect(
              tester.getBottomLeft(center).dy,
              tester.getBottomLeft(find.byType(TrainingTabView)).dy,
            );
            expect(find.text(AppStrings.trainingAddNewQuestion), findsNothing);
          } else {
            expect(find.text('Training question?'), findsOneWidget);
            expect(find.text(AppStrings.trainingAddNewQuestion), findsOneWidget);
          }
          final generateQuiz = find.text(AppStrings.trainingCreateWithAi);
          await tester.tap(generateQuiz);
          await tester.pumpAndSettle();
          expect(
            find.text(AppStrings.paidFeaturesUnavailableMessage),
            findsOneWidget,
          );
          await tester.tap(find.text(AppStrings.paidFeaturesUnavailableOk));
          await tester.pumpAndSettle();

          await tester.tap(_tab(AppStrings.trainingAssignmentTab));
          await tester.pumpAndSettle();
          expect(find.text('Assignment instructions'), findsOneWidget);
          final generateAssignment = find.text(
            AppStrings.trainingGenerateAssignment,
          );
          await tester.tap(generateAssignment);
          await tester.pumpAndSettle();
          expect(
            find.text(AppStrings.paidFeaturesUnavailableMessage),
            findsOneWidget,
          );
          expect(writes, isEmpty);
          await tester.tap(find.text(AppStrings.paidFeaturesUnavailableOk));
          await tester.pumpAndSettle();

          manager.saveBillingDetails(
            CompanyBillingDetails.fromApiJson({
              'status': 'canceled',
              'isInTrial': true,
              'can_use_paid_features': true,
            }),
          );
          await tester.tap(generateAssignment);
          await tester.pumpAndSettle();
          expect(
            find.text(AppStrings.trainingGenerateAssignmentDialogTitle),
            findsOneWidget,
          );
          expect(writes, isEmpty);
          if (assignedToSeat) {
            Navigator.of(
              tester.element(
                find.text(AppStrings.trainingGenerateAssignmentDialogTitle),
              ),
            ).pop();
            await tester.pumpAndSettle();
            expect(find.byType(TextField), findsNothing);
            await tester.tap(_tab(AppStrings.trainingSopTab));
            await tester.pumpAndSettle();
            await tester.tap(find.text(AppStrings.trainingCreateWithAi));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byType(TextField),
              AppStrings.trainingGenerateSopConfirmation,
            );
            await tester.pumpAndSettle();
            final regenerate = find.widgetWithText(
              TextButton,
              AppStrings.trainingRegenerate,
            );
            expect(tester.widget<TextButton>(regenerate).onPressed, isNotNull);
            await tester.ensureVisible(regenerate);
            await tester.tap(regenerate);
            await tester.pumpAndSettle();
            expect(writes, hasLength(1));
            expect(
              writes.single.url.path,
              endsWith(ApiEndPoints.generateTrainingModuleSop('lesson')),
            );

            manager.updateCurrentUser(
              user.copyWith(hierarchyMemberships: const []),
            );
            await tester.pumpAndSettle();
            expect(find.text(AppStrings.trainingCreateWithAi), findsNothing);
            final tabs = tester.widget<TrainingTabs>(find.byType(TrainingTabs));
            expect(tabs.maxTabIndex, 1);
            await tester.tap(_tab(AppStrings.trainingVideoTab));
            await tester.pumpAndSettle();
            expect(summaryField, findsNothing);
            expect(find.text('Manual summary'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }

  for (final organizationType in ['parent', 'sandbox', 'child']) {
    for (final isOwner in [false, true]) {
      for (final canManageSeat in [false, true]) {
        for (final managesSeat in [false, true]) {
          final canManage = isOwner || (canManageSeat && managesSeat);
          final canAccessExtras = isOwner || managesSeat;
          final role = canManageSeat ? 'dept_lead' : 'supervisor';
          for (final isViewer in [false, true]) {
            final canEdit = canManage && !isViewer;
            testWidgets(
              '$organizationType ${isViewer ? 'viewer' : 'editor'} respects '
              'scope (role: $role, owner: $isOwner, managed: $managesSeat) '
              'for Quiz and Assignment',
              (tester) async {
                tester.view.physicalSize = const Size(390, 844);
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                SharedPreferences.setMockInitialValues({});
                await AppPreference.init();
                AppManager.instance.resetSessionState();
                ApiCallExecutor.clearGetCache();
                addTearDown(AppManager.instance.resetSessionState);
                addTearDown(ApiCallExecutor.clearGetCache);
                writes.clear();
                activeOrganizationType = organizationType;

                await http.runWithClient(() async {
                  await AppManager.instance.fetchOrganizations(
                    requireSuccess: true,
                  );
                  AppManager.instance.updateCurrentUser(
                    User(
                      uuid: 'learner',
                      isOwner: isOwner,
                      roles: [role],
                      hierarchyMemberships: [
                        UserHierarchyMembership(
                          nodeUuid: 'node',
                          role: role,
                          manageableSeatProfileIds: managesSeat
                              ? const ['seat']
                              : const ['other-seat'],
                        ),
                      ],
                      organizationUuid: 'org-id',
                    ),
                  );
                  expect(
                    AppManager.instance.currentOrganization?.type,
                    organizationType,
                  );
                  const route = SeatDescriptionTrainingRoute(
                    job: 'seat',
                    category: 'category',
                    description: 'description',
                    initialModuleId: 'lesson',
                  );
                  await tester.pumpWidget(
                    ChangeNotifierProvider<AppManager>.value(
                      value: AppManager.instance,
                      child: Provider<TrainingSopEditorFactory>.value(
                        value: TiptapSopFixture().create,
                        child: MaterialApp(
                          home: isViewer
                              ? const TrainingLessonViewerScreen(
                                  trainingRoute: route,
                                )
                              : const Scaffold(
                                  body: EditTrainingSection(
                                    trainingRoute: route,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                  await tester.pumpAndSettle();

                  final tabs = tester.widget<TrainingTabs>(
                    find.byType(TrainingTabs),
                  );
                  expect(tabs.maxTabIndex, canAccessExtras ? 3 : 1);
                  await tester.tap(_tab(AppStrings.trainingSopTab));
                  // Tiptap's caret animation keeps scheduling frames while mounted.
                  if (canEdit) {
                    await tester.pump();
                    await tester.pump(const Duration(milliseconds: 300));
                    await tester.pump();
                  } else {
                    await tester.pumpAndSettle();
                  }
                  expect(tabs.navigation.selectedIndex, 1);
                  if (!canEdit) {
                    expect(find.text('Procedure'), findsOneWidget);
                    final sopField = find.byWidgetPredicate(
                      (widget) =>
                          widget is TextField &&
                          widget.decoration?.hintText ==
                              AppStrings.trainingSopHint,
                    );
                    expect(sopField, findsNothing);
                    expect(
                      find.text(AppStrings.trainingCreateWithAi),
                      findsNothing,
                    );
                  }
                  await tester.tap(_tab(AppStrings.trainingVideoTab));
                  await tester.pumpAndSettle();
                  await tester.tap(_tab(AppStrings.trainingQuizTab));
                  await tester.pumpAndSettle();
                  if (canAccessExtras) {
                    expect(tabs.navigation.selectedIndex, 2);
                    expect(find.text('Training question?'), findsOneWidget);
                    expect(
                      find.byTooltip(AppStrings.trainingQuestionActions),
                      canEdit ? findsOneWidget : findsNothing,
                    );
                    expect(
                      find.text(AppStrings.trainingAddNewQuestion),
                      canEdit ? findsOneWidget : findsNothing,
                    );
                    if (canEdit) {
                      expect(
                        tester
                            .widget<IconButton>(
                              find.byWidgetPredicate(
                                (widget) =>
                                    widget is IconButton &&
                                    widget.tooltip ==
                                        AppStrings.trainingQuestionActions,
                              ),
                            )
                            .onPressed,
                        isNotNull,
                      );
                    }
                    await tester.fling(
                      find.byType(PageView),
                      const Offset(-320, 0),
                      1000,
                    );
                    await tester.pumpAndSettle();
                    expect(tabs.navigation.selectedIndex, 3);

                    final editor = find.byWidgetPredicate(
                      (widget) =>
                          widget is TextField &&
                          widget.decoration?.hintText ==
                              AppStrings.trainingAssignmentDescriptionHint,
                    );
                    if (!canEdit) {
                      expect(editor, findsNothing);
                      expect(
                        find.text('Assignment instructions'),
                        findsOneWidget,
                      );
                      expect(
                        find.text(AppStrings.trainingGenerateAssignment),
                        findsNothing,
                      );
                      expect(writes, isEmpty);
                    } else {
                      expect(editor, findsOneWidget);
                      expect(
                        tester.widget<TextField>(editor).readOnly,
                        isFalse,
                      );
                      await tester.enterText(editor, 'Updated instructions');
                      await tester.pump(const Duration(milliseconds: 400));
                      await tester.pump();
                      expect(writes, hasLength(1));
                      expect(writes.single.method, 'PATCH');
                      expect(
                        writes.single.url.path,
                        endsWith('training_assignment/assignment-1/'),
                      );
                      expect(jsonDecode(writes.single.body), {
                        'instructions': 'Updated instructions',
                      });
                    }
                  } else {
                    expect(tabs.navigation.selectedIndex, 0);
                    await tester.tap(_tab(AppStrings.trainingAssignmentTab));
                    await tester.pumpAndSettle();
                    expect(tabs.navigation.selectedIndex, 0);
                    await tester.fling(
                      find.byType(PageView),
                      const Offset(-320, 0),
                      1000,
                    );
                    await tester.pumpAndSettle();
                    await tester.fling(
                      find.byType(PageView),
                      const Offset(-320, 0),
                      1000,
                    );
                    await tester.pumpAndSettle();
                    expect(tabs.navigation.selectedIndex, 1);
                    expect(writes, isEmpty);
                  }

                  expect(tester.takeException(), isNull);
                  await tester.pumpWidget(const SizedBox.shrink());
                }, () => client);
              },
            );
          }
        }
      }
    }
  }
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(TrainingTabs), matching: find.text(label));

MockClient _client(
  String Function() organizationType,
  bool Function() includeGenerationSource,
  bool Function() emptyQuestions,
  String? Function() videoProcessingStatus,
  Future<http.Response>? Function() seatLookupResponse,
  List<http.Request> writes,
) {
  return MockClient((request) async {
    if (request.method != 'GET') {
      writes.add(request);
      return http.Response('', 204);
    }
    final endpoint = request.url.path.replaceFirst(ApiEndPoints.version, '');
    final Object response;
    if (endpoint == ApiEndPoints.organizations) {
      response = [
        {'uuid': 'org-id', 'name': 'Organisation', 'type': organizationType()},
      ];
    } else if (endpoint == ApiEndPoints.trainingModulesAll) {
      response = {
        'results': [
          {
            ...lessonListingJson(id: 'lesson', descriptionId: 'description'),
            'title': 'Lesson from LMS',
            'thumbnail_link': null,
            'job': {'uuid': 'child-seat', 'title': 'Seat'},
          },
        ],
      };
    } else if (endpoint == ApiEndPoints.seatProfileJob('child-seat')) {
      final pendingSeat = seatLookupResponse();
      if (pendingSeat != null) return pendingSeat;
      response = {'uuid': 'child-seat', 'actual_id': 'seat'};
    } else if (endpoint == ApiEndPoints.lmsPublicLink('description')) {
      response = <String, Object>{};
    } else if (endpoint ==
        ApiEndPoints.seatDescriptionTrainingModules('description')) {
      response = [
        {'uuid': 'lesson', 'title': 'Lesson'},
      ];
    } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
      response = {
        'uuid': 'lesson',
        'title': 'Lesson',
        if (includeGenerationSource()) 'description': 'Lesson summary',
        if (includeGenerationSource())
          'training_video': {
            'uuid': 'video',
            'url': 'http://[',
            'transcript': 'Follow these steps.',
          },
      };
    } else if (endpoint == ApiEndPoints.latestBackgroundJob) {
      final status = videoProcessingStatus();
      response = {
        'job': status != null
            ? {
                'uuid': 'video-job',
                'status': status,
                'can_retry': false,
                'error_message': status == 'failed'
                    ? _nonRetryableVideoMessage
                    : '',
              }
            : null,
      };
    } else if (endpoint == ApiEndPoints.trainingModuleAssignment('lesson')) {
      response = {
        'uuid': 'assignment-1',
        'title': 'Assignment',
        'instructions': '<p>Assignment instructions</p>',
      };
    } else if (endpoint == ApiEndPoints.trainingModuleDocument('lesson')) {
      response = {'uuid': 'document', 'text': '<p>Procedure</p>'};
    } else if (endpoint == ApiEndPoints.trainingModuleQuestions('lesson')) {
      response = [
        if (!emptyQuestions())
          {
            'uuid': 'question-1',
            'question': 'Training question?',
            'options': [
              {'uuid': 'option-1', 'text': 'Answer'},
            ],
          },
      ];
    } else {
      throw StateError('Unexpected API request: $endpoint');
    }
    return http.Response(
      jsonEncode(response),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

const _nonRetryableVideoMessage = 'The audio could not be transcribed.';
