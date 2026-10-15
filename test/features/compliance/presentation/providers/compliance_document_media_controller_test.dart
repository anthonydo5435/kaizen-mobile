import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/compliance/data/repositories/compliance_document_media_repository_impl.dart';
import 'package:sparrowkaizen/features/compliance/domain/repositories/compliance_document_media_repository.dart';
import 'package:sparrowkaizen/features/compliance/domain/usecases/pick_compliance_document_file_usecase.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_document_media_controller.dart';

void main() {
  late _ImagePicker picker;
  late ComplianceDocumentMediaController controller;
  var isDisposed = false;
  setUp(() {
    isDisposed = false;
    picker = _ImagePicker();
    controller = ComplianceDocumentMediaController(
      PickComplianceDocumentFileUseCase(
        ComplianceDocumentMediaRepositoryImpl(imagePicker: picker),
      ),
    );
  });
  tearDown(() {
    if (!isDisposed) {
      controller.dispose();
    }
  });

  test(
    'camera selection opens the native camera and stores its captured file',
    () async {
      picker.load = () async => XFile('/tmp/captured.png');
      await controller.pickFile(ComplianceDocumentFileSource.camera);
      expect(picker.sources, [ImageSource.camera]);
      expect(controller.selectedFile!.path, '/tmp/captured.png');
      expect(controller.isPicking, isFalse);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'cancelling camera replacement keeps the gallery image selected',
    () async {
      picker.load = () async => XFile('/tmp/gallery.png');
      await controller.pickFile(ComplianceDocumentFileSource.gallery);
      picker.load = () async => null;
      await controller.pickFile(ComplianceDocumentFileSource.camera);
      expect(picker.sources, [ImageSource.gallery, ImageSource.camera]);
      expect(controller.selectedFile!.path, '/tmp/gallery.png');
      expect(controller.isPicking, isFalse);
      expect(controller.errorMessage, isNull);
    },
  );

  test('a denied camera request can be retried successfully', () async {
    picker.load = () async =>
        throw PlatformException(code: 'camera_access_denied');
    await controller.pickFile(ComplianceDocumentFileSource.camera);
    expect(
      controller.errorMessage,
      AppStrings.complianceCameraPermissionRequired,
    );
    expect(controller.isPicking, isFalse);
    picker.load = () async => XFile('/tmp/retry.png');
    await controller.pickFile(ComplianceDocumentFileSource.camera);
    expect(controller.selectedFile!.path, '/tmp/retry.png');
    expect(controller.errorMessage, isNull);
  });

  test(
    'duplicate camera launches are blocked and late results after disposal are ignored',
    () async {
      final photo = Completer<XFile?>();
      picker.load = () => photo.future;
      final picking = controller.pickFile(ComplianceDocumentFileSource.camera);
      expect(controller.isPicking, isTrue);
      await controller.pickFile(ComplianceDocumentFileSource.camera);
      expect(picker.sources, [ImageSource.camera]);
      controller.dispose();
      isDisposed = true;
      photo.complete(XFile('/tmp/late.png'));
      await picking;
      expect(controller.selectedFile, isNull);
    },
  );
}

class _ImagePicker extends ImagePicker {
  final sources = <ImageSource>[];
  Future<XFile?> Function() load = () async => null;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    sources.add(source);
    return load();
  }
}
