import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../training/domain/entities/seat_description_training_route.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/quarterly_audit.dart';
import 'check_in_controller.dart';
import 'check_in_media_upload_controller.dart';

/// Owns one description's draft, loading and comments while its page is kept alive.
class CheckInSingleDescriptionController extends ChangeNotifier {
  CheckInSingleDescriptionController({
    required CheckInController checkInController,
    required this.audit,
    required this.description,
    required this.date,
    required bool isOwner,
    bool isViewOnly = false,
    bool isSelfAudit = false,
    Map<String, int>? initialRatingCounts,
    AppManager? appManager,
    CheckInMediaUploadController? mediaUploadController,
  }) : _checkInController = checkInController,
       _isOwner = isOwner,
       _isViewOnly = isViewOnly,
       _isSelfAudit = isSelfAudit,
       _hasInitialRatingCounts = initialRatingCounts != null,
       _appManager = appManager ?? AppManager.instance,
       _mediaUploadController =
           mediaUploadController ?? CheckInMediaUploadController.instance {
    _counts = {
      'great': math.max(0, initialRatingCounts?['great'] ?? description.great),
      'almost_there': math.max(
        0,
        initialRatingCounts?['almost_there'] ?? description.almostThere,
      ),
      'needs_improvement': math.max(
        0,
        initialRatingCounts?['needs_improvement'] ??
            description.needsImprovement,
      ),
    };
    _lastHandledUploadSequence =
        _mediaUploadController.latestTerminalEventSequence;
    _mediaUploadController.addListener(_handleMediaUploadChanged);
    _appManager.addListener(_notifyIfActive);
    _auditDescriptionFuture = _loadAuditDescription();
    _initialization = _initialize();
  }

  static const _submitDebounceDuration = Duration(milliseconds: 180);

  final CheckInController _checkInController;
  final QuarterlyAudit audit;
  final QuarterlyAuditDescription description;
  final String date;
  final bool _hasInitialRatingCounts;
  final AppManager _appManager;
  final CheckInMediaUploadController _mediaUploadController;
  bool _isOwner;
  bool _isViewOnly;
  bool _isSelfAudit;
  late Map<String, int> _counts;
  late Future<AuditDescriptionAudit> _auditDescriptionFuture;
  late final Future<void> _initialization;
  AuditDescriptionAudit? _auditDescription;
  bool _isLoading = true;
  bool _hasLoadError = false;
  bool _hasLocalRatingChanges = false;
  bool _isDisposed = false;
  int _loadGeneration = 0;
  late int _lastHandledUploadSequence;
  Timer? _submitDebounceTimer;
  String? _errorMessage;

  Future<void> get ready => _initialization;
  bool get isLoading => _isLoading;
  bool get hasLoadError => _hasLoadError;
  bool get hasLoadedAudit => _auditDescription != null;
  bool get canCreateComments =>
      !_isViewOnly && CustomFunctions.isAuditWithinContinueWindow(date);
  bool get canEditRatings => canCreateComments && _isOwner && !_isSelfAudit;
  bool get canManageComments => canEditRatings;
  bool get showDecrementControl => _isOwner && !_isSelfAudit;
  String get descriptionText => description.description.isEmpty
      ? AppStrings.auditNoDescriptionAvailable
      : description.description;
  String get seatSpecifics => description.jobSpecifics;
  String get auditTypeLabel => description.auditFactorType;
  SeatDescriptionTrainingRoute get trainingRoute => description.trainingRoute;
  bool get canManageTraining =>
      _appManager.canCurrentUserManageTrainingForSeatProfile(
        seatProfileId: trainingRoute.job,
        additionalSeatProfileIds: [audit.jobUuid],
      );
  List<AuditDescriptionMedia> get media =>
      _auditDescription?.auditMedia ?? const [];
  List<CheckInDescriptionCommentData> get comments => media
      .map(CheckInDescriptionCommentData.fromMedia)
      .toList(growable: false);

  List<CheckInDescriptionRatingData> get ratings => [
    _ratingData(
      AuditRating.great,
      AppStrings.auditRatingGreat,
      AppColors.green1,
    ),
    _ratingData(
      AuditRating.almostThere,
      AppStrings.auditRatingAlmostThere,
      AppColors.orange1,
    ),
    _ratingData(
      AuditRating.needsImprovement,
      AppStrings.auditRatingNeedsImprovement,
      AppColors.red1,
    ),
  ];

  int countFor(AuditRating rating) => _counts[rating.apiValue] ?? 0;

  CheckInDescriptionRatingData _ratingData(
    AuditRating rating,
    String label,
    Color color,
  ) => CheckInDescriptionRatingData(
    rating: rating,
    label: label,
    color: color,
    count: countFor(rating),
    hasReachedLimit: !AuditRating.canIncrementCount(countFor(rating)),
  );

  void updateAccess({
    required bool isOwner,
    required bool isViewOnly,
    required bool isSelfAudit,
  }) {
    _isOwner = isOwner;
    _isViewOnly = isViewOnly;
    _isSelfAudit = isSelfAudit;
    _notifyIfActive();
  }

  Future<AuditDescriptionAudit> _loadAuditDescription() =>
      _checkInController.loadAuditDescription(
        quarterlyAuditId: audit.uuid,
        descriptionId: description.uuid,
        date: date,
      );

  Future<void> _initialize() async {
    final generation = _loadGeneration;
    try {
      final response = await _auditDescriptionFuture;
      if (!_isCurrent(generation)) return;
      _applyAudit(response);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _hasLoadError = true;
    } finally {
      if (_isCurrent(generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _applyAudit(AuditDescriptionAudit response) {
    _auditDescription = response;
    _hasLoadError = false;
    // List drafts and later taps take precedence over stale server ratings.
    if (!_hasLocalRatingChanges &&
        !_hasInitialRatingCounts &&
        response.audit.isNotEmpty) {
      _counts = {
        for (final rating in AuditRating.values)
          rating.apiValue: response.audit
              .where((value) => value == rating)
              .length,
      };
    }
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
    _hasLocalRatingChanges = true;
    notifyListeners();
    _submitDebounceTimer?.cancel();
    _submitDebounceTimer = Timer(_submitDebounceDuration, () {
      unawaited(_submitRatings(Map<String, int>.unmodifiable(_counts)));
    });
  }

  Future<void> _submitRatings(Map<String, int> counts) async {
    final descriptionFuture = _auditDescriptionFuture;
    try {
      final descriptionAudit = await descriptionFuture;
      final auditUuid = descriptionAudit.uuid.trim();
      if (auditUuid.isEmpty) return;
      await _checkInController.submitAuditDescriptionSelection(
        quarterlyAuditId: audit.uuid,
        seatDescriptionId: description.uuid,
        descriptionId: auditUuid,
        audit: counts,
      );
    } catch (error) {
      debugPrint('Unable to submit description audit: $error');
      _reportError(AppStrings.auditUnableToUpdateRating);
    }
  }

  Future<String> _resolveAuditUuid() async {
    final response = await _auditDescriptionFuture;
    final uuid = response.uuid.trim();
    if (uuid.isEmpty) throw StateError('Audit description uuid is empty.');
    return uuid;
  }

  Future<void> saveTextComment(String comment) async {
    if (!canCreateComments || comment.trim().isEmpty) return;
    await _checkInController.createAuditDescriptionComment(
      descriptionId: await _resolveAuditUuid(),
      comment: comment.trim(),
    );
    await refreshComments();
  }

  Future<void> saveMediaComment(
    String comment,
    File? mediaFile,
    String? mediaType,
  ) async {
    if (!canCreateComments) return;
    final shouldRefresh = await _checkInController
        .createAuditDescriptionMediaComment(
          descriptionId: await _resolveAuditUuid(),
          comment: comment,
          mediaFile: mediaFile,
          mediaType: mediaType,
        );
    if (shouldRefresh) await refreshComments();
  }

  Future<void> refreshComments() async {
    if (_isDisposed) return;
    final generation = ++_loadGeneration;
    try {
      final response = await _loadAuditDescription();
      if (!_isCurrent(generation)) return;
      _auditDescriptionFuture = Future.value(response);
      _applyAudit(response);
    } catch (_) {
      if (_isCurrent(generation)) _hasLoadError = !hasLoadedAudit;
      rethrow;
    } finally {
      if (_isCurrent(generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _handleMediaUploadChanged() {
    final tasks = _mediaUploadController.terminalTasksSince(
      _lastHandledUploadSequence,
    );
    if (tasks.isEmpty) return;
    _lastHandledUploadSequence = tasks.last.terminalEventSequence;
    var shouldRefresh = false;
    String? failureMessage;
    for (final task in tasks) {
      if (task.flow != CheckInMediaUploadFlow.descriptionComment ||
          (task.descriptionId != description.uuid &&
              task.descriptionId != _auditDescription?.uuid)) {
        continue;
      }
      if (task.isCompleted) {
        shouldRefresh = true;
      } else if (task.isFailed && failureMessage == null) {
        final message = task.errorMessage?.trim();
        if (message != null && message.isNotEmpty) failureMessage = message;
      }
    }
    if (shouldRefresh) unawaited(_refreshAfterUpload());
    if (failureMessage != null) _reportError(failureMessage);
  }

  Future<void> _refreshAfterUpload() async {
    try {
      await refreshComments();
    } catch (_) {
      _reportError(AppStrings.unableToLoadComments);
    }
  }

  void _reportError(String message) {
    if (_isDisposed) return;
    _errorMessage = message;
    notifyListeners();
  }

  String? takeErrorMessage() {
    final message = _errorMessage;
    _errorMessage = null;
    return message;
  }

  bool _isCurrent(int generation) =>
      !_isDisposed && generation == _loadGeneration;

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_submitDebounceTimer?.isActive ?? false) {
      // Preserve the final tap even if the screen closes before debounce fires.
      unawaited(_submitRatings(Map<String, int>.unmodifiable(_counts)));
    }
    _isDisposed = true;
    _submitDebounceTimer?.cancel();
    _mediaUploadController.removeListener(_handleMediaUploadChanged);
    _appManager.removeListener(_notifyIfActive);
    super.dispose();
  }

  static CheckInDescriptionProfileData buildProfileData(
    QuarterlyAudit audit,
    String date,
  ) => CheckInDescriptionProfileData(
    jobTitle: audit.jobTitle,
    profileName: audit.profileName.trim().isEmpty
        ? AppStrings.noProfile
        : audit.profileName,
    lastAuditDate: CustomFunctions.formatDate(date),
    imageUrl: CustomFunctions.resolveImageUrl(audit.profileImage),
  );
}

class CheckInDescriptionProfileData {
  const CheckInDescriptionProfileData({
    required this.jobTitle,
    required this.profileName,
    required this.lastAuditDate,
    required this.imageUrl,
  });

  final String jobTitle;
  final String profileName;
  final String lastAuditDate;
  final String? imageUrl;
}

class CheckInDescriptionRatingData {
  const CheckInDescriptionRatingData({
    required this.rating,
    required this.label,
    required this.color,
    required this.count,
    required this.hasReachedLimit,
  });

  final AuditRating rating;
  final String label;
  final Color color;
  final int count;
  final bool hasReachedLimit;
}

class CheckInDescriptionCommentData {
  CheckInDescriptionCommentData.fromMedia(this.media)
    : comment = media.comment?.trim().isNotEmpty == true
          ? media.comment!.trim()
          : AppStrings.noComment,
      isScreenRecording = media.type.trim().toLowerCase() == 'screen_recording',
      hasMedia =
          const [
            'image',
            'video',
            'screen_recording',
          ].contains(media.type.trim().toLowerCase()) &&
          media.media.trim().isNotEmpty;

  final AuditDescriptionMedia media;
  final String comment;
  final bool isScreenRecording;
  final bool hasMedia;
}
