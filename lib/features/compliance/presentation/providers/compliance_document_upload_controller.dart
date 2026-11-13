import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../domain/entities/compliance_document.dart';
import '../../domain/usecases/upload_compliance_document_usecase.dart';
import 'compliance_document_expiry_controller.dart';
import 'compliance_document_media_controller.dart';

/// Owns the upload form and submission while media and expiry keep their controllers.
class ComplianceDocumentUploadController extends ChangeNotifier {
  static const int nameMaxLength = 50;
  static const int descriptionMaxLength = 300;

  ComplianceDocumentUploadController({
    required ComplianceDocument document,
    required UploadComplianceDocumentUseCase uploadUseCase,
    required ComplianceDocumentMediaController mediaController,
    required ComplianceDocumentExpiryController expiryController,
  }) : _document = document,
       _uploadUseCase = uploadUseCase,
       _mediaController = mediaController,
       _expiryController = expiryController {
    _mediaController.addListener(_handleMediaChanged);
    nameController.addListener(_handleNameChanged);
    descriptionController.addListener(_handleDescriptionChanged);
  }

  final ComplianceDocument _document;
  final UploadComplianceDocumentUseCase _uploadUseCase;
  final ComplianceDocumentMediaController _mediaController;
  final ComplianceDocumentExpiryController _expiryController;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  String? _selectedPath;
  String? _selectedFileName;
  String? _nameError;
  String? _descriptionError;
  String? _errorMessage;
  bool _isUploading = false;
  bool _isSubmittingRecord = false;
  double _uploadProgress = 0;
  bool _isDisposed = false;

  String? get nameError => _nameError;
  String? get descriptionError => _descriptionError;
  String? get errorMessage => _errorMessage;
  bool get isUploading => _isUploading;
  bool get isSubmittingRecord => _isSubmittingRecord;
  double get uploadProgress => _uploadProgress;

  void _handleMediaChanged() {
    final path = _mediaController.selectedFile?.path;
    final fileName = _mediaController.selectedFileName;
    if (path != null &&
        (path != _selectedPath || fileName != _selectedFileName)) {
      _selectedPath = path;
      _selectedFileName = fileName;
      _nameError = null;
      nameController.text = fileName ?? CustomFunctions.fileNameFromPath(path);
    }
    notifyListeners();
  }

  void _handleNameChanged() {
    if (_nameError != null) {
      _nameError = _validateName();
      notifyListeners();
    }
  }

  void _handleDescriptionChanged() {
    if (_descriptionError != null) {
      _descriptionError = _validateDescription();
      notifyListeners();
    }
  }

  String? _validateName() {
    if (nameController.text.trim().isEmpty) {
      return AppStrings.complianceDocumentNameRequired;
    }
    return nameController.text.characters.length > nameMaxLength
        ? AppStrings.complianceDocumentNameTooLong
        : null;
  }

  String? _validateDescription() =>
      descriptionController.text.characters.length > descriptionMaxLength
      ? AppStrings.complianceDocumentDescriptionTooLong
      : null;

  Future<bool> submit() async {
    final file = _mediaController.selectedFile;
    if (_isDisposed ||
        _isUploading ||
        file == null ||
        _mediaController.isPicking) {
      return false;
    }
    _errorMessage = null;
    final name = nameController.text.trim();
    _nameError = _validateName();
    _descriptionError = _validateDescription();
    final validExpiry = !_document.hasExpiry || _expiryController.validate();
    if (_nameError != null || _descriptionError != null || !validExpiry) {
      notifyListeners();
      return false;
    }
    final description = descriptionController.text.trim();
    _isUploading = true;
    _isSubmittingRecord = false;
    _uploadProgress = 0;
    notifyListeners();
    try {
      await _uploadUseCase(
        complianceDocumentId: _document.id,
        fileName:
            _mediaController.selectedFileName ??
            CustomFunctions.fileNameFromPath(file.path),
        fileBytes: await file.readAsBytes(),
        contentType: CustomFunctions.contentTypeFromPath(
          file.path,
          fallback: 'application/pdf',
        ),
        name: name,
        description: description,
        expiryDate: _document.hasExpiry
            ? _expiryController.apiExpiryDate
            : null,
        onUploadProgress: (progress) {
          if (_isDisposed) return;
          _uploadProgress = progress;
          notifyListeners();
        },
        onRecordUploadStarted: () {
          if (_isDisposed) return;
          _uploadProgress = 1;
          _isSubmittingRecord = true;
          notifyListeners();
        },
      );
      return true;
    } catch (error) {
      debugPrint('Compliance document upload failed: $error');
      if (!_isDisposed) {
        _errorMessage = AppStrings.complianceDocumentUploadFailed;
      }
      return false;
    } finally {
      if (!_isDisposed) {
        _isUploading = false;
        _isSubmittingRecord = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mediaController.removeListener(_handleMediaChanged);
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
