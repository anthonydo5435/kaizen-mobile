import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user_hierarchy_membership.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/shared_lesson_details_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

import '../../fixtures/tiptap_sop_fixture.dart';

void main() {
  final writes = <http.Request>[];
  var activeOrganizationType = 'parent';
  // ApiCallExecutor retains its first HTTP client across widget tests.
  final client = _client(() => activeOrganizationType, writes);
  tearDownAll(client.close);
  for (final organizationType in ['parent', 'sandbox', 'child']) {
    for (final isOwner in [false, true]) {
      for (final hasSandboxAccess in [false, true]) {
        for (final managesSeat in [false, true]) {
          final canManage =
              (isOwner || managesSeat) && organizationType != 'child';
          final canAccessExtras =
              canManage || (hasSandboxAccess && (isOwner || managesSeat));
          for (final isViewer in [false, true]) {
            final canEdit = canManage && !isViewer;
            testWidgets(
              '$organizationType ${isViewer ? 'viewer' : 'editor'} respects '
              'sandbox access $hasSandboxAccess (owner: $isOwner, managed: $managesSeat) '
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
                      roles: const ['dept_lead'],
                      hierarchyMemberships: [
                        UserHierarchyMembership(
                          nodeUuid: 'node',
                          role: 'dept_lead',
                          manageableSeatProfileIds: managesSeat
                              ? const ['seat']
                              : const ['other-seat'],
                        ),
                      ],
                      organizationUuid: 'org-id',
                      hasSandboxAccess: hasSandboxAccess,
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
  List<http.Request> writes,
) {
  return MockClient((request) async {
    if (request.method != 'GET') {
      writes.add(request);
      return http.Response('', 204);
    }
    final endpoint = request.url.path
        .replaceFirst(ApiEndPoints.version, '')
        .replaceFirst(RegExp('^${ApiEndPoints.parentPrefix}'), '');
    final Object response;
    if (endpoint == ApiEndPoints.organizations) {
      response = [
        {'uuid': 'org-id', 'name': 'Organisation', 'type': organizationType()},
      ];
    } else if (endpoint == ApiEndPoints.lmsPublicLink('description')) {
      response = <String, Object>{};
    } else if (endpoint ==
        ApiEndPoints.seatDescriptionTrainingModules('description')) {
      response = [
        {'uuid': 'lesson', 'title': 'Lesson'},
      ];
    } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
      response = {'uuid': 'lesson', 'title': 'Lesson'};
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
