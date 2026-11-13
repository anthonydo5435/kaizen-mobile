import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/managers/app_manager.dart';
import '../../../../core/navigation/app_menu_type.dart';
import '../../../../core/navigation/main_navigation_controller.dart';
import '../../../../routes/app_router.dart';
import '../../data/datasources/training_library_remote_data_source.dart';
import '../../data/repositories/training_library_repository_impl.dart';
import '../../../seat_profile/data/datasources/seat_profile_remote_data_source.dart';
import '../../../seat_profile/data/repositories/seat_profile_repository_impl.dart';
import '../../../seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
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
        ChangeNotifierProvider<TrainingLibraryController>(
          create: (context) => TrainingLibraryController(
            context.read<GetTrainingLibraryModulesUseCase>(),
            getSeatProfilesUseCase: context.read<GetSeatProfilesUseCase>(),
            canCreateTraining: () =>
                AppManager.instance.currentUserCanOpenTrainingModuleCreateFlow,
            onNavigationBarsVisibilityChanged: (visible) => context
                .read<MainNavigationController?>()
                ?.setNavigationBarsVisible(AppMenuType.library, visible),
            trainingRepository: context.read<TrainingLibraryRepositoryImpl>(),
            canManageSeatTraining: (seatId) =>
                AppManager.instance.canCurrentUserManageTrainingForSeatProfile(
                  seatProfileId: seatId,
                ),
          )..initialize(),
        ),
      ],
      child: const _TrainingLibraryScreenView(),
    );
  }
}

class _TrainingLibraryScreenView extends StatelessWidget {
  const _TrainingLibraryScreenView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingLibraryController>();
    return ListenableBuilder(
      listenable: AppManager.instance,
      builder: (context, _) => TrainingLibraryContent(
        controller: controller,
        onModuleActions: (module) => controller.openModuleActions(
          module,
          showActions: (actionsController, lesson) =>
              showTrainingLibraryLessonActions(
                context,
                controller: actionsController,
                lesson: lesson,
              ),
        ),
        onOpenLesson: (route) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => EditTrainingScreen(
              trainingRoute: route,
              useNonBlockingVideoUpload: true,
            ),
          ),
        ),
        onSelectSeat: () => showTrainingLibrarySeatSelectionSheet(
          context,
          controller: controller,
        ),
        onCreate: () async {
          await AppRouter.pushNamed<void>(
            context,
            AppRouter.seatProfileTrainingSetup,
          );
          if (context.mounted) {
            await controller.refresh(preservePosition: true);
          }
        },
      ),
    );
  }
}
