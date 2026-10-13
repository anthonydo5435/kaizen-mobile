import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/video_playback_service.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../pages/training/compliance_full_screen_video_view.dart';
import '../providers/compliance_video_controller.dart';

class ComplianceVideoPlayer extends StatefulWidget {
  static const bottomControlsInset = 30.0;
  static const contentHorizontalInset = 10.0;
  static const contentPadding = EdgeInsets.symmetric(horizontal: contentHorizontalInset);
  static const topControlsMinHeight = 34.0;

  /// Fitted media bounds with enough room above the image for its actions.
  static Rect previewMediaBounds(
    Size viewport, {
    required Alignment alignment,
    Size mediaSize = const Size(16, 9),
    double minimumTop = 0,
  }) {
    final fitted = applyBoxFit(BoxFit.contain, mediaSize, viewport).destination;
    final preferred = alignment.inscribe(fitted, Offset.zero & viewport);
    final top = preferred.top.clamp(minimumTop.clamp(0, viewport.height), viewport.height).toDouble();
    final available = Size(viewport.width, viewport.height - top);
    return Alignment.topCenter.inscribe(
      applyBoxFit(BoxFit.contain, mediaSize, available).destination,
      Offset(0, top) & available,
    );
  }

  const ComplianceVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.localVideoPath,
    this.thumbnailLink,
    this.height = 240,
    this.showTitle = true,
    this.showSeekBar = true,
    this.showDuration = true,
    this.fillBounds = false,
    this.mediaAlignment = Alignment.center,
    this.topControlsInset = 10,
    this.topRightActions = const <Widget>[],
    this.onPositionChanged,
    this.onSeekHandlerChanged,
    this.onPlaybackControlsVisibilityChanged,
    this.onVideoBoundsChanged,
    this.onRevealControlsHandlerChanged,
    this.layoutBuilder,
  });

  final String videoUrl;
  final String title;
  final String? localVideoPath;
  final String? thumbnailLink;
  final double height;
  final bool showTitle;
  final bool showSeekBar;
  final bool showDuration;
  final bool fillBounds;
  final Alignment mediaAlignment;
  final double topControlsInset;
  final List<Widget> topRightActions;
  final ValueChanged<Duration>? onPositionChanged;
  final ValueChanged<Future<bool> Function(Duration)?>? onSeekHandlerChanged;
  final ValueChanged<bool>? onPlaybackControlsVisibilityChanged;
  final ValueChanged<Rect?>? onVideoBoundsChanged;
  final ValueChanged<VoidCallback?>? onRevealControlsHandlerChanged;
  final Widget Function(Widget video, Widget bottomControls)? layoutBuilder;

  @override
  State<ComplianceVideoPlayer> createState() => _ComplianceVideoPlayerState();
}

class _ComplianceVideoPlayerState extends State<ComplianceVideoPlayer>
    with AutomaticKeepAliveClientMixin<ComplianceVideoPlayer> {
  static const _cacheMaxAge = Duration(days: 30);

  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  Object? _initializationError;
  int _initializationGeneration = 0;
  VideoViewType _currentViewType = VideoViewType.textureView;
  bool _didRetryWithPlatformView = false;
  late bool _showThumbnailPreview;
  bool _isPreparingPlayback = false;
  bool _isScrubbing = false;
  double? _scrubPositionMillis;
  final ValueNotifier<bool> _showPlaybackControls = ValueNotifier<bool>(true);
  final _videoFrameKey = GlobalKey();
  GlobalKey _videoKey = GlobalKey();
  GlobalKey _thumbnailKey = GlobalKey();
  Timer? _hidePlaybackControlsTimer;
  bool _wasPlaybackActive = false;

  @override
  void initState() {
    super.initState();
    _showPlaybackControls.addListener(_notifyControlsVisibility);
    _showThumbnailPreview = _hasThumbnail;
    _setupController();
    widget.onSeekHandlerChanged?.call(_seekToPosition);
    widget.onRevealControlsHandlerChanged?.call(_revealPlaybackControls);
  }

  @override
  void didUpdateWidget(covariant ComplianceVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onRevealControlsHandlerChanged != widget.onRevealControlsHandlerChanged) {
      oldWidget.onRevealControlsHandlerChanged?.call(null);
      widget.onRevealControlsHandlerChanged?.call(_revealPlaybackControls);
    }
    if (oldWidget.onSeekHandlerChanged != widget.onSeekHandlerChanged) {
      oldWidget.onSeekHandlerChanged?.call(null);
      widget.onSeekHandlerChanged?.call(_seekToPosition);
    }
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.localVideoPath != widget.localVideoPath ||
        oldWidget.thumbnailLink != widget.thumbnailLink) {
      _showThumbnailPreview = _hasThumbnail;
      // A fading video can still be mounted when the new thumbnail is played.
      if (_showThumbnailPreview) {
        _videoKey = GlobalKey();
        _thumbnailKey = GlobalKey();
      }
      _isScrubbing = false;
      _scrubPositionMillis = null;
    }

    if (oldWidget.videoUrl != widget.videoUrl || oldWidget.localVideoPath != widget.localVideoPath) {
      _currentViewType = VideoViewType.textureView;
      _didRetryWithPlatformView = false;
      _disposeController();
      _setupController();
    }
  }

  @override
  void dispose() {
    _showPlaybackControls.removeListener(_notifyControlsVisibility);
    widget.onSeekHandlerChanged?.call(null);
    widget.onRevealControlsHandlerChanged?.call(null);
    _disposeController();
    _showPlaybackControls.dispose();
    super.dispose();
  }

  void _setupController() {
    _initializationError = null;
    _controller = null;
    _videoKey = GlobalKey();
    final generation = ++_initializationGeneration;
    _initializeFuture = _initializeController(generation, viewType: _currentViewType);
    // Observe fallback failures even before FutureBuilder receives the new future.
    _initializeFuture!.ignore();
  }

  Future<void> _initializeController(int generation, {required VideoViewType viewType}) async {
    VideoPlayerController? controller;

    try {
      controller = await VideoPlaybackService.acquireInitializedController(
        widget.videoUrl,
        localFilePath: widget.localVideoPath,
        cacheMaxAge: _cacheMaxAge,
        viewType: viewType,
      );
      if (controller == null) {
        throw ArgumentError('Invalid video URL');
      }

      if (!mounted || !_isActiveGeneration(generation)) {
        await VideoPlaybackService.releaseController(controller);
        return;
      }

      await controller.setLooping(false);
      await controller.setVolume(1);
      if (!mounted || !_isActiveGeneration(generation)) {
        await VideoPlaybackService.releaseController(controller);
        return;
      }

      setState(() {
        _controller = controller;
      });
      controller.addListener(_notifyPlaybackPosition);
      _notifyPlaybackPosition();
    } catch (error) {
      if (controller != null) {
        await VideoPlaybackService.releaseController(controller);
      }
      if (_shouldRetryWithPlatformView(viewType, generation)) {
        _currentViewType = VideoViewType.platformView;
        _didRetryWithPlatformView = true;
        _setupController();
        if (mounted) {
          setState(() {});
        }
        return;
      }
      if (mounted && _isActiveGeneration(generation)) {
        setState(() {
          _initializationError = error;
        });
      }
      rethrow;
    }
  }

  bool _shouldRetryWithPlatformView(VideoViewType attemptedViewType, int generation) {
    if (!mounted || !_isActiveGeneration(generation)) {
      return false;
    }

    if (CustomFunctions.isApplePlatform()) {
      return false;
    }

    return attemptedViewType == VideoViewType.textureView && !_didRetryWithPlatformView;
  }

  bool _isActiveGeneration(int generation) {
    return generation == _initializationGeneration;
  }

  void _notifyPlaybackPosition() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      _syncPlaybackControls();
      widget.onPositionChanged?.call(controller.value.position);
    }
  }

  void _notifyControlsVisibility() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // Source changes can reset visibility during a parent's build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onPlaybackControlsVisibilityChanged?.call(_showPlaybackControls.value);
        }
      });
      return;
    }
    widget.onPlaybackControlsVisibilityChanged?.call(_showPlaybackControls.value);
  }

  bool get _isPlaybackActive {
    final value = _controller?.value;
    return value != null &&
        value.isInitialized &&
        value.isPlaying &&
        !value.isCompleted &&
        !value.hasError &&
        (value.duration <= Duration.zero || value.position < value.duration);
  }

  void _syncPlaybackControls() {
    final isPlaying = _isPlaybackActive;
    if (!isPlaying || !_wasPlaybackActive) {
      _hidePlaybackControlsTimer?.cancel();
      _showPlaybackControls.value = !isPlaying;
    }
    _wasPlaybackActive = isPlaying;
  }

  void _revealPlaybackControls() {
    _hidePlaybackControlsTimer?.cancel();
    _showPlaybackControls.value = true;
    if (_isPlaybackActive && !_isScrubbing) {
      _hidePlaybackControlsTimer = Timer(const Duration(seconds: 3), () {
        _showPlaybackControls.value = !_isPlaybackActive;
      });
    }
  }

  void _disposeController() {
    _initializationGeneration++;
    _hidePlaybackControlsTimer?.cancel();
    _hidePlaybackControlsTimer = null;
    _wasPlaybackActive = false;
    _showPlaybackControls.value = true;

    final controller = _controller;
    _controller = null;
    _initializeFuture = null;
    _initializationError = null;
    _isPreparingPlayback = false;
    _isScrubbing = false;
    _scrubPositionMillis = null;
    if (controller != null) {
      controller.removeListener(_notifyPlaybackPosition);
      unawaited(VideoPlaybackService.releaseController(controller));
    }
  }

  @override
  bool get wantKeepAlive => true;

  bool get _hasThumbnail {
    return CustomFunctions.resolveImageUrl(widget.thumbnailLink) != null;
  }

  Future<VideoPlayerController?> _ensureControllerReady() async {
    if (!mounted) return null;
    final videoUrl = widget.videoUrl;
    final localVideoPath = widget.localVideoPath;
    final currentController = _controller;
    if (currentController != null && currentController.value.isInitialized && !currentController.value.hasError) {
      return currentController;
    }

    try {
      if (_initializeFuture == null || _initializationError != null || currentController?.value.hasError == true) {
        _disposeController();
        _setupController();
        if (mounted) {
          setState(() {});
        }
      }

      // Android can replace the texture initialization with a platform-view retry.
      // Follow that replacement instead of treating the first completion as ready.
      while (mounted && widget.videoUrl == videoUrl && widget.localVideoPath == localVideoPath) {
        final initializeFuture = _initializeFuture;
        if (initializeFuture == null) return null;
        await initializeFuture;
        if (identical(initializeFuture, _initializeFuture)) break;
      }

      final controller = _controller;
      if (!mounted ||
          widget.videoUrl != videoUrl ||
          widget.localVideoPath != localVideoPath ||
          controller == null ||
          !controller.value.isInitialized ||
          controller.value.hasError) {
        return null;
      }

      return controller;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _seekToPosition(Duration position) async {
    final videoUrl = widget.videoUrl;
    final localVideoPath = widget.localVideoPath;
    bool isCurrentSource() => mounted && widget.videoUrl == videoUrl && widget.localVideoPath == localVideoPath;
    for (var attempt = 0; attempt < 3 && isCurrentSource(); attempt++) {
      try {
        final controller = await _ensureControllerReady();
        if (!isCurrentSource()) return false;
        if (controller == null) continue;
        // Stop the player's position polling while seeking to avoid stale progress.
        await controller.pause();
        if (!isCurrentSource() || controller != _controller) return false;
        _isScrubbing = false;
        _scrubPositionMillis = null;
        _showThumbnailPreview = false;
        final target = Duration(
          milliseconds: position.inMilliseconds.clamp(0, controller.value.duration.inMilliseconds),
        );
        await controller.seekTo(target);
        if (!isCurrentSource() || controller != _controller) return false;
        if (target < controller.value.duration) {
          unawaited(VideoPlaybackService.prepareAudiblePlaybackAudioSession());
          await controller.play();
        }
        if (!isCurrentSource() || controller != _controller) return false;
        _notifyPlaybackPosition();
        _revealPlaybackControls();
        return true;
      } catch (error) {
        debugPrint('Transcript seek attempt failed: $error');
      }
    }
    return false;
  }

  Future<void> _togglePlayback() async {
    final activeController = _controller;
    final wasReadyBeforeTap = activeController != null && activeController.value.isInitialized;
    if (!wasReadyBeforeTap && mounted) {
      setState(() {
        _isPreparingPlayback = true;
      });
    }

    final controller = await _ensureControllerReady();
    if (controller == null || !controller.value.isInitialized) {
      if (mounted) {
        setState(() {
          _isPreparingPlayback = false;
        });
      }
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
      if (mounted) {
        setState(() {
          _isPreparingPlayback = false;
        });
      }
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration > Duration.zero && position >= duration) {
      await controller.seekTo(Duration.zero);
    }

    unawaited(VideoPlaybackService.prepareAudiblePlaybackAudioSession());
    await controller.play();
    if (mounted) {
      setState(() {
        _showThumbnailPreview = false;
        _isPreparingPlayback = false;
      });
    }
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    _revealPlaybackControls();
    final position = controller.value.position;
    final duration = controller.value.duration;
    final nextPosition = position + offset;

    if (nextPosition <= Duration.zero) {
      await controller.seekTo(Duration.zero);
      return;
    }

    if (nextPosition >= duration) {
      await controller.seekTo(duration);
      return;
    }

    await controller.seekTo(nextPosition);
  }

  Future<void> _openFullScreenVideo() async {
    final wasReadyBeforeOpen = _controller != null && _controller!.value.isInitialized;
    if (!wasReadyBeforeOpen && mounted) {
      setState(() {
        _isPreparingPlayback = true;
      });
    }

    final controller = await _ensureControllerReady();
    if (controller == null || !controller.value.isInitialized || !mounted) {
      if (mounted) {
        setState(() {
          _isPreparingPlayback = false;
        });
      }
      return;
    }

    final initialPosition = controller.value.position;
    final transcriptController = context.read<ComplianceVideoController?>();
    if (mounted) {
      setState(() {
        _isPreparingPlayback = false;
      });
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) {
          final view = ComplianceFullScreenVideoView(
            controller: controller,
            title: widget.title,
            initialPosition: initialPosition,
          );
          return transcriptController == null
              ? view
              : ChangeNotifierProvider<ComplianceVideoController>.value(value: transcriptController, child: view);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _controller;

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (controller == null) {
          return _buildPlayerContent(snapshot: snapshot, controller: null, controllerValue: null);
        }

        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, controllerValue, child) {
            return _buildPlayerContent(snapshot: snapshot, controller: controller, controllerValue: controllerValue);
          },
        );
      },
    );
  }

  Widget _buildPlayerContent({
    required AsyncSnapshot<void> snapshot,
    required VideoPlayerController? controller,
    required VideoPlayerValue? controllerValue,
  }) {
    final thumbnailUrl = CustomFunctions.resolveImageUrl(widget.thumbnailLink);
    final initializationError = _initializationError ?? snapshot.error;
    final isReady = controller != null && controllerValue?.isInitialized == true && initializationError == null;
    final isBuffering = isReady && (controllerValue?.isBuffering ?? false);
    final showThumbnailPreview =
        _showThumbnailPreview &&
        thumbnailUrl != null &&
        !(controllerValue?.isPlaying ?? false) &&
        initializationError == null;
    final isLoading =
        _isPreparingPlayback ||
        (!showThumbnailPreview &&
            initializationError == null &&
            !isReady &&
            snapshot.connectionState == ConnectionState.waiting);

    if (widget.onVideoBoundsChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportVideoBounds());
    }

    final video = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: _videoFrameKey,
          height: widget.height,
          decoration: const BoxDecoration(color: Colors.black),
          child: ClipRect(
            child: widget.fillBounds
                ? SizedBox.expand(
                    child: CustomMultiChildLayout(
                      delegate: _VideoMediaLayoutDelegate(
                        showThumbnail: showThumbnailPreview,
                        videoSize: isReady ? controllerValue!.size : const Size(16, 9),
                        mediaAlignment: widget.mediaAlignment,
                        topControlsInset: widget.topControlsInset,
                      ),
                      children: [
                        LayoutId(
                          id: _VideoMediaSlot.media,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: showThumbnailPreview
                                ? _buildThumbnailPreview(thumbnailUrl)
                                : isReady
                                ? SizedBox.expand(
                                    key: ValueKey(controller),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      alignment: Alignment.topCenter,
                                      child: SizedBox(
                                        width: controllerValue!.size.width,
                                        height: controllerValue.size.height,
                                        child: VideoPlayer(controller, key: _videoKey),
                                      ),
                                    ),
                                  )
                                : const ColoredBox(key: ValueKey('video-loading-background'), color: Colors.black),
                          ),
                        ),
                        LayoutId(
                          id: _VideoMediaSlot.overlay,
                          child: _buildOverlay(
                            controller: controller,
                            controllerValue: controllerValue,
                            initializationError: initializationError,
                            isReady: isReady,
                            isLoading: isLoading,
                            isBuffering: isBuffering,
                            showThumbnailPreview: showThumbnailPreview,
                            includeTopControls: false,
                          ),
                        ),
                        LayoutId(
                          id: _VideoMediaSlot.topControls,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: ComplianceVideoPlayer.topControlsMinHeight),
                            child: _buildTopControls(),
                          ),
                        ),
                      ],
                    ),
                  )
                : AspectRatio(
                    aspectRatio: isReady ? controllerValue!.aspectRatio : 1.7,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: showThumbnailPreview
                              ? _buildThumbnailPreview(thumbnailUrl)
                              : isReady
                              ? KeyedSubtree(
                                  key: ValueKey(controller),
                                  child: VideoPlayer(controller, key: _videoKey),
                                )
                              : const ColoredBox(key: ValueKey('video-loading-background'), color: Colors.black),
                        ),
                        _buildOverlay(
                          controller: controller,
                          controllerValue: controllerValue,
                          initializationError: initializationError,
                          isReady: isReady,
                          isLoading: isLoading,
                          isBuffering: isBuffering,
                          showThumbnailPreview: showThumbnailPreview,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
    return widget.layoutBuilder?.call(video, _buildBottomControls(controller, controllerValue)) ?? video;
  }

  Widget _buildThumbnailPreview(String thumbnailUrl) {
    final image = Image.network(
      thumbnailUrl,
      key: _thumbnailKey,
      fit: widget.fillBounds ? BoxFit.contain : BoxFit.cover,
      alignment: widget.fillBounds ? Alignment.topCenter : widget.mediaAlignment,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null && widget.onVideoBoundsChanged != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _reportVideoBounds());
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(key: ValueKey('video-loading-background'), color: Colors.black),
    );
    return KeyedSubtree(
      key: const ValueKey('video-thumbnail-preview'),
      child: widget.fillBounds ? SizedBox.expand(child: image) : image,
    );
  }

  void _reportVideoBounds() {
    if (!mounted) return;
    final frame = _videoFrameKey.currentContext?.findRenderObject();
    if (frame is! RenderBox || !frame.hasSize) return;
    final showThumbnail =
        _showThumbnailPreview && _hasThumbnail && _initializationError == null && _controller?.value.isPlaying != true;
    var media = (showThumbnail ? _thumbnailKey : _videoKey).currentContext?.findRenderObject();
    // Image wraps its painted image in a semantics render object.
    if (showThumbnail) {
      while (media is RenderProxyBox) {
        media = media.child;
      }
    }
    if (media is! RenderBox || !media.hasSize || media.size.isEmpty) {
      // Keep the panel's compact initial bounds until there is visible media.
      widget.onVideoBoundsChanged?.call(null);
      return;
    }
    var visibleBounds = Offset.zero & media.size;
    if (showThumbnail && media is RenderImage) {
      final image = media.image;
      if (image == null) {
        // Use the laid-out action row even while the thumbnail is decoding.
        final fitted = applyBoxFit(BoxFit.contain, const Size(16, 9), media.size);
        final previewBounds = Alignment.topCenter.inscribe(fitted.destination, visibleBounds);
        widget.onVideoBoundsChanged?.call(MatrixUtils.transformRect(media.getTransformTo(frame), previewBounds));
        return;
      }
      // The image widget includes letterboxing; measure its painted image instead.
      final fitted = applyBoxFit(
        widget.fillBounds ? BoxFit.contain : BoxFit.cover,
        Size(image.width.toDouble(), image.height.toDouble()),
        media.size,
      );
      visibleBounds = (widget.fillBounds ? Alignment.topCenter : widget.mediaAlignment).inscribe(
        fitted.destination,
        visibleBounds,
      );
    }
    final bounds = MatrixUtils.transformRect(media.getTransformTo(frame), visibleBounds);
    widget.onVideoBoundsChanged?.call(bounds.intersect(Offset.zero & frame.size));
  }

  Widget _buildOverlay({
    required VideoPlayerController? controller,
    required VideoPlayerValue? controllerValue,
    required Object? initializationError,
    required bool isReady,
    required bool isLoading,
    required bool isBuffering,
    required bool showThumbnailPreview,
    bool includeTopControls = true,
  }) {
    final playbackControls = _buildPlaybackControlsVisibility(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleIconButton(
            icon: Icons.replay_10_rounded,
            onTap: isReady ? () => _seekBy(const Duration(seconds: -10)) : null,
          ),
          const SizedBox(width: 8),
          _PlayButton(
            isLoading: isLoading,
            isPlaying: controllerValue?.isPlaying ?? false,
            onTap: initializationError != null ? null : _togglePlayback,
          ),
          const SizedBox(width: 8),
          _CircleIconButton(
            icon: Icons.forward_10_rounded,
            onTap: isReady ? () => _seekBy(const Duration(seconds: 10)) : null,
          ),
        ],
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _revealPlaybackControls,
          child: showThumbnailPreview
              ? const ColoredBox(color: Colors.transparent)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.10), Colors.black.withValues(alpha: 0.45)],
                    ),
                  ),
                ),
        ),
        if (initializationError != null)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: AppTextView.body(
                'Video could not be loaded.',
                color: AppColors.textPrimary,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (isReady && isBuffering && !showThumbnailPreview)
          Center(child: SizedBox(width: 28, height: 28, child: FastCircularProgressIndicator())),
        Positioned(
          left: ComplianceVideoPlayer.contentHorizontalInset,
          right: ComplianceVideoPlayer.contentHorizontalInset,
          top: 0,
          bottom: 0,
          child: widget.fillBounds && includeTopControls
              ? Align(
                  alignment: widget.mediaAlignment,
                  child: AspectRatio(
                    aspectRatio: isReady ? controllerValue!.aspectRatio : 16 / 9,
                    child: playbackControls,
                  ),
                )
              : playbackControls,
        ),
        if (widget.layoutBuilder == null)
          ValueListenableBuilder<bool>(
            valueListenable: _showPlaybackControls,
            builder: (context, showControls, _) => Positioned(
              left: ComplianceVideoPlayer.contentHorizontalInset,
              right: ComplianceVideoPlayer.contentHorizontalInset,
              bottom: ComplianceVideoPlayer.bottomControlsInset,
              child: showControls ? _buildBottomControls(controller, controllerValue) : const SizedBox.shrink(),
            ),
          ),
        if (includeTopControls) Positioned(top: widget.topControlsInset, right: 10, child: _buildTopControls()),
      ],
    );
  }

  Widget _buildTopControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...widget.topRightActions.expand((action) => [const SizedBox(width: 8), action]),
        GestureDetector(
          key: const ValueKey('video-fullscreen-button'),
          onTap: _openFullScreenVideo,
          child: Container(
            width: 30,
            height: 30,
            margin: EdgeInsets.only(left: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surfaceDark2, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.fullscreen, size: 23, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(VideoPlayerController? controller, VideoPlayerValue? controllerValue) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle || widget.showDuration)
          Padding(
            padding: EdgeInsets.only(bottom: widget.showSeekBar ? 0 : 8),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.showTitle)
                    Expanded(
                      child: AppTextView.body1(
                        widget.title,
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  if (widget.showTitle && widget.showDuration) const SizedBox(width: 8),
                  if (widget.showDuration)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * (widget.showTitle ? 0.6 : 1),
                        maxHeight: (widget.height / 2 - 58).clamp(0, double.infinity),
                      ),
                      child: SingleChildScrollView(primary: false, child: _buildDurationRow(controllerValue)),
                    ),
                ],
              ),
            ),
          ),
        if (widget.showSeekBar)
          Padding(
            padding: EdgeInsets.only(left: 3),
            child: SizedBox(height: 18, child: _buildSeekBar(controller, controllerValue)),
          ),
      ],
    );
  }

  Widget _buildPlaybackControlsVisibility({required Widget child}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showPlaybackControls,
      builder: (context, showControls, child) => showControls ? child! : const SizedBox.shrink(),
      child: child,
    );
  }

  Widget _buildSeekBar(VideoPlayerController? controller, VideoPlayerValue? controllerValue) {
    final duration = controllerValue?.duration ?? Duration.zero;
    final position = _resolvedDisplayedPosition(controllerValue);
    final maxMillis = duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
    final currentMillis = position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
    final bufferedMillis = _resolvedBufferedMillis(controllerValue, maxMillis: maxMillis, currentMillis: currentMillis);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.secondaryColor,
        secondaryActiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.55),
        inactiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.35),
        thumbColor: AppColors.textPrimary,
        overlayColor: AppColors.secondaryColor.withValues(alpha: 0.18),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
      ),
      child: Slider(
        // The containing footer owns the inset for title, track and captions.
        padding: EdgeInsets.zero,
        value: currentMillis,
        secondaryTrackValue: bufferedMillis,
        min: 0,
        max: maxMillis,
        onChangeStart: controller == null || controllerValue?.isInitialized != true
            ? null
            : (value) {
                setState(() {
                  _isScrubbing = true;
                  _scrubPositionMillis = value;
                });
                _revealPlaybackControls();
              },
        onChanged: controller == null || controllerValue?.isInitialized != true
            ? null
            : (value) {
                setState(() {
                  _scrubPositionMillis = value;
                });
              },
        onChangeEnd: controller == null || controllerValue?.isInitialized != true
            ? null
            : (value) async {
                setState(() {
                  _isScrubbing = false;
                  _scrubPositionMillis = null;
                });
                _revealPlaybackControls();
                await controller.seekTo(Duration(milliseconds: value.round()));
              },
      ),
    );
  }

  double? _resolvedBufferedMillis(
    VideoPlayerValue? controllerValue, {
    required double maxMillis,
    required double currentMillis,
  }) {
    if (controllerValue == null || controllerValue.buffered.isEmpty) {
      return null;
    }

    var bufferedEndMillis = 0.0;
    for (final range in controllerValue.buffered) {
      final rangeEndMillis = range.end.inMilliseconds.toDouble();
      if (rangeEndMillis > bufferedEndMillis) {
        bufferedEndMillis = rangeEndMillis;
      }
    }

    final clampedBufferedMillis = bufferedEndMillis.clamp(0.0, maxMillis);
    if (clampedBufferedMillis <= currentMillis) {
      return null;
    }

    return clampedBufferedMillis;
  }

  Duration _resolvedDisplayedPosition(VideoPlayerValue? controllerValue) {
    if (_isScrubbing && _scrubPositionMillis != null) {
      return Duration(milliseconds: _scrubPositionMillis!.round());
    }

    return controllerValue?.position ?? Duration.zero;
  }

  Widget _buildDurationRow(VideoPlayerValue? controllerValue) {
    final position = _resolvedDisplayedPosition(controllerValue);
    final duration = controllerValue?.duration ?? Duration.zero;

    return Wrap(
      alignment: WrapAlignment.end,
      children: [
        AppTextView.body4(
          CustomFunctions.formatDuration(position.inSeconds),
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        AppTextView.body4('/', color: AppColors.textSecondary, fontWeight: FontWeight.w700),
        AppTextView.body4(
          CustomFunctions.formatDuration(duration.inSeconds),
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

enum _VideoMediaSlot { media, overlay, topControls }

/// Keeps previews and playback below the measured action row in the fixed frame.
class _VideoMediaLayoutDelegate extends MultiChildLayoutDelegate {
  _VideoMediaLayoutDelegate({
    required this.showThumbnail,
    required this.videoSize,
    required this.mediaAlignment,
    required this.topControlsInset,
  });

  final bool showThumbnail;
  final Size videoSize;
  final Alignment mediaAlignment;
  final double topControlsInset;

  @override
  void performLayout(Size size) {
    final controlsSize = layoutChild(
      _VideoMediaSlot.topControls,
      BoxConstraints.loose(Size((size.width - 20).clamp(0, double.infinity), size.height)),
    );
    positionChild(_VideoMediaSlot.topControls, Offset(size.width - controlsSize.width - 10, topControlsInset));
    final mediaBounds = ComplianceVideoPlayer.previewMediaBounds(
      size,
      alignment: mediaAlignment,
      mediaSize: showThumbnail ? const Size(16, 9) : videoSize,
      minimumTop: topControlsInset + controlsSize.height + 6,
    );
    final mediaHeight = showThumbnail ? size.height - mediaBounds.top : mediaBounds.height;
    layoutChild(_VideoMediaSlot.media, BoxConstraints.tight(Size(size.width, mediaHeight)));
    positionChild(_VideoMediaSlot.media, Offset(0, mediaBounds.top));
    layoutChild(_VideoMediaSlot.overlay, BoxConstraints.tight(Size(size.width, mediaBounds.height)));
    positionChild(_VideoMediaSlot.overlay, Offset(0, mediaBounds.top));
  }

  @override
  bool shouldRelayout(_VideoMediaLayoutDelegate oldDelegate) =>
      showThumbnail != oldDelegate.showThumbnail ||
      videoSize != oldDelegate.videoSize ||
      mediaAlignment != oldDelegate.mediaAlignment ||
      topControlsInset != oldDelegate.topControlsInset;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;
  static const double _diameter = 36;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(icon, color: onTap == null ? AppColors.grey1 : AppColors.textPrimary, size: _diameter * 0.7),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isLoading, required this.isPlaying, required this.onTap});

  final bool isLoading;
  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(color: AppColors.secondaryColor, shape: BoxShape.circle),
        child: isLoading
            ? FastCircularProgressIndicator(width: 24, height: 24)
            : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.textPrimary, size: 42),
      ),
    );
  }
}
