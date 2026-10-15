import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_radio_selection_tile.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../seat_profile/data/datasources/seat_profile_remote_data_source.dart';
import '../../../seat_profile/data/repositories/seat_profile_repository_impl.dart';
import '../../../seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import '../../domain/entities/seat_description_training_route.dart';
import '../controllers/training_setup_controller.dart';
import '../widgets/training_selection_step_field.dart';
import 'edit_training_screen.dart';

class SetupTrainingScreen extends StatelessWidget {
  const SetupTrainingScreen({
    super.key,
    this.initialSeatProfileId,
    this.initialCategoryId,
    this.initialDescriptionId,
  });

  final String? initialSeatProfileId;
  final String? initialCategoryId;
  final String? initialDescriptionId;

  @override
  Widget build(BuildContext context) {
    if (!AppManager.instance.currentUserCanOpenTrainingModuleCreateFlow) {
      return const _TrainingSetupAccessDeniedView();
    }

    return MultiProvider(
      providers: [
        Provider<SeatProfileRemoteDataSource>(create: (_) => createSeatProfileRemoteDataSource()),
        ProxyProvider<SeatProfileRemoteDataSource, SeatProfileRepositoryImpl>(
          update: (_, remoteDataSource, __) => SeatProfileRepositoryImpl(remoteDataSource),
        ),
        ProxyProvider<SeatProfileRepositoryImpl, GetSeatProfilesUseCase>(
          update: (_, repository, __) => GetSeatProfilesUseCase(repository),
        ),
        ChangeNotifierProvider<TrainingSetupController>(
          create: (context) =>
              TrainingSetupController(
                context.read<GetSeatProfilesUseCase>(),
                canManageSeatProfile: (seatProfile) =>
                    AppManager.instance.canCurrentUserManageTrainingForSeatProfile(
                      seatProfileId: seatProfile.id,
                      additionalSeatProfileIds: <String>[seatProfile.resolvedSeatId],
                    ),
              )..initialize(
                initialSeatProfileId: initialSeatProfileId,
                initialCategoryId: initialCategoryId,
                initialDescriptionId: initialDescriptionId,
              ),
        ),
      ],
      child: const _SetupTrainingScreenView(),
    );
  }
}

class _TrainingSetupAccessDeniedView extends StatelessWidget {
  const _TrainingSetupAccessDeniedView();

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
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AppTextView.body(
              AppStrings.trainingCreateAccessDenied,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupTrainingScreenView extends StatelessWidget {
  const _SetupTrainingScreenView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingSetupController>();
    final showSetupAction =
        !controller.isLoading &&
        controller.errorMessage == null &&
        controller.seatProfiles.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: _buildHeader(context)),
            Expanded(child: _buildContent(context, controller)),
            if (showSetupAction)
              _TrainingSetupNextAction(
                isEnabled: controller.canViewTraining,
                onPressed: () => _openTrainingEditor(context, controller),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                child: SvgPicture.asset(
                  '${AppStrings.imagePath}back.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          const AppTextView.body(
            AppStrings.seatProfileSetupTrainingTitle,
            color: AppColors.secondaryColor,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, TrainingSetupController controller) {
    if (controller.isLoading && controller.seatProfiles.isEmpty) {
      return Center(child: FastCircularProgressIndicator());
    }

    if (controller.errorMessage != null && controller.seatProfiles.isEmpty) {
      return _CenteredMessage(message: controller.errorMessage!);
    }

    if (controller.seatProfiles.isEmpty) {
      return const _CenteredMessage(message: AppStrings.seatProfileTrainingNoOptionsAvailable);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 120),
                const AppTextView.body(
                  AppStrings.trainingSetupSelectionPrompt,
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  textAlign: TextAlign.center,
                  height: 1.35,
                ),
                const SizedBox(height: 42),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Column(
                    children: <Widget>[
                      TrainingSelectionStepField(
                        stepNumber: 1,
                        hintText: AppStrings.trainingSetupSelectSeat,
                        selectedText: controller.selectedSeatProfile?.title,
                        enabled: true,
                        onTap: () => _selectSeatProfile(context, controller),
                      ),
                      const SizedBox(height: 22),
                      TrainingSelectionStepField(
                        stepNumber: 2,
                        hintText: AppStrings.trainingSetupSelectCategory,
                        selectedText: controller.selectedCategory?.title,
                        enabled:
                            controller.selectedSeatProfile != null &&
                            controller.categoryOptions.isNotEmpty,
                        onTap: () => _selectCategory(context, controller),
                      ),
                      const SizedBox(height: 22),
                      TrainingSelectionStepField(
                        stepNumber: 3,
                        hintText: AppStrings.trainingSetupSelectDescription,
                        selectedText: controller.selectedDescription?.name,
                        enabled:
                            controller.selectedCategory != null &&
                            controller.descriptionOptions.isNotEmpty,
                        onTap: () => _selectDescription(context, controller),
                      ),
                      if (controller.selectedSeatProfile != null &&
                          controller.categoryOptions.isEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        const _InfoMessage(message: AppStrings.seatProfileNoCategoriesFound),
                      ],
                      if (controller.selectedCategory != null &&
                          controller.descriptionOptions.isEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        const _InfoMessage(message: AppStrings.seatProfileNoDescriptionsFound),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectSeatProfile(BuildContext context, TrainingSetupController controller) async {
    final selectedId = await _showSelectionSheet(
      context,
      title: AppStrings.trainingSetupSelectSeat,
      searchHint: AppStrings.trainingSetupSearchSeat,
      options: controller.seatProfiles
          .map((seatProfile) => _SelectionListOption(id: seatProfile.id, label: seatProfile.title))
          .toList(growable: false),
      selectedId: controller.selectedSeatProfileId,
    );

    if (selectedId == null || !context.mounted) {
      return;
    }

    controller.selectSeatProfile(selectedId);
  }

  Future<void> _selectCategory(BuildContext context, TrainingSetupController controller) async {
    if (controller.categoryOptions.isEmpty) {
      return;
    }

    final selectedId = await _showSelectionSheet(
      context,
      title: AppStrings.trainingSetupSelectCategoryTitle,
      searchHint: AppStrings.trainingSetupSearchCategory,
      options: controller.categoryOptions
          .map((category) => _SelectionListOption(id: category.id, label: category.title))
          .toList(growable: false),
      selectedId: controller.selectedCategoryId,
    );

    if (selectedId == null || !context.mounted) {
      return;
    }

    controller.selectCategory(selectedId);
  }

  Future<void> _selectDescription(BuildContext context, TrainingSetupController controller) async {
    if (controller.descriptionOptions.isEmpty) {
      return;
    }

    final selectedId = await _showSelectionSheet(
      context,
      title: AppStrings.trainingSetupSelectDescriptionTitle,
      searchHint: AppStrings.trainingSetupSearchDescription,
      options: controller.descriptionOptions
          .map((description) => _SelectionListOption(id: description.id, label: description.name))
          .toList(growable: false),
      selectedId: controller.selectedDescriptionId,
    );

    if (selectedId == null || !context.mounted) {
      return;
    }

    controller.selectDescription(selectedId);
  }

  Future<String?> _showSelectionSheet(
    BuildContext context, {
    required String title,
    required String searchHint,
    required List<_SelectionListOption> options,
    required String? selectedId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TrainingSetupOptionSheet(
        title: title,
        searchHint: searchHint,
        options: options,
        initialSelectedId: selectedId,
      ),
    );
  }

  Future<void> _openTrainingEditor(BuildContext context, TrainingSetupController controller) async {
    if (!controller.canViewTraining || !controller.canManageSelectedSeatProfile) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditTrainingScreen(
          trainingRoute: _resolvedTrainingRoute(controller),
          startNewLessonWhenEmpty: true,
          canManageTraining: AppManager.instance.canCurrentUserManageTrainingForSeatProfile(
            seatProfileId: controller.selectedSeatProfile?.id ?? '',
            additionalSeatProfileIds: <String>[
              controller.selectedSeatProfile?.resolvedSeatId ?? '',
            ],
          ),
          useNonBlockingVideoUpload: true,
        ),
      ),
    );
  }

  SeatDescriptionTrainingRoute _resolvedTrainingRoute(TrainingSetupController controller) {
    final seatProfileId = controller.selectedSeatProfileId?.trim() ?? '';
    final categoryId = controller.selectedCategoryId?.trim() ?? '';
    final descriptionId = controller.selectedDescriptionId?.trim() ?? '';
    return SeatDescriptionTrainingRoute(
      job: seatProfileId,
      category: categoryId,
      description: descriptionId,
    );
  }
}

class _SelectionListOption {
  const _SelectionListOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _TrainingSetupNextAction extends StatelessWidget {
  const _TrainingSetupNextAction({required this.isEnabled, required this.onPressed});

  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.mainBg,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 20,
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: AppButton(
          text: AppStrings.next,
          minimumHeight: 48,
          textSize: 18,
          textColor: isEnabled ? AppColors.textPrimary : AppColors.mainBg,
          onPressed: isEnabled ? onPressed : null,
        ),
      ),
    );
  }
}

class _TrainingSetupOptionSheet extends StatefulWidget {
  const _TrainingSetupOptionSheet({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.initialSelectedId,
  });

  final String title;
  final String searchHint;
  final List<_SelectionListOption> options;
  final String? initialSelectedId;

  @override
  State<_TrainingSetupOptionSheet> createState() => _TrainingSetupOptionSheetState();
}

class _TrainingSetupOptionSheetState extends State<_TrainingSetupOptionSheet> {
  late final TextEditingController _searchController;
  late final ValueNotifier<String> _searchQueryNotifier;
  late final ValueNotifier<String?> _selectedIdNotifier;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchQueryNotifier = ValueNotifier<String>('');
    _selectedIdNotifier = ValueNotifier<String?>(widget.initialSelectedId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQueryNotifier.dispose();
    _selectedIdNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final preferredHeight = mediaQuery.size.height * 0.74;
    final availableHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    final sheetHeight = preferredHeight < availableHeight ? preferredHeight : availableHeight;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          height: sheetHeight,
          decoration: const BoxDecoration(
            color: AppColors.mainBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 22),
          child: ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, _, __) {
              final options = _filteredOptions();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TrainingSetupSelectionHeader(
                    title: widget.title,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 22),
                  const AppDotDivider(),
                  const SizedBox(height: 26),
                  _TrainingSetupSearchField(
                    controller: _searchController,
                    hintText: widget.searchHint,
                    onChanged: (value) => _searchQueryNotifier.value = value,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: options.isEmpty
                        ? const _TrainingSetupNoMatches()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: options.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final option = options[index];
                              return ValueListenableBuilder<String?>(
                                valueListenable: _selectedIdNotifier,
                                builder: (context, selectedId, _) {
                                  return AppRadioSelectionTile(
                                    title: option.label,
                                    isSelected: selectedId == option.id,
                                    onTap: () => _selectedIdNotifier.value = option.id,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  const AppDotDivider(),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String?>(
                    valueListenable: _selectedIdNotifier,
                    builder: (context, selectedId, _) {
                      return AppButton(
                        text: AppStrings.done,
                        minimumHeight: 44,
                        textSize: 16,
                        onPressed: selectedId == null
                            ? null
                            : () => Navigator.of(context).pop(selectedId),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_SelectionListOption> _filteredOptions() {
    final normalizedQuery = _searchQueryNotifier.value.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return widget.options;
    }

    return widget.options
        .where((option) => option.label.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }
}

class _TrainingSetupSelectionHeader extends StatelessWidget {
  const _TrainingSetupSelectionHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: SvgPicture.asset(
              '${AppStrings.imagePath}back.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
            ),
          ),
        ),
        Expanded(
          child: AppTextView.title1(
            title,
            color: AppColors.secondaryColor,
            fontSize: 20,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 28),
      ],
    );
  }
}

class _TrainingSetupSearchField extends StatelessWidget {
  const _TrainingSetupSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.75), width: 1),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: AppColors.textPrimary,
        cursorHeight: 18,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
  }
}

class _TrainingSetupNoMatches extends StatelessWidget {
  const _TrainingSetupNoMatches();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AppTextView.body(
        AppStrings.trainingSetupNoMatches,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppTextView.body(message, color: AppColors.textSecondary, textAlign: TextAlign.center),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppTextView.body2(message, color: AppColors.textSecondary),
    );
  }
}
