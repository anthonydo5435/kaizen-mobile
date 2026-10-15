import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_button.dart';
import 'package:sparrowkaizen/core/widgets/app_overlay_close_button.dart';
import 'package:sparrowkaizen/core/widgets/app_swipe_reveal_action.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/paygrades/data/datasources/paygrade_remote_data_source.dart';
import 'package:sparrowkaizen/features/paygrades/data/repositories/paygrade_repository_impl.dart';
import 'package:sparrowkaizen/features/paygrades/domain/usecases/get_paygrades_usecase.dart';
import 'package:sparrowkaizen/features/paygrades/domain/entities/paygrade_detail.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/pages/paygrade_detail_screen.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/providers/paygrade_detail_controller.dart';

void main() {
  late _Executor executor;
  late GetPaygradesUseCase useCase;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'owner', isOwner: true, organizationUuid: 'org'),
    );
    executor = _Executor();
    useCase = GetPaygradesUseCase(
      PaygradeRepositoryImpl(
        PaygradeRemoteDataSource(apiCallExecutor: executor),
      ),
    );
  });
  tearDown(AppManager.instance.resetSessionState);

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PaygradeDetailScreen(
          paygradeId: 'job-id',
          getPaygradesUseCase: useCase,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditSheet(WidgetTester tester) async {
    await tester.drag(
      find.byType(AppSwipeRevealAction).first,
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.paygradesEditAction));
    await tester.pumpAndSettle();
  }

  Future<void> saveSheet(WidgetTester tester) async {
    final save = find.text(AppStrings.seatProfileSaveAction);
    await tester.ensureVisible(save);
    await tester.tap(save);
  }

  Future<void> openCreateSheet(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.paygradesAddLevelAction));
    await tester.pumpAndSettle();
  }

  Future<void> createFromSheet(WidgetTester tester) async {
    final create = find.text(AppStrings.seatProfileCreateAction);
    await tester.ensureVisible(create);
    await tester.tap(create);
  }

  Future<void> saveEdit(
    PaygradeDetailController controller,
    PaygradeEntry entry,
    String payRate,
  ) => controller.updatePaygrade(
    entry: entry,
    title: entry.title,
    description: entry.description,
    promotionRequirement: entry.promotionRequirement,
    payRate: payRate,
  );

  for (final ancillary in [false, true]) {
    final tab = ancillary ? 'ancillary' : 'primary';
    testWidgets(
      '$tab creation sends an optional rate and displays the new level',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        executor.pendingSave = Completer<void>();
        executor.omitCreatedPayRate = !ancillary;
        await openScreen(tester);
        if (ancillary) {
          await tester.tap(find.text(AppStrings.paygradesAncillaryTab));
          await tester.pumpAndSettle();
        }
        await openCreateSheet(tester);
        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(4));
        final rateField = tester.widget<TextField>(fields.at(1));
        expect(rateField.controller!.text, isEmpty);
        expect(rateField.cursorHeight, 15);
        expect(
          rateField.keyboardType,
          const TextInputType.numberWithOptions(decimal: true),
        );
        expect(
          tester.getTopLeft(fields.at(1)).dy,
          greaterThan(tester.getTopLeft(fields.first).dy),
        );
        expect(
          tester.getTopLeft(fields.at(1)).dy,
          lessThan(tester.getTopLeft(fields.at(2)).dy),
        );
        await tester.enterText(fields.first, 'New Designer');
        final rate = ancillary ? '0' : '12.50';
        await tester.enterText(fields.at(1), ' $rate ');
        await tester.enterText(fields.at(2), 'New responsibilities');
        await tester.ensureVisible(fields.at(3));
        await tester.enterText(fields.at(3), 'New promotion requirement');
        final create = find.byType(AppButton);
        await tester.ensureVisible(create);
        final buttonSize = tester.getSize(create);
        await tester.tap(create);
        await tester.pump();
        expect(tester.getSize(create), buttonSize);
        expect(tester.widget<AppButton>(create).onPressed, isNull);
        expect(executor.posts, hasLength(1));
        expect(executor.posts.single.endpoint, 'pay_grade/');
        expect(executor.posts.single.payload, {
          'uuid': '',
          'level': ancillary ? '2' : '3',
          'type': tab,
          'title': 'New Designer',
          'description': 'New responsibilities',
          'promotion_requirement': 'New promotion requirement',
          'position': ancillary ? 2 : 3,
          'from_sandbox': false,
          'job': 'job-id',
          'pay_rate': rate,
        });
        executor.pendingSave!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.text('ND${ancillary ? 2 : 3}: New Designer'),
          findsOneWidget,
        );
        expect(find.text('$rate/hr'), findsOneWidget);
        expect(executor.patches, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final rate in ['', '   ']) {
    testWidgets('creation omits an empty optional rate ($rate)', (
      tester,
    ) async {
      await openScreen(tester);
      await openCreateSheet(tester);
      await tester.enterText(find.byType(TextField).first, 'New Designer');
      await tester.enterText(find.byType(TextField).at(1), rate);
      await createFromSheet(tester);
      await tester.pumpAndSettle();
      expect(executor.posts, hasLength(1));
      expect(executor.posts.single.payload.containsKey('pay_rate'), isFalse);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('ND3: New Designer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('invalid creation rates and cancellation do not send a POST', (
    tester,
  ) async {
    await openScreen(tester);
    await openCreateSheet(tester);
    await tester.enterText(find.byType(TextField).first, 'New Designer');
    for (final rate in ['-1', 'abc', 'NaN', 'Infinity', '1e3']) {
      final rateField = find.byType(TextField).at(1);
      await tester.ensureVisible(rateField);
      await tester.enterText(rateField, rate);
      await createFromSheet(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paygradesPayRateInvalid), findsOneWidget);
      expect(executor.posts, isEmpty);
    }
    await tester.tap(find.byType(AppOverlayCloseButton));
    await tester.pumpAndSettle();
    expect(executor.posts, isEmpty);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('failed creation retains the optional rate for retry', (
    tester,
  ) async {
    await openScreen(tester);
    await openCreateSheet(tester);
    await tester.enterText(find.byType(TextField).first, 'New Designer');
    await tester.enterText(find.byType(TextField).at(1), '15');
    executor.failNextSave = true;
    await createFromSheet(tester);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.paygradesPayRateSaveFailed), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '15',
    );
    await createFromSheet(tester);
    await tester.pumpAndSettle();
    expect(executor.posts, hasLength(2));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('15/hr'), findsOneWidget);
  });

  testWidgets('permission loss while creating prevents a POST', (tester) async {
    await openScreen(tester);
    await openCreateSheet(tester);
    await tester.enterText(find.byType(TextField).first, 'New Designer');
    await tester.enterText(find.byType(TextField).at(1), '15');
    AppManager.instance.updateCurrentUser(
      User(uuid: 'member', organizationUuid: 'org', roles: ['team_member']),
    );
    await createFromSheet(tester);
    await tester.pumpAndSettle();
    expect(executor.posts, isEmpty);
    expect(find.text(AppStrings.paygradesPayRateSaveFailed), findsOneWidget);
  });

  testWidgets(
    'Edit prefills the rate below title and saves both in one PATCH',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      executor.pendingSave = Completer<void>();
      await openScreen(tester);
      expect(find.text('10.00/hr'), findsOneWidget);
      await tester.tap(find.text(AppStrings.paygradesRate).first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await openEditSheet(tester);
      expect(find.text(AppStrings.paygradesEditSheetTitle), findsOneWidget);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '10.00');
      expect(
        tester.widget<TextField>(fields.at(1)).keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      expect(
        tester.getTopLeft(fields.at(1)).dy,
        greaterThan(tester.getTopLeft(fields.first).dy),
      );
      expect(
        tester.getTopLeft(fields.at(1)).dy,
        lessThan(tester.getTopLeft(fields.at(2)).dy),
      );
      await tester.enterText(fields.first, 'Learning Designer');
      await tester.enterText(fields.at(1), '12.50');
      await tester.ensureVisible(find.text(AppStrings.seatProfileSaveAction));
      final save = find.byType(AppButton);
      final size = tester.getSize(save);
      await tester.tap(save);
      await tester.pump();
      expect(tester.getSize(save), size);
      expect(tester.widget<AppButton>(save).onPressed, isNull);
      expect(find.text('10.00/hr'), findsOneWidget);
      expect(executor.patches, hasLength(1));
      expect(executor.patches.single.endpoint, 'pay_grade/$_entryId/');
      expect(executor.patches.single.payload, {
        'uuid': _entryId,
        'title': 'Learning Designer',
        'description': 'Primary responsibilities',
        'promotion_requirement': 'Complete training',
        'pay_rate': '12.50',
      });
      executor.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(AppStrings.paygradesEditSheetTitle), findsNothing);
      expect(find.text('12.50/hr'), findsOneWidget);
      expect(find.text('20.00/hr'), findsOneWidget);
      expect(find.text('LD1: Learning Designer'), findsOneWidget);
      expect(find.text('Primary responsibilities'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid values and cancelling do not write', (tester) async {
    await openScreen(tester);
    await openEditSheet(tester);
    for (final value in ['', '-10', 'abc', 'NaN', 'Infinity', '1e3']) {
      await tester.ensureVisible(find.byType(TextField).at(1));
      await tester.enterText(find.byType(TextField).at(1), value);
      await saveSheet(tester);
      await tester.pump();
      expect(find.text(AppStrings.paygradesPayRateInvalid), findsOneWidget);
      expect(executor.patches, isEmpty);
    }
    await tester.ensureVisible(find.byType(TextField).at(1));
    await tester.enterText(find.byType(TextField).at(1), '99');
    await tester.tap(find.byType(AppOverlayCloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text(AppStrings.paygradesEditSheetTitle), findsNothing);
    expect(find.text('10.00/hr'), findsOneWidget);
    expect(executor.patches, isEmpty);
  });

  testWidgets('failed saves retain the draft and can retry', (tester) async {
    executor.failNextSave = true;
    await openScreen(tester);
    await openEditSheet(tester);
    await tester.enterText(find.byType(TextField).at(1), '0');
    await saveSheet(tester);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.paygradesPayRateSaveFailed), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '0',
    );
    expect(find.text('10.00/hr'), findsOneWidget);
    await saveSheet(tester);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text(AppStrings.paygradesEditSheetTitle), findsNothing);
    expect(find.text('0/hr'), findsOneWidget);
    expect(executor.patches, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ancillary rates save to the ancillary entry', (tester) async {
    await openScreen(tester);
    await tester.tap(find.text(AppStrings.paygradesAncillaryTab));
    await tester.pumpAndSettle();
    await openEditSheet(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '30.00',
    );
    await tester.enterText(find.byType(TextField).at(1), '35');
    await saveSheet(tester);
    await tester.pumpAndSettle();
    expect(executor.patches.single.endpoint, 'pay_grade/ancillary-entry/');
    expect(executor.patches.single.payload, {
      'uuid': 'ancillary-entry',
      'title': 'Lead Designer',
      'description': 'Primary responsibilities',
      'promotion_requirement': 'Complete training',
      'pay_rate': '35',
    });
    expect(find.text('35/hr'), findsOneWidget);
    await tester.tap(find.text(AppStrings.paygradesPrimaryTab));
    await tester.pumpAndSettle();
    expect(find.text('10.00/hr'), findsOneWidget);
  });

  testWidgets('pay rate taps stay read-only on collapsed and expanded cards', (
    tester,
  ) async {
    await openScreen(tester);
    await tester.tap(find.text('10.00/hr'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    await tester.drag(
      find.byType(AppSwipeRevealAction).first,
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.paygradesShowMoreAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.paygradesRate).first);
    await tester.tap(find.text('10.00/hr'));
    await tester.pumpAndSettle();
    expect(find.text('Primary responsibilities'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(executor.patches, isEmpty);
  });

  for (final rate in ['10.00', '']) {
    testWidgets('title edits preserve an unchanged pay rate ($rate)', (
      tester,
    ) async {
      executor.primaryPayRate = rate;
      await openScreen(tester);
      await openEditSheet(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        rate,
      );
      await tester.enterText(find.byType(TextField).first, 'Updated Designer');
      await saveSheet(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paygradesEditSheetTitle), findsNothing);
      expect(find.text('UD1: Updated Designer'), findsOneWidget);
      expect(executor.patches.single.payload.containsKey('pay_rate'), isFalse);
      expect(find.text(AppStrings.paygradesHourlyRate(rate)), findsOneWidget);
    });
  }

  testWidgets('permission loss while editing prevents a save', (tester) async {
    await openScreen(tester);
    await openEditSheet(tester);
    await tester.enterText(find.byType(TextField).at(1), '42');
    AppManager.instance.updateCurrentUser(
      User(uuid: 'member', organizationUuid: 'org', roles: ['team_member']),
    );
    await tester.pumpAndSettle();
    await saveSheet(tester);
    await tester.pumpAndSettle();
    expect(executor.patches, isEmpty);
    expect(find.text(AppStrings.paygradesPayRateSaveFailed), findsOneWidget);
    expect(find.text(AppStrings.paygradesEditSheetTitle), findsOneWidget);
    await tester.tap(find.byType(AppOverlayCloseButton));
    await tester.pumpAndSettle();
  });

  test(
    'a pending save targets its original tab and blocks duplicate writes',
    () async {
      final controller = PaygradeDetailController(useCase);
      addTearDown(controller.dispose);
      await controller.initialize('job-id');
      final entry = controller.detail!.payGrades.first;
      executor.pendingSave = Completer<void>();
      final save = saveEdit(controller, entry, '42');
      await expectLater(saveEdit(controller, entry, '43'), throwsStateError);
      await controller.selectTab(PaygradeDetailTab.ancillary);
      executor.pendingSave!.complete();
      await save;
      expect(controller.detail!.payGrades.single.payRate, '30.00');
      await controller.selectTab(PaygradeDetailTab.primary);
      expect(controller.detail!.payGrades.first.payRate, '42');
      expect(executor.patches, hasLength(1));
      expect(controller.isUpdatingPaygrade, isFalse);
    },
  );

  test(
    'permission loss and child organisations block writes in the controller',
    () async {
      final controller = PaygradeDetailController(useCase);
      addTearDown(controller.dispose);
      await controller.initialize('job-id');
      final entry = controller.detail!.payGrades.first;
      AppManager.instance.updateCurrentUser(
        User(uuid: 'member', organizationUuid: 'org', roles: ['team_member']),
      );
      expect(controller.canEditPayRate(entry), isFalse);
      await expectLater(saveEdit(controller, entry, '42'), throwsStateError);
      AppManager.instance.updateCurrentUser(
        User(uuid: 'owner', isOwner: true, organizationUuid: 'org'),
      );
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            {'uuid': 'org', 'name': 'Child', 'type': 'child'},
          ]),
          200,
        ),
      );
      addTearDown(client.close);
      await http.runWithClient(
        () => AppManager.instance.fetchOrganizations(
          forceRefresh: true,
          requireSuccess: true,
        ),
        () => client,
      );
      expect(AppManager.instance.currentOrganization?.type, 'child');
      expect(controller.canEditPayRate(entry), isFalse);
      await expectLater(saveEdit(controller, entry, '42'), throwsStateError);
      expect(executor.patches, isEmpty);
    },
  );

  test(
    'invalid direct saves are rejected and disposal ignores a pending result',
    () async {
      final controller = PaygradeDetailController(useCase);
      await controller.initialize('job-id');
      final entry = controller.detail!.payGrades.first;
      await expectLater(saveEdit(controller, entry, '-5'), throwsArgumentError);
      expect(executor.patches, isEmpty);
      executor.pendingSave = Completer<void>();
      final save = saveEdit(controller, entry, '15');
      controller.dispose();
      executor.pendingSave!.complete();
      await expectLater(save, completes);
    },
  );
}

const _entryId = '09d256d0-1ef4-47f5-b973-c2d824009bcc';

class _Executor extends ApiCallExecutor {
  final patches = <({String endpoint, Map<String, dynamic> payload})>[];
  final posts = <({String endpoint, Map<String, dynamic> payload})>[];
  Completer<void>? pendingSave;
  bool failNextSave = false;
  bool omitCreatedPayRate = false;
  String primaryPayRate = '10.00';

  @override
  Future<Response> processApi<Response>({
    required ApiCallType apiCallType,
    required String endpoint,
    required Response Function(dynamic json) decoder,
    Map<String, dynamic>? parameters,
    Map<String, String>? headers,
    String? authToken,
    bool allowAutoRefresh = true,
    bool allowConflictRetry = true,
    bool invalidateCacheBeforeRequest = false,
  }) async {
    if (apiCallType == ApiCallType.post && endpoint == 'pay_grade/') {
      posts.add((endpoint: endpoint, payload: parameters!));
      if (failNextSave) {
        failNextSave = false;
        throw StateError('offline');
      }
      await pendingSave?.future;
      final response = <String, dynamic>{
        ...parameters,
        'uuid': 'created-entry',
      };
      if (omitCreatedPayRate) {
        response.remove('pay_rate');
      }
      return decoder(response);
    }
    if (apiCallType == ApiCallType.patch) {
      patches.add((endpoint: endpoint, payload: parameters!));
      if (failNextSave) {
        failNextSave = false;
        throw StateError('offline');
      }
      await pendingSave?.future;
      return decoder(null);
    }
    if (endpoint.endsWith('/public-links/paygrades/')) {
      return decoder({'active': false});
    }
    if (endpoint == 'job/job-id/pay_grades/') {
      final ancillary = parameters!['type'] == 'ancillary';
      return decoder({
        'uuid': 'job-id',
        'title': 'Designer',
        'department': 'Operations',
        'paygrade_unit': 'hr',
        'pay_grades': [
          {
            'uuid': ancillary ? 'ancillary-entry' : _entryId,
            'title': ancillary
                ? 'Lead Designer'
                : 'Paygrade: Instructional Designer',
            'type': ancillary ? 'ancillary' : 'primary',
            'pay_rate': ancillary ? '30.00' : primaryPayRate,
            'level': 1,
            'description': 'Primary responsibilities',
            'promotion_requirement': 'Complete training',
          },
          if (!ancillary)
            {
              'uuid': 'second-entry',
              'title': 'Senior Designer',
              'pay_rate': '20.00',
              'level': 2,
            },
        ],
      });
    }
    throw StateError('Unexpected request: $apiCallType $endpoint');
  }
}
