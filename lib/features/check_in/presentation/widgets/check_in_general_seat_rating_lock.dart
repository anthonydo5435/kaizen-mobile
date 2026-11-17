import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';

class CheckInGeneralSeatRatingLock extends StatelessWidget {
  const CheckInGeneralSeatRatingLock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          color: AppColors.secondaryColor,
          size: 16,
        ),
        SizedBox(width: 4),
        Flexible(
          child: AppTextView.body2(
            AppStrings.auditGeneralSeatRatingLabel,
            color: AppColors.secondaryColor,
            fontSize: 12,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
