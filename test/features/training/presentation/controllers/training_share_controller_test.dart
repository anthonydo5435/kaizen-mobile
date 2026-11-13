import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/lms_public_link.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_share_controller.dart';

import '../../fixtures/training_share_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShareRepository repository;
  late TrainingShareController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(User(uuid: 'owner', isOwner: true));
    repository = ShareRepository();
    controller = TrainingShareController(
      repository,
      seatProfileId: 'job-id',
      descriptionId: 'description-id',
      lessons: shareLessons(),
    );
    await controller.loadLink();
  });

  tearDown(() {
    controller.dispose();
    AppManager.instance.resetSessionState();
  });

  test('defaults to all and sends only selected lesson UUIDs', () async {
    expect(controller.allSelected, isTrue);
    expect(controller.selectedCount, 3);
    controller.selectLesson('lesson-1', false);
    controller.selectLesson('unknown-lesson', true);
    expect(controller.selectedCount, 2);
    expect(controller.allSelected, isFalse);
    await controller.createLink();
    expect(repository.requests.single.descriptionId, 'description-id');
    expect(repository.requests.single.ids, ['lesson-0', 'lesson-2']);
    expect(controller.link, createdLmsLink);
  });

  test('loads an existing link and prevents creating it again', () async {
    repository.existingLink = LmsPublicLink(
      url: createdLmsLink,
      trainingModuleUuids: ['lesson-1'],
    );
    await controller.loadLink();
    expect(controller.link, createdLmsLink);
    expect(controller.hasLoaded, isTrue);
    expect(controller.canCreate, isFalse);
    controller.prepareLessons(shareLessons(5));
    await controller.createLink();
    expect(controller.link, createdLmsLink);
    expect(repository.requests, isEmpty);
  });

  test(
    'pending lookup prevents duplicate GETs and premature creation',
    () async {
      final pending = Completer<LmsPublicLink?>();
      repository.pendingLoad = pending.future;
      final loadsBefore = repository.loadRequests.length;
      final loading = controller.loadLink();
      await controller.loadLink();
      await controller.createLink();
      expect(controller.isLoading, isTrue);
      expect(controller.canCreate, isFalse);
      expect(repository.loadRequests.length, loadsBefore + 1);
      expect(repository.requests, isEmpty);
      pending.complete(null);
      await loading;
      expect(controller.canCreate, isTrue);
    },
  );

  test('failed lookup blocks creation until a successful retry', () async {
    repository.loadFailure = StateError('offline');
    await controller.loadLink();
    await controller.createLink();
    expect(controller.hasLoaded, isFalse);
    expect(controller.errorMessage, AppStrings.shareLoadLinkFailed);
    expect(repository.requests, isEmpty);
    repository.loadFailure = null;
    await controller.loadLink();
    expect(controller.errorMessage, isNull);
    expect(controller.canCreate, isTrue);
  });

  test('GET completion after closing the screen never notifies', () async {
    final closing = TrainingShareController(
      repository,
      seatProfileId: 'job-id',
      descriptionId: 'description-id',
    );
    final pending = Completer<LmsPublicLink?>();
    repository.pendingLoad = pending.future;
    final loading = closing.loadLink();
    closing.dispose();
    pending.complete(
      LmsPublicLink(url: createdLmsLink, trainingModuleUuids: ['lesson-0']),
    );
    await expectLater(loading, completes);
  });

  test(
    'select all toggles everything and blocks an empty submission',
    () async {
      controller.selectAll(false);
      expect(controller.selectedCount, 0);
      expect(controller.canCreate, isFalse);
      await controller.createLink();
      expect(repository.requests, isEmpty);
      controller.selectAll(true);
      expect(controller.allSelected, isTrue);
      await controller.createLink();
      expect(repository.requests.single.ids, [
        'lesson-0',
        'lesson-1',
        'lesson-2',
      ]);
    },
  );

  test(
    'locks selection and duplicate submissions until POST completes',
    () async {
      final pending = Completer<LmsPublicLink>();
      repository.pending = pending.future;
      final request = controller.createLink();
      controller.selectAll(false);
      controller.selectLesson('lesson-1', false);
      await controller.createLink();
      expect(controller.isWorking, isTrue);
      expect(controller.selectedCount, 3);
      expect(repository.requests, hasLength(1));
      pending.complete(
        LmsPublicLink(url: createdLmsLink, trainingModuleUuids: ['lesson-0']),
      );
      await request;
      expect(controller.isWorking, isFalse);
      expect(controller.link, createdLmsLink);
      await controller.createLink();
      expect(repository.requests, hasLength(1));
    },
  );

  test('failed requests preserve selection and allow retry', () async {
    controller.selectLesson('lesson-1', false);
    repository.failure = StateError('offline');
    await controller.createLink();
    expect(controller.errorMessage, AppStrings.shareCreateLinkFailed);
    expect(controller.isSelected('lesson-1'), isFalse);
    expect(controller.link, isNull);
    expect(controller.canCreate, isTrue);
    repository.failure = null;
    await controller.createLink();
    expect(controller.errorMessage, isNull);
    expect(controller.link, createdLmsLink);
    expect(repository.requests.last.ids, ['lesson-0', 'lesson-2']);
  });

  test(
    'revoke keeps the link until success and prevents duplicate writes',
    () async {
      controller.selectLesson('lesson-1', false);
      await controller.createLink();
      final pending = Completer<void>();
      repository.pendingDelete = pending.future;
      final deletion = controller.revokeLink();
      await controller.revokeLink();
      await controller.createLink();
      expect(controller.isWorking, isTrue);
      expect(controller.link, createdLmsLink);
      expect(controller.canRevoke, isFalse);
      expect(repository.deleteRequests, ['description-id']);
      expect(repository.requests, hasLength(1));
      pending.complete();
      await deletion;
      expect(controller.link, isNull);
      expect(controller.isWorking, isFalse);
      expect(controller.allSelected, isTrue);
      expect(controller.canCreate, isTrue);
      await controller.createLink();
      expect(repository.requests.last.ids, [
        'lesson-0',
        'lesson-1',
        'lesson-2',
      ]);
    },
  );

  test('failed revocation preserves the link and can retry', () async {
    repository.existingLink = LmsPublicLink(
      url: createdLmsLink,
      trainingModuleUuids: ['lesson-1'],
    );
    await controller.loadLink();
    repository.deleteFailure = StateError('offline');
    await controller.revokeLink();
    expect(controller.link, createdLmsLink);
    expect(controller.errorMessage, AppStrings.shareRevokeLinkFailed);
    expect(controller.canRevoke, isTrue);
    repository.deleteFailure = null;
    await controller.revokeLink();
    expect(controller.errorMessage, isNull);
    expect(controller.link, isNull);
  });

  test('revocation rechecks permissions before sending DELETE', () async {
    await controller.createLink();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', isOwner: false, roles: ['owner', 'csuite']),
    );
    await controller.revokeLink();
    expect(controller.canRevoke, isFalse);
    expect(repository.deleteRequests, isEmpty);
    expect(controller.link, createdLmsLink);
    expect(await controller.copyLink(), isFalse);
  });

  test('DELETE completion after disposal never notifies listeners', () async {
    repository.existingLink = LmsPublicLink(
      url: createdLmsLink,
      trainingModuleUuids: ['lesson-1'],
    );
    final closing = TrainingShareController(
      repository,
      seatProfileId: 'job-id',
      descriptionId: 'description-id',
    );
    await closing.loadLink();
    final pending = Completer<void>();
    repository.pendingDelete = pending.future;
    final deletion = closing.revokeLink();
    closing.dispose();
    pending.complete();
    await expectLater(deletion, completes);
  });

  test('rechecks permissions before creating a link', () async {
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', isOwner: false, roles: ['owner', 'csuite']),
    );
    await controller.createLink();
    expect(controller.canManage, isFalse);
    expect(repository.requests, isEmpty);
  });

  test('role-only owners cannot load public links', () async {
    AppManager.instance.updateCurrentUser(
      User(uuid: 'manager', roles: ['owner', 'csuite']),
    );
    final countBefore = repository.loadRequests.length;
    await controller.loadLink();
    expect(controller.canManage, isFalse);
    expect(repository.loadRequests.length, countBefore);
  });

  test('completing after disposal never notifies listeners', () async {
    final closing = TrainingShareController(
      repository,
      seatProfileId: 'job-id',
      descriptionId: 'description-id',
      lessons: shareLessons(),
    );
    await closing.loadLink();
    final pending = Completer<LmsPublicLink>();
    repository.pending = pending.future;
    final request = closing.createLink();
    closing.dispose();
    pending.complete(
      LmsPublicLink(url: createdLmsLink, trainingModuleUuids: ['lesson-0']),
    );
    await expectLater(request, completes);
  });
}
