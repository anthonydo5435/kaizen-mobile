import '../../../seat_profile/domain/entities/department.dart';
import '../entities/paygrade_detail.dart';
import '../entities/paygrade_page.dart';
import '../entities/shared_paygrades_content.dart';
import '../repositories/paygrade_repository.dart';

class GetPaygradesUseCase {
  const GetPaygradesUseCase(this._repository);

  final PaygradeRepository _repository;

  Future<String?> getPaygradesPublicLink(String jobId) {
    return _repository.getPaygradesPublicLink(jobId);
  }

  Future<String> createPaygradesPublicLink(String jobId) {
    return _repository.createPaygradesPublicLink(jobId);
  }

  Future<void> deletePaygradesPublicLink(String jobId) {
    return _repository.deletePaygradesPublicLink(jobId);
  }

  Future<PaygradePage> call({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String name = '',
    String? title,
    bool forceRefresh = false,
  }) {
    return _repository.getPaygrades(
      page: page,
      pageSize: pageSize,
      departmentId: departmentId,
      name: name,
      title: title,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Department>> getDepartments({required bool isOwner}) {
    return _repository.getDepartments(isOwner: isOwner);
  }

  Future<PaygradeDetail> getPaygradeDetail({
    required String paygradeId,
    required String type,
  }) {
    return _repository.getPaygradeDetail(paygradeId: paygradeId, type: type);
  }

  Future<SharedPaygradesContent> getSharedPaygrades(String publicId) {
    return _repository.getSharedPaygrades(publicId);
  }

  Future<void> generatePaygrades({
    required String actualId,
    required int numPaygrades,
  }) {
    return _repository.generatePaygrades(
      actualId: actualId,
      numPaygrades: numPaygrades,
    );
  }

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
  }) {
    return _repository.createPaygrade(
      jobId: jobId,
      type: type,
      level: level,
      title: title,
      description: description,
      promotionRequirement: promotionRequirement,
      position: position,
      fromSandbox: fromSandbox,
      payRate: payRate,
    );
  }

  Future<void> updatePaygrade({
    required String paygradeId,
    required String title,
    required String description,
    required String promotionRequirement,
    String? payRate,
  }) {
    return _repository.updatePaygrade(
      paygradeId: paygradeId,
      title: title,
      description: description,
      promotionRequirement: promotionRequirement,
      payRate: payRate,
    );
  }

  Future<void> updatePayRate({
    required String paygradeId,
    required String payRate,
  }) {
    return _repository.updatePayRate(paygradeId: paygradeId, payRate: payRate);
  }

  Future<void> deletePaygrade(String paygradeId) {
    return _repository.deletePaygrade(paygradeId);
  }
}
