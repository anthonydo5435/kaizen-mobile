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
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

void main() {
  testWidgets('uploaded video polls processing and retries using the job ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.saveBillingDetails(
      CompanyBillingDetails.fromApiJson({'can_use_paid_features': true}),
    );
    AppManager.instance.updateCurrentUser(User(uuid: 'owner', isOwner: true));
    addTearDown(AppManager.instance.resetSessionState);

    final latestRequests = <http.Request>[];
    final writes = <http.Request>[];
    final initialJobResponse = Completer<http.Response>();
    final retryResponse = Completer<http.Response>();
    String? status;
    var detailRequests = 0;
    const videoId = 'uploaded-video';
    const jobId = 'video-processing-job';
    const processingError = 'The audio could not be transcribed.';
    Map<String, Object?> job(String status) => {
      'uuid': jobId,
      'operation': 'lms.video_processing',
      'status': status,
      'can_retry': status == 'failed',
      'error_message': status == 'failed' ? processingError : '',
    };

    final client = MockClient((request) async {
      final endpoint = request.url.path.replaceFirst(ApiEndPoints.version, '');
      final Object response;
      if (request.method == 'PATCH' &&
          endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
        writes.add(request);
        return http.Response('', 204);
      } else if (request.method != 'GET') {
        writes.add(request);
        if (request.method != 'POST' ||
            endpoint != 'background_jobs/$jobId/retry/') {
          throw StateError('Unexpected ${request.method} request: $endpoint');
        }
        return retryResponse.future;
      } else if (endpoint == ApiEndPoints.latestBackgroundJob) {
        if (request.url.queryParameters['resource_uuid'] == 'original-video') {
          return initialJobResponse.future;
        }
        latestRequests.add(request);
        response = {'job': status == null ? null : job(status!)};
      } else if (endpoint ==
          ApiEndPoints.seatDescriptionTrainingModules('description')) {
        response = [
          {'uuid': 'lesson', 'title': 'Lesson'},
        ];
      } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
        detailRequests++;
        response = {
          'uuid': 'lesson',
          'title': 'Lesson',
          'description': status == 'completed'
              ? 'Processed summary'
              : 'Original summary',
          'training_video': {
            'uuid': status == 'completed' ? videoId : 'original-video',
            'url': 'http://[',
            'duration': 60,
            if (status == 'completed')
              'transcript': '[00:00] Processed transcript',
          },
        };
      } else if (endpoint == ApiEndPoints.lmsPublicLink('description')) {
        response = {'active': false};
      } else if (endpoint == ApiEndPoints.trainingModuleDocument('lesson')) {
        response = {'uuid': 'document', 'text': '<p>Procedure</p>'};
      } else {
        throw StateError('Unexpected API request: $endpoint');
      }
      return http.Response(jsonEncode(response), 200);
    });
    addTearDown(client.close);

    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppManager>.value(
          value: AppManager.instance,
          child: const MaterialApp(
            home: EditTrainingScreen(
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
      await tester.pump();
      await tester.pump();

      final loadingSummary = find.byKey(
        const ValueKey('training-summary-loading'),
      );
      final summaryCard = find.byKey(const ValueKey('training-summary-card'));
      final heading = find.text(AppStrings.trainingSummaryLabel);
      expect(
        tester.widget(loadingSummary),
        isA<FastCircularProgressIndicator>(),
      );
      expect(tester.getCenter(loadingSummary).dx, closeTo(195, 0.01));
      expect(
        tester.getTopLeft(loadingSummary).dy,
        greaterThan(
          tester.getBottomLeft(find.text(AppStrings.trainingViewTranscript)).dy,
        ),
      );
      expect(heading, findsNothing);
      initialJobResponse.complete(http.Response('{"job":null}', 200));
      await tester.pumpAndSettle();
      expect(loadingSummary, findsNothing);
      expect(heading, findsOneWidget);
      expect(find.text('Original summary'), findsOneWidget);
      expect(tester.getTopLeft(summaryCard).dx, 4);
      expect(tester.getTopRight(summaryCard).dx, 386);

      final controller = tester
          .element(find.byType(Scaffold).last)
          .read<TrainingModuleController>();
      controller.applyBackgroundUploadedVideo(
        moduleId: 'lesson',
        video: const SeatDescriptionTrainingVideo(
          uuid: videoId,
          title: 'Video',
          url: 'http://[',
          duration: 60,
          transcript: null,
        ),
        localVideoPath: '',
      );
      await tester.pump();

      final retry = find.text(AppStrings.trainingRetrySummaryGenerationAction);
      final progress = find.text(AppStrings.trainingGeneratingSummary);
      expect(heading, findsNothing);
      expect(progress, findsNothing);
      expect(loadingSummary, findsNothing);
      expect(latestRequests, hasLength(1));
      expect(writes, isEmpty);

      status = 'pending';
      await tester.pump(const Duration(seconds: 2));
      expect(latestRequests, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(latestRequests, hasLength(2));
      expect(heading, findsNothing);
      expect(progress, findsNothing);
      expect(loadingSummary, findsNothing);

      status = 'failed';
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(latestRequests, hasLength(3));
      expect(heading, findsOneWidget);
      expect(find.text(processingError), findsOneWidget);
      final description = find.text(AppStrings.trainingSummaryDescription);
      expect(description, findsOneWidget);
      expect(retry, findsOneWidget);
      expect(
        tester.getTopLeft(description).dy,
        greaterThan(tester.getBottomLeft(retry).dy),
      );
      tester.view.physicalSize = const Size(820, 1180);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(summaryCard).dx, 4);
      expect(tester.getTopRight(summaryCard).dx, 816);
      expect(
        tester.getTopRight(description).dx,
        lessThan(tester.getTopLeft(retry).dx),
      );
      expect(
        tester.getCenter(retry).dy,
        lessThan(tester.getBottomLeft(description).dy),
      );
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == AppStrings.trainingSummaryHint,
      );
      expect(tester.widget<TextField>(field).maxLength, 1000);
      final editable = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      final outline = InputDecorator.containerOf(tester.element(editable))!;
      final outlineRect = outline.localToGlobal(Offset.zero) & outline.size;
      final counterRect = tester.getRect(find.text('0/1000'));
      expect(outlineRect.contains(counterRect.topLeft), isTrue);
      expect(outlineRect.contains(counterRect.bottomRight), isTrue);
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pump();
      final summaryEditor = tester.widget<EditableText>(editable);
      expect(summaryEditor.focusNode.hasFocus, isTrue);
      expect(summaryEditor.showCursor, isTrue);
      expect(summaryEditor.controller.selection.baseOffset, 0);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(field, 'Manual summary');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('14/1000'), findsOneWidget);
      expect(writes.single.method, 'PATCH');
      expect(jsonDecode(writes.single.body), {'description': 'Manual summary'});

      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(writes, hasLength(2));
      expect(retry, findsNothing);
      expect(heading, findsNothing);
      expect(field, findsNothing);
      expect(progress, findsOneWidget);
      expect(
        find.text(AppStrings.trainingGeneratingSummaryDescription),
        findsOneWidget,
      );
      final loader = find.byWidgetPredicate(
        (widget) =>
            widget is FastCircularProgressIndicator && widget.width == 26,
      );
      expect(tester.getCenter(loader).dx, tester.getCenter(progress).dx);

      status = 'pending';
      retryResponse.complete(http.Response(jsonEncode(job(status!)), 200));
      await tester.pump();
      expect(progress, findsOneWidget);

      status = 'in_progress';
      await tester.pump(const Duration(seconds: 3));
      expect(latestRequests, hasLength(4));
      expect(heading, findsNothing);
      expect(progress, findsOneWidget);
      expect(detailRequests, 1);

      status = 'completed';
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(latestRequests, hasLength(5));
      expect(detailRequests, 2);
      expect(heading, findsOneWidget);
      expect(find.text('Processed summary'), findsOneWidget);
      expect(controller.hasSelectedModuleVideoTranscript, isTrue);
      expect(progress, findsNothing);
      expect(retry, findsNothing);
      await tester.pump(const Duration(seconds: 9));
      expect(latestRequests, hasLength(5));
      for (final request in latestRequests) {
        expect(request.url.queryParameters, {
          'resource_type': 'training_video',
          'resource_uuid': videoId,
          'operation': 'lms.video_processing',
        });
      }
      expect(writes, hasLength(2));
      expect(writes.last.method, 'POST');
      expect(writes.last.url.path, '/api/v1/background_jobs/$jobId/retry/');
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
