import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/quarterly_audit.dart';
import 'check_in_controller.dart';

/// Owns a list card's rating draft and resolves its audit description for writes.
class CheckInDescriptionCardController extends ChangeNotifier {
  CheckInDescriptionCardController({
    required CheckInController checkInController,
    required QuarterlyAudit audit,
    required QuarterlyAuditDescription description,
    required String date,
    required bool isOwner,
    required bool isSelfAudit,
  }) : _checkInController = checkInController,
       _audit = audit,
       _description = description,
       _date = date,
       _isOwner = isOwner,
       _isSelfAudit = isSelfAudit {
    _resetRatings();
  }

  static const _submitDebounceDuration = Duration(milliseconds: 180);

  final CheckInController _checkInController;
  QuarterlyAudit _audit;
  QuarterlyAuditDescription _description;
  String _date;
  bool _isOwner;
  bool _isSelfAudit;
  late Map<String, int> _counts;
  late Map<String, int> _lastSyncedCounts;
  bool _hasLocalChanges = false;
  bool _isOpeningDetails = false;
  bool _isDisposed = false;
  int _generation = 0;
  int _editRevision = 0;
  Timer? _submitDebounceTimer;
  Future<AuditDescriptionAudit>? _auditDescriptionFuture;
  Future<void>? _ratingSubmission;
  String? _errorMessage;

  bool get isOpeningDetails => _isOpeningDetails;
  bool get showDecrementControl => _isOwner && !_isSelfAudit;
  bool get canEditRatings => canCreateComments && _isOwner && !_isSelfAudit;
  bool get canCreateComments =>
      !_audit.isMismatch && CustomFunctions.isAuditWithinContinueWindow(_date);

  String get descriptionText => _description.description.isEmpty
      ? AppStrings.auditNoDescriptionAvailable
      : _description.description;

  String get auditTypeLabel {
    final label = CustomFunctions.capitalizeFirstLetter(
      _description.auditFactorType,
    );
    return label.isEmpty ? AppStrings.checkInTitle : label;
  }

  String? get milestoneLabel {
    final milestone = CustomFunctions.normalizeAuditMilestone(
      _description.milestoneDay,
    );
    return AppStrings.auditMilestoneOptions.contains(milestone)
        ? AppStrings.auditMilestoneCardLabel(milestone)
        : null;
  }

  int countFor(AuditRating rating) => _counts[rating.apiValue] ?? 0;

  String? takeErrorMessage() {
    final message = _errorMessage;
    _errorMessage = null;
    return message;
  }

  void update({
    required QuarterlyAudit audit,
    required QuarterlyAuditDescription description,
    required String date,
    required bool isOwner,
    required bool isSelfAudit,
  }) {
    final identityChanged =
        _audit.uuid != audit.uuid ||
        _description.uuid != description.uuid ||
        _date != date;
    _audit = audit;
    _description = description;
    _date = date;
    _isOwner = isOwner;
    _isSelfAudit = isSelfAudit;

    if (identityChanged) {
      _generation += 1;
      _submitDebounceTimer?.cancel();
      _auditDescriptionFuture = null;
      _ratingSubmission = null;
      _isOpeningDetails = false;
      _errorMessage = null;
      _editRevision = 0;
      _resetRatings();
    } else if (!_hasLocalChanges) {
      _resetRatings();
    }
    notifyListeners();
  }

  void incrementRating(AuditRating rating) {
    if (!canEditRatings || !AuditRating.canIncrementCount(countFor(rating))) {
      return;
    }
    _changeRating(rating, countFor(rating) + 1);
  }

  void decrementRating(AuditRating rating) {
    if (!canEditRatings || countFor(rating) <= 0) return;
    _changeRating(rating, countFor(rating) - 1);
  }

  void _changeRating(AuditRating rating, int count) {
    _counts = {..._counts, rating.apiValue: count};
    _editRevision += 1;
    _hasLocalChanges = true;
    notifyListeners();
    _submitDebounceTimer?.cancel();
    _submitDebounceTimer = Timer(_submitDebounceDuration, () {
      unawaited(_submitRatings());
    });
  }

  /// Flush the card draft before the detail screen edits the same description.
  Future<Map<String, int>?> prepareForDetails() async {
    if (_isOpeningDetails || _isDisposed) return null;
    final generation = _generation;
    _isOpeningDetails = true;
    notifyListeners();
    try {
      _submitDebounceTimer?.cancel();
      await _ratingSubmission;
      if (!_isCurrent(generation)) return null;
      if (_hasLocalChanges) await _submitRatings();
      if (!_isCurrent(generation)) return null;
      return Map<String, int>.unmodifiable(_counts);
    } finally {
      if (_isCurrent(generation)) {
        _isOpeningDetails = false;
        notifyListeners();
      }
    }
  }

  Future<void> _submitRatings() {
    final submission = _saveRatings(
      Map<String, int>.unmodifiable(_counts),
      _editRevision,
      _generation,
    );
    _ratingSubmission = submission;
    return submission;
  }

  Future<void> _saveRatings(
    Map<String, int> counts,
    int revision,
    int generation,
  ) async {
    final quarterlyAuditId = _audit.uuid;
    final seatDescriptionId = _description.uuid;
    try {
      final auditUuid = await resolveAuditUuid();
      final response = await _checkInController.submitAuditDescriptionSelection(
        quarterlyAuditId: quarterlyAuditId,
        seatDescriptionId: seatDescriptionId,
        descriptionId: auditUuid,
        audit: counts,
      );
      if (!_isCurrent(generation)) return;

      // PATCH responses can omit ratings; retain the payload the API accepted.
      _lastSyncedCounts = counts;
      _auditDescriptionFuture = Future.value(response);
      if (revision != _editRevision) return;
      _counts = Map.of(counts);
      _hasLocalChanges = false;
      notifyListeners();
    } catch (error) {
      debugPrint('Unable to submit description audit from list: $error');
      if (!_isCurrent(generation) || revision != _editRevision) return;
      _counts = Map.of(_lastSyncedCounts);
      _hasLocalChanges = false;
      _errorMessage = AppStrings.auditUnableToUpdateRating;
      notifyListeners();
    }
  }

  Future<String> resolveAuditUuid() async {
    final auditUuid = _description.auditUuid.trim();
    if (auditUuid.isNotEmpty) return auditUuid;
    final auditDescription =
        await (_auditDescriptionFuture ?? _loadAuditDescription());
    final resolvedUuid = auditDescription.uuid.trim();
    if (resolvedUuid.isEmpty) {
      throw StateError('Audit description uuid is empty.');
    }
    return resolvedUuid;
  }

  Future<AuditDescriptionAudit> _loadAuditDescription() async {
    final quarterlyAuditId = _audit.uuid.trim();
    final descriptionId = _description.uuid.trim();
    final date = _date.trim();
    if (quarterlyAuditId.isEmpty || descriptionId.isEmpty || date.isEmpty) {
      throw StateError('Audit description is missing required identifiers.');
    }
    final generation = _generation;
    final request = _checkInController.loadAuditDescription(
      quarterlyAuditId: quarterlyAuditId,
      descriptionId: descriptionId,
      date: date,
    );
    _auditDescriptionFuture = request;
    try {
      final response = await request;
      if (_isCurrent(generation)) {
        _auditDescriptionFuture = Future.value(response);
      }
      return response;
    } catch (_) {
      if (_isCurrent(generation)) _auditDescriptionFuture = null;
      rethrow;
    }
  }

  Future<void> saveTextComment(String comment) async {
    await _checkInController.createAuditDescriptionComment(
      descriptionId: await resolveAuditUuid(),
      comment: comment,
    );
  }

  Future<void> saveMediaComment(
    String comment,
    File? mediaFile,
    String? mediaType,
  ) async {
    await _checkInController.createAuditDescriptionMediaComment(
      descriptionId: await resolveAuditUuid(),
      comment: comment,
      mediaFile: mediaFile,
      mediaType: mediaType,
    );
  }

  void _resetRatings() {
    _lastSyncedCounts = {
      'great': _description.great,
      'almost_there': _description.almostThere,
      'needs_improvement': _description.needsImprovement,
    };
    _counts = Map.of(_lastSyncedCounts);
    _hasLocalChanges = false;
  }

  bool _isCurrent(int generation) => !_isDisposed && generation == _generation;

  @override
  void dispose() {
    _isDisposed = true;
    _submitDebounceTimer?.cancel();
    super.dispose();
  }
}
