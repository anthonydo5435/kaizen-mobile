import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/compliance_document.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/picked_compliance_document_file.dart';
import 'package:sparrowkaizen/features/compliance/domain/repositories/compliance_document_media_repository.dart';
import 'package:sparrowkaizen/features/compliance/domain/repositories/compliance_repository.dart';
import 'package:sparrowkaizen/features/compliance/domain/usecases/pick_compliance_document_file_usecase.dart';
import 'package:sparrowkaizen/features/compliance/domain/usecases/upload_compliance_document_usecase.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_document_expiry_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_document_media_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_document_upload_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MediaRepository repository;
  late ComplianceDocumentMediaController media;
  late ComplianceDocumentExpiryController expiry;
  late ComplianceDocumentUploadController upload;

  setUp(() {
    repository = _MediaRepository();
    media = ComplianceDocumentMediaController(
      PickComplianceDocumentFileUseCase(repository),
    );
    expiry = ComplianceDocumentExpiryController();
    upload = ComplianceDocumentUploadController(
      document: const ComplianceDocument(
        id: 'document',
        title: 'Passport',
        category: '',
        status: '',
        updatedAt: '',
      ),
      uploadUseCase: UploadComplianceDocumentUseCase(_UploadRepository()),
      mediaController: media,
      expiryController: expiry,
    );
  });
  tearDown(() {
    upload.dispose();
    media.dispose();
    expiry.dispose();
  });

  for (final example in [
    (
      path: '/tmp/image_picker_684668fc-6fad-417e-adfe-82e6bdd702f4.jpg',
      name: 'IMG_1234.jpg',
    ),
    (
      path: '/tmp/684668fc-6fad-417e-adfe-82e6bdd702f4.pdf',
      name: 'Signed copy.pdf',
    ),
    (
      path: '/tmp/9b1f95377ac21a00fe639432c67dd433.png',
      name: 'Holiday photo.png',
    ),
    (
      path: r'C:\cache\image_picker_684668fc-6fad-417e-adfe-82e6bdd702f4.jpeg',
      name: 'Photo 2026.jpeg',
    ),
    (path: '/documents/Passport scan.jpeg', name: 'Passport scan.jpeg'),
    (
      path: '/tmp/684668fc-6fad-417e-adfe-82e6bdd702f4.png',
      name: '684668fc-6fad-417e-adfe-82e6bdd702f4.png',
    ),
  ]) {
    test('prefills the selected filename ${example.name}', () async {
      repository.path = example.path;
      repository.name = example.name;
      await media.pickFile(ComplianceDocumentFileSource.gallery);
      expect(upload.nameController.text, example.name);
    });
  }

  for (final example in [
    (
      name: 'appstore-754A0875-371D-47BD-9B6D-F244515C26F0.png',
      expectedName: 'appstore.png',
    ),
    (
      name: 'My scan_754a0875-371d-47bd-9b6d-f244515c26f0.JPG',
      expectedName: 'My scan.JPG',
    ),
    (
      name: 'Signed copy-754A0875-371D-47BD-9B6D-F244515C26F0.pdf',
      expectedName: 'Signed copy.pdf',
    ),
    (name: 'scan-754A0875-371D-47BD-9B6D-F244515C26F0', expectedName: 'scan'),
    (name: 'IMG_20261111_123456.jpg', expectedName: 'IMG_20261111_123456.jpg'),
    (
      name: 'appstore-release-2026.png',
      expectedName: 'appstore-release-2026.png',
    ),
  ]) {
    test('removes only the generated suffix from ${example.name}', () async {
      repository.path = '/tmp/${example.name}';
      repository.name = example.name;
      await media.pickFile(ComplianceDocumentFileSource.gallery);
      expect(media.selectedFile!.path, '/tmp/${example.name}');
      expect(media.selectedFileName, example.expectedName);
      expect(upload.nameController.text, example.expectedName);
    });
  }

  test(
    'an overlong original filename must be shortened before upload',
    () async {
      final originalName = '${List.filled(51, 'a').join()}.png';
      repository.path = '/tmp/$originalName';
      await media.pickFile(ComplianceDocumentFileSource.gallery);
      expect(upload.nameController.text, originalName);
      expect(await upload.submit(), isFalse);
      expect(upload.nameError, AppStrings.complianceDocumentNameTooLong);
      expect(upload.isUploading, isFalse);
      upload.nameController.text = 'Shortened name.png';
      expect(upload.nameError, isNull);
    },
  );

  test(
    'an overlong description blocks upload and clears its error when corrected',
    () async {
      repository.path = '/tmp/photo.png';
      await media.pickFile(ComplianceDocumentFileSource.gallery);
      upload.descriptionController.text = List.filled(301, 'd').join();
      expect(await upload.submit(), isFalse);
      expect(
        upload.descriptionError,
        AppStrings.complianceDocumentDescriptionTooLong,
      );
      expect(upload.isUploading, isFalse);
      upload.descriptionController.text = List.filled(300, 'd').join();
      expect(upload.descriptionError, isNull);
    },
  );

  test(
    'cancelling replacement preserves edits and choosing a new file updates only its name',
    () async {
      repository.path = '/tmp/passport.jpg';
      await media.pickFile(ComplianceDocumentFileSource.gallery);
      upload.nameController.text = 'My passport.jpg';
      upload.descriptionController.text = 'Signed copy';
      repository.path = null;
      await media.pickFile(ComplianceDocumentFileSource.camera);
      expect(upload.nameController.text, 'My passport.jpg');
      expect(upload.descriptionController.text, 'Signed copy');
      repository.path = '/tmp/renewed-passport.pdf';
      await media.pickFile(ComplianceDocumentFileSource.pdf);
      expect(upload.nameController.text, 'renewed-passport.pdf');
      expect(upload.descriptionController.text, 'Signed copy');
    },
  );
}

class _MediaRepository implements ComplianceDocumentMediaRepository {
  String? path;
  String? name;

  @override
  Future<PickedComplianceDocumentFile?> pickFile(
    ComplianceDocumentFileSource source,
  ) async {
    final selectedPath = path;
    return selectedPath == null
        ? null
        : PickedComplianceDocumentFile(
            path: selectedPath,
            name: name ?? selectedPath.replaceAll('\\', '/').split('/').last,
          );
  }
}

class _UploadRepository extends Fake implements ComplianceRepository {}
