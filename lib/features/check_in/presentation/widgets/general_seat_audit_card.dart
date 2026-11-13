import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/seat_audit.dart';

class GeneralSeatAuditCard extends StatelessWidget {
  const GeneralSeatAuditCard({
    super.key,
    required this.seat,
    required this.scoreLabel,
    required this.onView,
  });

  final SeatAudit seat;
  final String scoreLabel;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceDark, AppColors.hex111317],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextView.body1(
            seat.job.title,
            color: AppColors.secondaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: seat.profiles
                .map((profile) => _ProfileAvatar(profile: profile))
                .toList(growable: false),
          ),
          const SizedBox(height: 24),
          const AppDotDivider(opacity: 0.5, dotSize: 5),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _ScoreTile(scoreLabel: scoreLabel)),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _ViewButton(onTap: onView)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final SeatAuditProfile profile;

  @override
  Widget build(BuildContext context) {
    final url = CustomFunctions.resolveImageUrl(profile.image);
    final fallback = Image.asset(
      AppStrings.dummyProfileImagePath,
      fit: BoxFit.cover,
    );
    return Tooltip(
      message: profile.name.isEmpty ? profile.email : profile.name,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textPrimary),
        ),
        clipBehavior: Clip.antiAlias,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.scoreLabel});

  final String scoreLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppTextView.title1(
            scoreLabel,
            color: AppColors.textPrimary,
            fontSize: 24,
          ),
          const SizedBox(height: 4),
          const AppTextView.body3(
            AppStrings.auditGeneralSeatOverallScore,
            color: AppColors.secondaryColor,
            textAlign: TextAlign.center,
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.purple1,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_outward_rounded,
                color: AppColors.textPrimary,
                size: 24,
              ),
              SizedBox(height: 4),
              AppTextView.body1(
                AppStrings.view,
                color: AppColors.textPrimary,
                textAlign: TextAlign.center,
                fontSize: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
