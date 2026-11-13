import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/paygrades/domain/entities/paygrade_detail.dart';
import 'package:sparrowkaizen/features/paygrades/domain/usecases/get_paygrades_usecase.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/pages/paygrade_detail_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'owner', isOwner: true, organizationUuid: 'org'),
    );
  });
  tearDown(() => AppManager.instance.resetSessionState());

  testWidgets(
    'fetches on load and retains created links across paygrade tabs',
    (tester) async {
      final pending = Completer<String?>();
      final useCase = _UseCase()..pendingLink = pending.future;
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(_app(useCase));
      await tester.pumpAndSettle();
      expect(useCase.linkCalls, ['GET actual-job']);

      await tester.tap(find.byTooltip(AppStrings.shareAction));
      await tester.pump();
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      expect(find.text(AppStrings.shareCreateLinkAction), findsNothing);
      pending.complete(_existingLink);
      await tester.pumpAndSettle();
      expect(find.text(_existingLink), findsOneWidget);
      expect(
        find.text(
          AppStrings.sharePublicLinkDescription(
            AppStrings.sharePaygradesContent,
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(AppStrings.shareCopyLinkAction));
      await tester.pumpAndSettle();
      expect(copied, _existingLink);

      await tester.tap(find.text(AppStrings.shareRevokeLinkAction));
      await tester.pumpAndSettle();
      expect(find.text(_existingLink), findsNothing);
      expect(find.byTooltip(AppStrings.shareCopyLinkAction), findsNothing);
      await tester.tap(find.text(AppStrings.shareCreateLinkAction));
      await tester.pumpAndSettle();
      expect(find.text(_createdLink), findsOneWidget);

      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.paygradesAncillaryTab));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AppStrings.shareAction));
      await tester.pumpAndSettle();
      expect(find.text(_createdLink), findsOneWidget);
      expect(useCase.detailTypes, ['primary', 'ancillary']);
      expect(useCase.linkCalls, [
        'GET actual-job',
        'DELETE actual-job',
        'POST actual-job',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed initial lookup retries before allowing creation', (
    tester,
  ) async {
    final useCase = _UseCase()..loadFailure = StateError('offline');
    await tester.pumpWidget(_app(useCase));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.shareAction));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.shareLoadLinkFailed), findsOneWidget);
    expect(find.text(AppStrings.shareCreateLinkAction), findsNothing);
    useCase.loadFailure = null;
    await tester.tap(find.text(AppStrings.actionRetry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.shareCreateLinkAction), findsOneWidget);
    expect(find.byTooltip(AppStrings.shareCopyLinkAction), findsNothing);
    expect(useCase.linkCalls, ['GET actual-job', 'GET actual-job']);
  });

  testWidgets('role-only owners do not fetch or expose public links', (
    tester,
  ) async {
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', isOwner: false, roles: ['owner', 'csuite']),
    );
    final useCase = _UseCase();
    await tester.pumpWidget(_app(useCase));
    await tester.pumpAndSettle();
    expect(find.byTooltip(AppStrings.shareAction), findsNothing);
    expect(useCase.linkCalls, isEmpty);
  });
}

Widget _app(_UseCase useCase) => MaterialApp(
  home: PaygradeDetailScreen(
    paygradeId: 'lookup-id',
    getPaygradesUseCase: useCase,
  ),
);

const _existingLink = 'https://dev.kaizenteams.ai/shared/paygrades/existing';
const _createdLink = 'https://dev.kaizenteams.ai/shared/paygrades/created';
const _detail = PaygradeDetail(
  id: 'actual-job',
  title: 'Admin Controller',
  department: 'Operations',
  paygradeUnit: 'hr',
  payGrades: [],
);

class _UseCase extends Fake implements GetPaygradesUseCase {
  Future<String?>? pendingLink;
  Object? loadFailure;
  final linkCalls = <String>[];
  final detailTypes = <String>[];

  @override
  Future<PaygradeDetail> getPaygradeDetail({
    required String paygradeId,
    required String type,
  }) async {
    detailTypes.add(type);
    return _detail;
  }

  @override
  Future<String?> getPaygradesPublicLink(String jobId) async {
    linkCalls.add('GET $jobId');
    if (loadFailure != null) throw loadFailure!;
    return pendingLink;
  }

  @override
  Future<String> createPaygradesPublicLink(String jobId) async {
    linkCalls.add('POST $jobId');
    return _createdLink;
  }

  @override
  Future<void> deletePaygradesPublicLink(String jobId) async {
    linkCalls.add('DELETE $jobId');
  }
}
