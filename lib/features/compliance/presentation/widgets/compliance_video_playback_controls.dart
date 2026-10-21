import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/fast_circular_progress.dart';

/// Shared playback actions for the Video tab and its fullscreen view.
class ComplianceVideoPlaybackControls extends StatelessWidget {
  static const playButtonDiameter = 52.0;

  const ComplianceVideoPlaybackControls({
    super.key,
    required this.isLoading,
    required this.isPlaying,
    required this.onTogglePlayback,
    required this.onSkipBackward,
    required this.onSkipForward,
  });

  final bool isLoading;
  final bool isPlaying;
  final VoidCallback? onTogglePlayback;
  final VoidCallback? onSkipBackward;
  final VoidCallback? onSkipForward;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _CircleIconButton(icon: Icons.replay_10_rounded, onTap: onSkipBackward),
      const SizedBox(width: 8),
      _PlayButton(isLoading: isLoading, isPlaying: isPlaying, onTap: onTogglePlayback),
      const SizedBox(width: 8),
      _CircleIconButton(icon: Icons.forward_10_rounded, onTap: onSkipForward),
    ],
  );
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;
  static const double _diameter = 36;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: onTap == null ? AppColors.grey1 : AppColors.textPrimary,
        size: _diameter * 0.7,
      ),
    ),
  );
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isLoading, required this.isPlaying, required this.onTap});

  final bool isLoading;
  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: ComplianceVideoPlaybackControls.playButtonDiameter,
      height: ComplianceVideoPlaybackControls.playButtonDiameter,
      decoration: const BoxDecoration(color: AppColors.secondaryColor, shape: BoxShape.circle),
      child: isLoading
          ? FastCircularProgressIndicator(width: 24, height: 24)
          : Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.textPrimary,
              size: 42,
            ),
    ),
  );
}
