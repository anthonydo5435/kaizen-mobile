import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_swipe_reveal_action.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../training/domain/entities/seat_description_training_route.dart';
import '../../../training/presentation/pages/edit_training_screen.dart';
import '../../domain/entities/seat_profile_detail.dart';
import '../../widgets/seat_profile_dotted_action_button.dart';
import '../providers/seat_profile_detail_controller.dart';
import 'seat_profile_description_sheet.dart';

class SeatProfileDescriptionsScreen extends StatelessWidget {
  const SeatProfileDescriptionsScreen({
    super.key,
    required this.category,
    this.controller,
    this.isShared = false,
  });

  final SeatProfileCategory category;
  final SeatProfileDetailController? controller;
  final bool isShared;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppManager.instance,
        if (controller != null) controller!,
      ]),
      builder: (context, _) {
        final detail = controller?.detail;
        final currentCategory =
            detail?.categories
                .where((item) => item.id == category.id)
                .firstOrNull ??
            category;
        final canManageContent =
            controller != null && _canManageSeatProfile(detail);

        return _DescriptionsScaffold(
          child: _DescriptionsList(
            category: currentCategory,
            controller: controller,
            detail: detail,
            canManageContent: canManageContent,
            isShared: isShared,
            onOpenDescription: (description) =>
                _showSeatDescriptionSheet(context, controller!, description),
            onDeleteDescription: (description) =>
                _showDeleteDescriptionDialog(context, controller!, description),
            onAddDescription: () =>
                _showSeatAdditionSheet(context, controller!, currentCategory),
          ),
        );
      },
    );
  }

  Future<void> _showSeatAdditionSheet(
    BuildContext context,
    SeatProfileDetailController controller,
    SeatProfileCategory category,
  ) async {
    if (!_canManageSeatProfile(controller.detail)) {
      return;
    }

    await showSeatProfileDescriptionBottomSheet(
      context,
      description: const SeatProfileDescription(
        id: '',
        actualId: '',
        name: '',
        auditSpecifics: '',
        auditFactorType: 'observation',
        milestoneDays: '30',
      ),
      title: AppStrings.seatProfileSeatAdditionDialogTitle,
      descriptionText: AppStrings.seatProfileCreateDescriptionSheetDescription,
      submitLabel: AppStrings.seatProfileSaveAction,
      onSave: (formData) => controller.addSeatDescription(
        categoryId: category.id,
        descriptionName: formData.descriptionName,
        auditSpecifics: formData.auditSpecifics,
        auditFactorType: formData.auditFactorType,
        milestoneDays: formData.milestoneDays,
      ),
    );
  }

  Future<void> _showSeatDescriptionSheet(
    BuildContext context,
    SeatProfileDetailController controller,
    SeatProfileDescription description,
  ) async {
    if (!_canManageSeatProfile(controller.detail)) {
      return;
    }

    await showSeatProfileDescriptionBottomSheet(
      context,
      description: description,
      onSave: (formData) => controller.updateSeatDescription(
        description: description,
        descriptionName: formData.descriptionName,
        auditSpecifics: formData.auditSpecifics,
        auditFactorType: formData.auditFactorType,
        milestoneDays: formData.milestoneDays,
      ),
    );
  }

  Future<void> _showDeleteDescriptionDialog(
    BuildContext context,
    SeatProfileDetailController controller,
    SeatProfileDescription description,
  ) async {
    if (!_canManageSeatProfile(controller.detail)) {
      return;
    }

    await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteSeatDescriptionDialog(
        controller: controller,
        description: description,
      ),
    );
  }

  bool _canManageSeatProfile(SeatProfileDetail? detail) {
    if (isShared) return false;
    final departmentId = detail?.department?.id.trim() ?? '';
    return AppManager.instance.canCurrentUserManageSeatProfileDepartment(
      departmentId: departmentId,
    );
  }
}

class _DescriptionsScaffold extends StatelessWidget {
  const _DescriptionsScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      appBar: AppBar(
        backgroundColor: AppColors.mainBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const AppTextView.title1(
          AppStrings.seatProfileDescriptionsTitle,
          color: AppColors.secondaryColor,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          child: child,
        ),
      ),
    );
  }
}

class _DescriptionsList extends StatelessWidget {
  const _DescriptionsList({
    required this.category,
    required this.controller,
    required this.detail,
    required this.canManageContent,
    required this.isShared,
    required this.onOpenDescription,
    required this.onDeleteDescription,
    required this.onAddDescription,
  });

  final SeatProfileCategory category;
  final SeatProfileDetailController? controller;
  final SeatProfileDetail? detail;
  final bool canManageContent;
  final bool isShared;
  final ValueChanged<SeatProfileDescription> onOpenDescription;
  final ValueChanged<SeatProfileDescription> onDeleteDescription;
  final VoidCallback onAddDescription;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (category.descriptions.isEmpty)
          const SliverToBoxAdapter(
            child: AppTextView.body2(
              AppStrings.seatProfileNoDescriptionsFound,
              color: AppColors.textSecondary,
            ),
          )
        else
          SliverList.separated(
            itemCount: category.descriptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildDescription(category.descriptions[index]),
          ),
        if (canManageContent)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SeatProfileDottedActionButton(
                label: AppStrings.seatProfileAddSeatDescriptionAction,
                onTap: onAddDescription,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescription(SeatProfileDescription description) {
    final isDeleting = controller?.isDeletingDescription(description) ?? false;
    return _DescriptionCard(
      key: ValueKey(description.id),
      name: description.name,
      auditFactorType: description.auditFactorType,
      isDeleting: isDeleting,
      onEdit: canManageContent && !isDeleting
          ? () => onOpenDescription(description)
          : null,
      onDelete: canManageContent && !isDeleting
          ? () => onDeleteDescription(description)
          : null,
      canManageContent: canManageContent,
      details: _DescriptionDetails(
        isDeleting: isDeleting,
        canManageContent: canManageContent,
        isShared: isShared,
        seatProfileId: detail?.id ?? '',
        seatProfileResolvedId: detail?.resolvedSeatId ?? '',
        categoryId: category.id,
        description: description,
        onOpenDescription: () => onOpenDescription(description),
      ),
    );
  }
}

/// Retains details through interrupted transitions without exposing collapsed actions.
class _DescriptionCard extends StatefulWidget {
  const _DescriptionCard({
    super.key,
    required this.name,
    required this.auditFactorType,
    required this.details,
    required this.isDeleting,
    required this.canManageContent,
    this.onDelete,
    this.onEdit,
  });

  final String name;
  final String auditFactorType;
  final Widget details;
  final bool isDeleting;
  final bool canManageContent;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard>
    with SingleTickerProviderStateMixin {
  static const _expandDuration = Duration(milliseconds: 320);
  static const _collapseDuration = Duration(milliseconds: 280);

  final ValueNotifier<bool> _isExpanded = ValueNotifier(false);
  late final AnimationController _expansionController;
  late final CurvedAnimation _expansion;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: _expandDuration,
      reverseDuration: _collapseDuration,
    );
    _expansion = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    _expansionController
      ..duration = disableAnimations ? Duration.zero : _expandDuration
      ..reverseDuration = disableAnimations ? Duration.zero : _collapseDuration;
  }

  @override
  void dispose() {
    _isExpanded.dispose();
    _expansion.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    _isExpanded.value = !_isExpanded.value;
    if (_isExpanded.value) {
      _expansionController.forward();
    } else {
      _expansionController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isExpanded,
      builder: (context, isExpanded, _) => AppSwipeRevealAction(
        isEnabled: !widget.isDeleting,
        actionWidth: 138,
        leadingActionWidth: 80,
        leadingActionChild: _DescriptionSwipeAction(
          label: isExpanded
              ? AppStrings.seatProfileShowLessAction
              : AppStrings.seatProfileShowMoreAction,
          color: AppColors.secondaryColor,
        ),
        onLeadingActionTap: _toggleExpansion,
        actionBuilder: widget.canManageContent
            ? (_, close) => _DescriptionSwipeEditActions(
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                close: close,
              )
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _toggleExpansion,
                borderRadius: BorderRadius.circular(12),
                splashFactory: NoSplash.splashFactory,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: AppTextView.body2(
                    widget.name,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _DescriptionCheckInTypeRow(
                auditFactorType: widget.auditFactorType,
              ),
              SizeTransition(
                sizeFactor: _expansion,
                axisAlignment: -1,
                child: FadeTransition(
                  opacity: _expansion,
                  child: AnimatedBuilder(
                    animation: _expansionController,
                    builder: (context, child) {
                      final canInteract =
                          isExpanded && _expansionController.isCompleted;
                      return IgnorePointer(
                        ignoring: !canInteract,
                        child: ExcludeSemantics(
                          excluding: !canInteract,
                          child: ExcludeFocus(
                            excluding: !canInteract,
                            child: child!,
                          ),
                        ),
                      );
                    },
                    child: widget.details,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescriptionSwipeEditActions extends StatelessWidget {
  const _DescriptionSwipeEditActions({
    required this.onEdit,
    required this.onDelete,
    required this.close,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _DescriptionSwipeAction(
            label: AppStrings.seatProfileEditAction,
            color: AppColors.secondaryColor,
            onTap: () {
              close();
              onEdit?.call();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DescriptionSwipeAction(
            label: AppStrings.seatProfileDeleteDescriptionAction,
            color: AppColors.red1,
            onTap: () {
              close();
              onDelete?.call();
            },
            child: SvgPicture.asset(
              '${AppStrings.imagePath}delete.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DescriptionSwipeAction extends StatelessWidget {
  const _DescriptionSwipeAction({
    required this.label,
    required this.color,
    this.onTap,
    this.child,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child:
                  child ??
                  AppTextView.body3(
                    label,
                    color: AppColors.textPrimary,
                    textAlign: TextAlign.center,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DescriptionCheckInTypeRow extends StatelessWidget {
  const _DescriptionCheckInTypeRow({required this.auditFactorType});

  final String auditFactorType;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: AppTextView.body3(
            '${AppStrings.seatProfileCheckInType}:',
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: AppTextView.body3(
            seatProfileDescriptionCheckInTypeLabel(auditFactorType),
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DescriptionDetails extends StatelessWidget {
  const _DescriptionDetails({
    required this.isDeleting,
    required this.canManageContent,
    required this.isShared,
    required this.seatProfileId,
    required this.seatProfileResolvedId,
    required this.categoryId,
    required this.description,
    required this.onOpenDescription,
  });

  final bool isDeleting;
  final bool canManageContent;
  final bool isShared;
  final String seatProfileId;
  final String seatProfileResolvedId;
  final String categoryId;
  final SeatProfileDescription description;
  final VoidCallback onOpenDescription;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDeleting || !canManageContent ? null : onOpenDescription,
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                AppTextView.body3(
                  '${AppStrings.seatProfileMilestoneDays}:',
                  color: AppColors.textSecondary,
                ),
                AppTextView.body3(
                  seatProfileDescriptionMilestoneLabel(
                    description.milestoneDays,
                  ),
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextView.body3(
              AppStrings.seatProfileAuditSpecifics,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            _ExpandableDescriptionText(
              description: description.auditSpecifics,
              onSeeAllTap: isDeleting
                  ? null
                  : () => _showAuditSpecificsDialog(context),
            ),
            if (!isShared) ...[
              const SizedBox(height: 12),
              _DescriptionActionRow(
                canEdit: canManageContent,
                onEditTap: isDeleting ? null : onOpenDescription,
                onTrainingTap: isDeleting
                    ? null
                    : () => _openTrainingModules(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openTrainingModules(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditTrainingScreen(
          trainingRoute: SeatDescriptionTrainingRoute(
            job: seatProfileId,
            category: categoryId,
            description: description.id,
          ),
          canManageTraining: AppManager.instance
              .canCurrentUserManageTrainingForSeatProfile(
                seatProfileId: seatProfileId,
                additionalSeatProfileIds: <String>[seatProfileResolvedId],
              ),
          useNonBlockingVideoUpload: true,
        ),
      ),
    );
  }

  Future<void> _showAuditSpecificsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _AuditSpecificsDialog(description: description.auditSpecifics),
    );
  }
}

class _DeleteSeatDescriptionDialog extends StatelessWidget {
  const _DeleteSeatDescriptionDialog({
    required this.controller,
    required this.description,
  });

  final SeatProfileDetailController controller;
  final SeatProfileDescription description;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return AppConfirmationDialog(
          title: AppStrings.seatProfileDeleteDescriptionTitle,
          description: AppStrings.seatProfileDeleteDescriptionDescription(
            description.name,
          ),
          confirmText: AppStrings.seatProfileDeleteDescriptionAction,
          cancelText: AppStrings.actionCancel,
          isConfirmLoading: controller.isDeletingDescription(description),
          onCancelCallback: () async {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          onConfirmCallback: () async {
            final didDelete = await controller.deleteSeatDescription(
              description,
            );
            if (!context.mounted) {
              return;
            }

            Navigator.of(context).pop(didDelete);
          },
        );
      },
    );
  }
}

class _DescriptionActionRow extends StatelessWidget {
  const _DescriptionActionRow({
    required this.canEdit,
    required this.onEditTap,
    required this.onTrainingTap,
  });

  final bool canEdit;
  final VoidCallback? onEditTap;
  final VoidCallback? onTrainingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canEdit)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _DescriptionActionTextButton(
                label: AppStrings.seatProfileEditAction,
                onTap: onEditTap,
              ),
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _DescriptionActionTextButton(
              label: AppStrings.seatProfileViewTrainings,
              onTap: onTrainingTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _DescriptionActionTextButton extends StatelessWidget {
  const _DescriptionActionTextButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: AppTextView.body4(
            label,
            fontSize: 12,
            color: onTap == null
                ? AppColors.textSecondary
                : AppColors.secondaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ExpandableDescriptionText extends StatelessWidget {
  const _ExpandableDescriptionText({
    required this.description,
    this.onSeeAllTap,
  });

  final String description;
  final VoidCallback? onSeeAllTap;

  static const _maxLines = 7;
  static const _linkPadding = 2.0;

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style.merge(
      const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          maxLines: _maxLines,
          textScaler: textScaler,
          textDirection: textDirection,
        )..layout(maxWidth: constraints.maxWidth);

        try {
          if (!textPainter.didExceedMaxLines) {
            return Text(description, style: textStyle, maxLines: _maxLines);
          }
          return _buildEllipsizedText(
            textPainter: textPainter,
            textStyle: textStyle,
            textScaler: textScaler,
            textDirection: textDirection,
            maxWidth: constraints.maxWidth,
          );
        } finally {
          textPainter.dispose();
        }
      },
    );
  }

  Widget _buildEllipsizedText({
    required TextPainter textPainter,
    required TextStyle textStyle,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required double maxWidth,
  }) {
    final linkStyle = textStyle.copyWith(
      color: AppColors.secondaryColor,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.secondaryColor,
    );
    final linkScale = textScaler.scale(12) / 12;
    final scaledPadding = _linkPadding * linkScale;
    final linkPainter =
        TextPainter(
          text: TextSpan(text: AppStrings.seeAllAction, style: linkStyle),
          textScaler: textScaler,
          textDirection: textDirection,
        )..layout(
          maxWidth: (maxWidth - scaledPadding * 2).clamp(0, double.infinity),
        );

    final link = WidgetSpan(
      style: linkStyle,
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: InkWell(
        onTap: onSeeAllTap,
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.all(_linkPadding),
          // WidgetSpan applies the surrounding text scale to its child.
          child: Text(
            AppStrings.seeAllAction,
            style: linkStyle,
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    );

    try {
      textPainter.text = TextSpan(style: textStyle, children: [link]);
      textPainter.setPlaceholderDimensions([
        PlaceholderDimensions(
          size: Size(
            linkPainter.width + scaledPadding * 2,
            linkPainter.height + scaledPadding * 2,
          ),
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          baselineOffset:
              linkPainter.computeDistanceToActualBaseline(
                TextBaseline.alphabetic,
              ) +
              scaledPadding,
        ),
      ]);

      final characters = description.characters.toList(growable: false);
      TextSpan preview(int length) => TextSpan(
        style: textStyle,
        children: [
          TextSpan(
            text:
                '${characters.take(length).join().trimRight()}${AppStrings.seatProfileDescriptionEllipsis}',
          ),
          link,
        ],
      );

      // Reserve room for the inline link without splitting an emoji or exceeding the preview.
      var lower = 0;
      var upper = characters.length;
      while (lower < upper) {
        final middle = (lower + upper + 1) ~/ 2;
        textPainter.text = preview(middle);
        textPainter.layout(maxWidth: maxWidth);
        if (textPainter.didExceedMaxLines) {
          upper = middle - 1;
        } else {
          lower = middle;
        }
      }
      return Text.rich(preview(lower), maxLines: _maxLines);
    } finally {
      linkPainter.dispose();
    }
  }
}

class _AuditSpecificsDialog extends StatelessWidget {
  const _AuditSpecificsDialog({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: AppDialogStyle.shape(radius: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: AppTextView.body1(
                      AppStrings.seatProfileAuditSpecifics,
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _AuditSpecificsDialogCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const AppDotDivider(),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: AppTextView.body(
                    description,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 140,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.done),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditSpecificsDialogCloseButton extends StatelessWidget {
  const _AuditSpecificsDialogCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppOverlayCloseButton(onTap: onTap);
  }
}
