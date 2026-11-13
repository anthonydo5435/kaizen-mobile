import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_media_comment_video_controller.dart';
import 'package:video_player/video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('token');
  });

  test(
    'only API-host videos receive the auth header and fullscreen uses the initialized player',
    () async {
      final headers = <Map<String, String>>[];
      final released = <VideoPlayerController>[];
      final first = _Player();
      final second = _Player();
      final controller = CheckInMediaCommentVideoController(
        '${ApiEndPoints.baseUrl}/media/first.mp4',
        acquireController: (url, requestHeaders) async {
          headers.add(requestHeaders);
          return headers.length == 1 ? first : second;
        },
        releaseController: (player) async => released.add(player),
      );
      await controller.initializeFuture;
      expect(headers.first, {'Authorization': 'Bearer token'});
      expect(controller.readyPlayer, same(first));
      controller.updateMediaUrl('https://media.example/second.mp4');
      await controller.initializeFuture;
      expect(headers.last, isEmpty);
      expect(released, [first]);
      expect(controller.readyPlayer, same(second));
      controller.dispose();
      expect(released, [first, second]);
    },
  );

  test(
    'a late initialized video is released after the selected media changes',
    () async {
      final pending = Completer<VideoPlayerController?>();
      final oldPlayer = _Player();
      final currentPlayer = _Player();
      final released = <VideoPlayerController>[];
      final controller = CheckInMediaCommentVideoController(
        'https://media.example/first.mp4',
        acquireController: (url, _) async =>
            url.endsWith('first.mp4') ? pending.future : currentPlayer,
        releaseController: (player) async => released.add(player),
      );
      final oldInitialization = controller.initializeFuture;
      controller.updateMediaUrl('https://media.example/second.mp4');
      await controller.initializeFuture;
      pending.complete(oldPlayer);
      await oldInitialization;
      expect(controller.readyPlayer, same(currentPlayer));
      expect(released, [oldPlayer]);
      controller.dispose();
    },
  );

  test(
    'disposing during initialization releases the late player without notifying the UI',
    () async {
      final pending = Completer<VideoPlayerController?>();
      final player = _Player();
      final released = <VideoPlayerController>[];
      final controller = CheckInMediaCommentVideoController(
        'https://media.example/first.mp4',
        acquireController: (_, __) => pending.future,
        releaseController: (player) async => released.add(player),
      );
      var notified = false;
      controller.addListener(() => notified = true);
      final initialization = controller.initializeFuture;
      controller.dispose();
      pending.complete(player);
      await initialization;
      expect(notified, isFalse);
      expect(released, [player]);
    },
  );
}

class _Player extends Fake implements VideoPlayerController {
  @override
  VideoPlayerValue get value => const VideoPlayerValue(
    duration: Duration(minutes: 1),
    isInitialized: true,
  );
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> setVolume(double volume) async {}
}
