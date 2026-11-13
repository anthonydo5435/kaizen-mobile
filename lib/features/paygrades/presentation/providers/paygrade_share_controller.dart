import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../domain/usecases/get_paygrades_usecase.dart';

class PaygradeShareController extends ChangeNotifier {
  PaygradeShareController(this._useCase, {required this.jobId});

  final GetPaygradesUseCase _useCase;
  final String jobId;
  String? _link;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isWorking = false;
  bool _hasLoaded = false;
  bool _isDisposed = false;

  String? get link => _link;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isWorking => _isWorking;
  bool get hasLoaded => _hasLoaded;
  bool get canManage =>
      jobId.trim().isNotEmpty &&
      AppManager.instance.currentUserCanManagePublicLinks;
  bool get canCreate =>
      canManage && _hasLoaded && !_isLoading && !_isWorking && _link == null;
  bool get canRevoke =>
      canManage && _hasLoaded && !_isLoading && !_isWorking && _link != null;

  Future<void> loadLink() async {
    if (_isDisposed || _isLoading || _isWorking || !canManage) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final link = await _useCase.getPaygradesPublicLink(jobId);
      if (_isDisposed) return;
      _link = link;
      _hasLoaded = true;
    } catch (_) {
      if (_isDisposed) return;
      _hasLoaded = false;
      _errorMessage = AppStrings.shareLoadLinkFailed;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> createLink() async {
    if (_isDisposed || !canCreate) return;
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final link = await _useCase.createPaygradesPublicLink(jobId);
      if (!_isDisposed) _link = link;
    } catch (_) {
      if (!_isDisposed) _errorMessage = AppStrings.shareCreateLinkFailed;
    } finally {
      if (!_isDisposed) {
        _isWorking = false;
        notifyListeners();
      }
    }
  }

  Future<void> revokeLink() async {
    if (_isDisposed || !canRevoke) return;
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _useCase.deletePaygradesPublicLink(jobId);
      if (!_isDisposed) _link = null;
    } catch (_) {
      if (!_isDisposed) _errorMessage = AppStrings.shareRevokeLinkFailed;
    } finally {
      if (!_isDisposed) {
        _isWorking = false;
        notifyListeners();
      }
    }
  }

  Future<bool> copyLink() async {
    final link = _link;
    if (_isDisposed || link == null || _isLoading || _isWorking || !canManage) {
      return false;
    }
    try {
      await Clipboard.setData(ClipboardData(text: link));
      return true;
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = AppStrings.shareCopyLinkFailed;
        notifyListeners();
      }
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
