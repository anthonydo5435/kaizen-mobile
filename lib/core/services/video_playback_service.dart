import 'dart:async';
import 'dart:io';

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../utils/custom_functions.dart';
import '../utils/webm_playback_helper.dart';

class VideoPlaybackService {
  VideoPlaybackService._();

  static const Duration defaultCacheMaxAge = Duration(days: 30);
  static const Duration _retainedControllerMaxIdleTime = Duration(minutes: 3);
  static const MethodChannel _audioSessionChannel = MethodChannel(
    'kaizenteams/video_audio_session',
  );
  static const MethodChannel _fullscreenChannel = MethodChannel(
    'kaizenteams/video_fullscreen',
  );
  static const String _customCacheNamespace = 'kaizen-video';
  static const String _packageCacheStoragePrefix =
      'cached_video_player_plus_caching_time_of_';
  static final Map<String, Future<void>> _warmUpJobs = <String, Future<void>>{};
  static final Map<String, _RetainedVideoControllerEntry> _idleControllers =
      <String, _RetainedVideoControllerEntry>{};
  static final Map<VideoPlayerController, _RetainedVideoControllerEntry>
  _leasedControllers = <VideoPlayerController, _RetainedVideoControllerEntry>{};
  static final Map<String, Duration> _lastKnownPositions = <String, Duration>{};

  static Future<void> warmUp(
    String? videoUrl, {
    Map<String, String> headers = const <String, String>{},
    Duration cacheMaxAge = defaultCacheMaxAge,
  }) async {
    final resolvedUrl = CustomFunctions.resolveNetworkUrl(videoUrl);
    if (resolvedUrl == null || _requiresAppleWebmTranscode(resolvedUrl)) {
      return;
    }

    await _warmUpResolvedUri(
      Uri.parse(resolvedUrl),
      headers: headers,
      cacheMaxAge: cacheMaxAge,
    );
  }

  static Future<void> prepareAudiblePlaybackAudioSession() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await _audioSessionChannel.invokeMethod<void>('prepareForPlayback');
    } catch (error) {
      // Best-effort only. Playback should continue even if the route stays unchanged.
    }
  }

  static Future<void> setFullscreen(bool enabled) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Use WindowInsets on Android, including apps targeting API 36.
        await _fullscreenChannel.invokeMethod<void>('setFullscreen', {
          'enabled': enabled,
        });
        return;
      } on MissingPluginException {
        // Older native builds still support Flutter's system UI request.
      }
    }
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  /// Watches the physical device while the interface is temporarily locked.
  static Future<bool> waitForDevicePortrait() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    try {
      return await _fullscreenChannel.invokeMethod<bool>('waitForPortrait') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> cancelDevicePortraitWait() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _fullscreenChannel.invokeMethod<void>('cancelWaitForPortrait');
    } on MissingPluginException {
      // A native build without this bridge has no sensor subscription to stop.
    }
  }

  static Future<VideoPlayerController?> createInitializedController(
    String? videoUrl, {
    String? localFilePath,
    Map<String, String> headers = const <String, String>{},
    Duration cacheMaxAge = defaultCacheMaxAge,
    VideoPlayerOptions? videoPlayerOptions,
    VideoViewType viewType = VideoViewType.textureView,
  }) async {
    final resolvedLocalFilePath = localFilePath?.trim();
    if (resolvedLocalFilePath != null && resolvedLocalFilePath.isNotEmpty) {
      final localFile = File(resolvedLocalFilePath);
      if (await localFile.exists()) {
        final localController = VideoPlayerController.file(
          localFile,
          videoPlayerOptions: videoPlayerOptions,
          viewType: viewType,
        );

        try {
          await localController.initialize();
          return localController;
        } catch (error) {
          await localController.dispose();
          debugPrint(
            'Local video initialization failed for $resolvedLocalFilePath: $error',
          );
        }
      }
    }

    final resolvedUrl = CustomFunctions.resolveNetworkUrl(videoUrl);
    if (resolvedUrl == null) {
      return null;
    }

    if (_requiresAppleWebmTranscode(resolvedUrl)) {
      return _createControllerFromResolvedSource(
        videoUrl,
        headers: headers,
        videoPlayerOptions: videoPlayerOptions,
        viewType: viewType,
      );
    }

    final videoUri = Uri.parse(resolvedUrl);
    final cacheKey = _cacheKeyFor(videoUri);

    final cachedFile = await _getValidCachedFile(
      cacheKey: cacheKey,
      cacheMaxAge: cacheMaxAge,
    );
    if (cachedFile != null) {
      final cachedController = VideoPlayerController.file(
        cachedFile,
        videoPlayerOptions: videoPlayerOptions,
        viewType: viewType,
      );

      try {
        await cachedController.initialize();
        return cachedController;
      } catch (error) {
        await cachedController.dispose();
        debugPrint(
          'Cached video initialization failed for $resolvedUrl: $error',
        );
        await _removeCachedFileByKey(cacheKey);
      }
    }

    final controller = VideoPlayerController.networkUrl(
      videoUri,
      httpHeaders: headers,
      videoPlayerOptions: videoPlayerOptions,
      viewType: viewType,
    );
    await controller.initialize();
    return controller;
  }

  static Future<VideoPlayerController?> acquireInitializedController(
    String? videoUrl, {
    String? localFilePath,
    Map<String, String> headers = const <String, String>{},
    Duration cacheMaxAge = defaultCacheMaxAge,
    VideoPlayerOptions? videoPlayerOptions,
    VideoViewType viewType = VideoViewType.textureView,
  }) async {
    final poolKey = await _controllerPoolKeyFor(
      videoUrl,
      localFilePath: localFilePath,
      headers: headers,
      viewType: viewType,
    );
    if (poolKey == null) {
      return createInitializedController(
        videoUrl,
        localFilePath: localFilePath,
        headers: headers,
        cacheMaxAge: cacheMaxAge,
        videoPlayerOptions: videoPlayerOptions,
        viewType: viewType,
      );
    }

    final retainedEntry = _idleControllers.remove(poolKey);
    if (retainedEntry != null) {
      retainedEntry.disposeTimer?.cancel();
      retainedEntry.disposeTimer = null;
      final retainedController = retainedEntry.controller;
      if (retainedController.value.isInitialized) {
        _leasedControllers[retainedController] = retainedEntry;
        await _restoreLastKnownPosition(retainedController, poolKey: poolKey);
        return retainedController;
      }

      await retainedController.dispose();
    }

    final controller = await createInitializedController(
      videoUrl,
      localFilePath: localFilePath,
      headers: headers,
      cacheMaxAge: cacheMaxAge,
      videoPlayerOptions: videoPlayerOptions,
      viewType: viewType,
    );
    if (controller == null) {
      return null;
    }

    final entry = _RetainedVideoControllerEntry(
      poolKey: poolKey,
      controller: controller,
    );
    _leasedControllers[controller] = entry;
    await _restoreLastKnownPosition(controller, poolKey: poolKey);
    return controller;
  }

  static Future<void> releaseController(
    VideoPlayerController controller,
  ) async {
    final leasedEntry = _leasedControllers.remove(controller);
    if (leasedEntry == null) {
      if (_isIdleController(controller)) {
        return;
      }
      await controller.dispose();
      return;
    }

    final poolKey = leasedEntry.poolKey;
    _lastKnownPositions[poolKey] = _normalizedResumePosition(controller.value);

    if (controller.value.isPlaying) {
      try {
        await controller.pause();
      } catch (_) {
        // Ignore pause failures and continue with disposal retention.
      }
    }

    final existingIdleEntry = _idleControllers.remove(poolKey);
    if (existingIdleEntry != null &&
        !identical(existingIdleEntry.controller, controller)) {
      existingIdleEntry.disposeTimer?.cancel();
      await existingIdleEntry.controller.dispose();
    }

    leasedEntry.disposeTimer?.cancel();
    leasedEntry.disposeTimer = Timer(
      _retainedControllerMaxIdleTime,
      () => unawaited(_expireIdleController(poolKey, controller)),
    );
    _idleControllers[poolKey] = leasedEntry;
  }

  static Future<VideoPlayerController?> _createControllerFromResolvedSource(
    String? videoUrl, {
    required Map<String, String> headers,
    VideoPlayerOptions? videoPlayerOptions,
    required VideoViewType viewType,
  }) async {
    final source = await WebmPlaybackHelper.resolvePlayableSource(
      videoUrl,
      headers: headers,
    );
    if (source == null) {
      return null;
    }

    final controller = source.isFile
        ? VideoPlayerController.file(
            File(source.path),
            videoPlayerOptions: videoPlayerOptions,
            viewType: viewType,
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(source.path),
            httpHeaders: headers,
            videoPlayerOptions: videoPlayerOptions,
            viewType: viewType,
          );
    await controller.initialize();
    return controller;
  }

  static Future<void> _warmUpResolvedUri(
    Uri videoUri, {
    required Map<String, String> headers,
    required Duration cacheMaxAge,
  }) async {
    final cacheKey = _cacheKeyFor(videoUri);
    final existingJob = _warmUpJobs[cacheKey];
    if (existingJob != null) {
      await existingJob;
      return;
    }

    late final Future<void> job;
    job =
        () async {
          try {
            await CachedVideoPlayerPlus.preCacheVideo(
              videoUri,
              downloadHeaders: headers,
              invalidateCacheIfOlderThan: cacheMaxAge,
              cacheKey: cacheKey,
            );
          } catch (error) {
            debugPrint('Video cache warm-up failed for $videoUri: $error');
          }
        }().whenComplete(() {
          if (identical(_warmUpJobs[cacheKey], job)) {
            _warmUpJobs.remove(cacheKey);
          }
        });

    _warmUpJobs[cacheKey] = job;
    await job;
  }

  static Future<File?> _getValidCachedFile({
    required String cacheKey,
    required Duration cacheMaxAge,
  }) async {
    final storageKey = _storageKeyFor(cacheKey);
    final fileInfo = await CachedVideoPlayerPlus.cacheManager.getFileFromCache(
      storageKey,
    );
    if (fileInfo == null) {
      return null;
    }

    final cachedAtMillis = await CachedVideoPlayerPlus.metadataStorage.read(
      storageKey,
    );
    var isCacheExpired = cachedAtMillis == null;
    if (cachedAtMillis != null) {
      final cachedDate = DateTime.fromMillisecondsSinceEpoch(cachedAtMillis);
      isCacheExpired =
          DateTime.timestamp().difference(cachedDate) > cacheMaxAge;
    }

    final file = fileInfo.file;
    final fileExists = await file.exists();
    final isEmptyFile = fileExists ? await file.length() == 0 : true;
    if (isCacheExpired || isEmptyFile) {
      await _removeCachedFileByKey(cacheKey);
      return null;
    }

    return file;
  }

  static Future<void> _removeCachedFileByKey(String cacheKey) async {
    final storageKey = _storageKeyFor(cacheKey);
    await Future.wait<void>([
      CachedVideoPlayerPlus.cacheManager.removeFile(storageKey),
      CachedVideoPlayerPlus.metadataStorage.remove(storageKey),
    ]);
  }

  static String _cacheKeyFor(Uri videoUri) {
    final normalizedUri = videoUri.replace(fragment: '');
    return '$_customCacheNamespace::$normalizedUri';
  }

  static String _storageKeyFor(String cacheKey) {
    return '$_packageCacheStoragePrefix$cacheKey';
  }

  static bool _requiresAppleWebmTranscode(String resolvedUrl) {
    return CustomFunctions.isApplePlatform() &&
        CustomFunctions.isWebmVideoUrl(resolvedUrl);
  }

  static Future<String?> _controllerPoolKeyFor(
    String? videoUrl, {
    String? localFilePath,
    required Map<String, String> headers,
    required VideoViewType viewType,
  }) async {
    final resolvedLocalFilePath = localFilePath?.trim();
    if (resolvedLocalFilePath != null && resolvedLocalFilePath.isNotEmpty) {
      final localFile = File(resolvedLocalFilePath);
      if (await localFile.exists()) {
        return _controllerPoolKeyForSource(
          'file::$resolvedLocalFilePath',
          headers: headers,
          viewType: viewType,
        );
      }
    }

    final resolvedUrl = CustomFunctions.resolveNetworkUrl(videoUrl);
    if (resolvedUrl == null) {
      return null;
    }

    return _controllerPoolKeyForSource(
      'url::$resolvedUrl',
      headers: headers,
      viewType: viewType,
    );
  }

  static String _controllerPoolKeyForSource(
    String sourceKey, {
    required Map<String, String> headers,
    required VideoViewType viewType,
  }) {
    if (headers.isEmpty) {
      return '$sourceKey::${viewType.name}';
    }

    final sortedEntries = headers.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final headersHash = Object.hashAll(
      sortedEntries.map((entry) => Object.hash(entry.key, entry.value)),
    );
    return '$sourceKey::${viewType.name}::$headersHash';
  }

  static Future<void> _restoreLastKnownPosition(
    VideoPlayerController controller, {
    required String poolKey,
  }) async {
    final resumePosition = _lastKnownPositions[poolKey];
    if (resumePosition == null || resumePosition <= Duration.zero) {
      return;
    }

    final duration = controller.value.duration;
    if (duration <= Duration.zero) {
      return;
    }

    final clampedPosition = resumePosition >= duration
        ? duration
        : resumePosition;
    if (controller.value.position == clampedPosition) {
      return;
    }

    try {
      await controller.seekTo(clampedPosition);
    } catch (_) {
      // Reusing the controller is still valuable even if resume seek fails.
    }
  }

  static Duration _normalizedResumePosition(VideoPlayerValue value) {
    final duration = value.duration;
    final position = value.position;
    if (duration <= Duration.zero || position <= Duration.zero) {
      return Duration.zero;
    }

    if (position >= duration) {
      return Duration.zero;
    }

    return position;
  }

  static bool _isIdleController(VideoPlayerController controller) {
    for (final entry in _idleControllers.values) {
      if (identical(entry.controller, controller)) {
        return true;
      }
    }

    return false;
  }

  static Future<void> _expireIdleController(
    String poolKey,
    VideoPlayerController controller,
  ) async {
    final retainedEntry = _idleControllers[poolKey];
    if (retainedEntry == null ||
        !identical(retainedEntry.controller, controller)) {
      return;
    }

    _idleControllers.remove(poolKey);
    retainedEntry.disposeTimer?.cancel();
    await retainedEntry.controller.dispose();
  }
}

class _RetainedVideoControllerEntry {
  _RetainedVideoControllerEntry({
    required this.poolKey,
    required this.controller,
  });

  final String poolKey;
  final VideoPlayerController controller;
  Timer? disposeTimer;
}
