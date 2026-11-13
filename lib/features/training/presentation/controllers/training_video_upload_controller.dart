import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/services/background_media_upload_controller.dart';
import '../../../../core/services/file_uploader.dart';
import '../../data/datasources/training_library_remote_data_source.dart';
import '../../data/repositories/training_library_repository_impl.dart';
import '../../domain/repositories/training_library_repository.dart';
import '../../domain/entities/seat_description_training.dart';

class TrainingVideoUploadTask {
  const TrainingVideoUploadTask._(this._task);

  final BackgroundMediaUploadTask _task;

  static const String _descriptionIdKey = 'descriptionId';
  static const String _moduleIdKey = 'moduleId';
  static const String _moduleTitleKey = 'moduleTitle';

  int get taskId => _task.taskId;
  String get descriptionId => _task.metadata[_descriptionIdKey] ?? '';
  String get moduleId => _task.metadata[_moduleIdKey] ?? '';
  String get moduleTitle => _task.metadata[_moduleTitleKey] ?? '';
  String get sourceFilePath => _task.sourceFilePath;
  String get sourceFileName => _task.sourceFileName;
  String get uploadFilePath => _task.uploadFilePath;
  String get uploadFileName => _task.uploadFileName;
  int get originalSizeBytes => _task.originalSizeBytes;
  int get uploadSizeBytes => _task.uploadSizeBytes;
  double get uploadProgress => _task.uploadProgress;
  bool get usedCompressedFile => _task.usedCompressedFile;
  String? get errorMessage => _task.errorMessage;
  int get terminalEventSequence => _task.terminalEventSequence;

  bool get isActive => _task.isActive;
  bool get isUploading => _task.isUploading;
  bool get isCompleted => _task.isCompleted;
  bool get isFailed => _task.isFailed;
  bool get canCancel => _task.canCancel;
  bool get canDismiss => _task.canDismiss;
  double? get progressValue => _task.progressValue;
  String get localVideoPath => _task.localFilePath;
  String get bannerTitle => _task.bannerTitle;
  String get bannerMessage => _task.bannerMessage;
  String? get bannerDetail => _task.bannerDetail;
  SeatDescriptionTrainingVideo? get uploadedVideo =>
      _task.resultPayloadAs<SeatDescriptionTrainingVideo>();

  static TrainingVideoUploadTask fromBackgroundTask(
    BackgroundMediaUploadTask task,
  ) {
    return TrainingVideoUploadTask._(task);
  }
}

class TrainingVideoUploadSummaryEvent {
  const TrainingVideoUploadSummaryEvent({
    required this.eventSequence,
    required this.descriptionId,
    required this.moduleId,
    required this.summary,
    this.snackBarMessage,
  });

  final int eventSequence;
  final String descriptionId;
  final String moduleId;
  final String? summary;
  final String? snackBarMessage;
}

class TrainingVideoUploadController extends ChangeNotifier {
  TrainingVideoUploadController._({
    TrainingLibraryRepository? trainingRepository,
    FileUploader? fileUploader,
    BackgroundMediaUploadController? backgroundUploadController,
  }) : _trainingRepository =
           trainingRepository ??
           TrainingLibraryRepositoryImpl(TrainingLibraryRemoteDataSource()),
       _fileUploader = fileUploader ?? const FileUploader(),
       _backgroundUploadController =
           backgroundUploadController ??
           BackgroundMediaUploadController.instance {
    _backgroundUploadController.addListener(_handleBackgroundUploadsChanged);
  }

  static final TrainingVideoUploadController instance =
      TrainingVideoUploadController._();

  static final Random _uuidRandom = Random.secure();

  static const String _descriptionIdKey = 'descriptionId';
  static const String _moduleIdKey = 'moduleId';
  static const String _moduleTitleKey = 'moduleTitle';

  final TrainingLibraryRepository _trainingRepository;
  final FileUploader _fileUploader;
  final BackgroundMediaUploadController _backgroundUploadController;
  final List<TrainingVideoUploadSummaryEvent> _summaryEvents =
      <TrainingVideoUploadSummaryEvent>[];
  int _nextSummaryEventSequence = 0;

  String? get startErrorMessage =>
      _backgroundUploadController.startErrorMessage;
  int get latestTerminalEventSequence =>
      _backgroundUploadController.latestTerminalEventSequence;
  int get latestSummaryEventSequence =>
      _summaryEvents.isEmpty ? 0 : _summaryEvents.last.eventSequence;
  bool get isActive => _backgroundUploadController.isActive;
  bool get shouldShowBanner => _backgroundUploadController.shouldShowBanner;

  List<TrainingVideoUploadTask> get visibleTasks => _backgroundUploadController
      .visibleTasks
      .where((task) => task.category == BackgroundMediaUploadCategory.training)
      .map(TrainingVideoUploadTask.fromBackgroundTask)
      .toList(growable: false);

  List<TrainingVideoUploadTask> terminalTasksSince(int eventSequence) {
    return _backgroundUploadController
        .terminalTasksSince(eventSequence)
        .where(
          (task) => task.category == BackgroundMediaUploadCategory.training,
        )
        .map(TrainingVideoUploadTask.fromBackgroundTask)
        .toList(growable: false);
  }

  List<TrainingVideoUploadSummaryEvent> summaryEventsSince(int eventSequence) {
    return _summaryEvents
        .where((event) => event.eventSequence > eventSequence)
        .toList(growable: false);
  }

  bool isUploadActiveForModule({
    required String descriptionId,
    required String moduleId,
  }) {
    final resolvedDescriptionId = descriptionId.trim();
    final resolvedModuleId = moduleId.trim();
    if (resolvedDescriptionId.isEmpty || resolvedModuleId.isEmpty) {
      return false;
    }

    return _backgroundUploadController.isTaskActiveForKey(
      _activeTaskKey(
        descriptionId: resolvedDescriptionId,
        moduleId: resolvedModuleId,
      ),
    );
  }

  Future<bool> startUploadForTrainingModule({
    required String descriptionId,
    required String moduleId,
    required String moduleTitle,
    required File sourceFile,
  }) {
    final resolvedDescriptionId = descriptionId.trim();
    final resolvedModuleId = moduleId.trim();
    if (resolvedDescriptionId.isEmpty || resolvedModuleId.isEmpty) {
      return Future<bool>.value(false);
    }

    return _backgroundUploadController.startUpload(
      BackgroundMediaUploadRequest(
        category: BackgroundMediaUploadCategory.training,
        sourceFile: sourceFile,
        fallbackErrorMessage: AppStrings.trainingVideoUploadFailed,
        errorMessageResolver: (_, fallbackMessage) => fallbackMessage,
        activeTaskKey: _activeTaskKey(
          descriptionId: resolvedDescriptionId,
          moduleId: resolvedModuleId,
        ),
        alreadyInProgressErrorMessage:
            AppStrings.trainingModuleVideoUploadAlreadyInProgress,
        metadata: <String, String>{
          _descriptionIdKey: resolvedDescriptionId,
          _moduleIdKey: resolvedModuleId,
          _moduleTitleKey: moduleTitle.trim(),
        },
        presentation: BackgroundMediaUploadTaskPresentation(
          preparingTitle: AppStrings.trainingPreparingVideoUploadFor(
            _resolvedModuleTitle(moduleTitle),
          ),
          uploadingTitle: AppStrings.trainingUploadingVideoFor(
            _resolvedModuleTitle(moduleTitle),
          ),
          finalizingTitle: AppStrings.trainingFinalizingVideoUploadFor(
            _resolvedModuleTitle(moduleTitle),
          ),
          completedTitle: AppStrings.trainingVideoUploadCompletedTitleFor(
            _resolvedModuleTitle(moduleTitle),
          ),
          failedTitle: AppStrings.trainingVideoUploadFailedTitleFor(
            _resolvedModuleTitle(moduleTitle),
          ),
          subjectLabel: _resolvedModuleTitle(moduleTitle),
          activeDetail: AppStrings.trainingBackgroundUploadContinues,
          finalizingDetail: AppStrings.trainingFinalizingUploadDetail,
          completedDetail: AppStrings.trainingReturnToLessonToAddThumbnail,
        ),
        prepareUpload: (file) =>
            BackgroundMediaUploadPreparedFile.fromSourceFile(
              file,
              fallbackFileName: 'training_video.mp4',
              fallbackContentType: 'video/mp4',
            ),
        createUploadTarget: (preparedFile) async {
          final presignedUpload = await _fileUploader.generatePresignedUpload(
            key: 'lms',
            fileName: preparedFile.uploadFileName,
          );
          return BackgroundMediaUploadTarget(
            uploadUrl: presignedUpload.uploadUrl.trim(),
            fileUrl: presignedUpload.fileUrl?.trim(),
          );
        },
        finalizeUpload: (context) async {
          final uploadUrl = context.uploadTarget.uploadUrl.trim();
          final videoUrl =
              context.uploadTarget.fileUrl?.trim() ??
              _fileUploader.publicUrlFromUploadUrl(uploadUrl);
          final videoDurationInSeconds = await _resolveVideoDurationInSeconds(
            context.preparedFile.uploadFile,
          );
          final uploadedVideo = await _trainingRepository
              .addSeatDescriptionTrainingModuleVideo(
                moduleId: resolvedModuleId,
                videoUuid: _generateClientUuid(),
                title: _buildTrainingVideoTitle(
                  context.preparedFile.uploadFileName,
                ),
                videoUrl: videoUrl,
                duration: videoDurationInSeconds,
              );
          return BackgroundMediaUploadResult(payload: uploadedVideo);
        },
        afterSuccess: (_) => _generateSummaryInBackground(
          descriptionId: resolvedDescriptionId,
          moduleId: resolvedModuleId,
        ),
      ),
    );
  }

  bool cancelUpload(int taskId) {
    return _backgroundUploadController.cancelUpload(taskId);
  }

  void dismissTask(int taskId) {
    _backgroundUploadController.dismissTask(taskId);
  }

  void _handleBackgroundUploadsChanged() {
    notifyListeners();
  }

  String _resolvedModuleTitle(String moduleTitle) {
    final resolved = moduleTitle.trim();
    if (resolved.isNotEmpty) {
      return resolved;
    }

    return AppStrings.trainingUntitledLesson;
  }

  String _activeTaskKey({
    required String descriptionId,
    required String moduleId,
  }) {
    return 'training:$descriptionId:$moduleId';
  }

  Future<void> _generateSummaryInBackground({
    required String descriptionId,
    required String moduleId,
  }) async {
    try {
      final generatedSummary = await _trainingRepository
          .generateSeatDescriptionTrainingModuleSummary(moduleId: moduleId);
      _recordSummaryEvent(
        descriptionId: descriptionId,
        moduleId: moduleId,
        summary: generatedSummary,
      );
    } catch (error) {
      if (error is ApiError && error.statusCode == 404) {
        _recordSummaryEvent(
          descriptionId: descriptionId,
          moduleId: moduleId,
          summary: null,
          snackBarMessage: AppStrings.trainingNoSummaryAvailableSnackBar,
        );
        return;
      }

      debugPrint('Unable to generate training summary: $error');
    }
  }

  void _recordSummaryEvent({
    required String descriptionId,
    required String moduleId,
    String? summary,
    String? snackBarMessage,
  }) {
    _nextSummaryEventSequence++;
    _summaryEvents.add(
      TrainingVideoUploadSummaryEvent(
        eventSequence: _nextSummaryEventSequence,
        descriptionId: descriptionId,
        moduleId: moduleId,
        summary: summary?.trim(),
        snackBarMessage: snackBarMessage?.trim(),
      ),
    );
    if (_summaryEvents.length > 50) {
      _summaryEvents.removeRange(0, _summaryEvents.length - 50);
    }
    notifyListeners();
  }

  Future<int> _resolveVideoDurationInSeconds(File videoFile) async {
    final controller = VideoPlayerController.file(videoFile);
    try {
      await controller.initialize();
      final seconds = controller.value.duration.inSeconds;
      return seconds < 0 ? 0 : seconds;
    } catch (error) {
      debugPrint('Unable to resolve training video duration: $error');
      return 0;
    } finally {
      await controller.dispose();
    }
  }

  String _buildTrainingVideoTitle(String fileName) {
    const maxTrainingVideoTitleLength = 128;
    final trimmedName = fileName.trim();
    if (trimmedName.length <= maxTrainingVideoTitleLength) {
      return trimmedName;
    }

    final extensionIndex = trimmedName.lastIndexOf('.');
    if (extensionIndex <= 0 || extensionIndex >= trimmedName.length - 1) {
      return trimmedName.substring(0, maxTrainingVideoTitleLength);
    }

    final extension = trimmedName.substring(extensionIndex);
    final availableBaseLength = maxTrainingVideoTitleLength - extension.length;
    if (availableBaseLength <= 0) {
      return trimmedName.substring(0, maxTrainingVideoTitleLength);
    }

    final baseName = trimmedName.substring(0, extensionIndex);
    final resolvedBaseLength = availableBaseLength.clamp(0, baseName.length);
    final truncatedBaseName = baseName.substring(0, resolvedBaseLength);
    return '$truncatedBaseName$extension';
  }

  String _generateClientUuid() {
    final bytes = List<int>.generate(
      16,
      (_) => _uuidRandom.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
