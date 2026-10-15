import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/navigation/app_menu_type.dart';
import '../../../../core/widgets/drawer_main_screen.dart';
import '../../data/datasources/compliance_remote_data_source.dart';
import '../../data/repositories/compliance_document_media_repository_impl.dart';
import '../../data/repositories/compliance_repository_impl.dart';
import '../../domain/entities/compliance_tab_type.dart';
import '../../domain/repositories/compliance_document_media_repository.dart';
import '../../domain/usecases/get_compliance_documents_usecase.dart';
import '../../domain/usecases/get_compliance_overview_usecase.dart';
import '../../domain/usecases/pick_compliance_document_file_usecase.dart';
import '../../domain/usecases/upload_compliance_document_usecase.dart';
import '../providers/compliance_controller.dart';
import '../providers/compliance_document_controller.dart';
import '../providers/compliance_learning_track_controller.dart';
import 'compliance_learning_track_tab_screen.dart';
import 'document/compliance_document_tab_screen.dart';

class ComplianceScreen extends StatelessWidget {
  const ComplianceScreen({super.key, required this.module});

  final ComplianceTabType module;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ComplianceDocumentMediaRepository>(
          create: (_) => ComplianceDocumentMediaRepositoryImpl(),
        ),
        ProxyProvider<
          ComplianceDocumentMediaRepository,
          PickComplianceDocumentFileUseCase
        >(
          update: (_, repository, __) =>
              PickComplianceDocumentFileUseCase(repository),
        ),
        Provider<ComplianceRemoteDataSource>(
          create: (_) => createComplianceRemoteDataSource(),
        ),
        ProxyProvider<ComplianceRemoteDataSource, ComplianceRepositoryImpl>(
          update: (_, remoteDataSource, __) =>
              createComplianceRepository(remoteDataSource),
        ),
        ProxyProvider<ComplianceRepositoryImpl, GetComplianceOverviewUseCase>(
          update: (_, repository, __) =>
              createGetComplianceOverviewUseCase(repository),
        ),
        ProxyProvider<ComplianceRepositoryImpl, GetComplianceDocumentsUseCase>(
          update: (_, repository, __) =>
              GetComplianceDocumentsUseCase(repository),
        ),
        ProxyProvider<
          ComplianceRepositoryImpl,
          UploadComplianceDocumentUseCase
        >(
          update: (_, repository, __) =>
              UploadComplianceDocumentUseCase(repository),
        ),
        ChangeNotifierProvider<ComplianceController>(
          create: (context) => ComplianceController(
            context.read<GetComplianceOverviewUseCase>(),
          ),
        ),
        ChangeNotifierProxyProvider<
          ComplianceController,
          ComplianceLearningTrackController
        >(
          create: (context) => ComplianceLearningTrackController(
            context.read<GetComplianceOverviewUseCase>(),
          ),
          update: (context, complianceController, tabController) {
            final controller =
                tabController ??
                ComplianceLearningTrackController(
                  context.read<GetComplianceOverviewUseCase>(),
                );
            controller.updateDependencies(
              context.read<GetComplianceOverviewUseCase>(),
            );
            controller.setTracks(
              complianceController.state.overview?.learningTracks ?? const [],
            );
            return controller;
          },
        ),
        ChangeNotifierProvider<ComplianceDocumentController>(
          create: (context) => ComplianceDocumentController(
            context.read<GetComplianceDocumentsUseCase>(),
          ),
        ),
      ],
      child: _ComplianceScreenView(module: module),
    );
  }
}

class _ComplianceScreenView extends StatefulWidget {
  const _ComplianceScreenView({required this.module});

  final ComplianceTabType module;

  @override
  State<_ComplianceScreenView> createState() => _ComplianceScreenViewState();
}

class _ComplianceScreenViewState extends State<_ComplianceScreenView> {
  late final ComplianceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ComplianceController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.module != ComplianceTabType.learningTrack) {
        return;
      }

      _controller.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLearningTrackModule =
        widget.module == ComplianceTabType.learningTrack;
    final isOverviewLoading = isLearningTrackModule
        ? context.select<ComplianceController, bool>(
            (controller) => controller.state.isLoading,
          )
        : false;

    return DrawerMainScreen(
      title: isLearningTrackModule
          ? AppStrings.homeLearningTracks
          : AppStrings.homeCompliance,
      selectedMenu: isLearningTrackModule
          ? AppMenuType.learningTracks
          : AppMenuType.compliance,
      centerTitle: true,
      child: SafeArea(
        top: false,
        bottom: false,
        child: isOverviewLoading
            ? FastCircularProgressIndicator()
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 1),
      child: widget.module == ComplianceTabType.learningTrack
          ? const ComplianceLearningTrackTabScreen()
          : const ComplianceDocumentTabScreen(),
    );
  }
}
