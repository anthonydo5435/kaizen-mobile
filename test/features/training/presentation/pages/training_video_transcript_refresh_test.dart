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
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_video_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

void main() {
  testWidgets(
    'a replacement transcript updates the first open sheet without reopening Edit Training',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await AppPreference.init();
      AppManager.instance.resetSessionState();
      AppManager.instance.updateCurrentUser(
        User(uuid: 'owner', isOwner: true, organizationUuid: 'org-id'),
      );
      addTearDown(AppManager.instance.resetSessionState);

      var detailRequests = 0;
      final refresh = Completer<http.Response>();
      final client = MockClient((request) async {
        expectSync(request.method, 'GET');
        final endpoint = request.url.path.replaceFirst(
          ApiEndPoints.version,
          '',
        );
        final Object response;
        if (endpoint ==
            ApiEndPoints.seatDescriptionTrainingModules('description')) {
          response = [
            {'uuid': 'lesson', 'title': 'Lesson'},
          ];
        } else if (endpoint == ApiEndPoints.lmsPublicLink('description')) {
          response = {'active': false};
        } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
          detailRequests++;
          if (detailRequests > 1) return refresh.future;
          response = _detail('old-video', '[00:00] Old transcript');
        } else {
          throw StateError('Unexpected request: $endpoint');
        }
        return _response(response);
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
        await tester.pumpAndSettle();
        final module = tester
            .element(find.text(AppStrings.trainingViewTranscript))
            .read<TrainingModuleController>();
        module.applyBackgroundUploadedVideo(
          moduleId: 'lesson',
          video: const SeatDescriptionTrainingVideo(
            uuid: 'uploaded-video',
            title: 'Video',
            url: 'http://[',
            duration: 60,
            transcript: null,
          ),
          localVideoPath: '',
        );
        await tester.pumpAndSettle();
        expect(detailRequests, 2);
        final captions = tester
            .element(find.text(AppStrings.trainingViewTranscript))
            .read<ComplianceVideoController>();
        captions.updatePlaybackPosition(const Duration(seconds: 1));
        await tester.tap(find.text(AppStrings.trainingViewTranscript));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.trainingNoTranscriptAvailable),
          findsOneWidget,
        );

        refresh.complete(
          _response(
            _detail(
              'uploaded-video',
              '[00:00] New transcript\n[00:05] Next cue',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          find.text(AppStrings.trainingNoTranscriptAvailable),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('New transcript'),
          ),
          findsOneWidget,
        );
        expect(captions.transcriptLines.first.text, 'New transcript');
        expect(captions.activeTranscriptIndex, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}

Map<String, Object?> _detail(String videoId, String? transcript) => {
  'uuid': 'lesson',
  'title': 'Lesson',
  'description': 'Summary',
  'training_video': {
    'uuid': videoId,
    'url': 'http://[',
    'duration': 60,
    'transcript': transcript,
  },
};

http.Response _response(Object json) => http.Response(
  jsonEncode(json),
  200,
  headers: {'content-type': 'application/json'},
);
