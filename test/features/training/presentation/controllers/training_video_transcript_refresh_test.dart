import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/services/file_uploader.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
// Use the existing native player interface for upload duration inspection.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TranscriptRepository repository;
  late TrainingModuleController controller;

  setUp(() async {
    repository = _TranscriptRepository();
    controller = TrainingModuleController(
      repository,
      canManageTraining: true,
      fileUploader: _FileUploader(),
    );
    await controller.initialize(jobId: 'seat', descriptionId: 'description');
  });
  tearDown(() => controller.dispose());

  void applyUpload(String videoId) => controller.applyBackgroundUploadedVideo(
    moduleId: 'first',
    video: _video(videoId),
    localVideoPath: '/local/$videoId.mp4',
  );

  test(
    'delete and continue uploads the replacement and refreshes after processing',
    () async {
      final originalPlatform = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = _VideoPlatform();
      final directory = Directory.systemTemp.createTempSync(
        'training-transcript-upload-',
      );
      addTearDown(() {
        VideoPlayerPlatform.instance = originalPlatform;
        directory.deleteSync(recursive: true);
      });
      final file = File('${directory.path}/replacement.mp4')
        ..writeAsBytesSync([0]);
      expect(await controller.deleteVideoForSelectedModule(), isTrue);
      expect(await controller.uploadVideoForSelectedModule(file), isTrue);
      expect(repository.refreshes, isEmpty);
      expect(controller.isCheckingSelectedVideoProcessing, isTrue);
      expect(controller.hasSelectedModuleVideoTranscript, isFalse);
      repository.uploadedJob.complete(_completedJob);
      await Future<void>.delayed(Duration.zero);
      expect(repository.checkedVideoIds, ['original-first', 'uploaded']);
      repository.refreshes.single.response.complete(
        _detail(
          'first',
          _video('uploaded', transcript: '[00:00] Replacement transcript'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.selectedModuleDetail!.trainingVideo!.transcript,
        '[00:00] Replacement transcript',
      );
      expect(controller.summaryController.text, 'Server summary');
      expect(controller.selectedModuleLocalVideoPath, file.path);
      expect(controller.isCheckingSelectedVideoProcessing, isFalse);
      expect(repository.legacyGenerationRequests, 0);
    },
  );

  test(
    'background upload refreshes the summary and transcript without replacing the title draft',
    () async {
      applyUpload('uploaded');
      repository.uploadedJob.complete(_completedJob);
      await Future<void>.delayed(Duration.zero);
      expect(repository.refreshes, hasLength(1));
      controller.moduleTitleController.text = 'Unsaved title';
      repository.refreshes.single.response.complete(
        _detail(
          'first',
          _video('uploaded', transcript: '[00:00] New transcript'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasSelectedModuleVideoTranscript, isTrue);
      expect(
        controller.selectedModuleDetail!.trainingVideo!.transcript,
        '[00:00] New transcript',
      );
      expect(controller.selectedModuleLocalVideoPath, '/local/uploaded.mp4');
      expect(controller.moduleTitleController.text, 'Unsaved title');
      expect(controller.summaryController.text, 'Server summary');
    },
  );

  test('loading another lesson ignores an unfinished job lookup', () async {
    applyUpload('uploaded');
    await controller.selectModule('second');
    repository.uploadedJob.complete(_completedJob);
    await Future<void>.delayed(Duration.zero);
    expect(repository.refreshes, isEmpty);
    expect(
      controller.selectedModuleDetail!.trainingVideo!.uuid,
      'original-second',
    );
  });

  test(
    'a refresh for the previous lesson cannot replace the current video',
    () async {
      applyUpload('uploaded');
      repository.uploadedJob.complete(_completedJob);
      await Future<void>.delayed(Duration.zero);
      await controller.selectModule('second');
      repository.refreshes.single.response.complete(
        _detail(
          'first',
          _video('uploaded', transcript: '[00:00] Stale lesson'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.selectedModuleId, 'second');
      expect(
        controller.selectedModuleDetail!.trainingVideo!.uuid,
        'original-second',
      );
      expect(
        controller.selectedModuleDetail!.trainingVideo!.transcript,
        '[00:00] Original',
      );
    },
  );

  test(
    'an earlier replacement cannot attach its transcript to the new video',
    () async {
      applyUpload('earlier');
      await Future<void>.delayed(Duration.zero);
      applyUpload('latest');
      await Future<void>.delayed(Duration.zero);
      repository.refreshes.first.response.complete(
        _detail('first', _video('earlier', transcript: '[00:00] Stale video')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.hasSelectedModuleVideoTranscript, isFalse);
      repository.refreshes.last.response.complete(
        _detail('first', _video('latest', transcript: '[00:00] Latest video')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.selectedModuleDetail!.trainingVideo!.transcript,
        '[00:00] Latest video',
      );
      expect(controller.selectedModuleLocalVideoPath, '/local/latest.mp4');
    },
  );
}

SeatDescriptionTrainingVideo _video(String id, {String? transcript}) =>
    SeatDescriptionTrainingVideo(
      uuid: id,
      title: 'Video',
      url: 'https://example.test/$id.mp4',
      duration: 60,
      transcript: transcript,
    );

const _completedJob = TrainingVideoProcessingJob(
  uuid: 'job',
  status: 'completed',
  canRetry: false,
);

SeatDescriptionTrainingModuleDetail _detail(
  String id,
  SeatDescriptionTrainingVideo? video,
) => SeatDescriptionTrainingModuleDetail(
  uuid: id,
  actualId: id,
  title: 'Lesson',
  thumbnails: const [],
  description: 'Server summary',
  assignmentTitle: null,
  assignmentInstructions: null,
  questions: const [],
  thumbnailLink: null,
  trainingVideo: video,
  isPubliclyAvailable: false,
  learningTrackCount: 0,
);

class _TranscriptRepository extends Fake implements TrainingLibraryRepository {
  final uploadedJob = Completer<TrainingVideoProcessingJob>();
  final checkedVideoIds = <String>[];
  int legacyGenerationRequests = 0;
  final videos = <String, SeatDescriptionTrainingVideo?>{
    for (final id in ['first', 'second'])
      id: _video('original-$id', transcript: '[00:00] Original'),
  };
  final refreshes =
      <
        ({
          String moduleId,
          Completer<SeatDescriptionTrainingModuleDetail> response,
        })
      >[];

  @override
  Future<List<SeatDescriptionTrainingModule>>
  getSeatDescriptionTrainingModules({
    required String descriptionId,
    bool forceRefresh = false,
  }) async => ['first', 'second']
      .map(
        (id) => SeatDescriptionTrainingModule(
          uuid: id,
          actualId: id,
          title: 'Lesson',
          thumbnailLink: null,
          isPubliclyAvailable: false,
        ),
      )
      .toList();

  @override
  Future<SeatDescriptionTrainingModuleDetail>
  getSeatDescriptionTrainingModuleDetail({
    required String moduleId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      return _detail(moduleId, videos[moduleId]);
    }
    final response = Completer<SeatDescriptionTrainingModuleDetail>();
    refreshes.add((moduleId: moduleId, response: response));
    return response.future;
  }

  @override
  Future<void> deleteSeatDescriptionTrainingModuleVideo({
    required String videoId,
  }) async {
    videos['first'] = null;
  }

  @override
  Future<SeatDescriptionTrainingVideo> addSeatDescriptionTrainingModuleVideo({
    required String moduleId,
    required String videoUuid,
    required String title,
    required String videoUrl,
    required int duration,
  }) async {
    final video = _video('uploaded');
    videos[moduleId] = video;
    return video;
  }

  @override
  Future<TrainingVideoProcessingJob?> getLatestVideoProcessingJob({
    required String videoId,
  }) async {
    checkedVideoIds.add(videoId);
    if (videoId.startsWith('original-')) return null;
    if (videoId == 'uploaded') return uploadedJob.future;
    return _completedJob;
  }

  @override
  Future<String?> generateSeatDescriptionTrainingModuleSummary({
    required String moduleId,
  }) async {
    legacyGenerationRequests++;
    return null;
  }
}

class _FileUploader extends Fake implements FileUploader {
  @override
  Future<PresignedFileUpload> generatePresignedUpload({
    required String key,
    required String fileName,
    String? authToken,
  }) async => const PresignedFileUpload(
    uploadUrl: 'https://example.test/upload',
    fileUrl: 'https://example.test/uploaded.mp4',
  );

  @override
  Future<void> uploadBinaryFile({
    required String uploadUrl,
    required List<int> fileBytes,
    required String contentType,
    void Function(double)? onProgress,
    Object? cancellationToken,
  }) async {}
}

class _VideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 60),
        size: const Size(640, 360),
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> dispose(int playerId) async => events.close();
}
