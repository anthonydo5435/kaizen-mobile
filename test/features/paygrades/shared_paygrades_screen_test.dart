import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_swipe_reveal_action.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/paygrades/data/models/shared_paygrades_content_model.dart';
import 'package:sparrowkaizen/features/paygrades/domain/entities/shared_paygrades_content.dart';
import 'package:sparrowkaizen/features/paygrades/domain/usecases/get_paygrades_usecase.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/pages/shared_paygrades_screen.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/pages/shared_paygrades_details_screen.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/widgets/paygrade_listing_card.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

import 'shared_paygrades_fixture.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.updateCurrentUser(User(isOwner: true));
  });
  tearDown(() => AppManager.instance.updateCurrentUser(null));

  testWidgets(
    'shared link opens expanded read-only cards without pay rate rows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final json = sharedPaygradesJson();
      (json['content'] as Map<String, dynamic>)['title'] =
          'P-ORG Department Lead With A Very Long Shared Paygrade Title';
      final useCase = _ScreenUseCase(
        SharedPaygradesContentModel.fromApiJson(json),
      );
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: SharedPaygradesScreen(
            publicId: 'shared-id',
            getPaygradesUseCase: useCase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(useCase.ids, ['shared-id']);
      expect(find.text(AppStrings.paygradesDetailsTitle), findsOneWidget);
      expect(find.byType(PaygradeListingCard), findsNothing);
      expect(find.byType(SharedPaygradesDetailsScreen), findsOneWidget);
      expect(find.text(AppStrings.paygradesPrimaryTab), findsOneWidget);
      expect(find.text(AppStrings.paygradesAncillaryTab), findsOneWidget);
      expect(find.text('P-ORG-DEPT'), findsOneWidget);
      expect(
        Navigator.of(
          tester.element(find.byType(SharedPaygradesDetailsScreen)),
        ).canPop(),
        isFalse,
      );
      expect(find.text('90.00'), findsNothing);
      expect(find.textContaining('Pay Rate'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      expect(find.text('Primary responsibilities'), findsOneWidget);
      expect(find.text('Complete training'), findsOneWidget);
      expect(find.text(AppStrings.paygradesGenerateWithAiAction), findsNothing);
      expect(find.text(AppStrings.paygradesAddLevelAction), findsNothing);
      expect(find.text(AppStrings.paygradesEditAction), findsNothing);
      expect(find.byType(AppSwipeRevealAction), findsNothing);
      expect(find.byTooltip(AppStrings.shareAction), findsNothing);

      await tester.tap(find.text(AppStrings.paygradesAncillaryTab));
      await tester.pumpAndSettle();
      expect(find.text('50.00'), findsNothing);
      expect(find.text('90.00'), findsNothing);
      expect(find.textContaining('Pay Rate'), findsNothing);
      expect(find.text(AppStrings.paygradesEmptyDescription), findsOneWidget);
      expect(
        find.text(AppStrings.paygradesEmptyPromotionRequirement),
        findsOneWidget,
      );
      expect(find.text(AppStrings.paygradesEditAction), findsNothing);
      await tester.tap(find.text(AppStrings.paygradesPrimaryTab));
      await tester.pumpAndSettle();
      expect(find.text('Primary responsibilities'), findsOneWidget);
      expect(find.text('Complete training'), findsOneWidget);
      expect(useCase.ids, ['shared-id']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('excluded rates and empty tabs render correctly', (tester) async {
    final json = sharedPaygradesJson(includesPayRates: false);
    (json['content'] as Map<String, dynamic>)['ancillary'] = <dynamic>[];
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: SharedPaygradesScreen(
          publicId: 'shared-id',
          getPaygradesUseCase: _ScreenUseCase(
            SharedPaygradesContentModel.fromApiJson(json),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('90.00'), findsNothing);
    expect(find.textContaining('Pay Rate'), findsNothing);
    await tester.tap(find.text(AppStrings.paygradesAncillaryTab));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.paygradesNoDetailItemsFound), findsOneWidget);
  });

  testWidgets('loading, error and retry stay within the shared flow', (
    tester,
  ) async {
    final content = SharedPaygradesContentModel.fromApiJson(
      sharedPaygradesJson(),
    );
    final pending = Completer<SharedPaygradesContent>();
    final useCase = _ScreenUseCase(content)..pending = pending.future;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: SharedPaygradesScreen(
          publicId: 'shared-id',
          getPaygradesUseCase: useCase,
        ),
      ),
    );
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('expired link'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sharedPaygradesUnableToLoad), findsOneWidget);
    useCase.pending = null;
    await tester.tap(find.text(AppStrings.actionRetry));
    await tester.pumpAndSettle();
    expect(find.byType(PaygradeListingCard), findsNothing);
    expect(find.byType(SharedPaygradesDetailsScreen), findsOneWidget);
    expect(find.text('P-ORG Dept Lead (Copy)-1'), findsOneWidget);
    expect(find.text(AppStrings.paygradesPrimaryTab), findsOneWidget);
    expect(find.text('90.00'), findsNothing);
    expect(find.text('Primary responsibilities'), findsOneWidget);
    expect(useCase.ids, ['shared-id', 'shared-id']);
  });

  for (final isAuthenticated in [false, true]) {
    testWidgets(
      'cold-start back opens the appropriate app entry ($isAuthenticated)',
      (tester) async {
        if (isAuthenticated) await AppPreference.setAuthToken('token');
        String? destination;
        await tester.pumpWidget(
          MaterialApp(
            home: SharedPaygradesScreen(
              publicId: 'shared-id',
              getPaygradesUseCase: _ScreenUseCase(
                SharedPaygradesContentModel.fromApiJson(sharedPaygradesJson()),
              ),
            ),
            onGenerateRoute: (settings) {
              destination = settings.name;
              return MaterialPageRoute<void>(builder: (_) => const Scaffold());
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        expect(
          destination,
          isAuthenticated
              ? AppRouter.defaultAuthenticatedRouteName
              : AppRouter.login,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _ScreenUseCase extends Fake implements GetPaygradesUseCase {
  _ScreenUseCase(this.content);
  final SharedPaygradesContent content;
  final List<String> ids = [];
  Future<SharedPaygradesContent>? pending;

  @override
  Future<SharedPaygradesContent> getSharedPaygrades(String publicId) {
    ids.add(publicId);
    return pending ?? Future.value(content);
  }
}
