import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/widgets/app_keyboard_bottom_sheet_surface.dart';

void main() {
  testWidgets('fills the lower corners only while the keyboard is visible', (
    tester,
  ) async {
    Widget buildHost(EdgeInsets viewInsets) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(viewInsets: viewInsets),
        child: const SizedBox(
          width: 320,
          child: AppKeyboardBottomSheetSurface(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(height: 120),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildHost(EdgeInsets.zero));

    expect(
      find.byKey(const ValueKey('app-keyboard-bottom-sheet-corner-fill')),
      findsNothing,
    );

    await tester.pumpWidget(buildHost(const EdgeInsets.only(bottom: 280)));

    expect(
      find.byKey(const ValueKey('app-keyboard-bottom-sheet-corner-fill')),
      findsOneWidget,
    );
  });
}
