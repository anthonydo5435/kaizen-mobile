import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:tiptap_flutter/tiptap_flutter.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/services/video_playback_service.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_ai_generate_button.dart';
import '../../../../core/widgets/app_bar_gradient_action.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_dot_divider.dart';
import '../../../../core/widgets/app_gradient_action_button.dart';
import '../../../../core/widgets/app_overlay_close_button.dart';
import '../../../../core/widgets/app_dialog_style.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../check_in/data/datasources/audit_remote_data_source.dart';
import '../../../check_in/data/repositories/audit_repository_impl.dart';
import '../../../compliance/presentation/widgets/compliance_video_transcript_panel.dart';
import '../../data/datasources/training_library_remote_data_source.dart';
import '../../data/repositories/training_library_repository_impl.dart';
import '../../domain/entities/seat_description_training.dart';
import '../../domain/entities/seat_description_training_route.dart';
import '../../domain/repositories/training_library_repository.dart';
import '../controllers/training_module_controller.dart';
import '../controllers/training_share_controller.dart';
import '../controllers/training_sop_editor_controller.dart';
import '../controllers/training_question_form_controller.dart';
import '../controllers/training_quiz_question_editor_controller.dart';
import '../controllers/training_tab_navigation_controller.dart';
import '../widgets/training_sop_document_view.dart';
import '../controllers/training_video_capture_bridge.dart';
import '../controllers/training_video_upload_controller.dart';
import '../widgets/training_option_delete_dialog.dart';
import '../widgets/training_share_action.dart';
import '../widgets/training_swipe_delete_action.dart';
import '../widgets/training_tab_view.dart';

part '../widgets/edit_training/edit_training_add_question_dialog.dart';
part '../widgets/edit_training/edit_training_add_question_dialog_widgets.dart';
part '../widgets/edit_training/edit_training_assignment_tab.dart';
part '../widgets/edit_training/edit_training_dialog_support.dart';
part '../widgets/edit_training/edit_training_edit_question_dialog.dart';
part '../widgets/edit_training/edit_training_generate_quiz_dialog.dart';
part '../widgets/edit_training/edit_training_generate_assignment_dialog.dart';
part '../widgets/edit_training/edit_training_generate_sop_dialog.dart';
part '../widgets/edit_training/edit_training_header_actions.dart';
part '../widgets/edit_training/edit_training_module_dialogs.dart';
part '../widgets/edit_training/edit_training_module_selector.dart';
part '../widgets/edit_training/edit_training_quiz_option_widgets.dart';
part '../widgets/edit_training/edit_training_quiz_question_actions_sheet.dart';
part '../widgets/edit_training/edit_training_quiz_question_card.dart';
part '../widgets/edit_training/edit_training_quiz_tab.dart';
part '../widgets/edit_training/edit_training_section_state_dialogs.dart';
part '../widgets/edit_training/edit_training_section_state_handlers.dart';
part '../widgets/edit_training/edit_training_section_state_media.dart';
part '../widgets/edit_training/edit_training_section_state_view.dart';
part '../widgets/edit_training/edit_training_shared_actions.dart';
part '../widgets/edit_training/edit_training_sop_tab.dart';
part '../widgets/edit_training/edit_training_tabs.dart';
part '../widgets/edit_training/edit_training_text_edit.dart';
part '../widgets/edit_training/edit_training_video_picker.dart';
part '../widgets/edit_training/edit_training_video_picker_tiles.dart';
part '../widgets/edit_training/edit_training_video_tab.dart';
part '../widgets/edit_training/training_read_only_tabs.dart';

class EditTrainingScreen extends StatelessWidget {
  const EditTrainingScreen({
    super.key,
    required this.trainingRoute,
    this.initialModuleId,
    this.canManageTraining,
    this.startNewLessonWhenEmpty = false,
    this.useNonBlockingVideoUpload = false,
  });

  final SeatDescriptionTrainingRoute trainingRoute;
  final String? initialModuleId;
  final bool? canManageTraining;
  final bool startNewLessonWhenEmpty;
  final bool useNonBlockingVideoUpload;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TrainingLibraryRepository>(
          create: (_) => createTrainingLibraryRepository(
            createTrainingLibraryRemoteDataSource(),
          ),
        ),
        ChangeNotifierProvider<TrainingShareController>(
          lazy: false,
          create: (context) => TrainingShareController(
            context.read<TrainingLibraryRepository>(),
            seatProfileId: trainingRoute.job,
            descriptionId: trainingRoute.description,
          )..loadLink(),
        ),
      ],
      child: EditTrainingSection(
        trainingRoute: trainingRoute,
        initialModuleId: initialModuleId,
        canManageTraining: canManageTraining,
        startNewLessonWhenEmpty: startNewLessonWhenEmpty,
        useNonBlockingVideoUpload: useNonBlockingVideoUpload,
        allowDeviceRotation: true,
        horizontalContentPadding: 8,
        builder: (context, section, headerActions, hideScreenHeader) {
          final isLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          return Scaffold(
            backgroundColor: AppColors.mainBg,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              top: !isLandscape,
              left: !isLandscape,
              right: !isLandscape,
              bottom: false,
              child: Column(
                children: [
                  Offstage(
                    offstage: hideScreenHeader,
                    child: SafeArea(
                      left: !isLandscape,
                      right: !isLandscape,
                      bottom: false,
                      minimum: EdgeInsets.fromLTRB(
                        isLandscape ? 12 : 8,
                        isLandscape ? 0 : 2,
                        isLandscape ? 12 : 8,
                        0,
                      ),
                      child: _buildHeader(context, headerActions),
                    ),
                  ),
                  SizedBox(height: isLandscape ? 0 : 18),
                  Expanded(child: section),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Widget headerActions) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(isLandscape ? 32 : 35),
      child: NavigationToolbar(
        centerMiddle: true,
        leading: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).maybePop(),
          child: Padding(
            padding: isLandscape
                ? const EdgeInsets.fromLTRB(0, 2, 4, 2)
                : const EdgeInsets.fromLTRB(0, 4, 8, 4),
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
        middle: const AppTextView.body(
          AppStrings.training,
          color: AppColors.secondaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: headerActions,
      ),
    );
  }
}

class EditTrainingSection extends StatelessWidget {
  const EditTrainingSection({
    super.key,
    required this.trainingRoute,
    this.initialModuleId,
    this.canManageTraining,
    this.startNewLessonWhenEmpty = false,
    this.isEmbedded = false,
    this.skipResumeSessionRefreshOnMediaPicker = false,
    this.showOnlyApiErrorSnackBars = false,
    this.useNonBlockingVideoUpload = false,
    this.allowDeviceRotation = false,
    this.horizontalContentPadding = 0,
    this.builder,
  });

  final SeatDescriptionTrainingRoute trainingRoute;
  final String? initialModuleId;
  final bool? canManageTraining;
  final bool startNewLessonWhenEmpty;
  final bool isEmbedded;
  final bool skipResumeSessionRefreshOnMediaPicker;
  final bool showOnlyApiErrorSnackBars;
  final bool useNonBlockingVideoUpload;
  final bool allowDeviceRotation;
  final double horizontalContentPadding;

  /// Builds the surrounding screen within the section's controller scope.
  final Widget Function(
    BuildContext context,
    Widget section,
    Widget headerActions,
    bool hideScreenHeader,
  )?
  builder;

  @override
  Widget build(BuildContext context) {
    final resolvedInitialModuleId =
        (initialModuleId?.trim().isNotEmpty ?? false)
        ? initialModuleId
        : trainingRoute.initialModuleId;

    final routeBasedTrainingAccess = AppManager.instance
        .canCurrentUserManageTrainingForSeatProfile(
          seatProfileId: trainingRoute.job,
        );
    final resolvedCanManageTraining =
        AppManager.instance.canCurrentOrganizationModifyContent &&
        (canManageTraining == true || routeBasedTrainingAccess);

    return MultiProvider(
      providers: [
        Provider<AuditRemoteDataSource>(create: (_) => AuditRemoteDataSource()),
        ProxyProvider<AuditRemoteDataSource, AuditRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              AuditRepositoryImpl(remoteDataSource),
        ),
        ChangeNotifierProvider<TrainingModuleController>(
          create: (context) =>
              TrainingModuleController(
                context.read<AuditRepositoryImpl>(),
                canManageTraining: resolvedCanManageTraining,
                sopEditorFactory: context.read<TrainingSopEditorFactory?>(),
                canViewQuizAndAssignment: AppManager.instance
                    .canCurrentUserViewTrainingQuizAndAssignment(
                      seatProfileId: trainingRoute.job,
                    ),
              )..initialize(
                jobId: trainingRoute.job,
                descriptionId: trainingRoute.description,
                initialModuleId: resolvedInitialModuleId,
                startNewLessonWhenEmpty: startNewLessonWhenEmpty,
              ),
        ),
      ],
      child: _EditTrainingSectionView(
        initialModuleId: resolvedInitialModuleId,
        trainingDescriptionId: trainingRoute.description,
        startNewLessonWhenEmpty: startNewLessonWhenEmpty,
        isEmbedded: isEmbedded,
        skipResumeSessionRefreshOnMediaPicker:
            skipResumeSessionRefreshOnMediaPicker,
        showOnlyApiErrorSnackBars: showOnlyApiErrorSnackBars,
        useNonBlockingVideoUpload: useNonBlockingVideoUpload,
        allowDeviceRotation: allowDeviceRotation,
        horizontalContentPadding: horizontalContentPadding,
        builder: builder,
      ),
    );
  }
}

class _EditTrainingSectionView extends StatefulWidget {
  const _EditTrainingSectionView({
    required this.initialModuleId,
    required this.trainingDescriptionId,
    required this.startNewLessonWhenEmpty,
    required this.isEmbedded,
    required this.skipResumeSessionRefreshOnMediaPicker,
    required this.showOnlyApiErrorSnackBars,
    required this.useNonBlockingVideoUpload,
    required this.allowDeviceRotation,
    required this.horizontalContentPadding,
    this.builder,
  });

  final String? initialModuleId;
  final String trainingDescriptionId;
  final bool startNewLessonWhenEmpty;
  final bool isEmbedded;
  final bool skipResumeSessionRefreshOnMediaPicker;
  final bool showOnlyApiErrorSnackBars;
  final bool useNonBlockingVideoUpload;
  final bool allowDeviceRotation;
  final double horizontalContentPadding;
  final Widget Function(
    BuildContext context,
    Widget section,
    Widget headerActions,
    bool hideScreenHeader,
  )?
  builder;

  @override
  State<_EditTrainingSectionView> createState() =>
      _EditTrainingSectionViewState();
}

class _EditTrainingSectionViewState extends State<_EditTrainingSectionView> {
  late final TrainingTabNavigationController _tabNavigation;
  int _lastHandledTabIndex = 0;
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _newLessonTitleFocusNode = FocusNode();
  final GlobalKey _newLessonTitleFieldKey = GlobalKey();
  final ValueNotifier<bool> _isPickingVideoNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> _isFinalizingVideoSetupNotifier =
      ValueNotifier<bool>(false);
  TrainingModuleController? _trainingController;
  String? _lastDocumentErrorMessage;
  String? _lastAssignmentErrorMessage;
  String? _lastQuestionsErrorMessage;
  int _lastHandledSummarySnackBarSequence = 0;
  int _lastHandledGlobalVideoUploadEventSequence = 0;
  int _lastHandledGlobalVideoSummaryEventSequence = 0;
  int _activeTrainingModalSheetCount = 0;
  late final Listenable _viewStateListenable;
  bool _isLandscapeVideoFullscreen = false;
  bool _isWaitingForDevicePortrait = false;
  int _portraitResetGeneration = 0;

  int get _selectedTabIndex => _tabNavigation.selectedIndex;

  bool get _isPickingVideo => _isPickingVideoNotifier.value;

  bool get _isFinalizingVideoSetup => _isFinalizingVideoSetupNotifier.value;

  bool get _isTrainingModalSheetOpen => _activeTrainingModalSheetCount > 0;

  bool get _isLandscapeSop =>
      widget.allowDeviceRotation &&
      !widget.isEmbedded &&
      _selectedTabIndex == 1 &&
      MediaQuery.orientationOf(context) == Orientation.landscape;

  bool get _isLandscapeVideo =>
      widget.allowDeviceRotation &&
      !widget.isEmbedded &&
      _selectedTabIndex == 0 &&
      _trainingController?.isCreatingNewLessonDraft != true &&
      !_isFinalizingVideoSetup &&
      (_trainingController?.selectedModuleDetail?.trainingVideo?.url
              ?.trim()
              .isNotEmpty ??
          false) &&
      MediaQuery.orientationOf(context) == Orientation.landscape;

  void _syncLandscapeVideoDisplay(bool enabled) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (_isLandscapeVideoFullscreen == enabled) return;
    _isLandscapeVideoFullscreen = enabled;
    unawaited(VideoPlaybackService.setFullscreen(enabled));
    if (!enabled && _selectedTabIndex == 0) {
      _updatePreferredOrientations();
    }
  }

  void _resetToPortrait() {
    if (_isWaitingForDevicePortrait) return;
    _isWaitingForDevicePortrait = true;
    final generation = ++_portraitResetGeneration;
    unawaited(_restoreRotationAfterDevicePortrait(generation));
  }

  Future<void> _restoreRotationAfterDevicePortrait(int generation) async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    if (!mounted || generation != _portraitResetGeneration) return;
    final isPortrait = await VideoPlaybackService.waitForDevicePortrait();
    if (!mounted || generation != _portraitResetGeneration || !isPortrait) {
      return;
    }
    _isWaitingForDevicePortrait = false;
    _updatePreferredOrientations();
  }

  void _cancelPortraitReset() {
    if (!_isWaitingForDevicePortrait) return;
    _isWaitingForDevicePortrait = false;
    _portraitResetGeneration += 1;
    unawaited(VideoPlaybackService.cancelDevicePortraitWait());
  }

  void _beginTrainingModalSheetPresentation() {
    _activeTrainingModalSheetCount += 1;
  }

  void _endTrainingModalSheetPresentation() {
    if (_activeTrainingModalSheetCount == 0) {
      return;
    }

    _activeTrainingModalSheetCount -= 1;
  }

  @override
  void initState() {
    super.initState();
    _tabNavigation = TrainingTabNavigationController()
      ..addListener(_handleTabChanged);
    _updatePreferredOrientations();
    _viewStateListenable = Listenable.merge([
      _tabNavigation,
      _isPickingVideoNotifier,
      _isFinalizingVideoSetupNotifier,
      if (widget.useNonBlockingVideoUpload)
        TrainingVideoUploadController.instance,
    ]);
    if (widget.useNonBlockingVideoUpload) {
      _lastHandledGlobalVideoUploadEventSequence =
          TrainingVideoUploadController.instance.latestTerminalEventSequence;
      _lastHandledGlobalVideoSummaryEventSequence =
          TrainingVideoUploadController.instance.latestSummaryEventSequence;
      TrainingVideoUploadController.instance.addListener(
        _handleGlobalVideoUploadChanged,
      );
    }
    unawaited(_restoreLostTrainingVideoIfNeeded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<TrainingModuleController>();
    if (identical(_trainingController, controller)) {
      return;
    }

    _trainingController?.removeListener(_handleTrainingControllerChanged);
    _trainingController = controller;
    _lastDocumentErrorMessage = _normalizeSnackBarMessage(
      controller.documentErrorMessage,
    );
    _lastAssignmentErrorMessage = _normalizeSnackBarMessage(
      controller.assignmentErrorMessage,
    );
    _lastQuestionsErrorMessage = _normalizeSnackBarMessage(
      controller.questionsErrorMessage,
    );
    _lastHandledSummarySnackBarSequence = controller.summarySnackBarSequence;
    _trainingController?.addListener(_handleTrainingControllerChanged);
  }

  @override
  void dispose() {
    _cancelPortraitReset();
    if (_isLandscapeVideoFullscreen) {
      unawaited(VideoPlaybackService.setFullscreen(false));
    }
    if (widget.allowDeviceRotation) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
    _trainingController?.removeListener(_handleTrainingControllerChanged);
    if (widget.useNonBlockingVideoUpload) {
      TrainingVideoUploadController.instance.removeListener(
        _handleGlobalVideoUploadChanged,
      );
    }
    _tabNavigation.removeListener(_handleTabChanged);
    _tabNavigation.dispose();
    _newLessonTitleFocusNode.dispose();
    _isPickingVideoNotifier.dispose();
    _isFinalizingVideoSetupNotifier.dispose();
    super.dispose();
  }

  void _updatePreferredOrientations() {
    if (!widget.allowDeviceRotation) return;
    unawaited(
      SystemChrome.setPreferredOrientations(
        _selectedTabIndex <= 1 && !_isWaitingForDevicePortrait
            ? const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();
    final exitsEmptyCreateDraft =
        widget.startNewLessonWhenEmpty && controller.modules.isEmpty;
    return AnimatedBuilder(
      animation: _viewStateListenable,
      builder: (context, _) {
        final isLandscapeVideo = _isLandscapeVideo;
        final isLandscapeExpanded = isLandscapeVideo || _isLandscapeSop;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncLandscapeVideoDisplay(isLandscapeVideo);
        });
        final section = _buildBody(controller);
        return PopScope<Object?>(
          canPop:
              !isLandscapeExpanded &&
              !controller.isCreatingModule &&
              (exitsEmptyCreateDraft || !controller.isCreatingNewLessonDraft),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && isLandscapeExpanded) {
              _resetToPortrait();
              return;
            }
            if (didPop ||
                exitsEmptyCreateDraft ||
                !controller.isCreatingNewLessonDraft ||
                controller.isCreatingModule) {
              return;
            }

            FocusScope.of(context).unfocus();
            unawaited(controller.cancelCreatingNewLessonDraft());
          },
          child:
              widget.builder?.call(
                context,
                section,
                _TrainingHeaderActions(
                  controller: controller,
                  onShowAllLessons: () => _showAllLessons(controller),
                  onAddLesson: () => _startNewLesson(controller),
                ),
                isLandscapeExpanded,
              ) ??
              section,
        );
      },
    );
  }
}
