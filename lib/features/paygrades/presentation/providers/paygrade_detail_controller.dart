import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../data/datasources/paygrade_remote_data_source.dart';
import '../../data/repositories/paygrade_repository_impl.dart';
import '../../domain/entities/paygrade_detail.dart';
import '../../domain/usecases/get_paygrades_usecase.dart';
import 'paygrade_share_controller.dart';

enum PaygradeDetailTab { primary, ancillary }

class PaygradeDetailController extends ChangeNotifier {
  PaygradeDetailController(this._getPaygradesUseCase);

  final GetPaygradesUseCase _getPaygradesUseCase;

  bool _isLoading = false;
  bool _isGeneratingPaygrades = false;
  bool _isUpdatingPaygrade = false;
  String? _errorMessage;
  String? _paygradeGenerationErrorMessage;
  String? _deletingPaygradeId;
  String _paygradeId = '';
  bool _isShared = false;
  bool _includesPayRates = true;
  int _loadVersion = 0;
  int _detailVersion = 0;
  bool _isDisposed = false;
  PaygradeShareController? _shareController;
  PaygradeDetailTab _selectedTab = PaygradeDetailTab.primary;
  final Map<PaygradeDetailTab, PaygradeDetail> _detailsByTab =
      <PaygradeDetailTab, PaygradeDetail>{};

  bool get isLoading => _isLoading;
  bool get isShared => _isShared;
  bool get includesPayRates => _includesPayRates;
  String get payRateLabel => _isShared
      ? AppStrings.paygradesRateForUnit(detail?.paygradeUnit ?? '')
      : AppStrings.paygradesRate;
  bool get isGeneratingPaygrades => _isGeneratingPaygrades;
  bool get isUpdatingPaygrade => _isUpdatingPaygrade;
  String? get errorMessage => _errorMessage;
  String? get paygradeGenerationErrorMessage => _paygradeGenerationErrorMessage;
  bool get isPrimaryTab => _selectedTab == PaygradeDetailTab.primary;
  PaygradeDetailTab get selectedTab => _selectedTab;
  PaygradeDetail? get detail => _detailsByTab[_selectedTab];
  PaygradeShareController? get shareController => _shareController;

  bool isDeletingPaygrade(String paygradeId) {
    return _deletingPaygradeId == paygradeId;
  }

  bool canEditPayRate(PaygradeEntry entry) {
    return !_isDisposed &&
        !_isShared &&
        _includesPayRates &&
        AppManager.instance.currentUserCanManagePaygrades &&
        !_isLoading &&
        !_isGeneratingPaygrades &&
        !_isUpdatingPaygrade &&
        _deletingPaygradeId == null &&
        entry.id.trim().isNotEmpty &&
        (detail?.payGrades.any((item) => item.id == entry.id) ?? false);
  }

  Future<void> updatePayRate({
    required PaygradeEntry entry,
    required String payRate,
  }) async {
    if (!canEditPayRate(entry)) {
      throw StateError(AppStrings.paygradesPayRateSaveFailed);
    }
    final rate = payRate.trim();
    if (!PaygradeEntry.isValidPayRate(rate)) {
      throw ArgumentError(AppStrings.paygradesPayRateInvalid);
    }

    final tab = _selectedTab;
    final detailVersion = _detailVersion;
    final organizationId = AppManager.instance.currentOrganizationId;
    _isUpdatingPaygrade = true;
    notifyListeners();
    try {
      await _getPaygradesUseCase.updatePayRate(
        paygradeId: entry.id,
        payRate: rate,
      );
      if (_isDisposed ||
          detailVersion != _detailVersion ||
          organizationId != AppManager.instance.currentOrganizationId) {
        return;
      }
      _replaceEntry(
        PaygradeEntry(
          id: entry.id,
          type: entry.type,
          title: entry.title,
          payRate: rate,
          level: entry.level,
          description: entry.description,
          promotionRequirement: entry.promotionRequirement,
        ),
        tab: tab,
      );
    } finally {
      if (!_isDisposed && detailVersion == _detailVersion) {
        _isUpdatingPaygrade = false;
        notifyListeners();
      }
    }
  }

  Future<void> initialize(String paygradeId) async {
    _resetDetail(paygradeId, isShared: false);
    await _loadSelectedTab(forceReload: true);
  }

  Future<void> initializeShared(String publicId) async {
    _resetDetail(publicId, isShared: true);
    await _loadSelectedTab(forceReload: true);
  }

  void _resetDetail(String id, {required bool isShared}) {
    _shareController?.dispose();
    _shareController = null;
    _loadVersion++;
    _detailVersion++;
    _isUpdatingPaygrade = false;
    _paygradeId = id.trim();
    _isShared = isShared;
    _includesPayRates = !isShared;
    _isLoading = false;
    _errorMessage = null;
    _selectedTab = PaygradeDetailTab.primary;
    _detailsByTab.clear();
  }

  Future<void> selectTab(PaygradeDetailTab tab) async {
    if (_selectedTab == tab && _detailsByTab.containsKey(tab)) {
      return;
    }

    _selectedTab = tab;
    notifyListeners();
    await _loadSelectedTab(forceReload: !_detailsByTab.containsKey(tab));
  }

  Future<void> retry() {
    return _loadSelectedTab(forceReload: true);
  }

  Future<bool> generatePaygradesWithAi({required int numPaygrades}) async {
    if (_isShared ||
        _isGeneratingPaygrades ||
        _isUpdatingPaygrade ||
        _deletingPaygradeId != null) {
      return false;
    }

    final currentDetail = detail;
    final resolvedActualId = currentDetail?.id.trim().isNotEmpty == true
        ? currentDetail!.id
        : _paygradeId.trim();
    if (resolvedActualId.isEmpty) {
      return false;
    }

    _isGeneratingPaygrades = true;
    _paygradeGenerationErrorMessage = null;
    _errorMessage = null;
    notifyListeners();

    try {
      await _getPaygradesUseCase.generatePaygrades(
        actualId: resolvedActualId,
        numPaygrades: numPaygrades,
      );
      _detailsByTab.clear();
      await _loadSelectedTab(forceReload: true);
      if (!_detailsByTab.containsKey(_selectedTab)) {
        _paygradeGenerationErrorMessage =
            _errorMessage ?? AppStrings.loginSomethingWentWrong;
        return false;
      }

      return true;
    } catch (error) {
      _paygradeGenerationErrorMessage = error.toString();
      return false;
    } finally {
      _isGeneratingPaygrades = false;
      notifyListeners();
    }
  }

  Future<void> createPaygrade({
    required String title,
    required String description,
    required String promotionRequirement,
    String? payRate,
  }) async {
    if (_isShared ||
        _isGeneratingPaygrades ||
        _isUpdatingPaygrade ||
        _deletingPaygradeId != null) {
      return;
    }

    if (!AppManager.instance.currentUserCanManagePaygrades) {
      throw StateError(AppStrings.paygradesPayRateSaveFailed);
    }
    final trimmedRate = payRate?.trim();
    final rate = trimmedRate == null || trimmedRate.isEmpty
        ? null
        : trimmedRate;
    if (rate != null && !PaygradeEntry.isValidPayRate(rate)) {
      throw ArgumentError(AppStrings.paygradesPayRateInvalid);
    }

    final currentDetail = detail;
    if (currentDetail == null) {
      throw StateError(AppStrings.loginSomethingWentWrong);
    }

    final nextPosition = currentDetail.payGrades.length + 1;
    final nextLevel = _resolveNextLevel(currentDetail.payGrades);

    _isUpdatingPaygrade = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final createdEntry = await _getPaygradesUseCase.createPaygrade(
        jobId: currentDetail.id.trim().isNotEmpty
            ? currentDetail.id
            : _paygradeId,
        type: _selectedTab.apiValue,
        level: nextLevel.toString(),
        title: title,
        description: description,
        promotionRequirement: promotionRequirement,
        position: nextPosition,
        fromSandbox: AppManager.instance.usesParentApiEndpoints,
        payRate: rate,
      );
      if (createdEntry.id.trim().isEmpty) {
        await _loadSelectedTab(forceReload: true);
        return;
      }
      _appendEntry(
        PaygradeEntry(
          id: createdEntry.id,
          type: createdEntry.type.trim().isNotEmpty
              ? createdEntry.type
              : _selectedTab.apiValue,
          title: createdEntry.title.trim().isNotEmpty
              ? createdEntry.title
              : title,
          payRate: createdEntry.payRate.trim().isNotEmpty
              ? createdEntry.payRate
              : rate ?? createdEntry.payRate,
          level: createdEntry.level > 0 ? createdEntry.level : nextLevel,
          description: createdEntry.description.trim().isNotEmpty
              ? createdEntry.description
              : description,
          promotionRequirement:
              createdEntry.promotionRequirement.trim().isNotEmpty
              ? createdEntry.promotionRequirement
              : promotionRequirement,
        ),
      );
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isUpdatingPaygrade = false;
      notifyListeners();
    }
  }

  Future<void> updatePaygrade({
    required PaygradeEntry entry,
    required String title,
    required String description,
    required String promotionRequirement,
    String? payRate,
  }) async {
    if (_isShared) {
      return;
    }
    if (!canEditPayRate(entry)) {
      throw StateError(AppStrings.paygradesPayRateSaveFailed);
    }
    final rate = payRate?.trim();
    if (rate != null && !PaygradeEntry.isValidPayRate(rate)) {
      throw ArgumentError(AppStrings.paygradesPayRateInvalid);
    }

    final tab = _selectedTab;
    final detailVersion = _detailVersion;
    final organizationId = AppManager.instance.currentOrganizationId;
    _isUpdatingPaygrade = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _getPaygradesUseCase.updatePaygrade(
        paygradeId: entry.id,
        title: title,
        description: description,
        promotionRequirement: promotionRequirement,
        payRate: rate,
      );
      if (_isDisposed ||
          detailVersion != _detailVersion ||
          organizationId != AppManager.instance.currentOrganizationId) {
        return;
      }
      _replaceEntry(
        PaygradeEntry(
          id: entry.id,
          type: entry.type,
          title: title,
          payRate: rate ?? entry.payRate,
          level: entry.level,
          description: description,
          promotionRequirement: promotionRequirement,
        ),
        tab: tab,
      );
    } finally {
      if (!_isDisposed && detailVersion == _detailVersion) {
        _isUpdatingPaygrade = false;
        notifyListeners();
      }
    }
  }

  Future<bool> deletePaygrade(PaygradeEntry entry) async {
    if (_isShared ||
        _isGeneratingPaygrades ||
        _isUpdatingPaygrade ||
        _deletingPaygradeId != null) {
      return false;
    }

    _deletingPaygradeId = entry.id;
    _errorMessage = null;
    notifyListeners();

    try {
      await _getPaygradesUseCase.deletePaygrade(entry.id);
      _removeEntry(entry.id);
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _deletingPaygradeId = null;
      notifyListeners();
    }
  }

  Future<void> _loadSelectedTab({required bool forceReload}) async {
    if (_isLoading) {
      return;
    }

    if (_paygradeId.isEmpty) {
      _errorMessage = _isShared
          ? AppStrings.sharedPaygradesUnableToLoad
          : AppStrings.loginSomethingWentWrong;
      notifyListeners();
      return;
    }

    if (!forceReload && _detailsByTab.containsKey(_selectedTab)) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    final loadVersion = ++_loadVersion;
    final selectedTab = _selectedTab;
    notifyListeners();

    try {
      if (_isShared) {
        final content = await _getPaygradesUseCase.getSharedPaygrades(
          _paygradeId,
        );
        if (loadVersion != _loadVersion) return;
        _includesPayRates = content.includesPayRates;
        _detailsByTab[PaygradeDetailTab.primary] = content.primary;
        _detailsByTab[PaygradeDetailTab.ancillary] = content.ancillary;
      } else {
        final detail = await _getPaygradesUseCase.getPaygradeDetail(
          paygradeId: _paygradeId,
          type: selectedTab.apiValue,
        );
        if (loadVersion != _loadVersion) return;
        _detailsByTab[selectedTab] = detail;
        _loadPublicLink(detail);
      }
    } catch (error) {
      if (loadVersion != _loadVersion) return;
      _errorMessage = _isShared
          ? AppStrings.sharedPaygradesUnableToLoad
          : error.toString();
    }

    _isLoading = false;
    notifyListeners();
    if (!_isShared && _selectedTab != selectedTab && _errorMessage == null) {
      await _loadSelectedTab(forceReload: false);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _detailVersion++;
    _loadVersion++;
    _shareController?.dispose();
    super.dispose();
  }

  void _loadPublicLink(PaygradeDetail detail) {
    final jobId = detail.id.trim().isNotEmpty ? detail.id.trim() : _paygradeId;
    if (_shareController?.jobId == jobId) return;
    _shareController?.dispose();
    _shareController = PaygradeShareController(
      _getPaygradesUseCase,
      jobId: jobId,
    );
    unawaited(_shareController!.loadLink());
  }

  void _replaceEntry(PaygradeEntry updatedEntry, {PaygradeDetailTab? tab}) {
    final targetTab = tab ?? _selectedTab;
    final currentDetail = _detailsByTab[targetTab];
    if (currentDetail == null) {
      return;
    }

    final updatedEntries = currentDetail.payGrades
        .map((entry) => entry.id == updatedEntry.id ? updatedEntry : entry)
        .toList(growable: false);

    _detailsByTab[targetTab] = PaygradeDetail(
      id: currentDetail.id,
      title: currentDetail.title,
      paygradeUnit: currentDetail.paygradeUnit,
      department: currentDetail.department,
      payGrades: updatedEntries,
    );
  }

  void _appendEntry(PaygradeEntry entry) {
    final currentDetail = detail;
    if (currentDetail == null) {
      return;
    }

    _detailsByTab[_selectedTab] = PaygradeDetail(
      id: currentDetail.id,
      title: currentDetail.title,
      paygradeUnit: currentDetail.paygradeUnit,
      department: currentDetail.department,
      payGrades: <PaygradeEntry>[...currentDetail.payGrades, entry],
    );
  }

  void _removeEntry(String paygradeId) {
    final currentDetail = detail;
    if (currentDetail == null) {
      return;
    }

    _detailsByTab[_selectedTab] = PaygradeDetail(
      id: currentDetail.id,
      title: currentDetail.title,
      paygradeUnit: currentDetail.paygradeUnit,
      department: currentDetail.department,
      payGrades: currentDetail.payGrades
          .where((entry) => entry.id != paygradeId)
          .toList(growable: false),
    );
  }

  int _resolveNextLevel(List<PaygradeEntry> entries) {
    var highestLevel = 0;
    for (final entry in entries) {
      if (entry.level > highestLevel) {
        highestLevel = entry.level;
      }
    }

    return highestLevel + 1;
  }
}

extension on PaygradeDetailTab {
  String get apiValue {
    return switch (this) {
      PaygradeDetailTab.primary => 'primary',
      PaygradeDetailTab.ancillary => 'ancillary',
    };
  }
}

PaygradeRepositoryImpl createPaygradeDetailRepository(
  PaygradeRemoteDataSource remoteDataSource,
) {
  return PaygradeRepositoryImpl(remoteDataSource);
}

GetPaygradesUseCase createGetPaygradeDetailUseCase(
  PaygradeRepositoryImpl repository,
) {
  return GetPaygradesUseCase(repository);
}
