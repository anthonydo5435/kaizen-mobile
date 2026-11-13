// ignore_for_file: depend_on_referenced_packages

import 'package:test/test.dart';
import 'package:sparrowkaizen/features/training/presentation/models/view_training_tab_access.dart';

void main() {
  for (final canView in [false, true]) {
    test(
      'Quiz and Assignment require viewing permission (can view: $canView)',
      () {
        for (final index in [0, 1, 2, 3]) {
          expect(
            isTrainingViewerTabEnabled(
              canViewQuizAndAssignment: canView,
              tabIndex: index,
            ),
            index < 2 || canView,
          );
        }
      },
    );

    test('normalizes restricted selections (can view: $canView)', () {
      for (final index in [2, 3]) {
        expect(
          normalizeTrainingViewerTabIndex(
            canViewQuizAndAssignment: canView,
            tabIndex: index,
          ),
          canView ? index : 0,
        );
      }
    });
  }

  test('only Video is available before a lesson is selected', () {
    for (final canView in [false, true]) {
      expect(
        maxTrainingTabIndex(
          hasSelectedModule: false,
          canViewQuizAndAssignment: canView,
        ),
        0,
      );
    }
  });

  test('indices outside the four viewer tabs are disabled', () {
    for (final index in [-1, 4, 999]) {
      expect(
        isTrainingViewerTabEnabled(
          canViewQuizAndAssignment: true,
          tabIndex: index,
        ),
        isFalse,
      );
    }
  });

  test('invalid indices return to Video', () {
    for (final index in [-1, 4, 999]) {
      expect(
        normalizeTrainingViewerTabIndex(
          canViewQuizAndAssignment: true,
          tabIndex: index,
        ),
        0,
      );
    }
  });
}
