import '../../../seat_profile/domain/entities/department.dart';
import '../../domain/entities/paygrade_detail.dart';
import '../../domain/entities/paygrade_page.dart';
import '../../domain/entities/shared_paygrades_content.dart';
import '../../domain/repositories/paygrade_repository.dart';
import '../datasources/paygrade_remote_data_source.dart';

class PaygradeRepositoryImpl implements PaygradeRepository {
  const PaygradeRepositoryImpl(this._remoteDataSource);

  final PaygradeRemoteDataSource _remoteDataSource;

  @override
  Future<String?> getPaygradesPublicLink(String jobId) {
    return _remoteDataSource.getPaygradesPublicLink(jobId);
  }

  @override
  Future<String> createPaygradesPublicLink(String jobId) {
    return _remoteDataSource.createPaygradesPublicLink(jobId);
  }

  @override
  Future<void> deletePaygradesPublicLink(String jobId) {
    return _remoteDataSource.deletePaygradesPublicLink(jobId);
  }

  @override
  Future<PaygradePage> getPaygrades({
    required int page,
    int pageSize = 10,
    String? departmentId,
    String name = '',
    String? title,
    bool forceRefresh = false,
  }) {
    return _remoteDataSource.getPaygrades(
      page: page,
      pageSize: pageSize,
      departmentId: departmentId,
      name: name,
      title: title,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<List<Department>> getDepartments({required bool isOwner}) {
    return _remoteDataSource.getDepartmentsByAccess(isOwner: isOwner);
  }

  @override
  Future<PaygradeDetail> getPaygradeDetail({
    required String paygradeId,
    required String type,
  }) {
    return _remoteDataSource.getPaygradeDetail(
      paygradeId: paygradeId,
      type: type,
    );
  }

  @override
  Future<SharedPaygradesContent> getSharedPaygrades(String publicId) {
    return _remoteDataSource.getSharedPaygrades(publicId);
  }

  @override
  Future<void> generatePaygrades({
    required String actualId,
    required int numPaygrades,
  }) {
    return _remoteDataSource.generatePaygrades(
      actualId: actualId,
      numPaygrades: numPaygrades,
    );
  }

  @override
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
    return _remoteDataSource.createPaygrade(
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

  @override
  Future<void> updatePaygrade({
    required String paygradeId,
    required String title,
    required String description,
    required String promotionRequirement,
    String? payRate,
  }) {
    return _remoteDataSource.updatePaygrade(
      paygradeId: paygradeId,
      title: title,
      description: description,
      promotionRequirement: promotionRequirement,
      payRate: payRate,
    );
  }

  @override
  Future<void> updatePayRate({
    required String paygradeId,
    required String payRate,
  }) {
    return _remoteDataSource.updatePayRate(
      paygradeId: paygradeId,
      payRate: payRate,
    );
  }

  @override
  Future<void> deletePaygrade(String paygradeId) {
    return _remoteDataSource.deletePaygrade(paygradeId);
  }
}
