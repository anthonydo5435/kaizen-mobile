class SeatDescriptionTrainingModule {
  const SeatDescriptionTrainingModule({
    required this.uuid,
    required this.actualId,
    required this.title,
    required this.thumbnailLink,
    required this.isPubliclyAvailable,
  });

  final String uuid;
  final String actualId;
  final String title;
  final String? thumbnailLink;
  final bool isPubliclyAvailable;

  String get resolvedParentModuleId {
    final resolvedActualId = actualId.trim();
    if (resolvedActualId.isNotEmpty) {
      return resolvedActualId;
    }

    return uuid.trim();
  }
}

class SeatDescriptionTrainingModuleDetail {
  const SeatDescriptionTrainingModuleDetail({
    required this.uuid,
    required this.actualId,
    required this.title,
    required this.thumbnails,
    required this.description,
    required this.assignmentTitle,
    required this.assignmentInstructions,
    required this.questions,
    required this.thumbnailLink,
    required this.trainingVideo,
    required this.isPubliclyAvailable,
    required this.learningTrackCount,
  });

  final String uuid;
  final String actualId;
  final String title;
  final List<String> thumbnails;
  final String? description;
  final String? assignmentTitle;
  final String? assignmentInstructions;
  final List<SeatDescriptionTrainingQuestion> questions;
  final String? thumbnailLink;
  final SeatDescriptionTrainingVideo? trainingVideo;
  final bool isPubliclyAvailable;
  final int learningTrackCount;

  String get resolvedParentModuleId {
    final resolvedActualId = actualId.trim();
    if (resolvedActualId.isNotEmpty) {
      return resolvedActualId;
    }

    return uuid.trim();
  }

  String? get previewThumbnailLink {
    if (thumbnailLink != null && thumbnailLink!.trim().isNotEmpty) {
      return thumbnailLink;
    }
    if (thumbnails.isEmpty) {
      return null;
    }
    return thumbnails.first;
  }

  bool get hasAssignmentContent {
    final resolvedTitle = assignmentTitle?.trim() ?? '';
    final resolvedInstructions = assignmentInstructions?.trim() ?? '';
    return resolvedTitle.isNotEmpty || resolvedInstructions.isNotEmpty;
  }
}

class SeatDescriptionTrainingQuestion {
  const SeatDescriptionTrainingQuestion({
    required this.uuid,
    required this.question,
    required this.options,
    required this.selectedOptionUuid,
    required this.imageUrl,
  });

  final String uuid;
  final String question;
  final List<SeatDescriptionTrainingQuestionOption> options;
  final String? selectedOptionUuid;
  final String? imageUrl;
}

class SeatDescriptionTrainingQuestionOption {
  const SeatDescriptionTrainingQuestionOption({
    required this.uuid,
    required this.text,
  });

  final String uuid;
  final String text;
}

class SeatDescriptionTrainingVideo {
  const SeatDescriptionTrainingVideo({
    required this.uuid,
    required this.title,
    required this.url,
    required this.duration,
    required this.transcript,
  });

  final String uuid;
  final String title;
  final String? url;
  final int duration;
  final String? transcript;

  SeatDescriptionTrainingVideo withTranscript(String transcript) =>
      SeatDescriptionTrainingVideo(
        uuid: uuid,
        title: title,
        url: url,
        duration: duration,
        transcript: transcript,
      );
}

class TrainingVideoProcessingJob {
  const TrainingVideoProcessingJob({
    required this.uuid,
    required this.status,
    required this.canRetry,
    this.errorMessage,
  });

  final String uuid;
  final String status;
  final bool canRetry;
  final String? errorMessage;

  bool get isCompleted => status == 'completed' && !canRetry;
  bool get isProcessing =>
      !canRetry && (status == 'pending' || status == 'in_progress');
}

class SeatDescriptionTrainingDocument {
  const SeatDescriptionTrainingDocument({
    required this.uuid,
    required this.text,
  });

  final String uuid;
  final String? text;
}

class SeatDescriptionTrainingAssignment {
  const SeatDescriptionTrainingAssignment({
    required this.uuid,
    required this.title,
    required this.instructions,
  });

  final String uuid;
  final String? title;
  final String? instructions;

  bool get hasContent {
    final resolvedTitle = title?.trim() ?? '';
    final resolvedInstructions = instructions?.trim() ?? '';
    return resolvedTitle.isNotEmpty || resolvedInstructions.isNotEmpty;
  }
}
