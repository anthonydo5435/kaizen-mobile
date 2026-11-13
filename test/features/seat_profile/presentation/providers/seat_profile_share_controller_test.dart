import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/providers/seat_profile_share_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _UseCase useCase;
  late SeatProfileShareController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(User(uuid: 'owner', isOwner: true));
    useCase = _UseCase();
    controller = SeatProfileShareController(
      useCase,
      seatId: 'job-id',
      departmentId: 'dept',
    );
  });
  tearDown(() {
    controller.dispose();
    AppManager.instance.resetSessionState();
  });

  test('loads existing links and enables revocation', () async {
    useCase.existing = _link;
    await controller.loadLink();
    expect(controller.link, _link);
    expect(controller.canRevoke, isTrue);
    expect(controller.canCreate, isFalse);
    expect(useCase.calls, ['GET job-id']);
  });

  test(
    'create and revoke update state only after successful requests',
    () async {
      await controller.loadLink();
      expect(controller.canCreate, isTrue);
      final pendingCreate = Completer<String>();
      useCase.pendingCreate = pendingCreate.future;
      final creation = controller.createLink();
      await controller.createLink();
      expect(controller.isWorking, isTrue);
      expect(controller.link, isNull);
      pendingCreate.complete(_link);
      await creation;
      expect(controller.link, _link);
      final pendingDelete = Completer<void>();
      useCase.pendingDelete = pendingDelete.future;
      final deletion = controller.revokeLink();
      await controller.revokeLink();
      expect(controller.link, _link);
      pendingDelete.complete();
      await deletion;
      expect(controller.link, isNull);
      expect(controller.canCreate, isTrue);
      expect(useCase.calls, ['GET job-id', 'POST job-id', 'DELETE job-id']);
    },
  );

  test('failed lookup blocks creation until retry succeeds', () async {
    useCase.failure = StateError('offline');
    await controller.loadLink();
    expect(controller.errorMessage, AppStrings.shareLoadLinkFailed);
    await controller.createLink();
    expect(useCase.calls, ['GET job-id']);
    useCase.failure = null;
    await controller.loadLink();
    expect(controller.canCreate, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('failed writes keep the previous state available for retry', () async {
    await controller.loadLink();
    useCase.failure = StateError('failed');
    await controller.createLink();
    expect(controller.link, isNull);
    expect(controller.errorMessage, AppStrings.shareCreateLinkFailed);
    useCase.failure = null;
    await controller.createLink();
    useCase.failure = StateError('failed');
    await controller.revokeLink();
    expect(controller.link, _link);
    expect(controller.errorMessage, AppStrings.shareRevokeLinkFailed);
  });

  test('permissions are checked again before writing', () async {
    await controller.loadLink();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', isOwner: false, roles: const ['owner', 'csuite']),
    );
    await controller.createLink();
    expect(controller.canCreate, isFalse);
    expect(useCase.calls, ['GET job-id']);
  });

  test('role-only owners cannot load public links', () async {
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', roles: ['owner', 'csuite']),
    );
    await controller.loadLink();
    expect(controller.canManage, isFalse);
    expect(useCase.calls, isEmpty);
  });

  test('losing the owner flag blocks cached link actions', () async {
    useCase.existing = _link;
    await controller.loadLink();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', isOwner: false, roles: ['owner', 'csuite']),
    );
    await controller.loadLink();
    await controller.revokeLink();
    expect(await controller.copyLink(), isFalse);
    expect(controller.canRevoke, isFalse);
    expect(useCase.calls, ['GET job-id']);
  });

  test(
    'finishing a request after disposal does not notify listeners',
    () async {
      final closingController = SeatProfileShareController(
        useCase,
        seatId: 'job-id',
        departmentId: 'dept',
      );
      final pending = Completer<String?>();
      useCase.pendingGet = pending.future;
      final loading = closingController.loadLink();
      closingController.dispose();
      pending.complete(_link);
      await expectLater(loading, completes);
    },
  );
}

const _link = 'https://dev.kaizenteams.ai/shared/seat-profile/public-id';

class _UseCase extends Fake implements GetSeatProfilesUseCase {
  String? existing;
  Object? failure;
  Future<String?>? pendingGet;
  Future<String>? pendingCreate;
  Future<void>? pendingDelete;
  final calls = <String>[];

  @override
  Future<String?> getSeatProfilePublicLink(String seatId) async {
    calls.add('GET $seatId');
    if (failure != null) throw failure!;
    return pendingGet ?? existing;
  }

  @override
  Future<String> createSeatProfilePublicLink(String seatId) async {
    calls.add('POST $seatId');
    if (failure != null) throw failure!;
    return pendingCreate ?? _link;
  }

  @override
  Future<void> deleteSeatProfilePublicLink(String seatId) async {
    calls.add('DELETE $seatId');
    if (failure != null) throw failure!;
    await pendingDelete;
  }
}
