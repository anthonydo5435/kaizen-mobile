import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/performance_report.dart';

Future<void> showPerformanceReportCoreValueDialog(
  BuildContext context, {
  required PerformanceReportCoreValue coreValue,
  required IconData icon,
  required Color accentColor,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _CoreValueDialogContent(
      coreValue: coreValue,
      icon: icon,
      accentColor: accentColor,
    ),
  );
}

class _CoreValueDialogContent extends StatelessWidget {
  const _CoreValueDialogContent({
    required this.coreValue,
    required this.icon,
    required this.accentColor,
  });

  final PerformanceReportCoreValue coreValue;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final description = coreValue.description?.trim();
    final detailCards = <Widget>[
      if (description?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CoreValueDetailCard(
            value: description!,
            accentColor: accentColor,
          ),
        ),
      ...coreValue.details.map(
        (detail) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CoreValueDetailCard(
            label: detail.label,
            value: detail.value,
            accentColor: accentColor,
          ),
        ),
      ),
    ];

    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: AppDialogStyle.shape(radius: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: mediaQuery.size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                    child: Icon(icon, color: AppColors.textPrimary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextView.body1(
                      coreValue.title,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppOverlayCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.fieldBorder.withValues(alpha: 0.16),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: detailCards.isEmpty
                      ? _CoreValueDetailCard(
                          value: AppStrings
                              .performanceReportCoreValueDetailsFallback,
                          accentColor: accentColor,
                        )
                      : Column(children: detailCards),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoreValueDetailCard extends StatelessWidget {
  const _CoreValueDetailCard({
    this.label,
    required this.value,
    required this.accentColor,
  });

  final String? label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label?.trim().isNotEmpty == true) ...[
            AppTextView.body4(
              label!.trim(),
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 4),
          ],
          AppTextView.body3(
            value,
            color: AppColors.textPrimary,
            fontSize: 13,
            height: 1.45,
          ),
        ],
      ),
    );
  }
}
