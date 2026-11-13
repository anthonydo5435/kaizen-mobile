import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../compliance/presentation/pages/document/full_screen_doc.dart';
import '../../../compliance/presentation/pages/training/compliance_full_screen_video_view.dart';
import '../providers/check_in_media_comment_video_controller.dart';

class CheckInMediaCommentsUploadCard extends StatelessWidget {
  const CheckInMediaCommentsUploadCard({
    super.key,
    required this.isUploading,
    required this.onTap,
  });

  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final previewWidth = width > 560 ? 440.0 : width * 0.82;

    return Container(
      width: previewWidth,
      constraints: const BoxConstraints(minHeight: 220),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: CustomPaint(
            painter: const _DashedBorderPainter(
              color: AppColors.hex9b9ead,
              radius: 18,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.mainBg,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppColors.lightPurple1,
                        shape: BoxShape.circle,
                      ),
                      child: isUploading
                          ? Padding(
                              padding: EdgeInsets.all(22),
                              child: FastCircularProgressIndicator(),
                            )
                          : const Icon(
                              Icons.file_upload_outlined,
                              color: Colors.white,
                              size: 34,
                            ),
                    ),
                    const SizedBox(height: 20),
                    AppTextView.body1(
                      isUploading
                          ? AppStrings.auditMediaUploading
                          : AppStrings.auditMediaUploadPrompt,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    AppTextView.body2(
                      AppStrings.auditMediaSupportedFormats,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    AppTextView.body2(
                      AppStrings.trainingVideoMaxFileSize,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;
  static const double _strokeWidth = 1.2;
  static const double _dashWidth = 7;
  static const double _dashSpace = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final nextDistance = distance + _dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, nextDistance.clamp(0, metric.length)),
          Offset.zero,
        );
        distance += _dashWidth + _dashSpace;
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class CheckInMediaCommentsPreview extends StatelessWidget {
  const CheckInMediaCommentsPreview({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
  });

  final String mediaUrl;
  final String? mediaType;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final previewWidth = width > 560 ? 440.0 : width * 0.82;
    final normalizedType = mediaType?.trim().toLowerCase();

    return switch (normalizedType) {
      'video' || 'screen_recording' => _SheetVideoPlayer(
        mediaUrl: mediaUrl,
        width: previewWidth,
        height: 220,
      ),
      'image' => _SheetCachedImage(
        mediaUrl: mediaUrl,
        width: previewWidth,
        height: 220,
      ),
      _ => CheckInMediaCommentsPlaceholder(width: previewWidth, height: 220),
    };
  }
}

class _SheetCachedImage extends StatelessWidget {
  const _SheetCachedImage({
    required this.mediaUrl,
    required this.width,
    required this.height,
  });

  final String mediaUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = CustomFunctions.resolveImageUrl(mediaUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl == null
            ? const CheckInMediaCommentsPlaceholder()
            : InkWell(
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ViewFullScreenDoc(
                      title: AppStrings.auditMediaImage,
                      imageUrl: imageUrl,
                    ),
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const CheckInMediaCommentsPlaceholder(),
                  errorWidget: (_, __, ___) =>
                      const CheckInMediaCommentsPlaceholder(),
                ),
              ),
      ),
    );
  }
}

class _SheetVideoPlayer extends StatefulWidget {
  const _SheetVideoPlayer({
    required this.mediaUrl,
    required this.width,
    required this.height,
  });

  final String mediaUrl;
  final double width;
  final double height;

  @override
  State<_SheetVideoPlayer> createState() => _SheetVideoPlayerState();
}

class _SheetVideoPlayerState extends State<_SheetVideoPlayer> {
  late final CheckInMediaCommentVideoController _playback;

  @override
  void initState() {
    super.initState();
    _playback = CheckInMediaCommentVideoController(widget.mediaUrl);
  }

  @override
  void didUpdateWidget(covariant _SheetVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playback.updateMediaUrl(widget.mediaUrl);
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  Future<void> _openFullScreenVideo() async {
    final controller = _playback.readyPlayer;
    if (controller == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComplianceFullScreenVideoView(
          controller: controller,
          title: '',
          initialPosition: controller.value.position,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _playback,
      builder: (context, _) => _buildPlayer(),
    );
  }

  Widget _buildPlayer() {
    return FutureBuilder<void>(
      future: _playback.initializeFuture,
      builder: (context, snapshot) {
        final controller = _playback.player;
        if (controller == null) {
          return _buildPlayerContent(
            snapshot: snapshot,
            controller: null,
            controllerValue: null,
          );
        }

        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, controllerValue, child) {
            return _buildPlayerContent(
              snapshot: snapshot,
              controller: controller,
              controllerValue: controllerValue,
            );
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
    final initializationError = _playback.initializationError ?? snapshot.error;
    final isReady =
        controller != null &&
        controllerValue?.isInitialized == true &&
        initializationError == null;
    final isBuffering = isReady && (controllerValue?.isBuffering ?? false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isReady)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controllerValue!.size.width,
                  height: controllerValue.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              const SizedBox(),

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.32),
                  ],
                ),
              ),
            ),
            if (isReady)
              Positioned(
                top: 12,
                right: 12,
                child: InkWell(
                  onTap: _openFullScreenVideo,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            if (isReady && isBuffering)
              Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: FastCircularProgressIndicator(),
                ),
              ),
            if (initializationError != null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: AppTextView.body(
                    AppStrings.auditMediaVideoLoadError,
                    color: AppColors.textPrimary,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (isReady)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    InkWell(
                      onTap: _playback.togglePlayback,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              controllerValue!.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            AppTextView.body2(
                              controllerValue.isPlaying
                                  ? AppStrings.auditMediaPause
                                  : AppStrings.auditMediaPlay,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: InkWell(
                  onTap: isReady ? _playback.togglePlayback : null,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: snapshot.connectionState != ConnectionState.done
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: FastCircularProgressIndicator(),
                          )
                        : Icon(
                            controllerValue?.isPlaying ?? false
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CheckInMediaCommentsPlaceholder extends StatelessWidget {
  const CheckInMediaCommentsPlaceholder({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        '${AppStrings.imagePath}no_image.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
