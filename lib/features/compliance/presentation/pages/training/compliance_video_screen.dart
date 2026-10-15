import 'package:flutter/material.dart';

import '../../../domain/entities/compliance_track_item_detail.dart';
import '../../widgets/compliance_video_transcript_panel.dart';

class ComplianceVideoScreen extends StatelessWidget {
  const ComplianceVideoScreen({super.key, required this.detail});

  final ComplianceTrackItemDetail detail;

  @override
  Widget build(BuildContext context) {
    return ComplianceVideoTranscriptPanel(
      videoId: detail.uuid,
      videoUrl: detail.videoUrl,
      title: detail.title,
      transcript: detail.videoTranscript,
      thumbnailLink: detail.videoThumbnailLink,
    );
  }
}
