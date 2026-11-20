import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/deep_link_service.dart';
import 'package:sparrowkaizen/main.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  testWidgets(
    'sheet taps dismiss the keyboard and preserve input and sheet actions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppPreference.init();
      AppManager.instance.resetSessionState();
      addTearDown(AppManager.instance.resetSessionState);
      addTearDown(DeepLinkService.instance.dispose);
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final navigator = AppRouter.navigatorKey.currentState!;
      const pageTarget = ValueKey('page-target');
      const firstInput = ValueKey('first-input');
      const secondInput = ValueKey('second-input');
      const blankArea = ValueKey('sheet-blank-area');
      var actionCount = 0;
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Column(
                children: [
                  TextField(),
                  Text('Page heading', key: pageTarget),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.byKey(pageTarget));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      unawaited(
        showModalBottomSheet<void>(
          context: navigator.context,
          enableDrag: false,
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Sheet heading'),
              const TextField(key: firstInput),
              const TextField(key: secondInput),
              const ColoredBox(
                key: blankArea,
                color: Colors.transparent,
                child: SizedBox(height: 96),
              ),
              TextButton(
                onPressed: () => actionCount++,
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(firstInput), 'Draft text');
      await tester.pump();

      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(blankArea)),
      );
      await drag.moveBy(const Offset(0, 30));
      await drag.moveBy(const Offset(0, -30));
      await drag.up();
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(secondInput));
      await tester.pump();
      final secondEditor = find.descendant(
        of: find.byKey(secondInput),
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(secondEditor).focusNode.hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(blankArea));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(find.byKey(firstInput));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(actionCount, 1);
      expect(find.text('Draft text'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
