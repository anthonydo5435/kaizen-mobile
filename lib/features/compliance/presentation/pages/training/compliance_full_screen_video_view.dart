import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/services/video_playback_service.dart';
import '../../../../../core/utils/custom_functions.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../../../core/widgets/fast_circular_progress.dart';
import '../../providers/compliance_video_controller.dart';
import '../../widgets/compliance_video_playback_controls.dart';
import '../../widgets/compliance_video_transcript_sheet.dart';

class ComplianceFullScreenVideoView extends StatefulWidget {
  const ComplianceFullScreenVideoView({
    super.key,
    required this.controller,
    required this.title,
    this.initialPosition = Duration.zero,
    this.exitOnPortrait = false,
    this.isEmbedded = false,
    this.video,
    this.onExit,
  });

  final VideoPlayerController controller;
  final String title;
  final Duration initialPosition;
  final bool exitOnPortrait;
  final bool isEmbedded;
  final Widget? video;
  final VoidCallback? onExit;

  @override
  State<ComplianceFullScreenVideoView> createState() =>
      _ComplianceFullScreenVideoViewState();
}

class _ComplianceFullScreenVideoViewState
    extends State<ComplianceFullScreenVideoView>
    with WidgetsBindingObserver {
  static const Duration _entryBufferingSuppressionDuration = Duration(
    milliseconds: 900,
  );
  static const Duration _bufferingIndicatorDelay = Duration(milliseconds: 350);

  final ValueNotifier<double?> _scrubPositionMillis = ValueNotifier(null);
  final ValueNotifier<bool> _showBufferingIndicator = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> _showPlaybackControls = ValueNotifier<bool>(true);
  Timer? _entryBufferingSuppressionTimer;
  Timer? _pendingBufferingIndicatorTimer;
  Timer? _hidePlaybackControlsTimer;
  Duration _lastObservedPosition = Duration.zero;
  bool _wasPlaybackActive = false;
  bool _isEntryBufferingSuppressed = false;
  bool _hasRestoredDisplay = false;
  bool _animateTranscript = true;
  bool _hasBeenLandscape = false;
  bool _portraitExitScheduled = false;
  late final ComplianceVideoController? _transcriptController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transcriptController = context.read<ComplianceVideoController?>();
    _enterFullscreen();
    _attachController(widget.controller);
    _syncInitialPosition();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPortraitExit();
    final animateTranscript = !MediaQuery.disableAnimationsOf(context);
    if (_animateTranscript != animateTranscript) {
      _animateTranscript = animateTranscript;
      _handleControllerChanged();
    }
  }

  @override
  void didUpdateWidget(covariant ComplianceFullScreenVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _detachController(oldWidget.controller);
      _scrubPositionMillis.value = null;
      _attachController(widget.controller);
      _syncInitialPosition();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachController(widget.controller);
    _showBufferingIndicator.dispose();
    _showPlaybackControls.dispose();
    _scrubPositionMillis.dispose();
    _restoreDisplay();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _checkPortraitExit();

  void _checkPortraitExit() {
    if (!mounted || !widget.exitOnPortrait || _hasRestoredDisplay) return;
    final size = View.of(context).physicalSize;
    if (size.width > size.height) {
      _hasBeenLandscape = true;
      return;
    }
    if (!_hasBeenLandscape || _portraitExitScheduled) return;
    _portraitExitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _portraitExitScheduled = false;
      if (!mounted || _hasRestoredDisplay) return;
      final size = View.of(context).physicalSize;
      if (size.width > size.height) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isActive) return;
      final navigator = Navigator.of(context);
      // Close a transcript sheet too when rotating back to the Video tab.
      navigator.popUntil((candidate) => identical(candidate, route));
      navigator.pop();
    });
  }

  void _restoreDisplay() {
    if (widget.isEmbedded) return;
    if (_hasRestoredDisplay) {
      return;
    }

    _hasRestoredDisplay = true;
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(VideoPlaybackService.setFullscreen(false));
  }

  void _enterFullscreen() {
    if (widget.isEmbedded) return;
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    unawaited(VideoPlaybackService.setFullscreen(true));
  }

  void _attachController(VideoPlayerController controller) {
    _lastObservedPosition = controller.value.position;
    _configureEntryBufferingSuppression(controller);
    controller.addListener(_handleControllerChanged);
    _handleControllerChanged();
  }

  void _detachController(VideoPlayerController controller) {
    controller.removeListener(_handleControllerChanged);
    _entryBufferingSuppressionTimer?.cancel();
    _entryBufferingSuppressionTimer = null;
    _pendingBufferingIndicatorTimer?.cancel();
    _pendingBufferingIndicatorTimer = null;
    _hidePlaybackControlsTimer?.cancel();
    _hidePlaybackControlsTimer = null;
    _wasPlaybackActive = false;
    _isEntryBufferingSuppressed = false;
  }

  void _configureEntryBufferingSuppression(VideoPlayerController controller) {
    _entryBufferingSuppressionTimer?.cancel();
    _entryBufferingSuppressionTimer = null;
    _pendingBufferingIndicatorTimer?.cancel();
    _pendingBufferingIndicatorTimer = null;

    final shouldSuppressBriefly =
        controller.value.isInitialized &&
        (controller.value.isPlaying ||
            controller.value.position > Duration.zero);
    if (!shouldSuppressBriefly) {
      _isEntryBufferingSuppressed = false;
      _showBufferingIndicator.value = false;
      return;
    }

    _isEntryBufferingSuppressed = true;
    _showBufferingIndicator.value = false;
    _entryBufferingSuppressionTimer = Timer(
      _entryBufferingSuppressionDuration,
      () {
        _entryBufferingSuppressionTimer = null;
        _isEntryBufferingSuppressed = false;
        _handleControllerChanged();
      },
    );
  }

  void _handleControllerChanged() {
    _syncPlaybackControls();
    final value = widget.controller.value;
    final position = value.position;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transcriptController?.updatePlaybackPosition(
            widget.controller.value.position,
            animate: _animateTranscript,
          );
        }
      });
    } else {
      _transcriptController?.updatePlaybackPosition(
        position,
        animate: _animateTranscript,
      );
    }
    final hasPositionChanged = position != _lastObservedPosition;
    _lastObservedPosition = position;

    if (hasPositionChanged) {
      _pendingBufferingIndicatorTimer?.cancel();
      _pendingBufferingIndicatorTimer = null;
      if (_showBufferingIndicator.value) {
        _showBufferingIndicator.value = false;
      }
      return;
    }

    final shouldShowIndicator =
        !_isEntryBufferingSuppressed && _shouldShowBufferingIndicator(value);
    if (!shouldShowIndicator) {
      _pendingBufferingIndicatorTimer?.cancel();
      _pendingBufferingIndicatorTimer = null;
      if (_showBufferingIndicator.value) {
        _showBufferingIndicator.value = false;
      }
      return;
    }

    if (_showBufferingIndicator.value ||
        _pendingBufferingIndicatorTimer != null) {
      return;
    }

    final stalledPosition = position;
    _pendingBufferingIndicatorTimer = Timer(_bufferingIndicatorDelay, () {
      _pendingBufferingIndicatorTimer = null;
      final latestValue = widget.controller.value;
      final isStillStalled =
          !_isEntryBufferingSuppressed &&
          latestValue.position == stalledPosition &&
          _shouldShowBufferingIndicator(latestValue);
      if (mounted) {
        _showBufferingIndicator.value = isStillStalled;
      }
    });
  }

  bool _shouldShowBufferingIndicator(VideoPlayerValue value) {
    if (!value.isInitialized || !value.isBuffering || !value.isPlaying) {
      return false;
    }

    final duration = value.duration;
    return duration <= Duration.zero || value.position < duration;
  }

  bool get _isPlaybackActive {
    final value = widget.controller.value;
    return value.isInitialized &&
        value.isPlaying &&
        !value.isCompleted &&
        !value.hasError &&
        (value.duration <= Duration.zero || value.position < value.duration);
  }

  void _syncPlaybackControls() {
    final isPlaying = _isPlaybackActive;
    if (_scrubPositionMillis.value != null) {
      _hidePlaybackControlsTimer?.cancel();
      _showPlaybackControls.value = true;
    } else if (!isPlaying || !_wasPlaybackActive) {
      _hidePlaybackControlsTimer?.cancel();
      _showPlaybackControls.value = !isPlaying;
    }
    _wasPlaybackActive = isPlaying;
  }

  void _revealPlaybackControls() {
    _hidePlaybackControlsTimer?.cancel();
    _hidePlaybackControlsTimer = null;
    _showPlaybackControls.value = true;
    if (_isPlaybackActive && _scrubPositionMillis.value == null) {
      _hidePlaybackControlsTimer = Timer(const Duration(seconds: 3), () {
        _hidePlaybackControlsTimer = null;
        _showPlaybackControls.value = !_isPlaybackActive;
      });
    }
  }

  Future<void> _syncInitialPosition() async {
    if (widget.isEmbedded) return;
    final controller = widget.controller;
    if (!controller.value.isInitialized) {
      return;
    }

    final duration = controller.value.duration;
    final initialPosition = widget.initialPosition;
    if (duration <= Duration.zero || initialPosition <= Duration.zero) {
      return;
    }

    await controller.seekTo(
      initialPosition >= duration ? duration : initialPosition,
    );
  }

  Future<void> _togglePlayback() async {
    final controller = widget.controller;
    if (!controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }

    final duration = controller.value.duration;
    if (duration > Duration.zero && controller.value.position >= duration) {
      await controller.seekTo(Duration.zero);
    }

    unawaited(VideoPlaybackService.prepareAudiblePlaybackAudioSession());
    await controller.play();
  }

  Future<void> _handleSurfaceTap() async {
    await _togglePlayback();
    if (mounted) {
      _revealPlaybackControls();
    }
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = widget.controller;
    if (!controller.value.isInitialized) return;
    _revealPlaybackControls();
    final target = Duration(
      milliseconds: (controller.value.position + offset).inMilliseconds.clamp(
        0,
        controller.value.duration.inMilliseconds,
      ),
    );
    await controller.seekTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _restoreDisplay();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: widget.controller,
          child: widget.video ?? VideoPlayer(widget.controller),
          builder: (context, controllerValue, child) {
            final controller = widget.controller;
            final isReady = controllerValue.isInitialized;

            return ValueListenableBuilder<bool>(
              valueListenable: _showBufferingIndicator,
              builder: (context, showBufferingIndicator, _) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleSurfaceTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: isReady
                            ? AspectRatio(
                                aspectRatio: controllerValue.aspectRatio,
                                child: child ?? VideoPlayer(controller),
                              )
                            : FastCircularProgressIndicator(
                                width: 32,
                                height: 32,
                              ),
                      ),
                      if (isReady &&
                          controllerValue.isBuffering &&
                          showBufferingIndicator)
                        Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: FastCircularProgressIndicator(),
                          ),
                        ),
                      _buildControlsOverlay(controllerValue),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(VideoPlayerValue controllerValue) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final footerBottomInset = isLandscape ? 8.0 : 24.0;
    return ValueListenableBuilder<bool>(
      valueListenable: _showPlaybackControls,
      builder: (context, showControls, _) => SafeArea(
        bottom: !isLandscape,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned(
                left: 8,
                right: 8,
                bottom: footerBottomInset + (showControls ? 0 : 8),
                child: _FullScreenVideoFooter(
                  title: widget.title,
                  showControls: showControls,
                  // Reserve the same room below the center buttons in both
                  // states so caption scrolling never overlaps their targets.
                  maxHeight:
                      (constraints.maxHeight / 2 -
                              ComplianceVideoPlaybackControls
                                      .playButtonDiameter /
                                  2 -
                              8 -
                              footerBottomInset)
                          .clamp(0, double.infinity),
                  controls: ValueListenableBuilder<double?>(
                    valueListenable: _scrubPositionMillis,
                    builder: (context, scrubPosition, _) =>
                        _FullScreenVideoControls(
                          controllerValue: controllerValue,
                          isReady: controllerValue.isInitialized,
                          isScrubbing: scrubPosition != null,
                          scrubPositionMillis: scrubPosition,
                          onExitFullscreen:
                              widget.onExit ??
                              () => Navigator.of(context).pop(),
                          onScrubStart: (value) {
                            _scrubPositionMillis.value = value;
                            _revealPlaybackControls();
                          },
                          onScrubChanged: (value) =>
                              _scrubPositionMillis.value = value,
                          onScrubEnd: (value) async {
                            _scrubPositionMillis.value = null;
                            _revealPlaybackControls();
                            await widget.controller.seekTo(
                              Duration(milliseconds: value.round()),
                            );
                          },
                        ),
                  ),
                ),
              ),
              if (controllerValue.isInitialized)
                Positioned.fill(
                  child: Center(
                    child: _FullScreenControlsVisibility(
                      visible: showControls,
                      child: ComplianceVideoPlaybackControls(
                        isLoading: false,
                        isPlaying: controllerValue.isPlaying,
                        onTogglePlayback: _togglePlayback,
                        onSkipBackward: () =>
                            _seekBy(const Duration(seconds: -10)),
                        onSkipForward: () =>
                            _seekBy(const Duration(seconds: 10)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenControlsVisibility extends StatelessWidget {
  const _FullScreenControlsVisibility({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: visible,
    // Keep layout and state so the footer can move captions into this space.
    maintainSize: true,
    maintainState: true,
    maintainAnimation: true,
    maintainFocusability: false,
    child: child,
  );
}

class _FullScreenControlSurface extends StatelessWidget {
  const _FullScreenControlSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.hex111317.withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _FullScreenVideoFooter extends StatelessWidget {
  const _FullScreenVideoFooter({
    required this.title,
    required this.showControls,
    required this.maxHeight,
    required this.controls,
  });

  final String title;
  final bool showControls;
  final double maxHeight;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final (caption, activeCueIndex) = context
        .select<ComplianceVideoController?, (String?, int?)>(
          (controller) => (
            controller?.hasVisibleActiveTranscript == true
                ? disableAnimations
                      ? controller!.activeTranscriptLine!.text
                      : controller!.activeTranscriptText
                : null,
            controller?.activeTranscriptIndex,
          ),
        );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        key: const ValueKey('fullscreen-video-footer'),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // Hidden controls reserve space above the caption, leaving it in the
          // seek row's place while preserving its viewport and scroll position.
          verticalDirection: showControls
              ? VerticalDirection.down
              : VerticalDirection.up,
          children: [
            if (caption != null) ...[
              Flexible(
                child: Container(
                  key: const ValueKey('fullscreen-active-transcript'),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(activeCueIndex),
                    primary: false,
                    child: AppTextView.body3(
                      caption,
                      color: AppColors.textPrimary,
                      height: 1.4,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            _FullScreenControlsVisibility(
              visible: showControls,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _FullScreenVideoTitleRow(title: title),
              ),
            ),
            const SizedBox(height: 4),
            _FullScreenControlsVisibility(
              visible: showControls,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _FullScreenControlSurface(child: controls),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenVideoTitleRow extends StatelessWidget {
  const _FullScreenVideoTitleRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _FullScreenControlSurface(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: AppTextView.body1(
                    title,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
            child: _FullScreenControlSurface(
              child: ComplianceVideoTranscriptButton(
                onPressed: () => showComplianceVideoTranscriptSheet(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenVideoControls extends StatelessWidget {
  const _FullScreenVideoControls({
    required this.controllerValue,
    required this.isReady,
    required this.isScrubbing,
    required this.scrubPositionMillis,
    required this.onExitFullscreen,
    required this.onScrubStart,
    required this.onScrubChanged,
    required this.onScrubEnd,
  });

  final VideoPlayerValue controllerValue;
  final bool isReady;
  final bool isScrubbing;
  final double? scrubPositionMillis;
  final VoidCallback onExitFullscreen;
  final ValueChanged<double> onScrubStart;
  final ValueChanged<double> onScrubChanged;
  final ValueChanged<double> onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final duration = controllerValue.duration;
    final position = isScrubbing && scrubPositionMillis != null
        ? Duration(milliseconds: scrubPositionMillis!.round())
        : controllerValue.position;
    final maxMillis = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final currentMillis = position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();
    final bufferedMillis = _resolvedBufferedMillis(
      controllerValue,
      maxMillis: maxMillis,
      currentMillis: currentMillis,
    );

    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.secondaryColor,
                secondaryActiveTrackColor: AppColors.textPrimary.withValues(
                  alpha: 0.55,
                ),
                inactiveTrackColor: AppColors.textPrimary.withValues(
                  alpha: 0.35,
                ),
                thumbColor: AppColors.textPrimary,
                overlayColor: AppColors.secondaryColor.withValues(alpha: 0.18),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              ),
              child: Slider(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                value: currentMillis,
                secondaryTrackValue: bufferedMillis,
                min: 0,
                max: maxMillis,
                onChangeStart: !isReady ? null : onScrubStart,
                onChanged: !isReady ? null : onScrubChanged,
                onChangeEnd: !isReady ? null : onScrubEnd,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
            child: AppTextView.body4(
              '${CustomFunctions.formatDuration(position.inSeconds)}/${CustomFunctions.formatDuration(duration.inSeconds)}',
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            key: const ValueKey('video-exit-fullscreen-button'),
            tooltip: AppStrings.trainingExitFullscreen,
            onPressed: onExitFullscreen,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(6),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(
              Icons.fullscreen_exit_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  double? _resolvedBufferedMillis(
    VideoPlayerValue controllerValue, {
    required double maxMillis,
    required double currentMillis,
  }) {
    if (controllerValue.buffered.isEmpty) {
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
}
