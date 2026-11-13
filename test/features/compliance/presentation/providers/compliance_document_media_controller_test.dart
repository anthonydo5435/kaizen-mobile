import 'dart:async';

import 'package:file_picker/file_picker.dart';
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
  late _FilePicker filePicker;
  late ComplianceDocumentMediaController controller;
  var isDisposed = false;
  setUp(() {
    isDisposed = false;
    picker = _ImagePicker();
    filePicker = _FilePicker();
    controller = ComplianceDocumentMediaController(
      PickComplianceDocumentFileUseCase(
        ComplianceDocumentMediaRepositoryImpl(
          imagePicker: picker,
          filePicker: filePicker,
        ),
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
      expect(controller.selectedFileName, 'captured.png');
      expect(controller.isSelectedFileImage, isTrue);
      expect(controller.isPicking, isFalse);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'cancelling camera replacement keeps the gallery image selected',
    () async {
      filePicker.file = _PickedFile('/tmp/cache.png', 'Gallery image.png');
      await controller.pickFile(ComplianceDocumentFileSource.gallery);
      picker.load = () async => null;
      await controller.pickFile(ComplianceDocumentFileSource.camera);
      expect(picker.sources, [ImageSource.camera]);
      expect(filePicker.type, FileType.image);
      expect(controller.selectedFile!.path, '/tmp/cache.png');
      expect(controller.selectedFileName, 'Gallery image.png');
      expect(controller.isSelectedFileImage, isTrue);
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

class _FilePicker extends FilePickerPlatform {
  PlatformFile? file;
  FileType? type;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.type = type;
    return file;
  }
}

final class _PickedFile extends PlatformFile {
  _PickedFile(String path, this.name) : uri = Uri.file(path);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
