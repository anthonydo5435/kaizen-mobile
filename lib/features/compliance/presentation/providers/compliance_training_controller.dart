import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/video_playback_service.dart';
import '../../domain/entities/compliance_track_item_detail.dart';
import '../../domain/entities/learning_module_detail_track.dart';
import '../../domain/usecases/get_compliance_track_item_detail_usecase.dart';
import '../../domain/usecases/get_compliance_tracks_usecase.dart';

class ComplianceTrainingController extends ChangeNotifier {
  ComplianceTrainingController(
    this._getComplianceTrackItemDetailUseCase,
    this._getComplianceTracksUseCase,
  );

  final GetComplianceTrackItemDetailUseCase
  _getComplianceTrackItemDetailUseCase;
  final GetComplianceTracksUseCase _getComplianceTracksUseCase;

  bool _isLoading = true;
  ComplianceTrackItemDetail? _detail;
  LearningTrackModuleDetail? _currentTrack;
  int _moduleCount = 0;
  int _currentModuleNumber = 0;
  int _loadGeneration = 0;
  bool _isDisposed = false;
  int _selectedTabIndex = 0;
  bool _isCompletingQuizSubmit = false;
  bool _isVideoRotationActive = false;
  bool _isVideoRotationEnabled = false;
  bool _hasConfiguredOrientation = false;
  bool _isVideoFullscreen = false;
  bool _isWaitingForDevicePortrait = false;
  int _portraitResetGeneration = 0;

  bool get isLoading => _isLoading;
  ComplianceTrackItemDetail? get detail => _detail;
  LearningTrackModuleDetail? get currentTrack => _currentTrack;
  int get moduleCount => _moduleCount;
  int get currentModuleNumber => _currentModuleNumber;
  int get selectedTabIndex => _selectedTabIndex;
  bool get isCompletingQuizSubmit => _isCompletingQuizSubmit;
  bool get canRotateVideo => _isVideoRotationEnabled;

  void selectTab(int index) {
    if (_isDisposed || index == _selectedTabIndex) return;
    _selectedTabIndex = index;
    _updateVideoRotation();
    notifyListeners();
  }

  void setCompletingQuizSubmit(bool value) {
    if (_isDisposed || value == _isCompletingQuizSubmit) return;
    _isCompletingQuizSubmit = value;
    notifyListeners();
  }

  /// Only the owning LTC Video tab may enable device rotation.
  void setVideoRotationActive(bool active) {
    if (_isDisposed) return;
    final wasEnabled = _isVideoRotationEnabled;
    _isVideoRotationActive = active;
    _updateVideoRotation();
    if (_isVideoRotationEnabled != wasEnabled) notifyListeners();
  }

  void _updateVideoRotation() {
    final enabled =
        _isVideoRotationActive &&
        _selectedTabIndex == 0 &&
        !_isLoading &&
        (_detail?.videoUrl?.trim().isNotEmpty ?? false);
    if (_hasConfiguredOrientation && enabled == _isVideoRotationEnabled) return;
    // Controllers used outside the training screen do not own orientation.
    if (!_hasConfiguredOrientation && !_isVideoRotationActive) return;
    _hasConfiguredOrientation = true;
    _isVideoRotationEnabled = enabled;
    if (!enabled) {
      _cancelPortraitReset();
      updateVideoFullscreen(false);
    }
    _requestPreferredOrientations();
  }

  void _requestPreferredOrientations() {
    unawaited(
      SystemChrome.setPreferredOrientations(
        _isVideoRotationEnabled && !_isWaitingForDevicePortrait
            ? const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      ),
    );
  }

  void updateVideoFullscreen(bool fullscreen) {
    if (_isDisposed) return;
    final enabled = fullscreen && _isVideoRotationEnabled;
    if (enabled == _isVideoFullscreen) return;
    _isVideoFullscreen = enabled;
    unawaited(VideoPlaybackService.setFullscreen(enabled));
  }

  Future<void> exitVideoFullscreen() async {
    if (_isDisposed ||
        !_isVideoRotationEnabled ||
        _isWaitingForDevicePortrait) {
      return;
    }
    _isWaitingForDevicePortrait = true;
    final generation = ++_portraitResetGeneration;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    if (_isDisposed || generation != _portraitResetGeneration) return;
    final isPortrait = await VideoPlaybackService.waitForDevicePortrait();
    if (_isDisposed || generation != _portraitResetGeneration || !isPortrait) {
      return;
    }
    _isWaitingForDevicePortrait = false;
    _requestPreferredOrientations();
  }

  void _cancelPortraitReset() {
    if (!_isWaitingForDevicePortrait) return;
    _isWaitingForDevicePortrait = false;
    _portraitResetGeneration++;
    unawaited(VideoPlaybackService.cancelDevicePortraitWait());
  }

  Future<bool> initialize({
    required String trackAssignmentUuid,
    required String itemUuid,
  }) async {
    if (_isDisposed) {
      return false;
    }
    final generation = ++_loadGeneration;
    _isLoading = true;
    _detail = null;
    _currentTrack = null;
    _moduleCount = 0;
    _currentModuleNumber = 0;
    _updateVideoRotation();
    notifyListeners();

    // Both reads can start together; quiz requests do not gate video readiness.
    final detailFuture = _loadDetail(
      trackAssignmentUuid: trackAssignmentUuid,
      itemUuid: itemUuid,
    );
    final tracks = await _loadTracks(trackAssignmentUuid);
    final detail = await detailFuture;
    if (_isDisposed || generation != _loadGeneration) {
      return false;
    }

    final modules = tracks.where((track) => !track.isBreakPoint).toList();
    final index = modules.indexWhere(
      (track) => track.trainingModuleItemId == itemUuid,
    );
    _moduleCount = modules.length;
    if (index >= 0) {
      _currentTrack = modules[index];
      _currentModuleNumber = index + 1;
      _detail = detail;
    }
    _isLoading = false;
    _updateVideoRotation();
    notifyListeners();
    return _detail != null;
  }

  Future<ComplianceTrackItemDetail?> _loadDetail({
    required String trackAssignmentUuid,
    required String itemUuid,
  }) async {
    try {
      return await _getComplianceTrackItemDetailUseCase.call(
        trackAssignmentUuid: trackAssignmentUuid,
        itemUuid: itemUuid,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<LearningTrackModuleDetail>> _loadTracks(
    String trackAssignmentUuid,
  ) async {
    try {
      return await _getComplianceTracksUseCase(
        trackAssignmentUuid: trackAssignmentUuid,
      );
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _cancelPortraitReset();
    if (_isVideoFullscreen) {
      unawaited(VideoPlaybackService.setFullscreen(false));
    }
    if (_hasConfiguredOrientation) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
    _isDisposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
