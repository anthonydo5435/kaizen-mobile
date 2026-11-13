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
import 'package:sparrowkaizen/features/compliance/domain/entities/compliance_track_item_detail.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/compliance_video_screen.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_video_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

const _transcript = '[00:00] First second\nthird fourth\n[00:05] Next caption';

void main() {
  for (final isEditor in [false, true]) {
    testWidgets(
      '${isEditor ? 'Edit Training' : 'LTC'} reveals active captions word by word',
      (tester) async {
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

        final client = MockClient(_lessonResponse);
        addTearDown(client.close);
        await http.runWithClient(() async {
          await tester.pumpWidget(
            ChangeNotifierProvider<AppManager>.value(
              value: AppManager.instance,
              child: MaterialApp(
                home: isEditor
                    ? const EditTrainingScreen(
                        trainingRoute: SeatDescriptionTrainingRoute(
                          job: 'seat',
                          category: 'category',
                          description: 'description',
                        ),
                        canManageTraining: true,
                      )
                    : const Scaffold(
                        body: ComplianceVideoScreen(detail: _detail),
                      ),
              ),
            ),
          );
          if (isEditor) {
            await tester.pumpAndSettle();
          } else {
            await tester.pump();
          }
          final controller = tester
              .element(find.text(AppStrings.trainingCc))
              .read<ComplianceVideoController>();
          controller.updatePlaybackPosition(Duration.zero);
          await tester.pump();
          expect(_captionText('First'), findsOneWidget);
          expect(_captionText('First second\nthird fourth'), findsNothing);

          await tester.pump(const Duration(seconds: 2));
          expect(_captionText('First'), findsOneWidget);
          controller.updatePlaybackPosition(const Duration(milliseconds: 1249));
          await tester.pump();
          expect(_captionText('First'), findsOneWidget);
          controller.updatePlaybackPosition(const Duration(milliseconds: 1250));
          await tester.pump();
          expect(_captionText('First second'), findsOneWidget);
          controller.updatePlaybackPosition(const Duration(milliseconds: 2500));
          await tester.pump();
          expect(_captionText('First second\nthird'), findsOneWidget);
          controller.updatePlaybackPosition(const Duration(milliseconds: 3750));
          await tester.pump();
          expect(_captionText('First second\nthird fourth'), findsOneWidget);

          controller.updatePlaybackPosition(const Duration(seconds: 5));
          await tester.pump();
          expect(_captionText('Next'), findsOneWidget);
          expect(_captionText('First second\nthird fourth'), findsNothing);

          await tester.tap(find.text(AppStrings.trainingViewTranscript));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text('First second\nthird fourth'),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }

  testWidgets('reduced motion renders complete captions immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(body: ComplianceVideoScreen(detail: _detail)),
        ),
      ),
    );
    tester
        .element(find.text(AppStrings.trainingCc))
        .read<ComplianceVideoController>()
        .updatePlaybackPosition(Duration.zero);
    await tester.pump();
    expect(_captionText('First second\nthird fourth'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Finder _captionText(String text) => find.descendant(
  of: find.byKey(const ValueKey('active-video-caption')),
  matching: find.text(text),
);

const _detail = ComplianceTrackItemDetail(
  uuid: 'item',
  position: 0,
  trainingModuleUuid: 'lesson',
  title: 'Lesson',
  quizStatus: '',
  videoUrl: null,
  videoDuration: 60,
  videoTranscript: _transcript,
  videoThumbnailLink: null,
  trainingDocument: null,
  quizCompletionPercentage: 0,
);

Future<http.Response> _lessonResponse(http.Request request) async {
  expect(request.method, 'GET');
  final endpoint = request.url.path.replaceFirst(ApiEndPoints.version, '');
  final Object response;
  if (endpoint == ApiEndPoints.seatDescriptionTrainingModules('description')) {
    response = [
      {'uuid': 'lesson', 'title': 'Lesson'},
    ];
  } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
    response = {
      'uuid': 'lesson',
      'title': 'Lesson',
      'description': 'Summary',
      'training_video': {
        'uuid': 'video',
        'url': 'http://[',
        'duration': 60,
        'transcript': _transcript,
      },
    };
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
}
