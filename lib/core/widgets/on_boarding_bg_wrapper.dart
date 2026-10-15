import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class OnBoardingBgWrapper extends StatelessWidget {
  final Widget child;

  const OnBoardingBgWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      // Using ResizeToAvoidBottomInset false prevents the background
      // from squishing when the keyboard pops up
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. The Gradient Base
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.5, -0.4),
                radius: 1.2,
                colors: [AppColors.bgGlow, AppColors.bgDark],
              ),
            ),
          ),

          // 2. The Decorative Curved Bar
          Positioned(
            top: -150,
            right: -400,
            child: IgnorePointer(
              // Ensures the arc doesn't block clicks
              child: Container(
                width: 600,
                height: 550,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.03),
                    width: 80,
                  ),
                ),
              ),
            ),
          ),

          // 3. The Actual Screen Content
          child,
        ],
      ),
    );
  }
}
