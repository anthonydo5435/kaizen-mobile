import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/repositories/compliance_document_media_repository.dart';

class ComplianceDocumentMediaRepositoryImpl implements ComplianceDocumentMediaRepository {
  ComplianceDocumentMediaRepositoryImpl({ImagePicker? imagePicker, FilePicker? filePicker})
    : _imagePicker = imagePicker ?? ImagePicker(),
      _filePicker = filePicker;

  final ImagePicker _imagePicker;
  final FilePicker? _filePicker;

  @override
  Future<String?> pickFile(ComplianceDocumentFileSource source) async {
    if (source == ComplianceDocumentFileSource.pdf) {
      final result = await (_filePicker ?? FilePicker.platform).pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      return result?.files.single.path;
    }
    final image = await _imagePicker.pickImage(
      source: source == ComplianceDocumentFileSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
    );
    return image?.path;
  }
}
