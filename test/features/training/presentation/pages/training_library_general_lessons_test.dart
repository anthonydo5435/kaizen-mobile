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
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_listing_search_bar.dart';
import 'package:sparrowkaizen/core/widgets/app_listing_tabs.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/setup_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/training_library_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_module_card.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import '../../fixtures/tiptap_sop_fixture.dart';
import '../../fixtures/training_library_fixtures.dart';

void main() {
  testWidgets(
    'General Lessons creates and reopens a lesson without seat setup',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await AppPreference.init();
      final appManager = AppManager.instance;
      appManager.resetSessionState();
      appManager.updateCurrentUser(
        User(uuid: 'owner', isOwner: true, organizationUuid: 'org-id'),
      );
      appManager.saveBillingDetails(
        CompanyBillingDetails.fromApiJson({'can_use_paid_features': true}),
      );
      appManager.dismissBillingBanner();
      addTearDown(appManager.resetSessionState);

      const seatLessonTitle = 'Seat-specific lesson';
      const generalLessonId = 'general-lesson';
      const generalLessonTitle = 'Welcome to the team';
      final requests = <http.Request>[];
      final generalLesson = {
        'uuid': generalLessonId,
        'module_type': 'general',
        'title': generalLessonTitle,
        'job': null,
        'category': null,
        'description': null,
        'duration': null,
      };
      var created = false;

      final client = MockClient((request) async {
        requests.add(request);
        final endpoint = request.url.path.replaceFirst(
          ApiEndPoints.version,
          '',
        );
        final Object? payload;
        if (endpoint == ApiEndPoints.trainingModulesAll) {
          final query = request.url.queryParameters;
          payload = switch (query['module_type']) {
            'job_based' => {
              'results': [
                {
                  ...lessonListingJson(),
                  'title': seatLessonTitle,
                  'thumbnail_link': null,
                },
              ],
            },
            'general' when !query.containsKey('searchType') => {
              'results': [if (created) generalLesson],
            },
            _ => throw StateError('Missing module type'),
          };
        } else if (endpoint == ApiEndPoints.seatProfileCategoryTrainings) {
          payload = [];
        } else if (endpoint == ApiEndPoints.trainingModules &&
            request.method == 'POST') {
          created = true;
          payload = generalLesson;
        } else if (endpoint ==
            ApiEndPoints.trainingModuleDetail(generalLessonId)) {
          payload = generalLesson;
        } else if (endpoint ==
            ApiEndPoints.trainingModuleQuestions(generalLessonId)) {
          payload = [];
        } else if (endpoint ==
                ApiEndPoints.trainingModuleDocument(generalLessonId) ||
            endpoint ==
                ApiEndPoints.trainingModuleAssignment(generalLessonId)) {
          payload = {};
        } else {
          throw StateError('Unexpected request ${request.method} $endpoint');
        }

        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.close);

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppManager>.value(value: appManager),
              Provider<TrainingSopEditorFactory>.value(
                value: TiptapSopFixture().create,
              ),
            ],
            child: const MaterialApp(
              home: TrainingLibraryScreen(),
              onGenerateRoute: AppRouter.onGenerateRoute,
            ),
          ),
        );
        await tester.pumpAndSettle();
        String selectedListingTab() => tester
            .widget<AppListingTabs>(find.byType(AppListingTabs))
            .tabs
            .singleWhere((tab) => tab.isSelected)
            .title;

        expect(selectedListingTab(), AppStrings.trainingLibrarySeatLessons);
        expect(find.text(seatLessonTitle), findsOneWidget);
        expect(
          find.byTooltip(AppStrings.trainingSetupSelectSeat),
          findsOneWidget,
        );

        await tester.tap(find.text(AppStrings.trainingLibraryGeneralLessons));
        await tester.pumpAndSettle();
        expect(selectedListingTab(), AppStrings.trainingLibraryGeneralLessons);
        expect(find.text(seatLessonTitle), findsNothing);
        expect(
          find.text(AppStrings.trainingLibraryNoGeneralLessons),
          findsOneWidget,
        );
        expect(find.byType(AppListingSearchBar), findsOneWidget);
        expect(
          find.byTooltip(AppStrings.trainingSetupSelectSeat),
          findsNothing,
        );

        await tester.tap(find.byTooltip(AppStrings.trainingLibraryCreate));
        await tester.pumpAndSettle();
        expect(find.byType(EditTrainingScreen), findsOneWidget);
        expect(find.byType(SetupTrainingScreen), findsNothing);
        expect(find.text(AppStrings.trainingSetupSelectCategory), findsNothing);
        expect(
          find.text(AppStrings.trainingSetupSelectDescription),
          findsNothing,
        );
        for (final tab in [
          AppStrings.trainingVideoTab,
          AppStrings.trainingSopTab,
          AppStrings.trainingQuizTab,
          AppStrings.trainingAssignmentTab,
        ]) {
          expect(find.text(tab), findsOneWidget);
        }
        expect(find.byTooltip(AppStrings.shareAction), findsNothing);

        await tester.enterText(
          find.widgetWithText(TextField, AppStrings.trainingLessonTitleHint),
          generalLessonTitle,
        );
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final post = requests.singleWhere(
          (request) => request.method == 'POST',
        );
        expect(jsonDecode(post.body), {
          'module_type': 'general',
          'title': generalLessonTitle,
        });

        for (final (tab, endpoint) in [
          (
            AppStrings.trainingSopTab,
            ApiEndPoints.trainingModuleDocument(generalLessonId),
          ),
          (
            AppStrings.trainingQuizTab,
            ApiEndPoints.trainingModuleQuestions(generalLessonId),
          ),
          (
            AppStrings.trainingAssignmentTab,
            ApiEndPoints.trainingModuleAssignment(generalLessonId),
          ),
        ]) {
          await tester.tap(find.bySemanticsLabel(tab));
          await tester.pumpAndSettle();
          expect(
            requests.any((request) => request.url.path.endsWith(endpoint)),
            isTrue,
          );
        }

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(generalLessonTitle), findsOneWidget);
        expect(find.text(seatLessonTitle), findsNothing);
        await tester.tap(
          find.descendant(
            of: find.byType(TrainingLibraryModuleCard),
            matching: find.byType(InkWell),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EditTrainingScreen), findsOneWidget);
        expect(find.text(generalLessonTitle), findsOneWidget);
        final editor = tester.widget<EditTrainingScreen>(
          find.byType(EditTrainingScreen),
        );
        expect(editor.trainingRoute.initialModuleId, generalLessonId);
        expect(editor.trainingRoute.isGeneral, isTrue);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.trainingLibrarySeatLessons));
        await tester.pumpAndSettle();
        expect(find.text(seatLessonTitle), findsOneWidget);
        expect(find.text(generalLessonTitle), findsNothing);
        await tester.tap(find.byTooltip(AppStrings.trainingLibraryCreate));
        await tester.pumpAndSettle();
        expect(find.byType(SetupTrainingScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
