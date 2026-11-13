import '../../domain/entities/department.dart';
import '../../domain/entities/seat_profile_category_draft.dart';
import '../../domain/entities/seat_profile_creation_result.dart';
import '../../domain/entities/seat_profile_detail.dart';
import '../../domain/entities/seat_profile_page.dart';
import '../../domain/repositories/seat_profile_repository.dart';
import '../datasources/seat_profile_remote_data_source.dart';

class SeatProfileRepositoryImpl implements SeatProfileRepository {
  const SeatProfileRepositoryImpl(this._remoteDataSource);

  final SeatProfileRemoteDataSource _remoteDataSource;

  @override
  Future<String?> getSeatProfilePublicLink(String seatId) {
    return _remoteDataSource.getSeatProfilePublicLink(seatId);
  }

  @override
  Future<String> createSeatProfilePublicLink(String seatId) {
    return _remoteDataSource.createSeatProfilePublicLink(seatId);
  }

  @override
  Future<void> deleteSeatProfilePublicLink(String seatId) {
    return _remoteDataSource.deleteSeatProfilePublicLink(seatId);
  }

  @override
  Future<SeatProfilePage> getSeatProfiles({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String title = '',
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getSeatProfiles(
      page: page,
      pageSize: pageSize,
      departmentId: departmentId,
      title: title,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<SeatProfileDetail> getSeatProfileDetail(String seatId) {
    return _remoteDataSource.getSeatProfileDetail(seatId);
  }

  @override
  Future<SeatProfileDetail> getSharedSeatProfileDetail(String publicId) {
    return _remoteDataSource.getSharedSeatProfileDetail(publicId);
  }

  @override
  Future<List<Department>> getDepartments() {
    return _remoteDataSource.getDepartments();
  }

  @override
  Future<SeatProfileCreationResult> createSeatProfile({
    required Department department,
    required String title,
    required String paygradeUnit,
  }) {
    return _remoteDataSource.createSeatProfile(
      department: department,
      title: title,
      paygradeUnit: paygradeUnit,
    );
  }

  @override
  Future<void> updateSeatProfile({
    required String seatId,
    required Department department,
    required String title,
    required String paygradeUnit,
  }) {
    return _remoteDataSource.updateSeatProfile(
      seatId: seatId,
      department: department,
      title: title,
      paygradeUnit: paygradeUnit,
    );
  }

  @override
  Future<void> generateSeatProfileJobContent({
    required String actualId,
    String? specificity,
    String? tone,
  }) {
    return _remoteDataSource.generateSeatProfileJobContent(
      actualId: actualId,
      specificity: specificity,
      tone: tone,
    );
  }

  @override
  Future<void> bulkUpsertSeatProfileCategories({
    required String actualId,
    required List<SeatProfileCategoryDraft> categories,
  }) {
    return _remoteDataSource.bulkUpsertSeatProfileCategories(
      actualId: actualId,
      categories: categories,
    );
  }

  @override
  Future<void> createSeatProfileDescription({
    required String actualId,
    required String categoryId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  }) {
    return _remoteDataSource.createSeatProfileDescription(
      actualId: actualId,
      categoryId: categoryId,
      descriptionName: descriptionName,
      auditSpecifics: auditSpecifics,
      auditFactorType: auditFactorType,
      milestoneDays: milestoneDays,
    );
  }

  @override
  Future<void> updateSeatProfileDescription({
    required String descriptionId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  }) {
    return _remoteDataSource.updateSeatProfileDescription(
      descriptionId: descriptionId,
      descriptionName: descriptionName,
      auditSpecifics: auditSpecifics,
      auditFactorType: auditFactorType,
      milestoneDays: milestoneDays,
    );
  }

  @override
  Future<void> deleteSeatProfileDescription({required String descriptionId}) {
    return _remoteDataSource.deleteSeatProfileDescription(
      descriptionId: descriptionId,
    );
  }

  @override
  Future<SeatProfileCreationResult> getSeatProfileJobContent(String actualId) {
    return _remoteDataSource.getSeatProfileJobContent(actualId);
  }

  @override
  Future<List<SeatProfileDetail>> seatProfileCategoryTrainings() {
    return _remoteDataSource.getSeatProfileCategoryTrainings();
  }
}
