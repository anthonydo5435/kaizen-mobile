import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/navigation/app_menu_type.dart';
import '../../../../core/navigation/main_navigation_controller.dart';
import '../../../../core/widgets/app_listing_tabs.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/training_library_remote_data_source.dart';
import '../../data/repositories/training_library_repository_impl.dart';
import '../../../seat_profile/data/datasources/seat_profile_remote_data_source.dart';
import '../../../seat_profile/data/repositories/seat_profile_repository_impl.dart';
import '../../../seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import '../../domain/entities/seat_description_training_route.dart';
import '../../domain/entities/training_library_module.dart';
import '../../domain/usecases/get_training_library_modules_usecase.dart';
import '../controllers/training_library_controller.dart';
import '../widgets/training_library_content.dart';
import '../widgets/training_library_lesson_actions.dart';
import '../widgets/training_library_seat_selection_sheet.dart';
import 'edit_training_screen.dart';

class TrainingLibraryScreen extends StatelessWidget {
  const TrainingLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TrainingLibraryRemoteDataSource>(
          create: (_) => createTrainingLibraryRemoteDataSource(),
        ),
        ProxyProvider<
          TrainingLibraryRemoteDataSource,
          TrainingLibraryRepositoryImpl
        >(
          update: (_, remoteDataSource, __) =>
              createTrainingLibraryRepository(remoteDataSource),
        ),
        ProxyProvider<
          TrainingLibraryRepositoryImpl,
          GetTrainingLibraryModulesUseCase
        >(
          update: (_, repository, __) =>
              createGetTrainingLibraryModulesUseCase(repository),
        ),
        Provider<SeatProfileRemoteDataSource>(
          create: (_) => createSeatProfileRemoteDataSource(),
        ),
        ProxyProvider<SeatProfileRemoteDataSource, SeatProfileRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              SeatProfileRepositoryImpl(remoteDataSource),
        ),
        ProxyProvider<SeatProfileRepositoryImpl, GetSeatProfilesUseCase>(
          update: (_, repository, __) => GetSeatProfilesUseCase(repository),
        ),
      ],
      child: const _TrainingLibraryScreenView(),
    );
  }
}

class _TrainingLibraryScreenView extends StatefulWidget {
  const _TrainingLibraryScreenView();

  @override
  State<_TrainingLibraryScreenView> createState() =>
      _TrainingLibraryScreenViewState();
}

class _TrainingLibraryScreenViewState
    extends State<_TrainingLibraryScreenView> {
  final _selectedType = ValueNotifier(TrainingModuleType.jobBased);
  late final TrainingLibraryController _seatLessons;
  TrainingLibraryController? _generalLessons;

  @override
  void initState() {
    super.initState();
    _seatLessons = _createController(TrainingModuleType.jobBased);
  }

  TrainingLibraryController _createController(TrainingModuleType type) {
    final appManager = AppManager.instance;
    return TrainingLibraryController(
      context.read<GetTrainingLibraryModulesUseCase>(),
      getSeatProfilesUseCase: context.read<GetSeatProfilesUseCase>(),
      moduleType: type,
      canCreateTraining: () =>
          appManager.currentUserCanOpenTrainingModuleCreateFlow,
      onNavigationBarsVisibilityChanged: (visible) {
        if (mounted && _selectedType.value == type) {
          _setNavigationBarsVisible(visible);
        }
      },
      trainingRepository: context.read<TrainingLibraryRepositoryImpl>(),
      canManageSeatTraining: (seatId) => appManager
          .canCurrentUserManageTrainingForSeatProfile(seatProfileId: seatId),
      canManageGeneralTraining: () =>
          appManager.currentUserCanManageGeneralTrainingModules,
    )..initialize();
  }

  void _setNavigationBarsVisible(bool visible) {
    context.read<MainNavigationController?>()?.setNavigationBarsVisible(
      AppMenuType.library,
      visible,
    );
  }

  void _selectTab(TrainingModuleType type) {
    if (_selectedType.value == type) return;

    FocusScope.of(context).unfocus();
    final controller = type == TrainingModuleType.jobBased
        ? _seatLessons
        : _generalLessons ??= _createController(type);
    _selectedType.value = type;
    _setNavigationBarsVisible(controller.navigationBarsVisible);
  }

  @override
  void dispose() {
    _seatLessons.dispose();
    _generalLessons?.dispose();
    _selectedType.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _selectedType,
      builder: (context, type, _) {
        final controller = type == TrainingModuleType.jobBased
            ? _seatLessons
            : _generalLessons!;
        final tabs = _TrainingLibraryTabs(
          selectedType: type,
          onTap: _selectTab,
        );
        return ListenableBuilder(
          listenable: Listenable.merge([controller, AppManager.instance]),
          builder: (context, _) => _buildContent(controller, tabs),
        );
      },
    );
  }

  Widget _buildContent(TrainingLibraryController controller, Widget tabs) {
    return TrainingLibraryContent(
      controller: controller,
      tabs: tabs,
      onModuleActions: (module) => controller.openModuleActions(
        module,
        showActions: (actionsController, lesson) =>
            showTrainingLibraryLessonActions(
              context,
              controller: actionsController,
              lesson: lesson,
            ),
      ),
      onOpenLesson: _openLesson,
      onSelectSeat: () => showTrainingLibrarySeatSelectionSheet(
        context,
        controller: controller,
      ),
      onCreate: () => unawaited(_openCreateFlow(controller)),
    );
  }

  Future<void> _openLesson(SeatDescriptionTrainingRoute route) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FutureBuilder<String?>(
          future: route.actualSeatProfileIdLookup,
          builder: (_, snapshot) {
            final actualSeatId = snapshot.data;
            return EditTrainingScreen(
              trainingRoute: actualSeatId == null
                  ? route
                  : route.withActualSeatProfileId(actualSeatId),
              useNonBlockingVideoUpload: true,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCreateFlow(TrainingLibraryController controller) async {
    if (controller.isGeneralListing) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const EditTrainingScreen(
            trainingRoute: SeatDescriptionTrainingRoute.general(),
            startNewLessonWhenEmpty: true,
            useNonBlockingVideoUpload: true,
          ),
        ),
      );
    } else {
      await AppRouter.pushNamed<void>(
        context,
        AppRouter.seatProfileTrainingSetup,
      );
    }
    if (mounted) await controller.refresh(preservePosition: true);
  }
}

class _TrainingLibraryTabs extends StatelessWidget {
  const _TrainingLibraryTabs({required this.selectedType, required this.onTap});

  final TrainingModuleType selectedType;
  final ValueChanged<TrainingModuleType> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: AppListingTabs(
        maxLabelLines: 2,
        tabs: [
          (
            title: AppStrings.trainingLibrarySeatLessons,
            isSelected: selectedType == TrainingModuleType.jobBased,
            onTap: () => onTap(TrainingModuleType.jobBased),
          ),
          (
            title: AppStrings.trainingLibraryGeneralLessons,
            isSelected: selectedType == TrainingModuleType.general,
            onTap: () => onTap(TrainingModuleType.general),
          ),
        ],
      ),
    );
  }
}
