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
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_ai_generate_button.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

void main() {
  for (final canManageTraining in [true, false]) {
    testWidgets(
      'Video Summary Generate uses PUT and preserves edit permissions: $canManageTraining',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        await AppPreference.init();
        AppManager.instance.resetSessionState();
        AppManager.instance.updateCurrentUser(
          User(
            uuid: 'user',
            isOwner: canManageTraining,
            organizationUuid: 'org-id',
            roles: const ['team_member'],
          ),
        );
        addTearDown(AppManager.instance.resetSessionState);

        final writes = <http.Request>[];
        final generationResponse = Completer<http.Response>();
        final client = MockClient((request) async {
          final endpoint = request.url.path.replaceFirst(
            ApiEndPoints.version,
            '',
          );
          if (request.method != 'GET') {
            writes.add(request);
            expect(request.method, 'PUT');
            expect(endpoint, 'training_modules/lesson/generate_summary/');
            return generationResponse.future;
          }
          final Object response;
          if (endpoint ==
              ApiEndPoints.seatDescriptionTrainingModules('description')) {
            response = [
              {
                'uuid': 'lesson',
                'actual_id': 'parent-lesson',
                'title': 'Lesson',
              },
            ];
          } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
            response = {
              'uuid': 'lesson',
              'actual_id': 'parent-lesson',
              'title': 'Lesson',
              'description': 'Original summary',
              'training_video': {
                'uuid': 'video',
                'url': 'http://[',
                'duration': 60,
              },
            };
          } else if (endpoint == ApiEndPoints.lmsPublicLink('description')) {
            response = {'active': false};
          } else if (endpoint ==
              ApiEndPoints.trainingModuleDocument('lesson')) {
            response = {'uuid': 'document', 'text': '<p>Procedure</p>'};
          } else {
            throw StateError('Unexpected API request: $endpoint');
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        addTearDown(client.close);

        await http.runWithClient(() async {
          await tester.pumpWidget(
            ChangeNotifierProvider<AppManager>.value(
              value: AppManager.instance,
              child: MaterialApp(
                home: EditTrainingScreen(
                  trainingRoute: const SeatDescriptionTrainingRoute(
                    job: 'seat',
                    category: 'category',
                    description: 'description',
                  ),
                  canManageTraining: canManageTraining,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(AppStrings.trainingSummaryLabel), findsOneWidget);
          final generate = find.byWidgetPredicate(
            (widget) =>
                widget is AppAiGenerateButton &&
                widget.label == AppStrings.trainingGenerateSummaryAction,
          );
          if (canManageTraining) {
            expect(generate, findsOneWidget);
            final editor = find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.hintText == AppStrings.trainingSummaryHint,
            );
            final summaryController = tester
                .widget<TextField>(editor)
                .controller!;
            final summaryField = find.byWidgetPredicate(
              (widget) =>
                  widget is TextField && widget.controller == summaryController,
            );
            final summaryBlock = find
                .ancestor(
                  of: summaryField,
                  matching: find.byType(AbsorbPointer),
                )
                .first;
            final inBlockLoader = find.descendant(
              of: summaryBlock,
              matching: find.byType(FastCircularProgressIndicator),
            );
            await tester.ensureVisible(generate);
            final initialSize = tester.getSize(generate);
            expect(
              tester.getCenter(generate).dx,
              greaterThan(
                tester.getCenter(find.text(AppStrings.trainingSummaryLabel)).dx,
              ),
            );
            await tester.tap(generate);
            await tester.pump();
            expect(writes, hasLength(1));
            expect(
              tester.widget<AppAiGenerateButton>(generate).isLoading,
              isTrue,
            );
            expect(tester.getSize(generate), initialSize);
            final button = find.descendant(
              of: generate,
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton,
              ),
            );
            expect(tester.widget<TextButton>(button).onPressed, isNull);
            expect(inBlockLoader, findsNothing);
            expect(tester.widget<TextField>(summaryField).readOnly, isTrue);

            generationResponse.complete(
              http.Response(
                jsonEncode({
                  'description': 'In this video, the speaker discusses',
                }),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
            await tester.pump();
            expect(inBlockLoader, findsNothing);
            expect(summaryController.text, isEmpty);
            await tester.pump(const Duration(milliseconds: 120));
            expect(summaryController.text, 'In th');
            expect(
              tester.widget<AppAiGenerateButton>(generate).isLoading,
              isTrue,
            );
            await tester.pumpAndSettle();
            expect(
              summaryController.text,
              'In this video, the speaker discusses',
            );
            expect(
              tester.widget<AppAiGenerateButton>(generate).isLoading,
              isFalse,
            );
            expect(tester.getSize(generate), initialSize);
            expect(find.byType(SnackBar), findsNothing);
            final controller = tester
                .element(generate)
                .read<TrainingModuleController>();
            controller.applyGeneratedSummaryForModule(
              moduleId: 'lesson',
              description: null,
            );
            await tester.pump();
            expect(
              tester.widget<AppAiGenerateButton>(generate).isEnabled,
              isFalse,
            );
            expect(tester.widget<TextButton>(button).onPressed, isNull);
            await tester.tap(generate);
            await tester.pump();
          } else {
            expect(generate, findsNothing);
            expect(find.text('Original summary'), findsOneWidget);
          }
          expect(writes, hasLength(canManageTraining ? 1 : 0));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }
}
