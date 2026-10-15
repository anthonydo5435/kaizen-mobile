import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../domain/entities/paygrade.dart';

class PaygradeListingCard extends StatefulWidget {
  const PaygradeListingCard({super.key, required this.paygrade, required this.onDetailsTap});

  final Paygrade paygrade;
  final VoidCallback onDetailsTap;

  @override
  State<PaygradeListingCard> createState() => _PaygradeListingCardState();
}

class _PaygradeListingCardState extends State<PaygradeListingCard> {
  final ValueNotifier<bool> _isExpanded = ValueNotifier(false);

  @override
  void dispose() {
    _isExpanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isExpanded,
      builder: (context, isExpanded, _) => _buildCard(isExpanded),
    );
  }

  Widget _buildCard(bool isExpanded) {
    final paygrade = widget.paygrade;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _isExpanded.value = !isExpanded,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextView.body1(
                      paygrade.seatName,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CardForwardArrow(isExpanded: isExpanded),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 14),
                _buildDepartmentRow(AppStrings.paygradesDepartment, paygrade.department),
                const SizedBox(height: 10),
                _buildStatRow(
                  AppStrings.paygradesPrimaryPaygrade,
                  paygrade.hasPrimaryPaygrade
                      ? AppStrings.paygradesAvailableYes
                      : AppStrings.paygradesAvailableNo,
                  isStatus: true,
                ),
                const SizedBox(height: 10),
                _buildStatRow(
                  AppStrings.paygradesAncillaryPaygrade,
                  paygrade.hasAncillaryPaygrade
                      ? AppStrings.paygradesAvailableYes
                      : AppStrings.paygradesAvailableNo,
                  isStatus: true,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: widget.onDetailsTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: AppTextView.body2(
                          AppStrings.paygradesDetailsTitle,
                          color: AppColors.secondaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.secondaryColor,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: AppTextView.body2(label, color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Flexible(
          child: AppTextView.body2(
            value,
            textAlign: TextAlign.end,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {required bool isStatus}) {
    final isPositive = value == AppStrings.paygradesAvailableYes;

    return Row(
      children: [
        Expanded(child: AppTextView.body2(label, color: AppColors.textSecondary)),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isPositive ? AppColors.lightGreen1 : AppColors.red1).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: isPositive ? AppColors.lightGreen1 : AppColors.red1),
            ),
            child: AppTextView.body3(
              value,
              color: isPositive ? AppColors.lightGreen1 : AppColors.red1,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 17),
            child: AppTextView.body2(
              value,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _CardForwardArrow extends StatelessWidget {
  const _CardForwardArrow({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 220),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.mainBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.28)),
        ),
        child: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
