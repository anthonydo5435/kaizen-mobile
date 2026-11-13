import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/training/domain/entities/lms_public_link.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training.dart';
import 'package:sparrowkaizen/features/training/domain/repositories/training_library_repository.dart';

List<SeatDescriptionTrainingModule> shareLessons([int count = 3]) =>
    List.generate(
      count,
      (index) => SeatDescriptionTrainingModule(
        uuid: 'lesson-$index',
        actualId: 'parent-$index',
        title: 'Lesson $index',
        thumbnailLink: null,
        isPubliclyAvailable: false,
      ),
    );

const createdLmsLink = 'https://dev.kaizenteams.ai/shared/lms/public-id';

class ShareRepository extends Fake implements TrainingLibraryRepository {
  final requests = <({String descriptionId, List<String> ids})>[];
  final loadRequests = <String>[];
  final deleteRequests = <String>[];
  LmsPublicLink? existingLink;
  Future<LmsPublicLink?>? pendingLoad;
  Object? loadFailure;
  Object? failure;
  Future<LmsPublicLink>? pending;
  Future<void>? pendingDelete;
  Object? deleteFailure;

  @override
  Future<void> deleteLmsPublicLink(String descriptionId) async {
    deleteRequests.add(descriptionId);
    if (deleteFailure != null) throw deleteFailure!;
    await pendingDelete;
    existingLink = null;
  }

  @override
  Future<LmsPublicLink?> getLmsPublicLink(String descriptionId) async {
    loadRequests.add(descriptionId);
    if (loadFailure != null) throw loadFailure!;
    return pendingLoad ?? existingLink;
  }

  @override
  Future<LmsPublicLink> createLmsPublicLink({
    required String descriptionId,
    required List<String> trainingModuleUuids,
  }) async {
    requests.add((descriptionId: descriptionId, ids: trainingModuleUuids));
    if (failure != null) throw failure!;
    return pending ??
        LmsPublicLink(
          url: createdLmsLink,
          trainingModuleUuids: trainingModuleUuids,
        );
  }
}
