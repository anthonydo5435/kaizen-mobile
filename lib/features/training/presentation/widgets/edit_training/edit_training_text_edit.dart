part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class _TrainingTextEditSheet extends StatefulWidget {
  const _TrainingTextEditSheet({
    required this.sheetTitle,
    required this.sheetDescription,
    required this.fieldLabel,
    required this.hintText,
    required this.initialValue,
    required this.saveButtonLabel,
    required this.saveIcon,
    required this.onSave,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.done,
  });

  final String sheetTitle;
  final String sheetDescription;
  final String fieldLabel;
  final String hintText;
  final String initialValue;
  final String saveButtonLabel;
  final IconData saveIcon;
  final Future<bool> Function(String value) onSave;
  final String? Function(String value)? validator;
  final int minLines;
  final int maxLines;
  final TextInputAction textInputAction;

  @override
  State<_TrainingTextEditSheet> createState() => _TrainingTextEditSheetState();
}

class _TrainingTextEditSheetState extends State<_TrainingTextEditSheet> {
  late final TextEditingController _controller;
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _errorTextNotifier = ValueNotifier<String?>(null);
  late final Listenable _sheetListenable;

  bool get _canSave => _controller.text.trim().isNotEmpty && !_isSavingNotifier.value;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)..addListener(_handleTextChanged);
    _sheetListenable = Listenable.merge([_controller, _isSavingNotifier, _errorTextNotifier]);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _isSavingNotifier.dispose();
    _errorTextNotifier.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (_errorTextNotifier.value != null) {
      _errorTextNotifier.value = null;
    }
  }

  Future<void> _submit() async {
    if (_isSavingNotifier.value) {
      return;
    }

    final value = _controller.text.trim();
    final validationMessage =
        widget.validator?.call(value) ??
        (value.isEmpty ? AppStrings.trainingFieldValueRequired : null);
    if (validationMessage != null) {
      _errorTextNotifier.value = validationMessage;
      return;
    }

    _isSavingNotifier.value = true;
    final didSave = await widget.onSave(value);
    if (!mounted) {
      return;
    }

    _isSavingNotifier.value = false;
    if (didSave) {
      Navigator.of(context).pop(true);
      return;
    }

    final errorMessage = context.read<TrainingModuleController>().errorMessage?.trim();
    _errorTextNotifier.value = (errorMessage != null && errorMessage.isNotEmpty)
        ? errorMessage
        : AppStrings.loginSomethingWentWrong;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sheetListenable,
      builder: (context, _) {
        final isSaving = _isSavingNotifier.value;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 620),
              decoration: const BoxDecoration(
                color: AppColors.mainBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextView.body1(
                              widget.sheetTitle,
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _DialogCloseButton(onTap: () => Navigator.of(context).pop()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppTextView.body3(
                        widget.sheetDescription,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                      const SizedBox(height: 18),
                      // AppTextView.body3(
                      //   widget.fieldLabel,
                      //   color: AppColors.textPrimary,
                      //   fontWeight: FontWeight.w700,
                      // ),
                      // const SizedBox(height: 8),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        cursorColor: Colors.white,
                        cursorHeight: 15,
                        minLines: widget.minLines,
                        maxLines: widget.maxLines,
                        textInputAction: widget.textInputAction,
                        keyboardType: widget.maxLines > 1
                            ? TextInputType.multiline
                            : TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.74),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceDark2.withValues(alpha: 0.42),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: AppColors.fieldBorder.withValues(alpha: 0.16),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: AppColors.fieldBorder.withValues(alpha: 0.16),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.secondaryColor),
                          ),
                        ),
                      ),
                      if (_errorTextNotifier.value != null) ...[
                        const SizedBox(height: 12),
                        _DialogErrorMessageCard(message: _errorTextNotifier.value!),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: AppGradientActionButton(
                          label: widget.saveButtonLabel,
                          icon: widget.saveIcon,
                          isLoading: isSaving,
                          onTap: _canSave ? _submit : null,
                          minHeight: 52,
                          borderRadius: 16,
                          textSize: 15,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrainingFormattingToolbar extends StatelessWidget {
  const _TrainingFormattingToolbar({
    required this.controller,
    required this.isSaving,
    this.onDoneTap,
    this.onBoldTap,
    this.onItalicTap,
    this.onUnderlineTap,
    this.onBulletListTap,
    this.onNumberedListTap,
    this.onQuoteTap,
    this.onHeadingTap,
  });

  final TrainingRichTextEditingController controller;
  final bool isSaving;
  final VoidCallback? onDoneTap;
  final VoidCallback? onBoldTap;
  final VoidCallback? onItalicTap;
  final VoidCallback? onUnderlineTap;
  final VoidCallback? onBulletListTap;
  final VoidCallback? onNumberedListTap;
  final VoidCallback? onQuoteTap;
  final VoidCallback? onHeadingTap;

  bool get _isCompact => onDoneTap != null;

  @override
  Widget build(BuildContext context) {
    if (!_isCompact) {
      return _buildTopToolbar();
    }
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mainBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.18)),
            ),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildFormattingButtons(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: 44,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: AppStrings.done,
              onPressed: onDoneTap,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.check_rounded, color: AppColors.textPrimary, size: 26),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFormattingButtons() => [
    _TrainingFormattingButton(
      isCompact: _isCompact,
      tooltip: AppStrings.trainingBoldAction,
      icon: Icons.format_bold_rounded,
      isActive: controller.isFormatActive(TrainingDocumentFormatKind.bold),
      onTap: isSaving ? null : onBoldTap,
    ),
    if (!_isCompact) const SizedBox(width: 8),
    _TrainingFormattingButton(
      isCompact: _isCompact,
      tooltip: AppStrings.trainingItalicAction,
      icon: Icons.format_italic_rounded,
      isActive: controller.isFormatActive(TrainingDocumentFormatKind.italic),
      onTap: isSaving ? null : onItalicTap,
    ),
    if (!_isCompact) const SizedBox(width: 8),
    _TrainingFormattingButton(
      isCompact: _isCompact,
      tooltip: AppStrings.trainingUnderlineAction,
      icon: Icons.format_underline_rounded,
      isActive: controller.isFormatActive(TrainingDocumentFormatKind.underline),
      onTap: isSaving ? null : onUnderlineTap,
    ),
    if (!_isCompact) const SizedBox(width: 8),
    _TrainingFormattingButton(
      isCompact: _isCompact,
      tooltip: AppStrings.trainingBulletListAction,
      icon: Icons.format_list_bulleted_rounded,
      isActive: controller.isBulletListActive,
      onTap: isSaving ? null : onBulletListTap,
    ),
    if (!_isCompact) const SizedBox(width: 8),
    _TrainingFormattingButton(
      isCompact: _isCompact,
      tooltip: AppStrings.trainingNumberedListAction,
      icon: Icons.format_list_numbered_rounded,
      isActive: controller.isNumberedListActive,
      onTap: isSaving ? null : onNumberedListTap,
    ),
    if (!_isCompact) const SizedBox(width: 8),
    _TrainingFormattingButton(
      isCompact: _isCompact,
      tooltip: AppStrings.trainingQuoteAction,
      icon: Icons.format_quote_rounded,
      isActive: controller.isFormatActive(TrainingDocumentFormatKind.quote),
      onTap: isSaving ? null : onQuoteTap,
    ),
    if (!_isCompact) const SizedBox(width: 8),
    _TrainingFormattingButton(
      isCompact: _isCompact,
      tooltip: AppStrings.trainingHeadingAction,
      icon: Icons.title_rounded,
      isActive: controller.isFormatActive(TrainingDocumentFormatKind.heading),
      onTap: isSaving ? null : onHeadingTap,
    ),
  ];

  Widget _buildTopToolbar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildFormattingButtons()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingFormattingButton extends StatelessWidget {
  const _TrainingFormattingButton({
    required this.tooltip,
    required this.icon,
    this.isActive = false,
    this.isCompact = false,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool isActive;
  final bool isCompact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!isCompact) {
      return _buildStandardButton();
    }
    final iconColor = isActive
        ? AppColors.secondaryColor
        : onTap != null
        ? AppColors.textPrimary
        : AppColors.textSecondary.withValues(alpha: 0.58);

    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.secondaryColor.withValues(alpha: 0.22)
                      : Colors.transparent,
                  border: isActive ? Border.all(color: AppColors.secondaryColor) : null,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardButton() {
    final isInteractive = onTap != null;
    final borderColor = isActive
        ? AppColors.secondaryColor.withValues(alpha: 0.64)
        : AppColors.fieldBorder.withValues(alpha: isInteractive ? 0.22 : 0.12);
    final backgroundColor = isActive
        ? AppColors.secondaryColor.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: isInteractive ? 0.08 : 0.04);
    final iconColor = isActive
        ? AppColors.secondaryColor
        : isInteractive
        ? AppColors.textPrimary
        : AppColors.textSecondary.withValues(alpha: 0.58);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
        ),
      ),
    );
  }
}
