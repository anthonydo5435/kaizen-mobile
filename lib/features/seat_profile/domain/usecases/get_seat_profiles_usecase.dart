import '../entities/department.dart';
import '../entities/seat_profile_category_draft.dart';
import '../entities/seat_profile_creation_result.dart';
import '../entities/seat_profile_detail.dart';
import '../entities/seat_profile_page.dart';
import '../repositories/seat_profile_repository.dart';

class GetSeatProfilesUseCase {
  const GetSeatProfilesUseCase(this._repository);

  final SeatProfileRepository _repository;

  Future<String?> getSeatProfilePublicLink(String seatId) {
    return _repository.getSeatProfilePublicLink(seatId);
  }

  Future<String> createSeatProfilePublicLink(String seatId) {
    return _repository.createSeatProfilePublicLink(seatId);
  }

  Future<void> deleteSeatProfilePublicLink(String seatId) {
    return _repository.deleteSeatProfilePublicLink(seatId);
  }

  Future<SeatProfilePage> call({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String title = '',
    bool forceRefresh = false,
  }) {
    return _repository.getSeatProfiles(
      page: page,
      pageSize: pageSize,
      departmentId: departmentId,
      title: title,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Department>> getDepartments() {
    return _repository.getDepartments();
  }

  Future<SeatProfileCreationResult> createSeatProfile({
    required Department department,
    required String title,
    required String paygradeUnit,
  }) {
    return _repository.createSeatProfile(
      department: department,
      title: title,
      paygradeUnit: paygradeUnit,
    );
  }

  Future<void> updateSeatProfile({
    required String seatId,
    required Department department,
    required String title,
    required String paygradeUnit,
  }) {
    return _repository.updateSeatProfile(
      seatId: seatId,
      department: department,
      title: title,
      paygradeUnit: paygradeUnit,
    );
  }

  Future<void> generateSeatProfileJobContent({
    required String actualId,
    String? specificity,
    String? tone,
  }) {
    return _repository.generateSeatProfileJobContent(
      actualId: actualId,
      specificity: specificity,
      tone: tone,
    );
  }

  Future<void> bulkUpsertSeatProfileCategories({
    required String actualId,
    required List<SeatProfileCategoryDraft> categories,
  }) {
    return _repository.bulkUpsertSeatProfileCategories(actualId: actualId, categories: categories);
  }

  Future<void> createSeatProfileDescription({
    required String actualId,
    required String categoryId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  }) {
    return _repository.createSeatProfileDescription(
      actualId: actualId,
      categoryId: categoryId,
      descriptionName: descriptionName,
      auditSpecifics: auditSpecifics,
      auditFactorType: auditFactorType,
      milestoneDays: milestoneDays,
    );
  }

  Future<void> updateSeatProfileDescription({
    required String descriptionId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  }) {
    return _repository.updateSeatProfileDescription(
      descriptionId: descriptionId,
      descriptionName: descriptionName,
      auditSpecifics: auditSpecifics,
      auditFactorType: auditFactorType,
      milestoneDays: milestoneDays,
    );
  }

  Future<void> deleteSeatProfileDescription({required String descriptionId}) {
    return _repository.deleteSeatProfileDescription(descriptionId: descriptionId);
  }

  Future<SeatProfileCreationResult> getSeatProfileJobContent(String actualId) {
    return _repository.getSeatProfileJobContent(actualId);
  }

  Future<SeatProfileDetail> getSeatProfileDetail(String seatId) {
    return _repository.getSeatProfileDetail(seatId);
  }

  Future<SeatProfileDetail> getSharedSeatProfileDetail(String publicId) {
    return _repository.getSharedSeatProfileDetail(publicId);
  }

  Future<List<SeatProfileDetail>> seatProfileCategoryTrainings() {
    return _repository.seatProfileCategoryTrainings();
  }
}
