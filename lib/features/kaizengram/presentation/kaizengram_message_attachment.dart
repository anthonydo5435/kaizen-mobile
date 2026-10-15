import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';

const int kaizengramMessageAttachmentLimit = 3;

enum KaizengramMessageAttachmentPickSource { media, pdf }

class KaizengramMessageAttachmentPicker {
  const KaizengramMessageAttachmentPicker._();

  static final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _pdfExtensions = <String>['pdf'];

  static Future<KaizengramMessageAttachmentPickSource?> pickSource(
    BuildContext context,
  ) {
    if (!context.mounted) {
      return Future<KaizengramMessageAttachmentPickSource?>.value(null);
    }

    return showModalBottomSheet<KaizengramMessageAttachmentPickSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _KaizengramAttachmentSourceSheet(),
    );
  }

  static Future<List<KaizengramMessageAttachment>> pick({
    required KaizengramMessageAttachmentPickSource source,
    required int availableSlots,
    Iterable<String> existingPaths = const <String>[],
  }) async {
    if (availableSlots <= 0) {
      return const <KaizengramMessageAttachment>[];
    }

    switch (source) {
      case KaizengramMessageAttachmentPickSource.media:
        return _pickMedia(
          availableSlots: availableSlots,
          existingPaths: existingPaths,
        );
      case KaizengramMessageAttachmentPickSource.pdf:
        return _pickPdf(
          availableSlots: availableSlots,
          existingPaths: existingPaths,
        );
    }
  }

  static Future<List<KaizengramMessageAttachment>> pickImages({
    required int availableSlots,
    Iterable<String> existingPaths = const <String>[],
  }) async {
    if (availableSlots <= 0) {
      return const <KaizengramMessageAttachment>[];
    }

    final List<XFile> pickedImages;
    if (availableSlots == 1) {
      final pickedSingleImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      pickedImages = pickedSingleImage == null
          ? <XFile>[]
          : <XFile>[pickedSingleImage];
    } else {
      pickedImages = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        limit: availableSlots,
      );
    }

    return _normalizedAttachmentsFromPaths(
      pickedImages.map((file) => file.path),
      existingPaths: existingPaths,
      availableSlots: availableSlots,
    );
  }

  static Future<List<KaizengramMessageAttachment>> pickPdfs({
    required int availableSlots,
    Iterable<String> existingPaths = const <String>[],
  }) {
    return _pickPdf(
      availableSlots: availableSlots,
      existingPaths: existingPaths,
    );
  }

  static Future<List<KaizengramMessageAttachment>> _pickMedia({
    required int availableSlots,
    required Iterable<String> existingPaths,
  }) async {
    final List<XFile> pickedMedia;
    if (availableSlots == 1) {
      final pickedSingleMedia = await _imagePicker.pickMedia(imageQuality: 85);
      pickedMedia = pickedSingleMedia == null
          ? <XFile>[]
          : <XFile>[pickedSingleMedia];
    } else {
      pickedMedia = await _imagePicker.pickMultipleMedia(
        imageQuality: 85,
        limit: availableSlots,
      );
    }

    return _normalizedAttachmentsFromPaths(
      pickedMedia.map((file) => file.path),
      existingPaths: existingPaths,
      availableSlots: availableSlots,
    );
  }

  static Future<List<KaizengramMessageAttachment>> _pickPdf({
    required int availableSlots,
    required Iterable<String> existingPaths,
  }) async {
    final List<PlatformFile> files;
    if (availableSlots == 1) {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _pdfExtensions,
      );
      files = file == null ? <PlatformFile>[] : <PlatformFile>[file];
    } else {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _pdfExtensions,
      );
    }
    if (files.isEmpty) {
      return const <KaizengramMessageAttachment>[];
    }

    return _normalizedAttachmentsFromPaths(
      files.map((file) => file.path),
      existingPaths: existingPaths,
      availableSlots: availableSlots,
    );
  }

  static List<KaizengramMessageAttachment> _normalizedAttachmentsFromPaths(
    Iterable<String?> rawPaths, {
    required Iterable<String> existingPaths,
    required int availableSlots,
  }) {
    final existingPathSet = existingPaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet();

    return rawPaths
        .map((path) => path?.trim() ?? '')
        .where((path) => path.isNotEmpty && !existingPathSet.contains(path))
        .take(availableSlots)
        .map(KaizengramMessageAttachment.fromPath)
        .toList(growable: false);
  }
}

class _KaizengramAttachmentSourceSheet extends StatelessWidget {
  const _KaizengramAttachmentSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey1,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppTextView.body1(
            AppStrings.attachmentPickerTitle,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          const SizedBox(height: 14),
          _KaizengramAttachmentSourceTile(
            icon: Icons.photo_library_outlined,
            title: AppStrings.attachmentPickerMediaTitle,
            subtitle: AppStrings.attachmentPickerMediaSubtitle,
            onTap: () {
              Navigator.of(
                context,
              ).pop(KaizengramMessageAttachmentPickSource.media);
            },
          ),
          const SizedBox(height: 12),
          _KaizengramAttachmentSourceTile(
            icon: Icons.picture_as_pdf_outlined,
            title: AppStrings.attachmentPickerPdfTitle,
            subtitle: AppStrings.attachmentPickerPdfSubtitle,
            onTap: () {
              Navigator.of(
                context,
              ).pop(KaizengramMessageAttachmentPickSource.pdf);
            },
          ),
        ],
      ),
    );
  }
}

class _KaizengramAttachmentSourceTile extends StatelessWidget {
  const _KaizengramAttachmentSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark3,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.secondaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextView.body2(
                      title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 3),
                    AppTextView.body4(
                      subtitle,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum KaizengramMessageAttachmentType { image, video, pdf }

class KaizengramMessageAttachment {
  const KaizengramMessageAttachment({required this.path, required this.type});

  factory KaizengramMessageAttachment.fromPath(String rawPath) {
    final normalizedPath = rawPath.trim();
    return KaizengramMessageAttachment(
      path: normalizedPath,
      type: kaizengramMessageAttachmentTypeForPath(normalizedPath),
    );
  }

  final String path;
  final KaizengramMessageAttachmentType type;

  bool get isImage => type == KaizengramMessageAttachmentType.image;
  bool get isVideo => type == KaizengramMessageAttachmentType.video;
  bool get isPdf => type == KaizengramMessageAttachmentType.pdf;
  bool get isNetworkPath =>
      path.startsWith('http://') || path.startsWith('https://');
}

KaizengramMessageAttachmentType kaizengramMessageAttachmentTypeForPath(
  String path,
) {
  if (_hasAnyKaizengramAttachmentExtension(path, <String>{'pdf'})) {
    return KaizengramMessageAttachmentType.pdf;
  }

  if (_hasAnyKaizengramAttachmentExtension(path, <String>{
    'mp4',
    'mov',
    'm4v',
    'avi',
    'webm',
    'mkv',
    '3gp',
  })) {
    return KaizengramMessageAttachmentType.video;
  }

  return KaizengramMessageAttachmentType.image;
}

bool _hasAnyKaizengramAttachmentExtension(String path, Set<String> extensions) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(normalizedPath);
  final resolvedPath = uri?.path.isNotEmpty == true
      ? uri!.path.toLowerCase()
      : normalizedPath.toLowerCase().split('?').first;

  return extensions.any((extension) => resolvedPath.endsWith('.$extension'));
}
