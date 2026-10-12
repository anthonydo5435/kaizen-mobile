import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/repositories/compliance_document_media_repository.dart';
import '../../domain/usecases/pick_compliance_document_file_usecase.dart';

class ComplianceDocumentMediaController extends ChangeNotifier {
  ComplianceDocumentMediaController(this._pickFileUseCase);

  final PickComplianceDocumentFileUseCase _pickFileUseCase;
  File? _selectedFile;
  bool _isPicking = false;
  bool _isDisposed = false;
  String? _errorMessage;

  File? get selectedFile => _selectedFile;
  bool get isPicking => _isPicking;
  String? get errorMessage => _errorMessage;

  Future<void> pickFile(ComplianceDocumentFileSource source) async {
    if (_isDisposed || _isPicking) {
      return;
    }
    _isPicking = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final path = await _pickFileUseCase(source);
      if (!_isDisposed && path != null) {
        _selectedFile = File(path);
      }
    } on PlatformException catch (error) {
      if (!_isDisposed) {
        final code = error.code.toLowerCase();
        _errorMessage =
            source == ComplianceDocumentFileSource.camera &&
                code.contains('camera') &&
                (code.contains('denied') || code.contains('restricted'))
            ? AppStrings.complianceCameraPermissionRequired
            : _pickError(source);
      }
    } catch (_) {
      if (!_isDisposed) {
        _errorMessage = _pickError(source);
      }
    } finally {
      if (!_isDisposed) {
        _isPicking = false;
        notifyListeners();
      }
    }
  }

  String _pickError(ComplianceDocumentFileSource source) => switch (source) {
    ComplianceDocumentFileSource.camera => AppStrings.complianceCameraOpenError,
    ComplianceDocumentFileSource.gallery => AppStrings.compliancePickImageError,
    ComplianceDocumentFileSource.pdf => AppStrings.compliancePickPdfError,
  };

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
