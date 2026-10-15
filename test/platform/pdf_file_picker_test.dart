import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/compliance/data/repositories/compliance_document_media_repository_impl.dart';
import 'package:sparrowkaizen/features/compliance/domain/repositories/compliance_document_media_repository.dart';
import 'package:sparrowkaizen/features/kaizengram/presentation/kaizengram_message_attachment.dart';

void main() {
  late FilePickerPlatform originalPicker;
  late _PdfPicker picker;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    picker = _PdfPicker();
    FilePickerPlatform.instance = picker;
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
  });

  test(
    'compliance selects a single PDF and preserves its local path',
    () async {
      picker.files = [_PdfFile('/tmp/compliance document.pdf')];

      final path = await ComplianceDocumentMediaRepositoryImpl().pickFile(
        ComplianceDocumentFileSource.pdf,
      );

      expect(path, '/tmp/compliance document.pdf');
      expect(picker.singlePicks, 1);
      expect(picker.multiplePicks, 0);
      expect(picker.type, FileType.custom);
      expect(picker.extensions, ['pdf']);
    },
  );

  test('cancelling compliance PDF selection returns no replacement', () async {
    final path = await ComplianceDocumentMediaRepositoryImpl().pickFile(
      ComplianceDocumentFileSource.pdf,
    );

    expect(path, isNull);
  });

  test('one remaining attachment slot opens single PDF selection', () async {
    picker.files = [_PdfFile('/tmp/attachment.pdf')];

    final attachments = await KaizengramMessageAttachmentPicker.pickPdfs(
      availableSlots: 1,
    );

    expect(attachments.map((attachment) => attachment.path), [
      '/tmp/attachment.pdf',
    ]);
    expect(picker.singlePicks, 1);
    expect(picker.multiplePicks, 0);
    expect(picker.type, FileType.custom);
    expect(picker.extensions, ['pdf']);
  });

  test(
    'multiple PDFs exclude existing attachments and respect capacity',
    () async {
      picker.files = [
        _PdfFile('/tmp/existing.pdf'),
        _PdfFile('/tmp/first.pdf'),
        _PdfFile('/tmp/second.pdf'),
        _PdfFile('/tmp/overflow.pdf'),
      ];

      final attachments = await KaizengramMessageAttachmentPicker.pickPdfs(
        availableSlots: 2,
        existingPaths: ['/tmp/existing.pdf'],
      );

      expect(attachments.map((attachment) => attachment.path), [
        '/tmp/first.pdf',
        '/tmp/second.pdf',
      ]);
      expect(picker.singlePicks, 0);
      expect(picker.multiplePicks, 1);
    },
  );

  for (final availableSlots in [1, 2]) {
    test(
      'cancelling PDF selection with $availableSlots slots adds nothing',
      () async {
        final attachments = await KaizengramMessageAttachmentPicker.pickPdfs(
          availableSlots: availableSlots,
        );

        expect(attachments, isEmpty);
      },
    );
  }
}

class _PdfPicker extends FilePickerPlatform {
  List<PlatformFile> files = [];
  int singlePicks = 0;
  int multiplePicks = 0;
  FileType? type;
  List<String>? extensions;

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
    singlePicks++;
    this.type = type;
    extensions = allowedExtensions;
    return files.singleOrNull;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
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
    multiplePicks++;
    this.type = type;
    extensions = allowedExtensions;
    return files;
  }
}

final class _PdfFile extends PlatformFile {
  _PdfFile(String path) : uri = Uri.file(path);

  @override
  final Uri uri;

  @override
  String get name => uri.pathSegments.last;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
