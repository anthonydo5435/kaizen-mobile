import '../../../seat_profile/domain/entities/department.dart';
import '../entities/paygrade_detail.dart';
import '../entities/paygrade_page.dart';
import '../entities/shared_paygrades_content.dart';

abstract class PaygradeRepository {
  Future<String?> getPaygradesPublicLink(String jobId);
  Future<String> createPaygradesPublicLink(String jobId);
  Future<void> deletePaygradesPublicLink(String jobId);

  Future<PaygradePage> getPaygrades({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String name = '',
    String? title,
    bool forceRefresh = false,
  });

  Future<List<Department>> getDepartments({required bool isOwner});
  Future<PaygradeDetail> getPaygradeDetail({
    required String paygradeId,
    required String type,
  });

  Future<SharedPaygradesContent> getSharedPaygrades(String publicId);

  Future<void> generatePaygrades({
    required String actualId,
    required int numPaygrades,
  });

  Future<PaygradeEntry> createPaygrade({
    required String jobId,
    required String type,
    required String level,
    required String title,
    required String description,
    required String promotionRequirement,
    required int position,
    required bool fromSandbox,
    String? payRate,
  });

  Future<void> updatePaygrade({
    required String paygradeId,
    required String title,
    required String description,
    required String promotionRequirement,
    String? payRate,
  });

  Future<void> updatePayRate({
    required String paygradeId,
    required String payRate,
  });

  Future<void> deletePaygrade(String paygradeId);
}
