import 'package:flutter/material.dart';

import '../../../domain/entities/compliance_track_item_detail.dart';
import '../../widgets/compliance_video_transcript_panel.dart';

class ComplianceVideoScreen extends StatelessWidget {
  const ComplianceVideoScreen({
    super.key,
    required this.detail,
    this.fullscreenInLandscape = false,
    this.onExitLandscapeFullscreen,
  });

  final ComplianceTrackItemDetail detail;
  final bool fullscreenInLandscape;
  final VoidCallback? onExitLandscapeFullscreen;

  @override
  Widget build(BuildContext context) {
    return ComplianceVideoTranscriptPanel(
      fullscreenInLandscape: fullscreenInLandscape,
      onExitLandscapeFullscreen: onExitLandscapeFullscreen,
      videoId: detail.uuid,
      videoUrl: detail.videoUrl,
      title: detail.title,
      transcript: detail.videoTranscript,
      thumbnailLink: detail.videoThumbnailLink,
    );
  }
}
