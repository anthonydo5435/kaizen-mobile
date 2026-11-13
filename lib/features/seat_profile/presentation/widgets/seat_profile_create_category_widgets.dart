part of '../pages/seat_profile_create_screen.dart';

class _CategoryRemainingCard extends StatelessWidget {
  const _CategoryRemainingCard({
    required this.remainingImportanceLabel,
    required this.isBalanced,
    required this.isCompact,
  });

  final String remainingImportanceLabel;
  final bool isBalanced;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCompact ? double.infinity : 220,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 18,
        vertical: isCompact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: isBalanced ? AppColors.secondaryColor : AppColors.red1,
        borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextView.title1(
              remainingImportanceLabel,
              color: AppColors.textPrimary,
              fontSize: isCompact ? 28 : 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: isCompact ? 10 : 12),
          Expanded(
            child: AppTextView.body1(
              AppStrings.seatProfileCategoryImportanceRemaining,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 14 : 18,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatCategoryInputRow extends StatelessWidget {
  const _SeatCategoryInputRow({
    required this.rowController,
    required this.onDeleteTap,
    required this.isCompact,
    required this.amountFieldWidth,
  });

  final SeatProfileCategoryRowController rowController;
  final VoidCallback? onDeleteTap;
  final bool isCompact;
  final double amountFieldWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DialogInputField(
            controller: rowController.nameController,
            hintText: AppStrings.seatProfileCategoryNameColumn,
            isCompact: isCompact,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(
                SeatProfileCategoryFormController.maxCategoryTitleLength,
              ),
            ],
          ),
        ),
        SizedBox(width: isCompact ? 8 : 12),
        SizedBox(
          width: amountFieldWidth,
          child: _DialogInputField(
            controller: rowController.weightController,
            hintText: AppStrings.seatProfileCategoryImportanceHint,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            isCompact: isCompact,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
        ),
        SizedBox(width: isCompact ? 6 : 8),
        SizedBox(
          width: isCompact ? 28 : 32,
          height: isCompact ? 46 : 52,
          child: InkWell(
            onTap: onDeleteTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: SvgPicture.asset(
                '${AppStrings.imagePath}delete.svg',
                colorFilter: const ColorFilter.mode(
                  AppColors.red1,
                  BlendMode.srcIn,
                ),
                width: isCompact ? 20 : 22,
                height: isCompact ? 20 : 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogInputField extends StatelessWidget {
  const _DialogInputField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textAlign = TextAlign.left,
    this.inputFormatters,
    this.isCompact = false,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isCompact ? 46 : 52,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.32),
        ),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textAlign: textAlign,
          inputFormatters: inputFormatters,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: AppColors.textPrimary,
          decoration: InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.65),
              fontSize: isCompact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogDottedActionButton extends StatelessWidget {
  const _DialogDottedActionButton({
    required this.label,
    required this.onTap,
    this.isCompact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.58,
      child: CustomPaint(
        painter: _SeatProfileDottedRoundedBorderPainter(
          color: AppColors.fieldBorder.withValues(alpha: 0.45),
          radius: isCompact ? 16 : 18,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
            child: Ink(
              height: isCompact ? 56 : 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
              ),
              child: Center(
                child: AppTextView.body1(
                  label,
                  color: AppColors.fieldBorder.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: isCompact ? 15 : 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageSeatCategoriesIntroSection extends StatelessWidget {
  const _ManageSeatCategoriesIntroSection({
    required this.isCompact,
    required this.remainingImportanceLabel,
    required this.isBalanced,
  });

  final bool isCompact;
  final String remainingImportanceLabel;
  final bool isBalanced;

  @override
  Widget build(BuildContext context) {
    final infoCard = Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.mainBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body1(
            AppStrings.seatProfileManageCategoriesSectionTitle,
            color: AppColors.lightPurple2,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
          SizedBox(height: isCompact ? 8 : 10),
          AppTextView.body(
            AppStrings.seatProfileManageCategoriesDescription,
            color: AppColors.lightPurple1,
            fontSize: isCompact ? 13 : 15,
            height: 1.45,
          ),
        ],
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          infoCard,
          const SizedBox(height: 12),
          _CategoryRemainingCard(
            remainingImportanceLabel: remainingImportanceLabel,
            isBalanced: isBalanced,
            isCompact: true,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: infoCard),
        const SizedBox(width: 16),
        _CategoryRemainingCard(
          remainingImportanceLabel: remainingImportanceLabel,
          isBalanced: isBalanced,
          isCompact: false,
        ),
      ],
    );
  }
}

class _SeatCategoryHeaderRow extends StatelessWidget {
  const _SeatCategoryHeaderRow({
    required this.isCompact,
    required this.amountFieldWidth,
    required this.deleteSlotWidth,
  });

  final bool isCompact;
  final double amountFieldWidth;
  final double deleteSlotWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextView.body1(
            AppStrings.seatProfileCategoryNameColumn,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 15 : 18,
          ),
        ),
        SizedBox(width: isCompact ? 8 : 12),
        SizedBox(
          width: amountFieldWidth,
          child: AppTextView.body1(
            AppStrings.seatProfileImportancePercentColumn,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 14 : 18,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: deleteSlotWidth),
      ],
    );
  }
}

class _SeatCategoryActionFooter extends StatelessWidget {
  const _SeatCategoryActionFooter({
    required this.isCompact,
    required this.totalImportanceLabel,
    required this.onAddTap,
  });

  final bool isCompact;
  final String totalImportanceLabel;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogDottedActionButton(
            label: AppStrings.seatProfileAddSeatCategoryAction,
            onTap: onAddTap,
            isCompact: true,
          ),
          const SizedBox(height: 10),
          AppTextView.body2(
            totalImportanceLabel,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.right,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _DialogDottedActionButton(
            label: AppStrings.seatProfileAddSeatCategoryAction,
            onTap: onAddTap,
          ),
        ),
        const SizedBox(width: 16),
        AppTextView.body1(
          totalImportanceLabel,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}
