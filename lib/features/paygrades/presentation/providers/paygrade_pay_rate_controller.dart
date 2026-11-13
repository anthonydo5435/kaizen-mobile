import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/paygrade_detail.dart';
import 'paygrade_detail_controller.dart';

class PaygradePayRateController extends ChangeNotifier {
  PaygradePayRateController({
    required this.entry,
    required PaygradeDetailController detailController,
  }) : _detailController = detailController,
       rateController = TextEditingController(text: entry.payRate) {
    rateController.addListener(_handleChanged);
  }

  final PaygradeEntry entry;
  final PaygradeDetailController _detailController;
  final TextEditingController rateController;
  bool _isSaving = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<bool> save() async {
    if (_isSaving || _isDisposed) return false;
    if (!PaygradeEntry.isValidPayRate(rateController.text)) {
      _errorMessage = AppStrings.paygradesPayRateInvalid;
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _detailController.updatePayRate(
        entry: entry,
        payRate: rateController.text.trim(),
      );
      return true;
    } catch (_) {
      _errorMessage = AppStrings.paygradesPayRateSaveFailed;
      return false;
    } finally {
      _isSaving = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  void _handleChanged() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    rateController
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }
}
