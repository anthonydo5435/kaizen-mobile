import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/widgets/app_ai_generate_button.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_share_button.dart';
import '../../../../core/widgets/app_swipe_reveal_action.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/paygrade_remote_data_source.dart';
import '../../data/repositories/paygrade_repository_impl.dart';
import '../../domain/entities/paygrade_detail.dart';
import '../../domain/usecases/get_paygrades_usecase.dart';
import '../providers/paygrade_detail_controller.dart';
import 'paygrade_entry_sheet.dart';
import 'paygrade_generate_sheet.dart';
import 'paygrade_share_dialogue.dart';

class PaygradeDetailScreen extends StatelessWidget {
  const PaygradeDetailScreen({super.key, required this.paygradeId, this.getPaygradesUseCase});

  final String paygradeId;
  final GetPaygradesUseCase? getPaygradesUseCase;
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PaygradeRemoteDataSource>(create: (_) => createPaygradeRemoteDataSource()),
        ProxyProvider<PaygradeRemoteDataSource, PaygradeRepositoryImpl>(
          update: (_, remoteDataSource, __) => createPaygradeDetailRepository(remoteDataSource),
        ),
        ProxyProvider<PaygradeRepositoryImpl, GetPaygradesUseCase>(
          update: (_, repository, __) => createGetPaygradeDetailUseCase(repository),
        ),
        ChangeNotifierProvider<PaygradeDetailController>(
          create: (context) =>
              PaygradeDetailController(getPaygradesUseCase ?? context.read<GetPaygradesUseCase>())
                ..initialize(paygradeId),
        ),
      ],
      child: const PaygradeDetailView(),
    );
  }
}

class PaygradeDetailView extends StatelessWidget {
  const PaygradeDetailView({super.key, this.isShared = false});

  final bool isShared;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PaygradeDetailController>();
    final detail = controller.detail;

    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          child: ListenableBuilder(
            listenable: AppManager.instance,
            builder: (context, _) {
              final canManageContent =
                  !isShared &&
                  !controller.isShared &&
                  AppManager.instance.currentUserCanManagePaygrades;

              return Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 18),
                  _PaygradeTabSwitcher(
                    selectedTab: controller.selectedTab,
                    onTabSelected: controller.selectTab,
                  ),
                  const SizedBox(height: 18),
                  if (controller.isLoading)
                    Expanded(child: Center(child: FastCircularProgressIndicator()))
                  else if (controller.errorMessage != null)
                    Expanded(child: _buildErrorMessage(controller))
                  else if (detail == null)
                    Expanded(child: _buildMessage(AppStrings.loginSomethingWentWrong))
                  else
                    Expanded(child: _buildContent(context, controller, detail, canManageContent)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PaygradeDetailController controller,
    PaygradeDetail detail,
    bool canManageContent,
  ) {
    final isSharedContent = isShared || controller.isShared;
    return ListView(
      children: [
        _buildSummary(
          detail,
          onShare: !isSharedContent && (controller.shareController?.canManage ?? false)
              ? () => showPaygradeShareDialogue(context, controller.shareController!)
              : null,
        ),
        if (canManageContent) ...[
          const SizedBox(height: 18),
          AppAiGenerateButton(
            label: AppStrings.paygradesGenerateWithAiAction,
            expand: true,
            minHeight: 44,
            showOutline: true,
            isLoading: controller.isGeneratingPaygrades,
            onTap: controller.isGeneratingPaygrades
                ? null
                : () => _openGeneratePaygradesSheet(context, controller),
          ),
        ],
        const SizedBox(height: 18),
        if (detail.payGrades.isEmpty) _buildMessage(AppStrings.paygradesNoDetailItemsFound),
        ...detail.payGrades.asMap().entries.map((item) {
          final entry = item.value;
          return Padding(
            key: ValueKey('${controller.selectedTab.name}-${entry.id}-${item.key}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: _PaygradeEntryCard(
              isEditable: canManageContent,
              isDeleting: controller.isDeletingPaygrade(entry.id),
              entry: entry,
              rowNumber: isShared ? entry.level : item.key + 1,
              alwaysExpanded: isSharedContent,
              showPayRate: !isSharedContent && controller.includesPayRates,
              payRateLabel: controller.payRateLabel,
              onEditTap: canManageContent
                  ? () => _openPaygradeSheet(context, controller, entry)
                  : null,
              onDeleteTap: canManageContent
                  ? () => _showDeleteDialog(context, controller, entry)
                  : null,
            ),
          );
        }),
        if (canManageContent) ...[
          SizedBox(height: detail.payGrades.isEmpty ? 18 : 2),
          _AddPaygradeLevelButton(onTap: () => _openCreatePaygradeSheet(context, controller)),
        ],
      ],
    );
  }

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (!isShared || navigator.canPop()) {
      navigator.pop();
      return;
    }
    final destination = AppPreference.getAuthToken().trim().isEmpty
        ? AppRouter.login
        : AppRouter.defaultAuthenticatedRouteName;
    navigator.pushReplacementNamed(destination);
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _goBack(context),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          icon: SvgPicture.asset(
            '${AppStrings.imagePath}back.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        Expanded(
          child: AppTextView.body(
            AppStrings.paygradesDetailsTitle,
            textAlign: TextAlign.center,
            color: AppColors.secondaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildSummary(PaygradeDetail detail, {VoidCallback? onShare}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextView.body1(
                  detail.title,
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
                if (detail.department.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  AppTextView.body2(
                    detail.department,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ],
            ),
          ),
          if (onShare != null) ...[const SizedBox(width: 12), AppShareButton(onTap: onShare)],
        ],
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Center(
      child: AppTextView.body(message, color: AppColors.textSecondary, textAlign: TextAlign.center),
    );
  }

  Widget _buildErrorMessage(PaygradeDetailController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextView.body(
            controller.errorMessage ?? AppStrings.loginSomethingWentWrong,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: controller.retry, child: const Text(AppStrings.actionRetry)),
        ],
      ),
    );
  }

  Future<void> _openPaygradeSheet(
    BuildContext context,
    PaygradeDetailController controller,
    PaygradeEntry entry,
  ) async {
    if (!AppManager.instance.currentUserCanManagePaygrades) {
      return;
    }

    final didSave = await showPaygradeEntryBottomSheet(
      context,
      entry: entry,
      mode: PaygradeEntrySheetMode.update,
      onSave:
          ({
            required String title,
            required String description,
            required String promotionRequirement,
            String? payRate,
          }) {
            return controller.updatePaygrade(
              entry: entry,
              title: title,
              description: description,
              promotionRequirement: promotionRequirement,
              payRate: payRate,
            );
          },
    );

    if (!didSave || !context.mounted) {
      return;
    }
  }

  Future<void> _openCreatePaygradeSheet(
    BuildContext context,
    PaygradeDetailController controller,
  ) async {
    if (!AppManager.instance.currentUserCanManagePaygrades) {
      return;
    }

    final didSave = await showPaygradeEntryBottomSheet(
      context,
      mode: PaygradeEntrySheetMode.create,
      onSave:
          ({
            required String title,
            required String description,
            required String promotionRequirement,
            String? payRate,
          }) {
            return controller.createPaygrade(
              title: title,
              description: description,
              promotionRequirement: promotionRequirement,
              payRate: payRate,
            );
          },
    );

    if (!didSave || !context.mounted) {
      return;
    }
  }

  Future<void> _openGeneratePaygradesSheet(
    BuildContext context,
    PaygradeDetailController controller,
  ) async {
    if (!AppManager.instance.currentUserCanManagePaygrades) {
      return;
    }

    final didGenerate = await showPaygradeGenerateSheet(
      context,
      controller: controller,
      hasExistingPaygrades: (controller.detail?.payGrades.length ?? 0) > 0,
    );

    if (!didGenerate || !context.mounted) {
      return;
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    PaygradeDetailController controller,
    PaygradeEntry entry,
  ) async {
    if (!AppManager.instance.currentUserCanManagePaygrades) {
      return;
    }

    final didDelete = await showDialog<bool>(
      context: context,
      builder: (_) => _DeletePaygradeDialog(controller: controller, entry: entry),
    );

    if (!context.mounted) {
      return;
    }

    if (didDelete == false && (controller.errorMessage ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: AppTextView.body2(controller.errorMessage!)));
    }
  }
}

class _PaygradeTabSwitcher extends StatelessWidget {
  const _PaygradeTabSwitcher({required this.selectedTab, required this.onTabSelected});

  final PaygradeDetailTab selectedTab;
  final ValueChanged<PaygradeDetailTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: AppStrings.paygradesPrimaryTab,
              isSelected: selectedTab == PaygradeDetailTab.primary,
              onTap: () => onTabSelected(PaygradeDetailTab.primary),
            ),
          ),
          Expanded(
            child: _TabButton(
              title: AppStrings.paygradesAncillaryTab,
              isSelected: selectedTab == PaygradeDetailTab.ancillary,
              onTap: () => onTabSelected(PaygradeDetailTab.ancillary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.title, required this.isSelected, required this.onTap});

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppTextView.body2(
          title,
          textAlign: TextAlign.center,
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaygradeEntryCard extends StatefulWidget {
  const _PaygradeEntryCard({
    required this.entry,
    required this.rowNumber,
    required this.isEditable,
    required this.isDeleting,
    required this.showPayRate,
    required this.payRateLabel,
    this.alwaysExpanded = false,
    this.onEditTap,
    this.onDeleteTap,
  });

  final PaygradeEntry entry;
  final int rowNumber;
  final bool isEditable;
  final bool isDeleting;
  final bool showPayRate;
  final String payRateLabel;
  final bool alwaysExpanded;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  @override
  State<_PaygradeEntryCard> createState() => _PaygradeEntryCardState();
}

class _PaygradeEntryCardState extends State<_PaygradeEntryCard> {
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
      builder: (context, isExpanded, _) => _buildCard(context, widget.alwaysExpanded || isExpanded),
    );
  }

  Widget _buildCard(BuildContext context, bool isExpanded) {
    final entry = widget.entry;
    final cleanedTitle = _cleanPaygradeTitle(entry.title);
    final paygradePrefix = _buildPaygradePrefix(cleanedTitle, widget.rowNumber);
    final cardTitle = '$paygradePrefix: $cleanedTitle';
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
            AppTextView.body1(
              cardTitle,
              fontSize: 16,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 16),
            if (widget.showPayRate) ...[
              const SizedBox(height: 6),
              _buildRow(widget.payRateLabel, AppStrings.paygradesHourlyRate(entry.payRate)),
            ],
            if (isExpanded) ...[
              const SizedBox(height: 8),
              _buildMultilineRow(
                context,
                AppStrings.paygradesDescription,
                entry.description,
                emptyValue: AppStrings.paygradesEmptyDescription,
              ),
              const SizedBox(height: 8),
              _buildMultilineRow(
                context,
                AppStrings.paygradesPromotionRequirement,
                entry.promotionRequirement,
                emptyValue: AppStrings.paygradesEmptyPromotionRequirement,
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.alwaysExpanded) {
      return card;
    }

    final canEdit = widget.isEditable && widget.onEditTap != null;
    final canDelete = widget.isEditable && widget.onDeleteTap != null;
    return AppSwipeRevealAction(
      isEnabled: !widget.isDeleting,
      borderRadius: 12,
      actionWidth: canEdit && canDelete ? 138 : 64,
      actionGap: 10,
      leadingActionWidth: 80,
      leadingActionChild: _PaygradeSwipeAction(
        label: isExpanded ? AppStrings.paygradesShowLessAction : AppStrings.paygradesShowMoreAction,
        color: AppColors.secondaryColor,
      ),
      onLeadingActionTap: () => _isExpanded.value = !isExpanded,
      actionBuilder: canEdit || canDelete
          ? (context, close) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canEdit)
                  Expanded(
                    child: _PaygradeSwipeAction(
                      label: AppStrings.paygradesEditAction,
                      color: AppColors.secondaryColor,
                      onTap: () {
                        close();
                        widget.onEditTap?.call();
                      },
                    ),
                  ),
                if (canEdit && canDelete) const SizedBox(width: 10),
                if (canDelete)
                  Expanded(
                    child: _PaygradeSwipeAction(
                      label: AppStrings.paygradesDeleteAction,
                      color: AppColors.red1,
                      onTap: () {
                        close();
                        widget.onDeleteTap?.call();
                      },
                      child: SvgPicture.asset(
                        '${AppStrings.imagePath}delete.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
              ],
            )
          : null,
      child: card,
    );
  }

  String _cleanPaygradeTitle(String title) {
    return title.replaceFirst(RegExp(r'^\s*paygrade\s*:\s*', caseSensitive: false), '').trim();
  }

  String _buildPaygradePrefix(String cleanedTitle, int rowNumber) {
    if (cleanedTitle.isEmpty) {
      return rowNumber.toString();
    }

    final prefix = cleanedTitle
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    if (prefix.isEmpty) {
      return rowNumber.toString();
    }

    return '$prefix$rowNumber';
  }

  Widget _buildRow(String label, String value) {
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        AppTextView.body2(label, color: AppColors.textSecondary),
        AppTextView.body2(
          value,
          textAlign: TextAlign.end,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }

  Widget _buildMultilineRow(
    BuildContext context,
    String label,
    String value, {
    required String emptyValue,
  }) {
    final resolvedValue = value.trim().isEmpty ? emptyValue : value.trim();
    final isEmpty = value.trim().isEmpty;
    const detailFontSize = 13.0;
    const detailFontWeight = FontWeight.w400;
    const detailLineHeight = 1.45;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = TextStyle(
          color: isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
          fontSize: detailFontSize,
          fontWeight: detailFontWeight,
          height: detailLineHeight,
        );
        final textPainter = TextPainter(
          text: TextSpan(text: resolvedValue, style: textStyle),
          maxLines: 3,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final shouldShowSeeAll = !isEmpty && textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextView.body3(label, color: AppColors.textSecondary),
            const SizedBox(height: 2),
            AppTextView.body(
              resolvedValue,
              color: isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
              fontSize: detailFontSize,
              fontWeight: detailFontWeight,
              height: detailLineHeight,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (shouldShowSeeAll) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () =>
                    _showExpandedTextDialog(context, title: label, description: resolvedValue),
                child: AppTextView.body2(
                  AppStrings.seeAllAction,
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showExpandedTextDialog(
    BuildContext context, {
    required String title,
    required String description,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PaygradeExpandedTextDialog(title: title, description: description),
    );
  }
}

class _PaygradeExpandedTextDialog extends StatelessWidget {
  const _PaygradeExpandedTextDialog({required this.title, required this.description});

  final String title;
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
                  Expanded(
                    child: AppTextView.body1(
                      title,
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _PaygradeExpandedTextDialogCloseButton(onTap: () => Navigator.of(context).pop()),
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

class _PaygradeExpandedTextDialogCloseButton extends StatelessWidget {
  const _PaygradeExpandedTextDialogCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppOverlayCloseButton(onTap: onTap);
  }
}

class _AddPaygradeLevelButton extends StatelessWidget {
  const _AddPaygradeLevelButton({required this.onTap});

  final VoidCallback onTap;
  static const double _borderRadius = 12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedPaygradeButtonPainter(
          color: AppColors.secondaryColor.withValues(alpha: 0.78),
          radius: _borderRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_borderRadius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: AppColors.secondaryColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: AppTextView.body3(
                      AppStrings.paygradesAddLevelAction,
                      color: AppColors.secondaryColor,
                      fontWeight: FontWeight.w700,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedPaygradeButtonPainter extends CustomPainter {
  const _DashedPaygradeButtonPainter({required this.color, required this.radius});

  final Color color;
  final double radius;
  static const double _strokeWidth = 1.2;
  static const double _dashWidth = 7;
  static const double _dashSpace = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final nextDistance = distance + _dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, nextDistance.clamp(0, metric.length)),
          Offset.zero,
        );
        distance += _dashWidth + _dashSpace;
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedPaygradeButtonPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _DeletePaygradeDialog extends StatelessWidget {
  const _DeletePaygradeDialog({required this.controller, required this.entry});

  final PaygradeDetailController controller;
  final PaygradeEntry entry;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return AppConfirmationDialog(
          title: AppStrings.paygradesDeleteTitle,
          description: AppStrings.paygradesDeleteDescription(entry.title),
          confirmText: AppStrings.paygradesDeleteAction,
          cancelText: AppStrings.trainingCancel,
          isConfirmLoading: controller.isDeletingPaygrade(entry.id),
          onCancelCallback: () async {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          onConfirmCallback: () async {
            final didDelete = await controller.deletePaygrade(entry);
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

class _PaygradeSwipeAction extends StatelessWidget {
  const _PaygradeSwipeAction({required this.label, required this.color, this.onTap, this.child});

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
