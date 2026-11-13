part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

class TrainingTabs extends StatelessWidget {
  const TrainingTabs({
    super.key,
    required this.navigation,
    required this.maxTabIndex,
  });

  final TrainingTabNavigationController navigation;
  final int maxTabIndex;

  List<Widget> get _tabs => [
    _TrainingTab(
      index: 0,
      label: AppStrings.trainingVideoTab,
      icon: AppAssets.video,
      selectedIcon: AppAssets.videoEnabled,
      maxTabIndex: maxTabIndex,
    ),
    _TrainingTab(
      index: 1,
      label: AppStrings.trainingSopTab,
      icon: AppAssets.sop,
      selectedIcon: AppAssets.sopEnabled,
      maxTabIndex: maxTabIndex,
    ),
    _TrainingTab(
      index: 2,
      label: AppStrings.trainingQuizTab,
      icon: AppAssets.quizTab,
      selectedIcon: AppAssets.quizTabEnabled,
      maxTabIndex: maxTabIndex,
    ),
    _TrainingTab(
      index: 3,
      label: AppStrings.trainingAssignmentTab,
      icon: AppAssets.assignment,
      selectedIcon: AppAssets.assignmentEnabled,
      maxTabIndex: maxTabIndex,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);

    return ListenableProvider<TrainingTabNavigationController>.value(
      value: navigation,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            enabled: !highContrast,
            child: Material(
              color: AppColors.surfaceDark.withValues(
                alpha: highContrast ? 1 : 0.72,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.fromBorderSide(
                    BorderSide(
                      color: AppColors.textPrimary.withValues(
                        alpha: highContrast ? 0.4 : 0.16,
                      ),
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.textPrimary.withValues(alpha: 0.14),
                      AppColors.textPrimary.withValues(alpha: 0.025),
                      AppColors.secondaryColor.withValues(alpha: 0.08),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Selector<TrainingTabNavigationController, int>(
                            selector: (_, tabs) => tabs.selectedIndex,
                            builder: (context, selectedIndex, child) =>
                                AnimatedAlign(
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  alignment: AlignmentDirectional(
                                    -1 + 2 * selectedIndex / 3,
                                    0,
                                  ),
                                  child: child,
                                ),
                            child: const FractionallySizedBox(
                              widthFactor: 0.25,
                              heightFactor: 1,
                              child: _TrainingGlassSelectionLens(),
                            ),
                          ),
                        ),
                      ),
                      Row(children: _tabs),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingTab extends StatelessWidget {
  const _TrainingTab({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.maxTabIndex,
  });

  final int index;
  final String label;
  final String icon;
  final String selectedIcon;
  final int maxTabIndex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Selector<TrainingTabNavigationController, bool>(
          selector: (_, tabs) => tabs.selectedIndex == index,
          builder: (context, isSelected, _) => _TrainingTabItem(
            label: label,
            iconAsset: isSelected ? selectedIcon : icon,
            isSelected: isSelected,
            isEnabled: index <= maxTabIndex,
            onTap: () {
              context.read<TrainingTabNavigationController>().selectTab(index);
            },
          ),
        ),
      ),
    );
  }
}

class _TrainingTabItem extends StatelessWidget {
  const _TrainingTabItem({
    required this.label,
    required this.iconAsset,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = !isEnabled
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : isSelected
        ? AppColors.lightPurple1
        : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      label: label,
      onTap: isEnabled ? onTap : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        splashColor: AppColors.textPrimary.withValues(alpha: 0.12),
        highlightColor: AppColors.textPrimary.withValues(alpha: 0.06),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: ExcludeSemantics(
              child: Opacity(
                opacity: isEnabled ? 1 : 0.55,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.05 : 1,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: SvgPicture.asset(
                        iconAsset,
                        width: label == 'Video' ? 14 : 20,
                        height: label == 'Video' ? 14 : 20,
                        excludeFromSemantics: true,
                        colorFilter: ColorFilter.mode(
                          textColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AppTextView.body3(
                        label,
                        color: textColor,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        textAlign: TextAlign.center,
                        fontSize: 11,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingGlassSelectionLens extends StatelessWidget {
  const _TrainingGlassSelectionLens();

  @override
  Widget build(BuildContext context) {
    final edge = BorderSide(
      color: AppColors.textPrimary.withValues(alpha: 0.22),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border(top: edge, left: edge, right: edge),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.textPrimary.withValues(alpha: 0.2),
            AppColors.secondaryColor.withValues(alpha: 0.15),
            AppColors.textPrimary.withValues(alpha: 0.065),
          ],
        ),
      ),
    );
  }
}
