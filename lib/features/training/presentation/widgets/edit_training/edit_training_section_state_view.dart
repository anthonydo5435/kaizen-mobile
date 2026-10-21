part of 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';

extension _EditTrainingSectionViewStateView on _EditTrainingSectionViewState {
  Widget _buildBody(TrainingModuleController controller) {
    return LayoutBuilder(
      builder: (context, constraints) => _buildSectionLayout(
        controller,
        availableHeight: constraints.maxHeight,
      ),
    );
  }

  Widget _buildSectionLayout(
    TrainingModuleController controller, {
    required double availableHeight,
  }) {
    if (controller.isLoading &&
        controller.modules.isEmpty &&
        !controller.isCreatingNewLessonDraft) {
      return Center(child: FastCircularProgressIndicator());
    }

    final fillAvailableSpace = !widget.isEmbedded;
    final isSopTab = _selectedTabIndex == 1;
    final isLandscapeSop = _isLandscapeSop;
    final isEditingSopWithKeyboard =
        fillAvailableSpace &&
        isSopTab &&
        MediaQuery.viewInsetsOf(context).bottom > 0;
    final collapseLessonHeader =
        fillAvailableSpace &&
        isSopTab &&
        (isEditingSopWithKeyboard || availableHeight < 440);
    final contentCard = _buildTabContent(
      controller,
      showLessonHeader: !collapseLessonHeader && !_isLandscapeVideo,
    );
    final contentChildren = <Widget>[
      if (fillAvailableSpace) Expanded(child: contentCard) else contentCard,
    ];

    if (widget.isEmbedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...contentChildren,
          const SizedBox(height: 18),
          TrainingTabs(
            navigation: _tabNavigation,
            maxTabIndex: controller.maxAccessibleTabIndex,
          ),
        ],
      );
    }

    // Resize the editing area for the keyboard while navigation stays at the screen bottom.
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: contentChildren,
      ),
      bottomNavigationBar: Offstage(
        offstage: _isLandscapeVideo || isLandscapeSop,
        child: SafeArea(
          top: false,
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: TrainingTabs(
            navigation: _tabNavigation,
            maxTabIndex: controller.maxAccessibleTabIndex,
          ),
        ),
      ),
    );
  }

  Widget _buildLessonHeader(
    TrainingModuleController controller, {
    required int tabIndex,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tabIndex == 0 && controller.isCreatingNewLessonDraft) ...[
          _NewLessonTitleField(
            key: _newLessonTitleFieldKey,
            controller: controller.newLessonTitleController,
            focusNode: _newLessonTitleFocusNode,
            isSubmitting: controller.isCreatingModule,
            canSubmit: controller.canSubmitNewLessonTitle,
            onSubmit: () => _createModuleFromDraft(controller),
          ),
          const SizedBox(height: 16),
        ] else if (tabIndex == 0 && controller.hasSelectedModule) ...[
          TrainingLessonTitleField(
            valueText: controller.selectedModuleTitle,
            hintText: AppStrings.trainingLessonTitleHint,
            isReadOnly: !controller.canEditSelectedModuleTitle,
            onTap:
                !controller.canEditSelectedModuleTitle ||
                    controller.isSavingModuleTitle
                ? null
                : () => _showModuleTitleEditBottomSheet(controller),
            isLoading: controller.isSavingModuleTitle,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildTabContent(
    TrainingModuleController controller, {
    required bool showLessonHeader,
  }) {
    final isBackgroundVideoUploadActive =
        widget.useNonBlockingVideoUpload &&
        TrainingVideoUploadController.instance.isUploadActiveForModule(
          descriptionId: widget.trainingDescriptionId,
          moduleId: controller.selectedModuleId,
        );
    return TrainingTabView(
      navigation: _tabNavigation,
      maxTabIndex: controller.maxAccessibleTabIndex,
      isSwipeEnabled: !_isLandscapeVideo && !_isLandscapeSop,
      onPageApproaching: (index) {
        if (index == 1) {
          unawaited(controller.loadDocumentForSelectedModule());
        } else if (index == 3) {
          unawaited(controller.loadAssignmentForSelectedModule());
        }
      },
      // Keep the video surface full width; inset the other pages separately.
      pagePaddingBuilder: (index) => index == 0
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(
              horizontal:
                  index == 1 &&
                      !widget.isEmbedded &&
                      MediaQuery.orientationOf(context) == Orientation.landscape
                  ? 4
                  : widget.horizontalContentPadding +
                        (widget.isEmbedded && index != 2 ? 4 : 0),
            ),
      pageBuilder: (context, index) {
        final showsLoading =
            (controller.isLoading && controller.selectedModuleDetail == null) ||
            (index == 2 && controller.isQuestionsLoading);
        final showsEmptyQuiz =
            index == 2 &&
            !controller.canManageTraining &&
            !controller.isQuestionsLoading &&
            controller.selectedModuleQuestions.isEmpty;
        final fillsPage =
            (index == 1 || index == 3 || showsEmptyQuiz || showsLoading) &&
            controller.hasSelectedModule &&
            !controller.isCreatingNewLessonDraft;
        final tabContent = _buildTabPageForIndex(
          controller,
          tabIndex: index,
          isBackgroundVideoUploadActive: isBackgroundVideoUploadActive,
        );
        final page = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Offstage(
              offstage: !showLessonHeader,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: index == 0
                      ? widget.horizontalContentPadding +
                            (widget.isEmbedded ? 4 : 0)
                      : 0,
                ),
                child: _buildLessonHeader(controller, tabIndex: index),
              ),
            ),
            if (fillsPage) Expanded(child: tabContent) else tabContent,
          ],
        );
        return fillsPage
            ? page
            : SingleChildScrollView(
                key: PageStorageKey<int>(index),
                primary: false,
                keyboardDismissBehavior: index == 0
                    ? ScrollViewKeyboardDismissBehavior.onDrag
                    : ScrollViewKeyboardDismissBehavior.manual,
                padding: const EdgeInsets.only(bottom: 12),
                physics: const BouncingScrollPhysics(),
                child: page,
              );
      },
    );
  }

  Widget _buildTabPageForIndex(
    TrainingModuleController controller, {
    required int tabIndex,
    required bool isBackgroundVideoUploadActive,
  }) {
    final contentHorizontalPadding =
        widget.horizontalContentPadding + (widget.isEmbedded ? 4 : 0);
    if (controller.isCreatingNewLessonDraft) {
      return _VideoTabContent(
        detail: null,
        localVideoPath: null,
        isReadOnly: false,
        isUploadEnabled: false,
        isPickingVideo: _isPickingVideo,
        isFinalizingVideoSetup: _isFinalizingVideoSetup,
        isUploadingVideo: false,
        isDeletingVideo: false,
        isUploadingThumbnail: false,
        canEditSummary: false,
        isEditingSummary: false,
        isSavingSummary: false,
        summaryController: controller.summaryController,
        contentHorizontalPadding: contentHorizontalPadding,
      );
    }

    if (!controller.hasSelectedModule) {
      return _ContentMessage(
        message:
            controller.errorMessage ?? AppStrings.trainingNoModulesAvailable,
      );
    }

    if (controller.isLoading && controller.selectedModuleDetail == null) {
      return const Center(child: FastCircularProgressIndicator());
    }

    if (controller.errorMessage != null &&
        controller.selectedModuleDetail == null) {
      return _ContentMessage(message: controller.errorMessage!);
    }

    if (tabIndex == 0) {
      return _VideoTabContent(
        fullscreenInLandscape:
            widget.allowDeviceRotation && _selectedTabIndex == 0,
        onExitLandscapeFullscreen: widget.allowDeviceRotation
            ? _resetToPortrait
            : null,
        detail: controller.selectedModuleDetail,
        localVideoPath: controller.selectedModuleLocalVideoPath,
        isReadOnly: !controller.canManageTraining,
        isUploadEnabled:
            controller.canUploadSelectedModuleVideo &&
            !isBackgroundVideoUploadActive,
        isPickingVideo: _isPickingVideo,
        isFinalizingVideoSetup: _isFinalizingVideoSetup,
        isUploadingVideo:
            controller.isUploadingVideo || isBackgroundVideoUploadActive,
        isDeletingVideo: controller.isDeletingVideo,
        isUploadingThumbnail: controller.isUploadingThumbnail,
        canEditSummary: controller.canEditSelectedModuleSummary,
        isEditingSummary: controller.isEditingSummary,
        isSavingSummary: controller.isSavingSummary,
        summaryController: controller.summaryController,
        contentHorizontalPadding: contentHorizontalPadding,
        canGenerateSummary:
            controller.canGenerateSummaryForSelectedModule &&
            !isBackgroundVideoUploadActive,
        isGeneratingSummary: controller.isGeneratingSummary,
        isWritingSummary: controller.isWritingSummary,
        onUploadVideoTap: () => _selectVideoSourceAndUpload(controller),
        onReUploadVideoTap: () => _reUploadVideo(controller),
        onUpdateThumbnailTap: () => _pickAndUploadThumbnail(controller),
        onEditSummaryTap: controller.startEditingSummary,
        onCancelSummaryTap: controller.cancelEditingSummary,
        onSaveSummaryTap: () => controller.saveSummaryForSelectedModule(),
        onGenerateSummaryTap: () {
          FocusScope.of(context).unfocus();
          unawaited(
            controller.generateSummaryForSelectedModule(
              animate: !MediaQuery.disableAnimationsOf(context),
            ),
          );
        },
      );
    }

    if (tabIndex == 1) {
      final moduleId = controller.selectedModuleId;
      final editorVersion = controller.documentEditorVersion;
      return _SopTabContent(
        isLoading:
            controller.isDocumentLoading ||
            !controller.hasResolvedSelectedModuleDocument,
        canManageGeneration: controller.canManageTraining,
        canGenerate: controller.canGenerateSopForSelectedModule,
        isGeneratingSop: controller.isGeneratingSop,
        canEditDocument: controller.canEditSelectedModuleDocument,
        isSavingDocument: controller.isSavingDocument,
        showPdf: false,
        canViewPdf: controller.canOpenDocumentPdf,
        isOpeningPdf: controller.isOpeningDocumentPdf,
        documentHtml: controller.documentHtml,
        editorKey: ValueKey((moduleId, editorVersion)),
        errorMessage: controller.documentErrorMessage,
        editorControllerBuilder: () => controller.sopEditorController,
        onGenerateSopTap: () => _handleGenerateSopTap(controller),
        onViewPdfTap: () => _openSopPdf(controller),
        onExitLandscape: widget.allowDeviceRotation && !widget.isEmbedded
            ? _resetToPortrait
            : null,
        onDoneTap: () {
          if (MediaQuery.viewInsetsOf(context).bottom > 0) {
            FocusScope.of(context).unfocus();
          }
        },
      );
    }

    if (tabIndex == 2) {
      return _QuizTabContent(
        isLoading: controller.isQuestionsLoading,
        questions: controller.selectedModuleQuestions,
        canManageQuestions: controller.canManageTraining,
        canAddQuestion: controller.canAddQuestionToSelectedModule,
        canGenerateQuiz: controller.canGenerateQuizForSelectedModule,
        isGeneratingQuiz: controller.isGeneratingQuiz,
        isAddingQuestion: controller.isAddingQuestion,
        savingQuestionId: controller.savingQuestionId,
        deletingQuestionId: controller.deletingQuestionId,
        onAddQuestionTap: () => _showAddQuestionDialog(controller),
        onGenerateQuizTap: () => _showGenerateQuizDialog(controller),
        onDeleteQuestionTap: (question) => _showDeleteQuestionDialog(
          controller: controller,
          question: question,
        ),
        onEditQuestionTap: (question) =>
            _showEditQuestionDialog(controller, question),
      );
    }

    if (tabIndex == 3) {
      return _AssignmentTabContent(
        isLoading:
            controller.isAssignmentLoading ||
            !controller.hasResolvedSelectedModuleAssignment,
        canManageGeneration: controller.canManageTraining,
        canGenerate: controller.canGenerateAssignmentForSelectedModule,
        isGenerating: controller.isGeneratingAssignment,
        canEditAssignment: controller.canEditSelectedModuleAssignment,
        isSavingAssignment: controller.isSavingAssignment,
        titleController: controller.assignmentTitleController,
        descriptionController: controller.assignmentDescriptionController,
        instructions: controller.selectedModuleAssignmentInstructions,
        errorMessage: controller.assignmentErrorMessage,
        onGenerateTap: () => _handleGenerateAssignmentTap(controller),
        onDoneTap: () => FocusScope.of(context).unfocus(),
        onBoldTap: controller.applyAssignmentBoldFormatting,
        onItalicTap: controller.applyAssignmentItalicFormatting,
        onUnderlineTap: controller.applyAssignmentUnderlineFormatting,
        onBulletListTap: controller.applyAssignmentBulletListFormatting,
        onNumberedListTap: controller.applyAssignmentNumberedListFormatting,
        onQuoteTap: controller.applyAssignmentQuoteFormatting,
        onHeadingTap: controller.applyAssignmentHeadingFormatting,
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _syncSelectedTabData(TrainingModuleController controller) async {
    if (!controller.canAccessSelectedModuleExtras ||
        _selectedTabIndex > controller.maxAccessibleTabIndex) {
      return;
    }

    if (_selectedTabIndex == 1) {
      await controller.loadDocumentForSelectedModule();
      return;
    }

    if (_selectedTabIndex == 2) {
      await controller.loadQuestionsForSelectedModule();
      return;
    }

    if (_selectedTabIndex == 3) {
      await controller.loadAssignmentForSelectedModule();
    }
  }

  Future<void> _createModuleFromDraft(
    TrainingModuleController controller,
  ) async {
    final didCreate = await controller.createModuleFromDraft();
    if (!mounted) {
      return;
    }

    if (didCreate != true) {
      final message = controller.errorMessage?.trim();
      if (message != null && message.isNotEmpty) {
        _showApiErrorSnackBar(message);
      }
      return;
    }
  }
}
