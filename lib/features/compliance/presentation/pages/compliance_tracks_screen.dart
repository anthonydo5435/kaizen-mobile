import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../../domain/usecases/get_compliance_certificate_usecase.dart';
import '../../domain/usecases/get_compliance_tracks_usecase.dart';
import '../providers/compliance_controller.dart';
import '../providers/compliance_tracks_controller.dart';
import '../widgets/compliance_tracks_search_bar.dart';
import '../widgets/tracks_card.dart';
import 'training/certificate_screen.dart';

class ComplianceTracksScreen extends StatelessWidget {
  const ComplianceTracksScreen({
    super.key,
    required this.trackAssignmentUuid,
    required this.title,
    this.showCertificate = false,
  });

  final String trackAssignmentUuid;
  final String title;
  final bool showCertificate;

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
        ProxyProvider<
          ComplianceRepositoryImpl,
          GetComplianceCertificateUseCase
        >(
          update: (_, repository, __) =>
              GetComplianceCertificateUseCase(repository),
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
        showCertificate: showCertificate,
      ),
    );
  }
}

class _ComplianceTracksScreenView extends StatefulWidget {
  const _ComplianceTracksScreenView({
    required this.trackAssignmentUuid,
    required this.title,
    required this.showCertificate,
  });

  final String trackAssignmentUuid;
  final String title;
  final bool showCertificate;

  @override
  State<_ComplianceTracksScreenView> createState() =>
      _ComplianceTracksScreenViewState();
}

class _ComplianceTracksScreenViewState
    extends State<_ComplianceTracksScreenView> {
  late final ComplianceTracksController _controller;
  late final GetComplianceCertificateUseCase _getComplianceCertificateUseCase;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ComplianceTracksController>();
    _getComplianceCertificateUseCase = context
        .read<GetComplianceCertificateUseCase>();

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
                    child: tracks.isEmpty && !widget.showCertificate
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
                            itemCount:
                                tracks.length +
                                (widget.showCertificate ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 18),
                            itemBuilder: (context, index) {
                              if (index == tracks.length) {
                                return _CertificateRow(onTap: _openCertificate);
                              }

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
    if (_isPassed(track.displayStatus)) {
      return false;
    }

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

  Future<void> _openCertificate() async {
    final certificateFuture = _getComplianceCertificateUseCase(
      trackAssignmentUuid: widget.trackAssignmentUuid,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            CertificateScreen.loading(certificateFuture: certificateFuture),
      ),
    );
  }
}

class _CertificateRow extends StatelessWidget {
  const _CertificateRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 88,
        padding: const EdgeInsets.all(12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SvgPicture.asset(
            '${AppStrings.imagePath}certificate.svg',
            width: 64,
            height: 64,
          ),
        ),
      ),
    );
  }
}
