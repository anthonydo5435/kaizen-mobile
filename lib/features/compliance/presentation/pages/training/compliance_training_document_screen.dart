import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../domain/entities/compliance_track_item_detail.dart';

class ComplianceTrainingDocumentScreen extends StatelessWidget {
  const ComplianceTrainingDocumentScreen({super.key, required this.detail});

  final ComplianceTrackItemDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: _TrainingDocumentHtml(detail.trainingDocument),
      ),
    );
  }
}

class _TrainingDocumentHtml extends StatelessWidget {
  const _TrainingDocumentHtml(this.html);

  final String? html;

  @override
  Widget build(BuildContext context) {
    final value = html?.trim();
    if (value == null || value.isEmpty) {
      return const AppTextView.body3(
        AppStrings.noContentAvailable,
        color: AppColors.surfaceDark,
        height: 1.7,
      );
    }

    return Html(
      data: value,
      shrinkWrap: true,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: AppColors.surfaceDark,
          fontSize: FontSize(13),
          fontWeight: FontWeight.w400,
          lineHeight: const LineHeight(1.65),
        ),
        'p': Style(
          margin: Margins.only(bottom: 12),
          lineHeight: const LineHeight(1.65),
        ),
        'ul': Style(margin: Margins.only(bottom: 12)),
        'ol': Style(margin: Margins.only(bottom: 12)),
        'li': Style(margin: Margins.only(bottom: 6)),
        'h1': _headingStyle(20),
        'h2': _headingStyle(18),
        'h3': _headingStyle(16),
        'h4': _headingStyle(15),
        'h5': _headingStyle(14),
        'h6': _headingStyle(14),
        'a': Style(color: AppColors.secondaryColor),
      },
    );
  }

  Style _headingStyle(double fontSize) => Style(
    margin: Margins.only(bottom: 10),
    color: AppColors.surfaceDark,
    fontSize: FontSize(fontSize),
    fontWeight: FontWeight.w700,
    lineHeight: const LineHeight(1.35),
  );
}
