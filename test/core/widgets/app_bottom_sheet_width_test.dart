import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/deep_link_service.dart';
import 'package:sparrowkaizen/core/widgets/app_department_filter_strip.dart';
import 'package:sparrowkaizen/core/widgets/app_department_selection_sheet.dart';
import 'package:sparrowkaizen/core/widgets/app_keyboard_bottom_sheet_surface.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_lesson_actions_sheet.dart';
import 'package:sparrowkaizen/main.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  testWidgets('app sheets fill the available width on iPad and phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    addTearDown(AppManager.instance.resetSessionState);
    addTearDown(DeepLinkService.instance.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1024, 1366);

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final navigator = AppRouter.navigatorKey.currentState!;

    for (final viewport in [const Size(1024, 1366), const Size(390, 844)]) {
      tester.view.physicalSize = viewport;
      await tester.pumpAndSettle();

      unawaited(
        showAppDepartmentSelectionSheet(
          navigator.context,
          items: const [
            AppDepartmentFilterItem(id: 'all', name: AppStrings.categoryAll),
          ],
          selectedDepartmentId: 'all',
        ),
      );
      await tester.pumpAndSettle();
      final departmentSheet = tester.getRect(
        find.byType(AppKeyboardBottomSheetSurface),
      );
      expect(departmentSheet.left, 0);
      expect(departmentSheet.right, viewport.width);
      navigator.pop();
      await tester.pumpAndSettle();

      unawaited(
        showTrainingLibraryLessonActionsSheet(
          navigator.context,
          canEdit: true,
          isPubliclyAvailable: false,
        ),
      );
      await tester.pumpAndSettle();
      final actionsSheet = tester.getRect(
        find.byType(TrainingLibraryLessonActionsSheet),
      );
      expect(actionsSheet.left, 0);
      expect(actionsSheet.right, viewport.width);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
