import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/compliance_remote_data_source.dart';
import '../../data/repositories/compliance_repository_impl.dart';
import '../../domain/entities/learning_module_detail_track.dart';
import '../../domain/usecases/get_compliance_tracks_usecase.dart';
import '../providers/compliance_controller.dart';
import '../providers/compliance_tracks_controller.dart';
import '../widgets/compliance_tracks_search_bar.dart';
import '../widgets/tracks_card.dart';

class ComplianceTracksScreen extends StatelessWidget {
  const ComplianceTracksScreen({
    super.key,
    required this.trackAssignmentUuid,
    required this.title,
  });

  final String trackAssignmentUuid;
  final String title;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ComplianceRemoteDataSource>(
          create: (_) => createComplianceRemoteDataSource(),
        ),
        ProxyProvider<ComplianceRemoteDataSource, ComplianceRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createComplianceRepository(remoteDataSource),
        ),
        ProxyProvider<ComplianceRepositoryImpl, GetComplianceTracksUseCase>(
          update: (_, repository, __) => GetComplianceTracksUseCase(repository),
        ),
        ChangeNotifierProvider<ComplianceTracksController>(
          create: (context) => ComplianceTracksController(
            context.read<GetComplianceTracksUseCase>(),
          ),
        ),
      ],
      child: _ComplianceTracksScreenView(
        trackAssignmentUuid: trackAssignmentUuid,
        title: title,
      ),
    );
  }
}

class _ComplianceTracksScreenView extends StatefulWidget {
  const _ComplianceTracksScreenView({
    required this.trackAssignmentUuid,
    required this.title,
  });

  final String trackAssignmentUuid;
  final String title;

  @override
  State<_ComplianceTracksScreenView> createState() =>
      _ComplianceTracksScreenViewState();
}

class _ComplianceTracksScreenViewState
    extends State<_ComplianceTracksScreenView> {
  late final ComplianceTracksController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ComplianceTracksController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _controller.initialize(widget.trackAssignmentUuid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComplianceTracksController>();
    final tracks = controller.filteredTracks;
    final allTracks = controller.allTracks;

    return Scaffold(
      backgroundColor: AppColors.mainBg,
      appBar: AppBar(
        backgroundColor: AppColors.mainBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 40,
        leading: const AppBackButton(),
        title: AppTextView.body1(
          widget.title.trim().isEmpty
              ? AppStrings.complianceTracksTitle
              : widget.title,
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: controller.isLoading
          ? FastCircularProgressIndicator()
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  ComplianceTracksSearchBar(
                    controller: controller.searchController,
                    onChanged: controller.updateSearchQuery,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: tracks.isEmpty
                        ? const Center(
                            child: AppTextView.body(
                              AppStrings.complianceNoTracksFound,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            itemCount: tracks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 18),
                            itemBuilder: (context, index) {
                              final track = tracks[index];

                              return TracksCard(
                                track: track,
                                isDisabled: _isDisabled(track, allTracks),
                                headerText: _headerText(track, allTracks),
                                onTap: () async {
                                  final itemUuid = track.trainingModuleItemId;
                                  if (itemUuid == null || itemUuid.isEmpty) {
                                    return;
                                  }

                                  final shouldRefresh =
                                      await AppRouter.pushNamed<dynamic>(
                                        context,
                                        AppRouter.complianceTraining,
                                        arguments: ComplianceTrainingRouteArgs(
                                          trackAssignmentUuid:
                                              widget.trackAssignmentUuid,
                                          itemUuid: track.trainingModuleItemId
                                              .toString(),
                                        ),
                                      );

                                  if (!context.mounted ||
                                      shouldRefresh != true) {
                                    return;
                                  }

                                  await _controller.initialize(
                                    widget.trackAssignmentUuid,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  String? _headerText(
    LearningTrackModuleDetail track,
    List<LearningTrackModuleDetail> orderedTracks,
  ) {
    final previousTrack = _previousActionableTrack(track, orderedTracks);
    if (previousTrack == null) {
      return null;
    }

    return _isPassed(previousTrack.displayStatus)
        ? AppStrings.complianceMasteredBasics
        : null;
  }

  bool _isDisabled(
    LearningTrackModuleDetail track,
    List<LearningTrackModuleDetail> orderedTracks,
  ) {
    final previousTrack = _previousActionableTrack(track, orderedTracks);
    if (previousTrack == null) {
      return false;
    }

    return _isPending(previousTrack.displayStatus);
  }

  LearningTrackModuleDetail? _previousActionableTrack(
    LearningTrackModuleDetail track,
    List<LearningTrackModuleDetail> orderedTracks,
  ) {
    final currentIndex = orderedTracks.indexWhere(
      (item) => item.trainingModuleItemId == track.trainingModuleItemId,
    );
    if (currentIndex <= 0) {
      return null;
    }

    for (var cursor = currentIndex - 1; cursor >= 0; cursor--) {
      final previousTrack = orderedTracks[cursor];
      if (!previousTrack.isBreakPoint) {
        return previousTrack;
      }
    }

    return null;
  }

  bool _isPassed(String status) {
    return CustomFunctions.isPassedStatus(status);
  }

  bool _isPending(String status) {
    return CustomFunctions.isPendingStatus(status);
  }
}
