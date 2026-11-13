import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_selection_sheet.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../domain/entities/compliance_video_transcript.dart';
import '../providers/compliance_video_controller.dart';

Future<void> showComplianceVideoTranscriptSheet(BuildContext context) {
  final controller = context.read<ComplianceVideoController?>();
  controller?.clearSeekError();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => controller == null
        ? ChangeNotifierProvider(
            create: (_) => ComplianceVideoController(null),
            child: const _TranscriptSheet(),
          )
        : ChangeNotifierProvider<ComplianceVideoController>.value(
            value: controller,
            child: const _TranscriptSheet(),
          ),
  );
}

class ComplianceVideoTranscriptButton extends StatelessWidget {
  const ComplianceVideoTranscriptButton({
    super.key,
    required this.onPressed,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 6),
  });

  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        alignment: Alignment.bottomRight,
        padding: padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        AppStrings.trainingViewTranscript,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: AppColors.secondaryColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.secondaryColor,
        ),
      ),
    );
  }
}

class _TranscriptSheet extends StatelessWidget {
  const _TranscriptSheet();

  @override
  Widget build(BuildContext context) {
    final error = context.select<ComplianceVideoController, String?>(
      (controller) => controller.seekError,
    );
    return AppSelectionSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFilterSheetHeader(
            title: AppStrings.trainingTranscriptTitle,
            onClose: () => Navigator.of(context).pop(),
          ),
          const Expanded(child: _TranscriptSection()),
          AppSelectionError(message: error),
        ],
      ),
    );
  }
}

class _TranscriptSection extends StatefulWidget {
  const _TranscriptSection();

  @override
  State<_TranscriptSection> createState() => _TranscriptSectionState();
}

class _TranscriptSectionState extends State<_TranscriptSection> {
  final _scrollController = ScrollController();
  final _initialLineKey = GlobalKey();
  final _centerKey = GlobalKey();
  int? _initialIndex;
  bool _didInitialize = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) return;
    _didInitialize = true;
    _initialIndex = context
        .read<ComplianceVideoController>()
        .activeTranscriptIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final row = _initialLineKey.currentContext?.findRenderObject();
      if (row is! RenderBox || !row.hasSize) return;
      final position = _scrollController.position;
      final offset = (row.size.height - position.viewportDimension) / 2;
      _scrollController.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComplianceVideoController>();
    final lines = controller.transcriptLines;
    if (lines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: AppTextView.body3(
            AppStrings.trainingNoTranscriptAvailable,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    final initialIndex = _initialIndex;
    if (initialIndex == null) {
      return ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: lines.length,
        separatorBuilder: (_, index) => const SizedBox(height: 14),
        itemBuilder: (_, index) => _buildItem(controller, index),
      );
    }
    // Start layout at the active cue so long, variable-height lists open immediately.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomScrollView(
        controller: _scrollController,
        center: _centerKey,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          SliverList.builder(
            itemCount: initialIndex,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildItem(controller, initialIndex - index - 1),
            ),
          ),
          SliverList.separated(
            key: _centerKey,
            itemCount: lines.length - initialIndex,
            separatorBuilder: (_, index) => const SizedBox(height: 14),
            itemBuilder: (_, index) => _buildItem(
              controller,
              initialIndex + index,
              key: index == 0 ? _initialLineKey : null,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildItem(
    ComplianceVideoController controller,
    int index, {
    Key? key,
  }) {
    final line = controller.transcriptLines[index];
    return _TranscriptItem(
      key: key,
      line: line,
      isHighlighted: controller.activeTranscriptIndex == index,
      isSeeking: controller.seekingIndex == index,
      onTap: line.start == null || controller.isSeeking
          ? null
          : () async {
              final didSeek = await controller.seekToTranscriptLine(index);
              if (mounted && didSeek) Navigator.of(context).pop();
            },
    );
  }
}

class _TranscriptItem extends StatelessWidget {
  const _TranscriptItem({
    super.key,
    required this.line,
    required this.isHighlighted,
    required this.isSeeking,
    required this.onTap,
  });

  final ComplianceTranscriptLine line;
  final bool isHighlighted;
  final bool isSeeking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final start = line.start;
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (start != null) ...[
            SizedBox(
              width: 84,
              child: Row(
                children: [
                  Flexible(
                    child: AppTextView.body3(
                      CustomFunctions.formatDuration(start.inSeconds),
                      color: isHighlighted
                          ? AppColors.secondaryColor
                          : AppColors.textSecondary,
                      fontWeight: isHighlighted
                          ? FontWeight.w700
                          : FontWeight.w500,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: isSeeking
                        ? const FastCircularProgressIndicator(
                            width: 14,
                            height: 14,
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: AppTextView.body3(
              line.text,
              color: isHighlighted
                  ? AppColors.secondaryColor
                  : AppColors.textPrimary,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
