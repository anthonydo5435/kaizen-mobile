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
import 'package:sparrowkaizen/features/seat_profile/domain/entities/department.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_detail.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/seat_profile_detail_screen.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/shared_seat_profile_screen.dart';

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

  testWidgets('details load the link before opening the card share dialog', (
    tester,
  ) async {
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
    expect(useCase.calls, ['GET actual-job']);
    expect(
      find.ancestor(
        of: find.byTooltip(AppStrings.shareAction),
        matching: find.byType(AppBar),
      ),
      findsNothing,
    );

    await tester.tap(find.byTooltip(AppStrings.shareAction));
    await tester.pump();
    expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.shareCreateLinkAction), findsNothing);
    pending.complete(_existingLink);
    await tester.pumpAndSettle();
    expect(find.text(_existingLink), findsOneWidget);
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
    expect(useCase.calls, [
      'GET actual-job',
      'DELETE actual-job',
      'POST actual-job',
    ]);
    expect(tester.takeException(), isNull);
  });

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
    expect(useCase.calls, ['GET actual-job', 'GET actual-job']);
  });

  testWidgets('shared and unprivileged details never expose link management', (
    tester,
  ) async {
    final useCase = _UseCase();
    await tester.pumpWidget(
      MaterialApp(
        home: SharedSeatProfileScreen(
          publicId: 'public-id',
          getSeatProfilesUseCase: useCase,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip(AppStrings.shareAction), findsNothing);
    expect(useCase.calls, isEmpty);
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', isOwner: false, roles: ['owner', 'csuite']),
    );
    await tester.pumpWidget(_app(useCase));
    await tester.pumpAndSettle();
    expect(find.byTooltip(AppStrings.shareAction), findsNothing);
    expect(useCase.calls, isEmpty);
  });
}

Widget _app(_UseCase useCase) => MaterialApp(
  home: SeatProfileDetailScreen(
    seatId: 'lookup-id',
    getSeatProfilesUseCase: useCase,
  ),
);

const _existingLink = 'https://dev.kaizenteams.ai/shared/seat-profile/existing';
const _createdLink = 'https://dev.kaizenteams.ai/shared/seat-profile/created';
const _detail = SeatProfileDetail(
  id: 'lookup-id',
  actualId: 'actual-job',
  title: 'Admin Controller',
  department: Department(id: 'department', name: 'Operations'),
  paygradeUnit: 'hr',
  categories: [],
);

class _UseCase extends Fake implements GetSeatProfilesUseCase {
  Future<String?>? pendingLink;
  Object? loadFailure;
  final calls = <String>[];

  @override
  Future<SeatProfileDetail> getSeatProfileDetail(String seatId) async =>
      _detail;

  @override
  Future<SeatProfileDetail> getSharedSeatProfileDetail(String publicId) async =>
      _detail;

  @override
  Future<String?> getSeatProfilePublicLink(String seatId) async {
    calls.add('GET $seatId');
    if (loadFailure != null) throw loadFailure!;
    return pendingLink;
  }

  @override
  Future<String> createSeatProfilePublicLink(String seatId) async {
    calls.add('POST $seatId');
    return _createdLink;
  }

  @override
  Future<void> deleteSeatProfilePublicLink(String seatId) async {
    calls.add('DELETE $seatId');
  }
}
