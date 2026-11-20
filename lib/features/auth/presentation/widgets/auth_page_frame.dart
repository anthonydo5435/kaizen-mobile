import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/widgets/app_text_view.dart';
import 'auth_background_scaffold.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.leading,
    this.showBrandHeader = true,
    this.contentTopSpacing,
    this.alignTop = false,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget? leading;
  final bool showBrandHeader;
  final double? contentTopSpacing;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final isTabletLayout = MediaQuery.of(context).size.shortestSide >= 600;

    return AuthBackgroundScaffold(
      alignTop: alignTop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading != null) ...[
            Align(alignment: Alignment.centerLeft, child: leading!),
            SizedBox(height: isTabletLayout ? 12 : 18),
          ] else
            SizedBox(height: isTabletLayout ? 0 : 40),
          if (showBrandHeader) ...[
            const _AuthBrandHeader(),
            SizedBox(height: contentTopSpacing ?? (isTabletLayout ? 64 : 90)),
          ] else
            SizedBox(height: contentTopSpacing ?? (isTabletLayout ? 28 : 44)),
          _AuthIntroBlock(title: title, subtitle: subtitle),
          SizedBox(height: 48),
          body,
        ],
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Flexible(
          child: AppTextView.body1(
            AppStrings.kaizen,
            color: AppColors.secondaryColor,
            fontSize: 25,
            fontWeight: FontWeight.w400,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          width: 1,
          height: 18,
          margin: const EdgeInsets.only(left: 7, top: 4, right: 7),
          color: AppColors.textPrimary,
        ),
        const Flexible(
          child: AppTextView.body1(
            AppStrings.teams,
            color: AppColors.textPrimary,
            fontSize: 25,
            fontWeight: FontWeight.w400,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AuthIntroBlock extends StatelessWidget {
  const _AuthIntroBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextView.title(
          title,
          textAlign: TextAlign.center,
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 10),
        AppTextView.body3(
          subtitle,
          textAlign: TextAlign.center,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ],
    );
  }
}
