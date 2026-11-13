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
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

import '../../fixtures/tiptap_sop_fixture.dart';

void main() {
  testWidgets(
    'quiz source choices send lowercase payloads and reset to Both when reopened',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await AppPreference.init();
      ApiCallExecutor.clearGetCache();
      AppManager.instance.resetSessionState();
      AppManager.instance.updateCurrentUser(
        User(uuid: 'owner', isOwner: true, organizationUuid: 'org-id'),
      );
      addTearDown(AppManager.instance.resetSessionState);
      addTearDown(ApiCallExecutor.clearGetCache);

      final writes = <http.Request>[];
      final sopFixture = TiptapSopFixture();
      final client = MockClient((request) async {
        final endpoint = request.url.path.replaceFirst(
          ApiEndPoints.version,
          '',
        );
        if (request.method != 'GET') {
          writes.add(request);
          expect(request.method, 'PUT');
          expect(endpoint, ApiEndPoints.generateTrainingModuleQuiz('lesson'));
          return http.Response('{}', 200);
        }
        final Object response;
        if (endpoint ==
            ApiEndPoints.seatDescriptionTrainingModules('description')) {
          response = [
            {'uuid': 'lesson', 'title': 'Lesson'},
          ];
        } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
          response = {
            'uuid': 'lesson',
            'title': 'Lesson',
            'description': 'Lesson summary',
            'training_video': {
              'uuid': 'video',
              'url': 'http://[',
              'duration': 60,
              'transcript': 'Follow these steps.',
            },
          };
        } else if (endpoint == ApiEndPoints.trainingModuleDocument('lesson')) {
          response = {'uuid': 'document', 'text': '<p>Procedure</p>'};
        } else if (endpoint == ApiEndPoints.trainingModuleQuestions('lesson')) {
          response = [];
        } else if (endpoint == ApiEndPoints.lmsPublicLink('description')) {
          response = {'active': false};
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
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppManager>.value(
                value: AppManager.instance,
              ),
              Provider<TrainingSopEditorFactory>.value(
                value: sopFixture.create,
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const EditTrainingScreen(
                trainingRoute: SeatDescriptionTrainingRoute(
                  job: 'seat',
                  category: 'category',
                  description: 'description',
                ),
                canManageTraining: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(TrainingTabs),
            matching: find.text(AppStrings.trainingQuizTab),
          ),
        );
        await tester.pumpAndSettle();

        final choices = [
          (
            label: AppStrings.trainingVideoTab,
            source: QuizGenerationSource.video,
          ),
          (label: AppStrings.trainingSopTab, source: QuizGenerationSource.sop),
          (
            label: AppStrings.trainingQuizSourceBoth,
            source: QuizGenerationSource.both,
          ),
        ];
        for (final choice in choices) {
          final openSheet = find.text(AppStrings.trainingCreateWithAi);
          await tester.ensureVisible(openSheet);
          await tester.tap(openSheet);
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          expect(
            find.text(AppStrings.trainingQuizGenerateFrom),
            findsOneWidget,
          );
          final controller = tester
              .element(find.text(AppStrings.trainingQuizGenerateFrom))
              .read<TrainingModuleController>();
          expect(controller.quizGenerationSource, QuizGenerationSource.both);
          final source = find.descendant(
            of: sheet,
            matching: find.text(choice.label),
          );
          await tester.ensureVisible(source);
          await tester.tap(source);
          await tester.pump();
          expect(controller.quizGenerationSource, choice.source);

          final replace = find.descendant(
            of: sheet,
            matching: find.byType(Switch),
          );
          await tester.ensureVisible(replace);
          if (choice.source == QuizGenerationSource.sop) {
            await tester.tap(replace);
            await tester.pump();
          }
          final generate = find.descendant(
            of: sheet,
            matching: find.text(AppStrings.trainingQuizGenerateWithAi),
          );
          expect(
            tester.getBottomLeft(replace).dy,
            lessThan(tester.getTopLeft(generate).dy),
          );
          await tester.tap(generate);
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          expect(jsonDecode(writes.last.body), {
            'num_questions': 3,
            'options_per_question': 4,
            'difficulty_level': 'medium',
            'replace_existing_questions':
                choice.source != QuizGenerationSource.sop,
            'source': choice.source.apiValue,
          });
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
        }
        expect(writes, hasLength(3));
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}
