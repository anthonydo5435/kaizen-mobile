import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_listing_search_bar.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/shared_lms_remote_data_source.dart';
import '../../data/repositories/shared_lms_repository_impl.dart';
import '../../domain/entities/shared_lms_content.dart';
import '../../domain/repositories/shared_lms_repository.dart';
import '../controllers/shared_lms_controller.dart';
import '../widgets/training_library_module_card.dart';
import '../widgets/training_library_status_state.dart';

class SharedLmsScreen extends StatelessWidget {
  const SharedLmsScreen({super.key, required this.publicId, this.repository});

  final String publicId;
  final SharedLmsRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedLmsRemoteDataSource>(
          create: (_) => SharedLmsRemoteDataSource(),
        ),
        ProxyProvider<SharedLmsRemoteDataSource, SharedLmsRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              SharedLmsRepositoryImpl(remoteDataSource),
        ),
        ChangeNotifierProvider<SharedLmsController>(
          create: (context) {
            final controller = SharedLmsController(
              repository ?? context.read<SharedLmsRepositoryImpl>(),
            );
            unawaited(controller.load(publicId));
            return controller;
          },
        ),
      ],
      child: const _SharedLmsView(),
    );
  }
}

class _SharedLmsView extends StatelessWidget {
  const _SharedLmsView();

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final destination = AppPreference.getAuthToken().trim().isEmpty
        ? AppRouter.login
        : AppRouter.defaultAuthenticatedRouteName;
    navigator.pushReplacementNamed(destination);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SharedLmsController>();
    final content = controller.content;
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      appBar: AppBar(
        backgroundColor: AppColors.mainBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leadingWidth: 40,
        leading: AppBackButton(onPressed: () => _goBack(context)),
        title: const AppTextView.title1(
          AppStrings.trainingLibraryTitle,
          color: AppColors.secondaryColor,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
      body: SafeArea(
        top: false,
        child: controller.isLoading
            ? const Center(child: FastCircularProgressIndicator())
            : controller.errorMessage != null
            ? ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  TrainingLibraryStatusState(
                    message: controller.errorMessage!,
                    actionLabel: AppStrings.trainingLibraryRetry,
                    onActionTap: controller.retry,
                  ),
                ],
              )
            : content == null
            ? const Center(
                child: AppTextView.body(AppStrings.sharedLmsUnableToLoad),
              )
            : _SharedLmsContentView(controller: controller, content: content),
      ),
    );
  }
}

class _SharedLmsContentView extends StatelessWidget {
  const _SharedLmsContentView({
    required this.controller,
    required this.content,
  });

  final SharedLmsController controller;
  final SharedLmsContent content;

  @override
  Widget build(BuildContext context) {
    final lessons = controller.visibleLessons;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SharedLmsHeading(content: content),
                const SizedBox(height: 15),
                AppListingSearchBar(
                  controller: controller.searchController,
                  hintText: AppStrings.trainingLibrarySearchLesson,
                  onChanged: controller.updateSearchQuery,
                  onClearTap: controller.clearSearch,
                ),
              ],
            ),
          ),
        ),
        if (lessons.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                child: AppTextView.body(
                  content.lessons.isEmpty
                      ? AppStrings.sharedLmsNoLessons
                      : AppStrings.trainingLibraryNoMatchingLessons,
                  color: AppColors.textSecondary,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: _SharedLmsLessonGrid(
              sharedContentId: controller.publicId,
              lessons: lessons,
            ),
          ),
      ],
    );
  }
}

class _SharedLmsHeading extends StatelessWidget {
  const _SharedLmsHeading({required this.content});

  final SharedLmsContent content;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (content.title.isNotEmpty)
        _SharedLmsInfoRow(
          label: AppStrings.sharedLmsSeatLabel,
          value: content.title,
          icon: Icons.event_seat_outlined,
        ),
      if (content.categoryTitle.isNotEmpty)
        _SharedLmsInfoRow(
          label: AppStrings.sharedLmsCategoryLabel,
          value: content.categoryTitle,
          icon: Icons.category_outlined,
        ),
      if (content.description.isNotEmpty)
        _SharedLmsInfoRow(
          label: AppStrings.sharedLmsDescriptionLabel,
          value: content.description,
          icon: Icons.description_outlined,
        ),
    ];
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.trainingLessonActionSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows
            .asMap()
            .entries
            .map((row) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: row.key == rows.length - 1 ? 0 : 12,
                ),
                child: row.value,
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _SharedLmsInfoRow extends StatelessWidget {
  const _SharedLmsInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark1,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.lightPurple1, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextView.body2(
                label,
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              AppTextView.body1(
                value,
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SharedLmsLessonGrid extends StatelessWidget {
  const _SharedLmsLessonGrid({
    required this.sharedContentId,
    required this.lessons,
  });

  final String sharedContentId;
  final List<SharedLmsLesson> lessons;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final crossAxisCount = constraints.crossAxisExtent >= 1020
            ? 3
            : (constraints.crossAxisExtent >= 620 ? 2 : 1);
        final cardWidth =
            (constraints.crossAxisExtent - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final textScaleExtra =
            (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(
              0.0,
              double.infinity,
            ) *
            6;
        final cardHeight =
            (cardWidth / 1.9).clamp(176.0, 280.0) + textScaleExtra;

        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          itemCount: lessons.length,
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return TrainingLibraryModuleCard.shared(
              sharedTitle: lesson.title,
              sharedThumbnailLink: lesson.thumbnailUrl,
              sharedDuration: lesson.duration,
              onTap: () => Navigator.of(context).pushNamed(
                AppRouter.sharedLessonDetails,
                arguments: SharedLessonDetailsRouteArgs(
                  sharedContentId: sharedContentId,
                  publicId: lesson.publicId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
