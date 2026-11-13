import '../entities/department.dart';
import '../entities/seat_profile_category_draft.dart';
import '../entities/seat_profile_creation_result.dart';
import '../entities/seat_profile_detail.dart';
import '../entities/seat_profile_page.dart';

abstract class SeatProfileRepository {
  Future<String?> getSeatProfilePublicLink(String seatId);
  Future<String> createSeatProfilePublicLink(String seatId);
  Future<void> deleteSeatProfilePublicLink(String seatId);

  Future<SeatProfilePage> getSeatProfiles({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String title = '',
    bool forceRefresh = false,
  });
  Future<SeatProfileDetail> getSeatProfileDetail(String seatId);
  Future<SeatProfileDetail> getSharedSeatProfileDetail(String publicId);
  Future<List<Department>> getDepartments();
  Future<SeatProfileCreationResult> createSeatProfile({
    required Department department,
    required String title,
    required String paygradeUnit,
  });
  Future<void> updateSeatProfile({
    required String seatId,
    required Department department,
    required String title,
    required String paygradeUnit,
  });
  Future<void> generateSeatProfileJobContent({
    required String actualId,
    String? specificity,
    String? tone,
  });
  Future<void> bulkUpsertSeatProfileCategories({
    required String actualId,
    required List<SeatProfileCategoryDraft> categories,
  });
  Future<void> createSeatProfileDescription({
    required String actualId,
    required String categoryId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  });
  Future<void> updateSeatProfileDescription({
    required String descriptionId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  });
  Future<void> deleteSeatProfileDescription({required String descriptionId});
  Future<SeatProfileCreationResult> getSeatProfileJobContent(String actualId);
  Future<List<SeatProfileDetail>> seatProfileCategoryTrainings();
}
