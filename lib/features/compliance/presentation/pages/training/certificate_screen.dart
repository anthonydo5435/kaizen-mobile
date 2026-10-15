import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_view.dart';

class CertificateScreen extends StatelessWidget {
  const CertificateScreen({
    super.key,
    required this.title,
    required this.description,
    required this.score,
    required this.status,
    this.certificateUrl,
  });

  final String title;
  final String description;
  final String score;
  final String status;
  final String? certificateUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        top: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 32, 8, 24),
          child: Column(
            children: [
              const SizedBox(height: 30),
              _CertificateImage(certificateUrl: certificateUrl),
              const SizedBox(height: 80),
              _buildScoreSection(),
              const SizedBox(height: 20),
              _buildStatistics(),

              Spacer(),
              AppButton(
                text: AppStrings.backToModules,
                backgroundColor: AppColors.lightPurple1,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection() {
    return Column(
      children: [
        AppTextView.title1(
          score,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 48,
        ),
        AppTextView.title1(
          title,
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 24,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        AppTextView.body(
          description,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppTextView.body3(
          'Your Score: ',
          color: AppColors.grey1,
          fontWeight: FontWeight.w400,
        ),
        AppTextView.body3(
          score,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        const SizedBox(width: 24),
        AppTextView.body3(
          'Status: ',
          color: AppColors.grey1,
          fontWeight: FontWeight.w400,
        ),
        AppTextView.body3(
          status,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
      ],
    );
  }
}

class _CertificateImage extends StatelessWidget {
  const _CertificateImage({required this.certificateUrl});

  final String? certificateUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = certificateUrl?.trim();
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return Image.asset(
        'lib/assets/images/certificate.png',
        width: 350,
        height: 250,
        fit: BoxFit.contain,
      );
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      width: 350,
      height: 250,
      fit: BoxFit.contain,
      placeholder: (_, __) => Image.asset(
        'lib/assets/images/no_image.png',
        width: 350,
        height: 250,
        fit: BoxFit.contain,
      ),
      errorWidget: (_, __, ___) => Image.asset(
        'lib/assets/images/no_image.png',
        width: 350,
        height: 250,
        fit: BoxFit.contain,
      ),
    );
  }
}
