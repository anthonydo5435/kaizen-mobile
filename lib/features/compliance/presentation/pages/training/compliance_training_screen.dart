import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/upgrade_plan_dialog.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/certificate_screen.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/training/quiz_result_dialogue.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/utils/custom_functions.dart';
import '../../../../../core/widgets/app_back_button.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../data/datasources/compliance_remote_data_source.dart';
import '../../../data/repositories/compliance_repository_impl.dart';
import '../../../domain/entities/compliance_certificate.dart';
import '../../../domain/entities/compliance_quiz_result.dart';
import '../../../domain/entities/compliance_track_item_detail.dart';
import '../../../domain/entities/learning_module_detail_track.dart';
import '../../../domain/usecases/get_compliance_certificate_usecase.dart';
import '../../../domain/usecases/get_compliance_quiz_result_usecase.dart';
import '../../../domain/usecases/get_compliance_quiz_usecase.dart';
import '../../../domain/usecases/get_compliance_track_item_detail_usecase.dart';
import '../../../domain/usecases/get_compliance_tracks_usecase.dart';
import '../../../domain/usecases/pause_compliance_quiz_usecase.dart';
import '../../../domain/usecases/start_compliance_quiz_usecase.dart';
import '../../../domain/usecases/submit_compliance_quiz_usecase.dart';
import '../../providers/compliance_controller.dart';
import '../../providers/compliance_quiz_controller.dart';
import '../../providers/compliance_training_controller.dart';
import 'compliance_quiz_screen.dart';
import 'compliance_training_document_screen.dart';
import 'compliance_video_screen.dart';
import 'welcome_quiz_screen.dart';

class ComplianceTrainingScreen extends StatefulWidget {
  const ComplianceTrainingScreen({
    super.key,
    required this.trackAssignmentUuid,
    required this.itemUuid,
  });

  final String trackAssignmentUuid;
  final String itemUuid;

  @override
  State<ComplianceTrainingScreen> createState() =>
      _ComplianceTrainingScreenState();
}

class _ComplianceTrainingScreenState extends State<ComplianceTrainingScreen> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ComplianceRemoteDataSource>(
          create: (_) => createComplianceTrainingRemoteDataSource(),
        ),
        ProxyProvider<ComplianceRemoteDataSource, ComplianceRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createComplianceRepository(remoteDataSource),
        ),
        ProxyProvider<
          ComplianceRepositoryImpl,
          GetComplianceTrackItemDetailUseCase
        >(
          update: (_, repository, __) =>
              createGetComplianceTrackItemDetailUseCase(repository),
        ),
        ProxyProvider<ComplianceRepositoryImpl, GetComplianceQuizUseCase>(
          update: (_, repository, __) =>
              createGetComplianceQuizUseCase(repository),
        ),
        ProxyProvider<ComplianceRepositoryImpl, GetComplianceTracksUseCase>(
          update: (_, repository, __) => GetComplianceTracksUseCase(repository),
        ),
        ProxyProvider<
          ComplianceRepositoryImpl,
          GetComplianceCertificateUseCase
        >(
          update: (_, repository, __) =>
              createGetComplianceCertificateUseCase(repository),
        ),
        ProxyProvider<ComplianceRepositoryImpl, GetComplianceQuizResultUseCase>(
          update: (_, repository, __) =>
              createGetComplianceQuizResultUseCase(repository),
        ),
        ProxyProvider<ComplianceRepositoryImpl, StartComplianceQuizUseCase>(
          update: (_, repository, __) =>
              createStartComplianceQuizUseCase(repository),
        ),
        ProxyProvider<ComplianceRepositoryImpl, PauseComplianceQuizUseCase>(
          update: (_, repository, __) =>
              createPauseComplianceQuizUseCase(repository),
        ),
        ProxyProvider<ComplianceRepositoryImpl, SubmitComplianceQuizUseCase>(
          update: (_, repository, __) =>
              createSubmitComplianceQuizUseCase(repository),
        ),
        ChangeNotifierProvider<ComplianceTrainingController>(
          create: (context) => ComplianceTrainingController(
            context.read<GetComplianceTrackItemDetailUseCase>(),
            context.read<GetComplianceTracksUseCase>(),
          ),
        ),
        ChangeNotifierProvider<ComplianceQuizController>(
          create: (context) => ComplianceQuizController(
            context.read<GetComplianceQuizUseCase>(),
            context.read<GetComplianceQuizResultUseCase>(),
            context.read<StartComplianceQuizUseCase>(),
            context.read<PauseComplianceQuizUseCase>(),
            context.read<SubmitComplianceQuizUseCase>(),
          ),
        ),
      ],
      child: _ComplianceTrainingScreenView(
        trackAssignmentUuid: widget.trackAssignmentUuid,
        itemUuid: widget.itemUuid,
      ),
    );
  }
}

class _ComplianceTrainingScreenView extends StatefulWidget {
  const _ComplianceTrainingScreenView({
    required this.trackAssignmentUuid,
    required this.itemUuid,
  });

  final String trackAssignmentUuid;
  final String itemUuid;

  @override
  State<_ComplianceTrainingScreenView> createState() =>
      _ComplianceTrainingScreenViewState();
}

class _ComplianceTrainingScreenViewState
    extends State<_ComplianceTrainingScreenView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ComplianceTrainingController _controller;
  late final ComplianceQuizController _quizController;
  late final GetComplianceTracksUseCase _getComplianceTracksUseCase;
  late final GetComplianceCertificateUseCase _getComplianceCertificateUseCase;
  var _selectedTabIndex = 0;
  var _isHandlingQuizTabChange = false;
  var _isIgnoringTabSelection = false;
  var _isCompletingQuizSubmit = false;
  ComplianceCertificate? _pendingCertificate;
  late String _currentItemUuid;
  LearningTrackModuleDetail? get _currentTrack => _controller.currentTrack;

  @override
  void initState() {
    super.initState();
    _currentItemUuid = widget.itemUuid;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _controller = context.read<ComplianceTrainingController>();
    _quizController = context.read<ComplianceQuizController>();
    _getComplianceTracksUseCase = context.read<GetComplianceTracksUseCase>();
    _getComplianceCertificateUseCase = context
        .read<GetComplianceCertificateUseCase>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _loadTrainingContent();
    });
  }

  Future<void> _loadTrainingContent() async {
    final didLoad = await _controller.initialize(
      trackAssignmentUuid: widget.trackAssignmentUuid,
      itemUuid: _currentItemUuid,
    );

    if (!mounted || !didLoad) {
      return;
    }

    final detail = _controller.detail;
    final trainingModuleUuid = detail?.trainingModuleUuid.trim();
    if (trainingModuleUuid == null || trainingModuleUuid.isEmpty) {
      return;
    }

    await _quizController.prepareQuiz(
      trackAssignmentUuid: widget.trackAssignmentUuid,
      trainingModuleUuid: trainingModuleUuid,
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_isIgnoringTabSelection || _tabController.indexIsChanging) {
      return;
    }

    if (_selectedTabIndex == _tabController.index) {
      return;
    }

    final previousTabIndex = _selectedTabIndex;
    final nextTabIndex = _tabController.index;

    if (previousTabIndex != 2 && nextTabIndex == 2) {
      _handleQuizTabTransition(previousTabIndex);
      return;
    }

    setState(() {
      _selectedTabIndex = nextTabIndex;
    });

    if (previousTabIndex == 2 && nextTabIndex != 2) {
      _quizController.cancelQuizTimer();
    }
  }

  Future<void> _handleTakeQuizPressed(LearningTrackModuleDetail track) async {
    if (context.read<AppManager>().showBillingBanner) {
      await showDialog<void>(
        context: context,
        builder: (_) => const UpgradePlanDialog(),
        barrierDismissible: false,
      );
      return;
    }

    if (_tabController.index == 2) {
      if (!_quizController.hasAnsweredAllQuestions) {
        return;
      }

      final detail = _controller.detail;
      final trainingModuleUuid = detail?.trainingModuleUuid.trim();
      if (trainingModuleUuid == null || trainingModuleUuid.isEmpty) {
        return;
      }

      setState(() {
        _isCompletingQuizSubmit = true;
      });

      try {
        final didSubmit = await _quizController.submitQuiz(
          trackAssignmentUuid: widget.trackAssignmentUuid,
        );
        if (!mounted) {
          return;
        }

        if (!didSubmit) {
          CustomFunctions.showCustomAlert(
            context,
            'Failed',
            'Quiz submission has failed, please try again!',
          );
          return;
        }

        await _openQuizResultForTrack(
          track,
          trainingModuleUuid: trainingModuleUuid,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isCompletingQuizSubmit = false;
          });
        }
      }
      return;
    }

    if (_tabController.index != 1) {
      return;
    }

    final detail = _controller.detail;
    final trainingModuleUuid = detail?.trainingModuleUuid.trim();
    if (trainingModuleUuid == null || trainingModuleUuid.isEmpty) {
      return;
    }

    await _handleQuizTabOpenRequest(
      track,
      trainingModuleUuid: trainingModuleUuid,
      fromTabNavigation: false,
    );
  }

  Future<String?> _openWelcomeQuiz(
    LearningTrackModuleDetail track, {
    required String trainingModuleUuid,
    bool clearAnswers = false,
  }) async {
    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Welcome Quiz',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) =>
          ChangeNotifierProvider<ComplianceQuizController>.value(
            value: _quizController,
            child: WelcomeQuizScreen(
              track: track,
              trackAssignmentUuid: widget.trackAssignmentUuid,
              trainingModuleUuid: trainingModuleUuid,
              clearAnswersOnStart: clearAnswers,
            ),
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );

    if (!mounted) {
      return null;
    }

    return action;
  }

  Future<String?> _openQuizResultForTrack(
    LearningTrackModuleDetail track, {
    required String trainingModuleUuid,
  }) async {
    final quizResult = await _quizController.getQuizResult(
      trackAssignmentUuid: widget.trackAssignmentUuid,
      trainingModuleUuid: trainingModuleUuid,
    );
    if (!mounted) {
      return null;
    }

    if (quizResult == null) {
      CustomFunctions.showCustomAlert(
        context,
        'Failed',
        'Unable to load quiz result, please try again!',
      );
      return null;
    }

    final action = await _showQuizResultDialog(quizResult, track);
    if (!mounted) {
      return null;
    }

    await _handleQuizResultAction(
      action,
      track,
      trainingModuleUuid: trainingModuleUuid,
      quizResult: quizResult,
    );
    return action;
  }

  Future<String?> _showQuizResultDialog(
    ComplianceQuizResult quizResult,
    LearningTrackModuleDetail track,
  ) async {
    final detail = _controller.detail;
    final hasNextTrackItem = await _hasNextTrackItem();
    final primaryActionText = hasNextTrackItem
        ? 'Next Module'
        : 'View Certificate';
    if (!mounted) {
      return null;
    }

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => QuizResultDialog(
        result: quizResult,
        fallbackTitle: detail?.title ?? track.displayName,
        primaryActionText: primaryActionText,
        fallbackSubtitle: track.displayJob,
        onPrimaryAction: hasNextTrackItem
            ? null
            : () async {
                final certificate = await _loadCertificate();
                if (certificate == null) {
                  return null;
                }

                _pendingCertificate = certificate;
                return 'view_certificate';
              },
      ),
    );
  }

  Future<void> _handleQuizTabOpenRequest(
    LearningTrackModuleDetail track, {
    required String trainingModuleUuid,
    required bool fromTabNavigation,
    int? fallbackTabIndex,
  }) async {
    await _quizController.waitForPreparation();
    if (!mounted ||
        _controller.detail?.trainingModuleUuid.trim() != trainingModuleUuid ||
        (fromTabNavigation && _tabController.index != 2)) {
      return;
    }

    final passedQuizResult = _quizController.quizResult?.isPassed == true
        ? _quizController.quizResult
        : null;
    if (passedQuizResult != null) {
      final action = await _showQuizResultDialog(passedQuizResult, track);
      if (!mounted) {
        return;
      }

      await _handleQuizResultAction(
        action,
        track,
        trainingModuleUuid: trainingModuleUuid,
        quizResult: passedQuizResult,
      );
      if (!mounted ||
          action == 'retake_quiz' ||
          action == 'next_module' ||
          action == 'track_modules') {
        return;
      }

      if (fromTabNavigation && fallbackTabIndex != null) {
        _selectTab(fallbackTabIndex);
      }
      return;
    }

    final welcomeAction = await _openWelcomeQuiz(
      track,
      trainingModuleUuid: trainingModuleUuid,
    );
    if (!mounted) {
      return;
    }

    if (welcomeAction == 'start_quiz') {
      _selectTab(2);
      return;
    }

    if (welcomeAction == 'track_modules') {
      _openTrackModulesScreen();
      return;
    }

    if (fromTabNavigation && fallbackTabIndex != null) {
      _selectTab(fallbackTabIndex);
    }
  }

  Future<void> _handleQuizResultAction(
    String? action,
    LearningTrackModuleDetail track, {
    required String trainingModuleUuid,
    required ComplianceQuizResult quizResult,
  }) async {
    if (action == 'view_certificate') {
      final certificate = _pendingCertificate;
      _pendingCertificate = null;
      await _openCertificateScreen(quizResult, certificate: certificate);
      return;
    }

    if (action == 'next_module') {
      await _openNextModuleOrCertificate(quizResult);
      return;
    }

    if (action == 'retake_quiz') {
      await _quizController.initialize(
        trackAssignmentUuid: widget.trackAssignmentUuid,
        trainingModuleUuid: trainingModuleUuid,
        forceRefresh: true,
      );
      if (!mounted) {
        return;
      }

      final welcomeAction = await _openWelcomeQuiz(
        track,
        trainingModuleUuid: trainingModuleUuid,
      );
      if (!mounted) {
        return;
      }

      if (welcomeAction == 'start_quiz') {
        _selectTab(2);
        return;
      }

      if (welcomeAction == 'track_modules') {
        _openTrackModulesScreen();
      }
      return;
    }

    if (action == 'track_modules') {
      _openTrackModulesScreen();
    }
  }

  Future<void> _handleQuizTabTransition(int fallbackTabIndex) async {
    if (_isHandlingQuizTabChange) {
      return;
    }

    if (context.read<AppManager>().showBillingBanner) {
      await showDialog<void>(
        context: context,
        builder: (_) => const UpgradePlanDialog(),
        barrierDismissible: false,
      );
      if (mounted) {
        _selectTab(fallbackTabIndex);
      }
      return;
    }

    final learningTrack = _currentTrack;
    final detail = _controller.detail;
    final trainingModuleUuid = detail?.trainingModuleUuid.trim();
    if (learningTrack == null ||
        trainingModuleUuid == null ||
        trainingModuleUuid.isEmpty) {
      return;
    }

    _isHandlingQuizTabChange = true;
    await _handleQuizTabOpenRequest(
      learningTrack,
      trainingModuleUuid: trainingModuleUuid,
      fromTabNavigation: true,
      fallbackTabIndex: fallbackTabIndex,
    );
    _isHandlingQuizTabChange = false;
  }

  void _selectTab(int index) {
    if (!mounted) {
      return;
    }

    _isIgnoringTabSelection = true;
    _tabController.animateTo(index);
    setState(() {
      _selectedTabIndex = index;
    });
    if (index == 2) {
      _quizController.startQuizTimer();
    } else {
      _quizController.cancelQuizTimer();
    }
    _isIgnoringTabSelection = false;
  }

  bool get _shouldPromptPauseQuiz =>
      _selectedTabIndex == 2 &&
      _quizController.hasStartedQuiz &&
      !_quizController.hasPassedQuizResult;

  Future<bool> _showPauseQuizDialog() async {
    final shouldPause = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: _quizController,
          builder: (dialogBuilderContext, _) {
            final isPausingQuiz = _quizController.isPausingQuiz;

            return AppConfirmationDialog(
              title: AppStrings.trainingPauseQuizTitle,
              description: AppStrings.trainingPauseQuizDescription,
              confirmText: AppStrings.trainingPauseQuizConfirm,
              cancelText: AppStrings.trainingPauseQuizCancel,
              isConfirmLoading: isPausingQuiz,
              onConfirmCallback: () async {
                if (isPausingQuiz) {
                  return;
                }

                final didPause = await _quizController
                    .pauseQuiz(trackAssignmentUuid: widget.trackAssignmentUuid)
                    .timeout(
                      const Duration(seconds: 10),
                      onTimeout: () => false,
                    );

                if (!mounted) {
                  return;
                }

                if (!didPause) {
                  _closePauseDialog(false);
                  if (mounted) {
                    CustomFunctions.showCustomAlert(
                      context,
                      'Failed',
                      'Unable to pause quiz, please try again!',
                    );
                  }
                  return;
                }

                _closePauseDialog(true);
              },
              onCancelCallback: () async {
                _closePauseDialog(false);
              },
            );
          },
        );
      },
    );

    return shouldPause == true;
  }

  void _closePauseDialog(bool result) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop(result);
      }
    });
  }

  Future<void> _handleBackPressed() async {
    if (!_shouldPromptPauseQuiz) {
      Navigator.of(context).maybePop();
      return;
    }

    final shouldPauseQuiz = await _showPauseQuizDialog();
    if (!mounted || !shouldPauseQuiz) {
      return;
    }

    Navigator.of(context).maybePop();
  }

  Future<void> _handleTrackModulesPressed() async {
    if (!_shouldPromptPauseQuiz) {
      _openTrackModulesScreen();
      return;
    }

    final shouldPauseQuiz = await _showPauseQuizDialog();
    if (!mounted || !shouldPauseQuiz) {
      return;
    }

    _openTrackModulesScreen();
  }

  Future<void> _openNextModuleOrCertificate(ComplianceQuizResult result) async {
    final nextTrack = await _nextModuleTrack();
    if (!mounted) {
      return;
    }

    if (nextTrack == null) {
      await _openCertificateScreen(result, fetchCertificate: true);
      return;
    }

    final nextItemUuid = nextTrack.trainingModuleItemId?.trim();
    if (nextItemUuid == null || nextItemUuid.isEmpty) {
      await _openCertificateScreen(result, fetchCertificate: true);
      return;
    }

    setState(() {
      _currentItemUuid = nextItemUuid;
    });
    _selectTab(0);
    await _loadTrainingContent();
  }

  Future<void> _openCertificateScreen(
    ComplianceQuizResult? result, {
    bool fetchCertificate = false,
    ComplianceCertificate? certificate,
  }) async {
    final detail = _controller.detail;
    var resolvedCertificate = certificate;
    if (fetchCertificate) {
      resolvedCertificate = await _loadCertificate();
      if (resolvedCertificate == null) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    final shouldOpenTrackModules = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Certificate',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => CertificateScreen(
        title: 'Congratulations!',
        description:
            resolvedCertificate?.trackName ??
            detail?.title ??
            _currentTrack?.displayName ??
            '',
        score:
            resolvedCertificate?.displayPercentage ??
            result?.displayScore ??
            '${detail?.quizCompletionPercentage ?? 100}%',
        status: result?.displayStatus ?? 'Pass',
        certificateUrl: resolvedCertificate?.certificate,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );

    if (!mounted || shouldOpenTrackModules != true) {
      return;
    }

    _openTrackModulesScreen();
  }

  Future<ComplianceCertificate?> _loadCertificate() async {
    try {
      return await _getComplianceCertificateUseCase(
        trackAssignmentUuid: widget.trackAssignmentUuid,
      );
    } catch (_) {
      if (!mounted) {
        return null;
      }

      CustomFunctions.showCustomAlert(
        context,
        'Failed',
        'Unable to load certificate, please try again!',
      );
      return null;
    }
  }

  Future<LearningTrackModuleDetail?> _nextModuleTrack() async {
    try {
      final tracks = await _getComplianceTracksUseCase(
        trackAssignmentUuid: widget.trackAssignmentUuid,
      );
      final currentIndex = tracks.indexWhere(
        (track) => track.trainingModuleItemId == _currentItemUuid,
      );
      if (currentIndex < 0 || currentIndex + 1 >= tracks.length) {
        return null;
      }

      for (final track in tracks.skip(currentIndex + 1)) {
        final itemUuid = track.trainingModuleItemId?.trim();
        if (!track.isBreakPoint && itemUuid != null && itemUuid.isNotEmpty) {
          return track;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasNextTrackItem() async {
    return await _nextModuleTrack() != null;
  }

  void _openTrackModulesScreen() {
    Navigator.of(context).maybePop(true);
  }

  @override
  Widget build(BuildContext context) {
    final learningTrack = _currentTrack;
    final detail = context.watch<ComplianceTrainingController>().detail;
    final isLoading = context.watch<ComplianceTrainingController>().isLoading;
    final quizController = context.watch<ComplianceQuizController>();
    final isSubmittingQuiz =
        quizController.isPreparingQuiz ||
        quizController.isSubmittingQuiz ||
        quizController.isLoadingQuizResult ||
        _isCompletingQuizSubmit;
    final canSubmitQuiz =
        _selectedTabIndex != 2 || quizController.hasAnsweredAllQuestions;

    return PopScope(
      canPop: !_shouldPromptPauseQuiz,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }

        await _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: AppColors.mainBg,
        appBar: AppBar(
          backgroundColor: AppColors.mainBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leadingWidth: 40,
          leading: AppBackButton(onPressed: _handleBackPressed),
        ),
        body: isLoading
            ? FastCircularProgressIndicator()
            : learningTrack == null
            ? Center(
                child: AppTextView.body(
                  AppStrings.complianceNoTracksFound,
                  color: AppColors.textSecondary,
                ),
              )
            : detail == null
            ? Center(
                child: AppTextView.body(
                  AppStrings.complianceNoTracksFound,
                  color: AppColors.textSecondary,
                ),
              )
            : SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _TrainingOverviewCard(
                        detail: detail,
                        currentModuleNumber: _controller.currentModuleNumber,
                        moduleCount: _controller.moduleCount,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _TrainingTabs(controller: _tabController),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: ComplianceVideoScreen(detail: detail),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
                            child: ComplianceTrainingDocumentScreen(
                              detail: detail,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
                            child: ComplianceQuizScreen(
                              trackAssignmentUuid: widget.trackAssignmentUuid,
                              trainingModuleUuid: detail.trainingModuleUuid,
                              isActive: _selectedTabIndex == 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: learningTrack == null || isLoading
            ? null
            : _BottomActions(
                onTrackModulesPressed: _handleTrackModulesPressed,
                onTakeQuizPressed: () => _handleTakeQuizPressed(learningTrack),
                isTakeQuizEnabled:
                    (_selectedTabIndex == 1 || _selectedTabIndex == 2) &&
                    canSubmitQuiz,
                takeQuizLabel: _selectedTabIndex == 2
                    ? AppStrings.trainingSubmitQuiz
                    : AppStrings.trainingTakeQuiz,
                isTakeQuizLoading:
                    (_selectedTabIndex != 0 &&
                        quizController.isPreparingQuiz) ||
                    (_selectedTabIndex == 2 && isSubmittingQuiz),
              ),
      ),
    );
  }
}

class _TrainingOverviewCard extends StatelessWidget {
  const _TrainingOverviewCard({
    required this.detail,
    required this.currentModuleNumber,
    required this.moduleCount,
  });

  final ComplianceTrackItemDetail detail;
  final int currentModuleNumber;
  final int moduleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextView.body1(
            detail.title,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          const SizedBox(height: 3),
          AppTextView.body(
            AppStrings.trainingVideoPositionLabel(
              currentModuleNumber,
              moduleCount,
            ),
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const AppTextView.body(
                AppStrings.trainingProgressLabel,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              const Spacer(),
              AppTextView.body(
                '${detail.quizCompletionPercentage}%',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (detail.quizCompletionPercentage.clamp(0, 100)) / 100,
              minHeight: 7,
              backgroundColor: AppColors.textPrimary,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.progressColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ComplianceRemoteDataSource createComplianceTrainingRemoteDataSource() {
  return ComplianceRemoteDataSource();
}

GetComplianceTrackItemDetailUseCase createGetComplianceTrackItemDetailUseCase(
  ComplianceRepositoryImpl repository,
) {
  return GetComplianceTrackItemDetailUseCase(repository);
}

GetComplianceQuizUseCase createGetComplianceQuizUseCase(
  ComplianceRepositoryImpl repository,
) {
  return GetComplianceQuizUseCase(repository);
}

GetComplianceQuizResultUseCase createGetComplianceQuizResultUseCase(
  ComplianceRepositoryImpl repository,
) {
  return GetComplianceQuizResultUseCase(repository);
}

StartComplianceQuizUseCase createStartComplianceQuizUseCase(
  ComplianceRepositoryImpl repository,
) {
  return StartComplianceQuizUseCase(repository);
}

PauseComplianceQuizUseCase createPauseComplianceQuizUseCase(
  ComplianceRepositoryImpl repository,
) {
  return PauseComplianceQuizUseCase(repository);
}

SubmitComplianceQuizUseCase createSubmitComplianceQuizUseCase(
  ComplianceRepositoryImpl repository,
) {
  return SubmitComplianceQuizUseCase(repository);
}

GetComplianceCertificateUseCase createGetComplianceCertificateUseCase(
  ComplianceRepositoryImpl repository,
) {
  return GetComplianceCertificateUseCase(repository);
}

class _TrainingTabs extends StatelessWidget {
  const _TrainingTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorColor: AppColors.secondaryColor,
      labelColor: AppColors.secondaryColor,
      unselectedLabelColor: AppColors.textSecondary,
      dividerColor: AppColors.fieldBorder.withValues(alpha: 0.22),
      tabs: const [
        Tab(text: AppStrings.trainingVideoTab),
        Tab(text: AppStrings.trainingDocumentTab),
        Tab(text: AppStrings.trainingQuizTab),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onTrackModulesPressed,
    required this.onTakeQuizPressed,
    required this.isTakeQuizEnabled,
    required this.takeQuizLabel,
    required this.isTakeQuizLoading,
  });

  final VoidCallback onTrackModulesPressed;
  final VoidCallback onTakeQuizPressed;
  final bool isTakeQuizEnabled;
  final String takeQuizLabel;
  final bool isTakeQuizLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 1, 10, 0),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                text: AppStrings.trainingTrackModules,
                onPressed: isTakeQuizLoading ? null : onTrackModulesPressed,
                backgroundColor: AppColors.lightPurple1,
                textColor: AppColors.grey2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: takeQuizLabel,
                onPressed: isTakeQuizEnabled ? onTakeQuizPressed : null,
                isLoading: isTakeQuizLoading,
                backgroundColor: isTakeQuizEnabled
                    ? AppColors.secondaryColor
                    : AppColors.grey1,
                textColor: isTakeQuizEnabled
                    ? AppColors.textPrimary
                    : AppColors.grey2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
