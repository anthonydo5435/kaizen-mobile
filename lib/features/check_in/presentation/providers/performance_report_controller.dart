import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/utils/app_permission_utils.dart';
import '../../../login/domain/entities/user.dart';
import '../../domain/entities/audit_member.dart';
import '../../domain/entities/audit_profile.dart';
import '../../domain/entities/performance_report.dart';
import '../../domain/usecases/resolve_performance_report_min_date.dart';
import 'check_in_controller.dart';
import 'check_in_state.dart';

/// Owns report presentation state; report writes stay in CheckInController.
class PerformanceReportController extends ChangeNotifier {
  PerformanceReportController({
    required this.checkInController,
    Future<User?> Function()? loadUser,
  }) : _loadUser = loadUser ?? AppPreference.getUser {
    _syncCommitment();
    checkInController.addListener(_onReportChanged);
  }

  static const timeRanges = <String>[
    AppStrings.performanceReportThisQuarter,
    AppStrings.performanceReportCustomDateRange,
  ];

  final CheckInController checkInController;
  final Future<User?> Function() _loadUser;
  final TextEditingController commentsController = TextEditingController();
  int _selectedCategoryIndex = 0;
  String? _categorySelectionKey;
  bool _isCoreValuesExpanded = false;
  bool _canGenerateRemarks = false;
  bool _isDisposed = false;

  CheckInState get state => checkInController.state;
  PerformanceReport? get report => state.performanceReport;
  PerformanceReportViewData? get viewData =>
      checkInController.performanceReportViewData;
  bool get canGenerateRemarks => _canGenerateRemarks;
  bool get isCoreValuesExpanded => _isCoreValuesExpanded;
  // Check-in writes are also available in child organisations.
  bool get isCommitmentReadOnly => report?.isCertified ?? true;
  bool get isCertifying =>
      state.isAuditActionLoading || state.isFacilitatorSignatureUploading;
  int get selectedCategoryIndex =>
      checkInController.resolvePerformanceReportSelectedCategoryIndex(
        selectedCategoryIndex: _selectedCategoryIndex,
        categorySelectionKey: _categorySelectionKey,
      );
  List<PerformanceReportRatingRow> get ratingRows {
    final currentReport = report;
    if (currentReport == null) return const [];
    return currentReport.categoryTabs.isEmpty
        ? currentReport.ratingRows
        : currentReport.categoryTabs[selectedCategoryIndex].rows;
  }

  DateTime get minDate => const ResolvePerformanceReportMinDate()(report);

  Future<void> loadAccess() async {
    final user = await _loadUser();
    if (_isDisposed) return;
    _canGenerateRemarks = AppPermissionUtils.canAccessAuditTeamMembers(user);
    notifyListeners();
  }

  Future<String?> loadFacilitatorSignatureUrl() async =>
      (await _loadUser())?.signature?.image;

  void selectCategory(int index) {
    final currentViewData = viewData;
    if (currentViewData == null ||
        index < 0 ||
        index > currentViewData.maxCategoryIndex) {
      return;
    }
    _selectedCategoryIndex = index;
    _categorySelectionKey = currentViewData.categorySelectionKey;
    notifyListeners();
  }

  void toggleCoreValues() {
    _isCoreValuesExpanded = !_isCoreValuesExpanded;
    notifyListeners();
  }

  void updateCommitment(String value) {
    checkInController.updatePerformanceReportCommitment(value);
    _syncCommitment();
  }

  Future<void> selectProfile(AuditMemberProfile selectedProfile) async {
    final currentReport = report;
    if (state.isPerformanceReportLoading ||
        currentReport == null ||
        selectedProfile.uuid.trim().isEmpty) {
      return;
    }
    _selectedCategoryIndex = 0;
    _categorySelectionKey = null;
    _isCoreValuesExpanded = false;
    await checkInController.initializePerformanceReport(
      _buildSelectedReportProfile(
        currentProfile: currentReport.profile,
        selectedProfile: selectedProfile,
      ),
    );
  }

  void _onReportChanged() {
    _syncCommitment();
    notifyListeners();
  }

  void _syncCommitment() {
    final text = state.performanceReportCommitment;
    if (commentsController.text == text) return;
    commentsController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    checkInController.removeListener(_onReportChanged);
    commentsController.dispose();
    super.dispose();
  }

  AuditProfile _buildSelectedReportProfile({
    required AuditProfile currentProfile,
    required AuditMemberProfile selectedProfile,
  }) {
    final selectedProfileUuid = selectedProfile.uuid.trim();
    final selectedEmail = selectedProfile.email.trim();

    return AuditProfile(
      uuid: selectedProfileUuid,
      profileJob: currentProfile.profileJob,
      profileUuid: selectedProfileUuid,
      email: selectedEmail.isEmpty ? currentProfile.email : selectedEmail,
      imageUrl: selectedProfile.imageUrl,
      isFavorite: currentProfile.isFavorite,
      lastAuditDates: currentProfile.lastAuditDates,
      roleTitle: currentProfile.roleTitle,
      name: selectedProfile.name,
      lastAuditLabel: currentProfile.lastAuditLabel,
      yearQuarter: currentProfile.yearQuarter,
      seatProfile: currentProfile.seatProfile,
      overallScore: currentProfile.overallScore,
      confidenceLevel: currentProfile.confidenceLevel,
      status: currentProfile.status,
      reviewerInitials: currentProfile.reviewerInitials,
      avatarLabel: currentProfile.avatarLabel,
      profiles: currentProfile.profiles,
      avatarImageUrl: selectedProfile.imageUrl,
    );
  }
}
