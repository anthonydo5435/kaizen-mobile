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
import 'package:sparrowkaizen/core/widgets/app_overlay_close_button.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/training_library_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_module_card.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_share_action.dart';

import '../../fixtures/training_library_fixtures.dart';

void main() {
  testWidgets('LMS listing opens a lesson with a working top-bar Share action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'owner', isOwner: true, organizationUuid: 'org-id'),
    );
    addTearDown(AppManager.instance.resetSessionState);
    final requests = <http.Request>[];
    Map<String, dynamic>? existingLink;
    final client = MockClient((request) async {
      requests.add(request);
      final endpoint = request.url.path.replaceFirst(ApiEndPoints.version, '');
      final Object response;
      if (endpoint == ApiEndPoints.trainingModulesAll) {
        response = {
          'results': [
            {
              ...lessonListingJson(
                id: 'lesson-1',
                descriptionId: 'description-id',
              ),
              'title': 'Listing lesson',
              'thumbnail_link': null,
            },
          ],
        };
      } else if (endpoint ==
          ApiEndPoints.seatDescriptionTrainingModules('description-id')) {
        response = List.generate(
          3,
          (index) => {
            'uuid': 'lesson-$index',
            'title': 'Lesson $index',
            'actual_id': 'parent-$index',
            'is_publicly_available': false,
          },
        );
      } else if ([0, 1, 2].any(
        (index) =>
            endpoint == ApiEndPoints.trainingModuleDetail('lesson-$index'),
      )) {
        final lessonId = request.url.path
            .split('/')
            .where((part) => part.isNotEmpty)
            .last;
        response = {
          'uuid': lessonId,
          'title': lessonId == 'lesson-1'
              ? 'Opened lesson'
              : 'Lesson ${lessonId.split('-').last}',
        };
      } else if (endpoint == ApiEndPoints.lmsPublicLink('description-id')) {
        if (request.method == 'GET') {
          response = existingLink ?? {'active': false};
        } else if (request.method == 'DELETE') {
          existingLink = null;
          return http.Response('', 204);
        } else {
          existingLink = {
            'active': true,
            'view_type': 'lms',
            'public_path': '/shared/lms/generated-id',
            'training_module_uuids':
                (jsonDecode(request.body) as Map)['training_module_uuids'],
          };
          response = existingLink!;
        }
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
          child: const MaterialApp(home: TrainingLibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Listing lesson'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(TrainingLibraryModuleCard),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditTrainingScreen), findsOneWidget);
      expect(find.text('Opened lesson'), findsWidgets);
      expect(
        requests.where(
          (request) =>
              request.method == 'GET' &&
              request.url.path.endsWith('/public-links/lms/'),
        ),
        hasLength(1),
      );
      expect(find.byTooltip(AppStrings.shareAction), findsOneWidget);
      expect(find.text(AppStrings.shareAction), findsNothing);
      final trainingController = tester
          .element(find.byType(TrainingShareAction))
          .read<TrainingModuleController>();
      final allLessons = find.byTooltip(AppStrings.trainingAllLessons);
      final newLesson = find.byTooltip(AppStrings.trainingNewLesson);
      expect(
        tester.getTopLeft(allLessons).dx,
        lessThan(tester.getTopLeft(newLesson).dx),
      );
      expect(
        tester.getTopLeft(find.byIcon(Icons.share_outlined)).dx,
        greaterThan(
          tester.getTopRight(find.text(AppStrings.training).first).dx,
        ),
      );
      await tester.tap(allLessons);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.trainingAllLessons), findsOneWidget);
      final addNewLesson = find.text(AppStrings.trainingAddNewLesson);
      expect(addNewLesson, findsOneWidget);
      expect(
        tester.getTopLeft(addNewLesson).dy,
        lessThan(tester.getTopLeft(find.text('Lesson 0')).dy),
      );
      await tester.tap(addNewLesson);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.trainingAllLessons), findsNothing);
      expect(trainingController.isCreatingNewLessonDraft, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(trainingController.isCreatingNewLessonDraft, isFalse);
      expect(trainingController.selectedModuleId, 'lesson-1');

      await tester.tap(allLessons);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lesson 2'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.trainingAllLessons), findsNothing);
      expect(find.text('Lesson 2'), findsOneWidget);

      await tester.tap(newLesson);
      await tester.pumpAndSettle();
      expect(trainingController.isCreatingNewLessonDraft, isTrue);
      expect(find.byType(TextField), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(trainingController.isCreatingNewLessonDraft, isFalse);
      expect(trainingController.selectedModuleId, 'lesson-2');

      await tester.tap(find.byTooltip(AppStrings.shareAction));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 selected'), findsOneWidget);
      await tester.tap(find.text('Lesson 0'));
      await tester.pump();
      await tester.tap(find.text(AppStrings.shareCreateLinkAction));
      await tester.pumpAndSettle();
      final creation = requests.singleWhere(
        (request) => request.method == 'POST',
      );
      expect(
        creation.url.path,
        '${ApiEndPoints.version}job_category_description/description-id/public-links/lms/',
      );
      expect(jsonDecode(creation.body), {
        'view_type': 'lms',
        'public_path': '',
        'training_module_uuids': ['lesson-1', 'lesson-2'],
      });
      expect(
        find.text('${ApiEndPoints.publicWebBaseUrl}/shared/lms/generated-id'),
        findsOneWidget,
      );
      expect(find.text(AppStrings.sharePublicLinkTitle), findsOneWidget);
      await tester.tap(find.byType(AppOverlayCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AppStrings.shareAction));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.sharePublicLinkTitle), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(
        requests.where(
          (request) => request.url.path.endsWith(
            ApiEndPoints.seatDescriptionTrainingModules('description-id'),
          ),
        ),
        hasLength(1),
      );
      await tester.tap(find.byType(AppOverlayCloseButton));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(EditTrainingScreen))).pop();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(TrainingLibraryModuleCard),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        requests.where(
          (request) =>
              request.method == 'GET' &&
              request.url.path.endsWith('/public-links/lms/'),
        ),
        hasLength(2),
      );
      await tester.tap(find.byTooltip(AppStrings.shareAction));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.sharePublicLinkTitle), findsOneWidget);
      expect(
        find.text('${ApiEndPoints.publicWebBaseUrl}/shared/lms/generated-id'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text(AppStrings.shareCreateLinkAction), findsNothing);
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      await tester.tap(find.text(AppStrings.shareRevokeLinkAction));
      await tester.pumpAndSettle();
      final deletion = requests.singleWhere(
        (request) => request.method == 'DELETE',
      );
      expect(
        deletion.url.path,
        '${ApiEndPoints.version}job_category_description/description-id/public-links/lms/',
      );
      expect(deletion.body, isEmpty);
      expect(find.text(AppStrings.shareCreateLinkAction), findsOneWidget);
      expect(find.text('3 of 3 selected'), findsOneWidget);
      expect(
        find.text('${ApiEndPoints.publicWebBaseUrl}/shared/lms/generated-id'),
        findsNothing,
      );
      await tester.tap(find.text(AppStrings.shareCreateLinkAction));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.shareRevokeLinkAction), findsOneWidget);
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
