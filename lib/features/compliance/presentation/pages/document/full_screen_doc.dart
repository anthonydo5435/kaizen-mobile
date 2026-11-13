// ignore_for_file: file_names

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';

import '../../../../../core/constants/app_strings.dart';

class ViewFullScreenDoc extends StatefulWidget {
  const ViewFullScreenDoc({super.key, required this.title, required this.imageUrl});

  final String title;
  final String imageUrl;

  @override
  State<ViewFullScreenDoc> createState() => _ViewFullScreenDocState();
}

class _ViewFullScreenDocState extends State<ViewFullScreenDoc> {
  bool get _isPdfDocument {
    final resolvedUrl = CustomFunctions.resolveNetworkUrl(widget.imageUrl);
    final uri = resolvedUrl == null ? null : Uri.tryParse(resolvedUrl);
    final path = uri?.path.toLowerCase() ?? resolvedUrl?.toLowerCase() ?? '';
    return path.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final content = _isPdfDocument
        ? _buildPdfPreview()
        : Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SizedBox.expand(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) =>
                      SizedBox(width: 36, height: 36, child: FastCircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 56),
                ),
              ),
            ),
          );

    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 2, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: SvgPicture.asset(
                      '${AppStrings.imagePath}back.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPreview() {
    final resolvedUrl = CustomFunctions.resolveNetworkUrl(widget.imageUrl);
    if (resolvedUrl == null) {
      return const Center(
        child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white70, size: 56),
      );
    }

    return ColoredBox(
      color: AppColors.mainBg,
      child: PdfViewer.uri(
        Uri.parse(resolvedUrl),
        useProgressiveLoading: true,
        preferRangeAccess: true,
        params: PdfViewerParams(
          margin: 0,
          backgroundColor: AppColors.mainBg,
          pageDropShadow: const BoxShadow(color: Colors.transparent),
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
            return ColoredBox(
              color: AppColors.mainBg,
              child: Center(
                child: SizedBox(width: 36, height: 36, child: FastCircularProgressIndicator()),
              ),
            );
          },
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(
                this.context,
              ).showSnackBar(const SnackBar(content: Text('Unable to load PDF document.')));
            });

            return const ColoredBox(
              color: AppColors.mainBg,
              child: Center(
                child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white70, size: 56),
              ),
            );
          },
        ),
      ),
    );
  }
}
