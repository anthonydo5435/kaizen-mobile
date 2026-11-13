const int trainingViewerTabCount = 4;

int maxTrainingTabIndex({
  required bool hasSelectedModule,
  required bool canViewQuizAndAssignment,
}) => !hasSelectedModule
    ? 0
    : (canViewQuizAndAssignment ? trainingViewerTabCount - 1 : 1);

/// Tab visibility is independent of permission to edit the lesson.
bool isTrainingViewerTabEnabled({
  required bool canViewQuizAndAssignment,
  required int tabIndex,
}) {
  return tabIndex >= 0 &&
      tabIndex <=
          maxTrainingTabIndex(
            hasSelectedModule: true,
            canViewQuizAndAssignment: canViewQuizAndAssignment,
          );
}

int normalizeTrainingViewerTabIndex({
  required bool canViewQuizAndAssignment,
  required int tabIndex,
}) {
  if (isTrainingViewerTabEnabled(
    canViewQuizAndAssignment: canViewQuizAndAssignment,
    tabIndex: tabIndex,
  )) {
    return tabIndex;
  }

  return 0;
}
