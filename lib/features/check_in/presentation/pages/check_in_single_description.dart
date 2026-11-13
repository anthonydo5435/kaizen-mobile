import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/widgets/app_button.dart';
import 'package:sparrowkaizen/core/widgets/app_text_view.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/quarterly_audit.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_media_preview.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/description_media_comment_bottom_sheet.dart';

import '../../../training/presentation/pages/edit_training_screen.dart';
import '../providers/check_in_single_description_controller.dart';
import '../widgets/description_text_comment_dialog.dart';
import 'check_in_media_comments_bottom_sheet.dart';
import 'check_in_screen_recording_capture_screen.dart';

part '../widgets/check_in_single_description_cards.dart';
part '../widgets/check_in_single_description_comments.dart';
part '../widgets/check_in_single_description_ratings.dart';

class SingleDescriptionDetails extends StatefulWidget {
  const SingleDescriptionDetails({
    super.key,
    required this.audit,
    required this.descriptions,
    required this.initialDescriptionIndex,
    required this.date,
    required this.isOwner,
    this.isViewOnly = false,
    this.isSelfAudit = false,
    this.initialRatingCounts,
  });

  final QuarterlyAudit audit;
  final List<QuarterlyAuditDescription> descriptions;
  final int initialDescriptionIndex;
  final String date;
  final bool isOwner;
  final bool isViewOnly;
  final bool isSelfAudit;
  final Map<String, int>? initialRatingCounts;

  @override
  State<SingleDescriptionDetails> createState() =>
      _SingleDescriptionDetailsState();
}

class _SingleDescriptionDetailsState extends State<SingleDescriptionDetails> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.initialDescriptionIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 2, 8, 0),
              child: _DescriptionDetailsHeader(),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _CheckInProfileCard(
                profile: CheckInSingleDescriptionController.buildProfileData(
                  widget.audit,
                  widget.date,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: _DescriptionPageCounter(
                controller: _pageController,
                pageCount: widget.descriptions.length,
                onPageSelected: _goToDescriptionPage,
              ),
            ),
            Expanded(child: _buildDescriptionPager(context)),
          ],
        ),
      ),
    );
  }

  void _goToDescriptionPage(int page) {
    if (!_pageController.hasClients ||
        page < 0 ||
        page >= widget.descriptions.length) {
      return;
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(page);
      return;
    }

    unawaited(
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  Widget _buildDescriptionPager(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      // The next description enters from the right when dragging right to left.
      reverse: false,
      itemCount: widget.descriptions.length,
      onPageChanged: (index) {
        context.read<CheckInController>().selectQuarterlyAuditDescription(
          widget.descriptions[index].uuid,
        );
      },
      itemBuilder: (context, index) {
        final description = widget.descriptions[index];
        return _AnimatedDescriptionPage(
          key: ValueKey(description.uuid),
          controller: _pageController,
          pageIndex: index,
          child: _DescriptionDetailsPage(
            key: ValueKey(
              '${widget.audit.uuid}:${description.uuid}:${widget.date}',
            ),
            audit: widget.audit,
            description: description,
            date: widget.date,
            isOwner: widget.isOwner,
            isViewOnly: widget.isViewOnly,
            isSelfAudit: widget.isSelfAudit,
            initialRatingCounts: index == widget.initialDescriptionIndex
                ? widget.initialRatingCounts
                : null,
          ),
        );
      },
    );
  }
}

class _AnimatedDescriptionPage extends StatelessWidget {
  const _AnimatedDescriptionPage({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.child,
  });

  final PageController controller;
  final int pageIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedBuilder(
        animation: controller,
        child: RepaintBoundary(child: child),
        builder: (context, pageContent) {
          final page = controller.hasClients
              ? controller.page ?? controller.initialPage.toDouble()
              : controller.initialPage.toDouble();
          final distance = (page - pageIndex).abs().clamp(0.0, 1.0);
          final progress = reduceMotion
              ? 0.0
              : Curves.easeInOutCubic.transform(distance);

          // Follow the swipe without rebuilding the page's ratings or comments.
          return Transform.translate(
            offset: Offset(0, 8 * progress),
            child: Transform.scale(
              scale: 1 - 0.04 * progress,
              alignment: Alignment.topCenter,
              child: Opacity(opacity: 1 - 0.12 * progress, child: pageContent),
            ),
          );
        },
      ),
    );
  }
}

class _DescriptionPageCounter extends StatelessWidget {
  const _DescriptionPageCounter({
    required this.controller,
    required this.pageCount,
    required this.onPageSelected,
  });

  final PageController controller;
  final int pageCount;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentPage = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble()).round()
            : controller.initialPage;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DescriptionPagerArrow(
              icon: Icons.arrow_back_rounded,
              tooltip: AppStrings.auditPreviousDescription,
              onPressed: currentPage > 0
                  ? () => onPageSelected(currentPage - 1)
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AppTextView.body2(
                AppStrings.auditDescriptionPagePosition(
                  currentPage + 1,
                  pageCount,
                ),
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _DescriptionPagerArrow(
              icon: Icons.arrow_forward_rounded,
              tooltip: AppStrings.auditNextDescription,
              onPressed: currentPage < pageCount - 1
                  ? () => onPageSelected(currentPage + 1)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _DescriptionPagerArrow extends StatelessWidget {
  const _DescriptionPagerArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        backgroundColor: AppColors.surfaceDark,
        disabledForegroundColor: AppColors.textSecondary.withValues(
          alpha: 0.35,
        ),
        disabledBackgroundColor: AppColors.surfaceDark.withValues(alpha: 0.5),
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(32, 32),
        fixedSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: const CircleBorder(),
      ),
    );
  }
}

class _DescriptionDetailsPage extends StatefulWidget {
  const _DescriptionDetailsPage({
    super.key,
    required this.audit,
    required this.description,
    required this.date,
    required this.isOwner,
    required this.isViewOnly,
    required this.isSelfAudit,
    this.initialRatingCounts,
  });

  final QuarterlyAudit audit;
  final QuarterlyAuditDescription description;
  final String date;
  final bool isOwner;
  final bool isViewOnly;
  final bool isSelfAudit;
  final Map<String, int>? initialRatingCounts;

  @override
  State<_DescriptionDetailsPage> createState() =>
      _DescriptionDetailsPageState();
}

class _DescriptionDetailsPageState extends State<_DescriptionDetailsPage>
    with AutomaticKeepAliveClientMixin<_DescriptionDetailsPage> {
  late final CheckInSingleDescriptionController _controller;
  final ScrollController _scrollController = ScrollController();

  // Keep each page and controller mounted while paging, including pending saves.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = CheckInSingleDescriptionController(
      checkInController: context.read<CheckInController>(),
      audit: widget.audit,
      description: widget.description,
      date: widget.date,
      isOwner: widget.isOwner,
      isViewOnly: widget.isViewOnly,
      isSelfAudit: widget.isSelfAudit,
      initialRatingCounts: widget.initialRatingCounts,
    )..addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _DescriptionDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOwner != widget.isOwner ||
        oldWidget.isViewOnly != widget.isViewOnly ||
        oldWidget.isSelfAudit != widget.isSelfAudit) {
      _controller.updateAccess(
        isOwner: widget.isOwner,
        isViewOnly: widget.isViewOnly,
        isSelfAudit: widget.isSelfAudit,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final message = _controller.takeErrorMessage();
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToCommentsSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Future<void> scrollToBottom({
        Duration duration = const Duration(milliseconds: 320),
      }) async {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
      }

      scrollToBottom().then((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await scrollToBottom(duration: const Duration(milliseconds: 220));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            _SeatDescriptionCard(seatDescription: _controller.descriptionText),
            const SizedBox(height: 18),
            _SeatSpecificsCard(controller: _controller),
            const SizedBox(height: 18),
            _PassSelectionCard(controller: _controller),
            const SizedBox(height: 18),
            _CommentsCard(
              controller: _controller,
              onCommentsSheetClosed: _scrollToCommentsSection,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DescriptionDetailsHeader extends StatelessWidget {
  const _DescriptionDetailsHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                child: SvgPicture.asset(
                  '${AppStrings.imagePath}back.svg',
                  height: 24,
                  width: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          const AppTextView.body(
            AppStrings.auditDescriptionDetails,
            color: AppColors.secondaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}
