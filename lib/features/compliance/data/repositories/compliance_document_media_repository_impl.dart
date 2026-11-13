import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/picked_compliance_document_file.dart';
import '../../domain/repositories/compliance_document_media_repository.dart';

class ComplianceDocumentMediaRepositoryImpl
    implements ComplianceDocumentMediaRepository {
  ComplianceDocumentMediaRepositoryImpl({
    ImagePicker? imagePicker,
    FilePickerPlatform? filePicker,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _filePicker = filePicker;

  final ImagePicker _imagePicker;
  final FilePickerPlatform? _filePicker;

  @override
  Future<PickedComplianceDocumentFile?> pickFile(
    ComplianceDocumentFileSource source,
  ) async {
    if (source != ComplianceDocumentFileSource.camera) {
      // Keep the library filename instead of image_picker's generated image copy name.
      final result = await (_filePicker ?? FilePickerPlatform.instance)
          .pickFile(
            type: source == ComplianceDocumentFileSource.gallery
                ? FileType.image
                : FileType.custom,
            allowedExtensions: source == ComplianceDocumentFileSource.pdf
                ? const ['pdf']
                : null,
          );
      final path = result?.path;
      return path == null
          ? null
          : PickedComplianceDocumentFile(path: path, name: result!.name);
    }
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    return image == null
        ? null
        : PickedComplianceDocumentFile(path: image.path, name: image.name);
  }
}
