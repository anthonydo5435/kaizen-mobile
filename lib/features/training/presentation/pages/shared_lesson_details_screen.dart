import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../../routes/app_router.dart';
import '../../../check_in/data/datasources/audit_remote_data_source.dart';
import '../../../check_in/data/repositories/audit_repository_impl.dart';
import '../../../check_in/domain/repositories/audit_repository.dart';
import '../../data/datasources/shared_lms_remote_data_source.dart';
import '../../data/datasources/training_library_remote_data_source.dart';
import '../../data/repositories/shared_lms_repository_impl.dart';
import '../../data/repositories/training_library_repository_impl.dart';
import '../../domain/entities/seat_description_training.dart';
import '../../domain/entities/seat_description_training_route.dart';
import '../../domain/repositories/shared_lms_repository.dart';
import '../../domain/repositories/training_library_repository.dart';
import '../controllers/training_module_controller.dart';
import '../controllers/training_share_controller.dart';
import '../controllers/training_tab_navigation_controller.dart';
import '../models/view_training_tab_access.dart';
import '../widgets/training_assignment_layout.dart';
import '../widgets/training_sop_document_view.dart';
import '../widgets/training_tab_view.dart';
import '../widgets/training_share_action.dart';
import 'edit_training_screen.dart';

part '../widgets/view_training/view_training_content.dart';

class SharedLessonDetailsScreen extends StatelessWidget {
  const SharedLessonDetailsScreen({
    super.key,
    required this.sharedContentId,
    required this.publicId,
    this.sharedLmsRepository,
  });

  final String sharedContentId;
  final String publicId;
  final SharedLmsRepository? sharedLmsRepository;

  @override
  Widget build(BuildContext context) => _LessonViewerScope.shared(
    sharedContentId: sharedContentId,
    sharedLessonId: publicId,
    sharedLmsRepository: sharedLmsRepository,
  );
}

class TrainingLessonViewerScreen extends StatelessWidget {
  const TrainingLessonViewerScreen({
    super.key,
    required this.trainingRoute,
    this.auditRepository,
    this.trainingLibraryRepository,
  });

  final SeatDescriptionTrainingRoute trainingRoute;
  final AuditRepository? auditRepository;
  final TrainingLibraryRepository? trainingLibraryRepository;

  @override
  Widget build(BuildContext context) => _LessonViewerScope.training(
    trainingRoute: trainingRoute,
    auditRepository: auditRepository,
    trainingLibraryRepository: trainingLibraryRepository,
  );
}

class _LessonViewerScope extends StatelessWidget {
  const _LessonViewerScope.training({
    required this.trainingRoute,
    required this.auditRepository,
    required this.trainingLibraryRepository,
  }) : sharedContentId = null,
       sharedLessonId = null,
       sharedLmsRepository = null;

  const _LessonViewerScope.shared({
    required this.sharedContentId,
    required this.sharedLessonId,
    required this.sharedLmsRepository,
  }) : trainingRoute = null,
       auditRepository = null,
       trainingLibraryRepository = null;

  final SeatDescriptionTrainingRoute? trainingRoute;
  final String? sharedContentId;
  final String? sharedLessonId;
  final SharedLmsRepository? sharedLmsRepository;
  final AuditRepository? auditRepository;
  final TrainingLibraryRepository? trainingLibraryRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuditRemoteDataSource>(create: (_) => AuditRemoteDataSource()),
        ProxyProvider<AuditRemoteDataSource, AuditRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              AuditRepositoryImpl(remoteDataSource),
        ),
        if (trainingRoute != null)
          Provider<TrainingLibraryRepository>(
            create: (_) =>
                trainingLibraryRepository ??
                createTrainingLibraryRepository(
                  createTrainingLibraryRemoteDataSource(),
                ),
          ),
        if (trainingRoute != null)
          ChangeNotifierProvider<TrainingShareController>(
            lazy: false,
            create: (context) => TrainingShareController(
              context.read<TrainingLibraryRepository>(),
              seatProfileId: trainingRoute!.job,
              descriptionId: trainingRoute!.description,
            )..loadLink(),
          ),
        Provider<SharedLmsRemoteDataSource>(
          create: (_) => SharedLmsRemoteDataSource(),
        ),
        ProxyProvider<SharedLmsRemoteDataSource, SharedLmsRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              SharedLmsRepositoryImpl(remoteDataSource),
        ),
        ChangeNotifierProvider<TrainingModuleController>(
          create: (context) {
            final lessonId = sharedLessonId;
            final sharedId = sharedContentId?.trim() ?? '';
            final sharedRepository =
                lessonId != null &&
                    lessonId.trim().isNotEmpty &&
                    sharedId.isNotEmpty
                ? (sharedLmsRepository ??
                      context.read<SharedLmsRepositoryImpl>())
                : null;
            final controller = TrainingModuleController(
              auditRepository ?? context.read<AuditRepositoryImpl>(),
              canManageTraining: false,
              sharedLessonDetailLoader: sharedRepository == null
                  ? null
                  : (publicId) =>
                        sharedRepository.getSharedLesson(sharedId, publicId),
            );
            if (lessonId != null) {
              unawaited(
                controller.initializeSharedLesson(
                  sharedId.isNotEmpty ? lessonId : '',
                ),
              );
            } else {
              final route = trainingRoute;
              if (route == null) {
                unawaited(controller.initializeSharedLesson(''));
              } else {
                unawaited(
                  controller.initialize(
                    jobId: route.job,
                    descriptionId: route.description,
                    initialModuleId: route.initialModuleId,
                  ),
                );
              }
            }
            return controller;
          },
        ),
      ],
      child: _LessonViewerView(
        seatProfileId: trainingRoute?.job ?? '',
        isSharedLesson: sharedLessonId != null,
      ),
    );
  }
}

class _LessonViewerView extends StatefulWidget {
  const _LessonViewerView({
    required this.seatProfileId,
    required this.isSharedLesson,
  });

  final String seatProfileId;
  final bool isSharedLesson;

  @override
  State<_LessonViewerView> createState() => _LessonViewerViewState();
}

class _LessonViewerViewState extends State<_LessonViewerView> {
  late final TrainingModuleController _trainingController;
  final TrainingTabNavigationController _navigation =
      TrainingTabNavigationController();
  int _lastHandledTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _trainingController = context.read<TrainingModuleController>();
    _trainingController.addListener(_handleTrainingModuleChanged);
    _navigation.addListener(_handleTabChanged);
    AppManager.instance.addListener(_handleTrainingModuleChanged);
  }

  @override
  void dispose() {
    AppManager.instance.removeListener(_handleTrainingModuleChanged);
    _trainingController.removeListener(_handleTrainingModuleChanged);
    _navigation.removeListener(_handleTabChanged);
    _navigation.dispose();
    super.dispose();
  }

  bool get _canViewQuizAndAssignment =>
      widget.isSharedLesson ||
      AppManager.instance.canCurrentUserViewTrainingQuizAndAssignment(
        seatProfileId: widget.seatProfileId,
      );

  int get _maxTabIndex => maxTrainingTabIndex(
    hasSelectedModule: _trainingController.canAccessSelectedModuleExtras,
    canViewQuizAndAssignment: _canViewQuizAndAssignment,
  );

  int _coerceSelectedTab() {
    final index = _trainingController.canAccessSelectedModuleExtras
        ? normalizeTrainingViewerTabIndex(
            canViewQuizAndAssignment: _canViewQuizAndAssignment,
            tabIndex: _navigation.selectedIndex,
          )
        : 0;
    if (_navigation.selectedIndex != index) _navigation.selectTab(index);
    return index;
  }

  void _handleTrainingModuleChanged() {
    if (mounted) _coerceSelectedTab();
  }

  void _handleTabChanged() {
    final index = _coerceSelectedTab();
    if (_lastHandledTabIndex == index) return;
    _lastHandledTabIndex = index;
    unawaited(_syncSelectedTabData(index));
  }

  Future<void> _syncSelectedTabData(int index) async {
    if (index > _maxTabIndex) return;
    switch (index) {
      case 1:
        await _trainingController.loadDocumentForSelectedModule();
      case 2:
        await _trainingController.loadQuestionsForSelectedModule();
      case 3:
        await _trainingController.loadAssignmentForSelectedModule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingModuleController>();
    return AnimatedBuilder(
      animation: AppManager.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.mainBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                child: _buildHeader(context),
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildBody(controller)),
            ],
          ),
        ),
        bottomNavigationBar: controller.modules.isEmpty
            ? null
            : SafeArea(
                top: false,
                bottom: false,
                minimum: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: TrainingTabs(
                  navigation: _navigation,
                  maxTabIndex: _maxTabIndex,
                ),
              ),
      ),
    );
  }

  Widget _buildBody(TrainingModuleController controller) {
    if (controller.isLoading && controller.modules.isEmpty) {
      return const Center(child: FastCircularProgressIndicator());
    }
    if (controller.modules.isEmpty) {
      return _CenteredMessage(
        message:
            controller.errorMessage ?? AppStrings.trainingNoModulesAvailable,
      );
    }

    return TrainingTabView(
      navigation: _navigation,
      maxTabIndex: _maxTabIndex,
      onPageApproaching: (index) {
        if (index == 1) {
          unawaited(_syncSelectedTabData(index));
        }
      },
      pagePaddingBuilder: (index) => index == 0
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 8),
      pageBuilder: (context, index) => _buildTabPage(controller, index),
    );
  }

  Widget _buildTabPage(TrainingModuleController controller, int index) {
    final content = _buildTabContent(controller, index);
    final showsEmptyQuiz =
        index == 2 &&
        !controller.isQuestionsLoading &&
        controller.selectedModuleQuestions.isEmpty;
    if (index == 1 || index == 3 || showsEmptyQuiz) return content;
    final showsLoading =
        (controller.isLoading && controller.selectedModuleDetail == null) ||
        (index == 2 && controller.isQuestionsLoading);
    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (index == 0 && controller.selectedModuleTitle.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TrainingLessonTitleField(
              valueText: controller.selectedModuleTitle,
              hintText: AppStrings.trainingLessonTitleHint,
              isReadOnly: true,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (showsLoading) Expanded(child: content) else content,
      ],
    );
    if (showsLoading) return page;
    return SingleChildScrollView(
      key: PageStorageKey<String>('${controller.selectedModuleId}:$index'),
      primary: false,
      padding: const EdgeInsets.only(bottom: 12),
      physics: const BouncingScrollPhysics(),
      child: page,
    );
  }

  Widget _buildTabContent(TrainingModuleController controller, int index) {
    if (index == 1) {
      final detailError = controller.selectedModuleDetail == null
          ? controller.errorMessage
          : null;
      return TrainingReadOnlySopTab(
        isLoading:
            controller.isLoading ||
            controller.isDocumentLoading ||
            (!controller.hasResolvedSelectedModuleDocument &&
                detailError == null),
        errorMessage: controller.documentErrorMessage ?? detailError,
        document: controller.selectedModuleDocument,
      );
    }

    if (controller.isLoading && controller.selectedModuleDetail == null) {
      return const Center(child: FastCircularProgressIndicator());
    }
    if (controller.errorMessage != null &&
        controller.selectedModuleDetail == null) {
      return _ContentMessage(message: controller.errorMessage!);
    }

    switch (index) {
      case 0:
        return TrainingReadOnlyVideoTab(
          controller: controller,
          contentHorizontalPadding: 8,
        );
      case 2:
        if (controller.questionsErrorMessage != null) {
          return _ContentMessage(message: controller.questionsErrorMessage!);
        }
        return TrainingReadOnlyQuizTab(controller: controller);
      default:
        return _AssignmentTabContent(
          isLoading: controller.isAssignmentLoading,
          errorMessage: controller.assignmentErrorMessage,
          assignment: controller.selectedModuleAssignment,
        );
    }
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 35,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop();
                } else if (widget.isSharedLesson) {
                  navigator.pushReplacementNamed(
                    AppRouter.defaultAuthenticatedRouteName,
                  );
                }
              },
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
            AppStrings.training,
            color: AppColors.secondaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          if (!widget.isSharedLesson)
            const Align(
              alignment: Alignment.centerRight,
              child: TrainingShareAction(),
            ),
        ],
      ),
    );
  }
}
