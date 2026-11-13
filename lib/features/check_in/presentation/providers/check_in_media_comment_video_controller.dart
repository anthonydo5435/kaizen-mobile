import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/services/video_playback_service.dart';
import '../../../../core/utils/custom_functions.dart';

/// Retains the sheet's initialized player when entering fullscreen.
class CheckInMediaCommentVideoController extends ChangeNotifier {
  CheckInMediaCommentVideoController(
    String mediaUrl, {
    Future<VideoPlayerController?> Function(String, Map<String, String>)?
    acquireController,
    Future<void> Function(VideoPlayerController)? releaseController,
  }) : _mediaUrl = mediaUrl,
       _acquireController =
           acquireController ??
           ((url, headers) => VideoPlaybackService.acquireInitializedController(
             url,
             headers: headers,
           )),
       _releaseController =
           releaseController ?? VideoPlaybackService.releaseController {
    _setupController();
  }

  String _mediaUrl;
  final Future<VideoPlayerController?> Function(String, Map<String, String>)
  _acquireController;
  final Future<void> Function(VideoPlayerController) _releaseController;
  bool _isDisposed = false;
  VideoPlayerController? _player;
  Future<void>? _initializeFuture;
  Object? _initializationError;
  int _initializationGeneration = 0;

  VideoPlayerController? get player => _player;
  Future<void>? get initializeFuture => _initializeFuture;
  Object? get initializationError => _initializationError;
  VideoPlayerController? get readyPlayer =>
      _player?.value.isInitialized == true && _initializationError == null
      ? _player
      : null;

  void updateMediaUrl(String mediaUrl) {
    if (_mediaUrl == mediaUrl) return;
    _disposeController();
    _mediaUrl = mediaUrl;
    _setupController();
    notifyListeners();
  }

  void _setupController() {
    _initializationError = null;
    final generation = ++_initializationGeneration;
    _initializeFuture = _initializeController(generation);
  }

  Future<void> _initializeController(int generation) async {
    VideoPlayerController? controller;
    try {
      final resolvedVideoUrl = CustomFunctions.resolveNetworkUrl(_mediaUrl);
      if (resolvedVideoUrl == null) throw ArgumentError('Invalid video URL');
      controller = await _acquireController(
        _mediaUrl,
        _buildVideoHeaders(resolvedVideoUrl),
      );
      if (controller == null) {
        throw ArgumentError('Unable to resolve video source');
      }
      if (!_isActiveGeneration(generation)) {
        await _releaseController(controller);
        return;
      }

      await controller.setLooping(false);
      await controller.setVolume(1);
      if (!_isActiveGeneration(generation)) {
        await _releaseController(controller);
        return;
      }
      _player = controller;
      notifyListeners();
    } catch (error) {
      if (controller != null) await _releaseController(controller);
      if (!_isActiveGeneration(generation)) return;
      debugPrint('Audit video initialization failed: $error');
      _initializationError = error;
      notifyListeners();
      rethrow;
    }
  }

  bool _isActiveGeneration(int generation) {
    return !_isDisposed && generation == _initializationGeneration;
  }

  Map<String, String> _buildVideoHeaders(String resolvedVideoUrl) {
    final authToken = AppPreference.getAuthToken().trim();
    if (authToken.isEmpty) {
      return const <String, String>{};
    }

    final apiHost = Uri.tryParse(ApiEndPoints.baseUrl)?.host;
    final mediaHost = Uri.tryParse(resolvedVideoUrl)?.host;
    if (apiHost == null || mediaHost == null || apiHost != mediaHost) {
      return const <String, String>{};
    }

    return <String, String>{'Authorization': 'Bearer $authToken'};
  }

  void _disposeController() {
    _initializationGeneration++;
    final controller = _player;
    _player = null;
    _initializeFuture = null;
    _initializationError = null;
    if (controller != null) {
      unawaited(_releaseController(controller));
    }
  }

  Future<void> togglePlayback() async {
    final controller = _player;
    if (controller == null) {
      return;
    }

    if (!controller.value.isInitialized) {
      try {
        await _initializeFuture;
      } catch (_) {
        return;
      }
    }

    if (!controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration > Duration.zero && position >= duration) {
      await controller.seekTo(Duration.zero);
    }

    unawaited(VideoPlaybackService.prepareAudiblePlaybackAudioSession());
    await controller.play();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeController();
    super.dispose();
  }
}
