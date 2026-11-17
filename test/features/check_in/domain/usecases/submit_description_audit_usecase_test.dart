// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/submit_description_audit_usecase.dart';
import 'package:test/test.dart';

void main() {
  late _AuditRepository repository;
  late SubmitDescriptionAuditUseCase submit;

  setUp(() {
    repository = _AuditRepository();
    submit = SubmitDescriptionAuditUseCase(repository);
  });

  test('a later count waits for the earlier save to finish', () async {
    final first = submit(descriptionId: 'audit-a', audit: {'great': 4});
    final second = submit(descriptionId: 'audit-a', audit: {'great': 5});
    await _drainMicrotasks();

    expect(repository.requests, hasLength(1));
    repository.requests.first.complete();
    await first;
    await _drainMicrotasks();

    expect(repository.requests, hasLength(2));
    expect(repository.requests.last.counts['great'], 5);
    repository.requests.last.complete();
    await second;
  });

  test('different descriptions can save independently', () async {
    final first = submit(descriptionId: 'audit-a', audit: {'great': 4});
    final second = submit(descriptionId: 'audit-b', audit: {'great': 7});
    await _drainMicrotasks();

    expect(repository.requests.map((request) => request.id), [
      'audit-a',
      'audit-b',
    ]);
    repository.requests.last.complete();
    await second;
    repository.requests.first.complete();
    await first;
  });

  test('a failed save does not block the newer count', () async {
    final first = submit(descriptionId: 'audit-a', audit: {'great': 4});
    final failure = expectLater(first, throwsStateError);
    final second = submit(descriptionId: 'audit-a', audit: {'great': 5});
    await _drainMicrotasks();

    repository.requests.first.result.completeError(StateError('Save failed'));
    await failure;
    await _drainMicrotasks();

    expect(repository.requests, hasLength(2));
    expect(repository.requests.last.counts['great'], 5);
    repository.requests.last.complete();
    await second;
  });

  test('queued counts cannot be changed by later widget edits', () async {
    final first = submit(descriptionId: 'audit-a', audit: {'great': 4});
    final counts = {'great': 5};
    final second = submit(descriptionId: 'audit-a', audit: counts);
    counts['great'] = 20;
    await _drainMicrotasks();

    repository.requests.first.complete();
    await first;
    await _drainMicrotasks();

    expect(repository.requests.last.counts['great'], 5);
    repository.requests.last.complete();
    await second;
  });

  test('checks current permissions when a queued save starts', () async {
    var canModify = true;
    submit = SubmitDescriptionAuditUseCase(
      repository,
      beforeSubmit: () {
        if (!canModify) {
          throw StateError('Read only');
        }
      },
    );
    final first = submit(descriptionId: 'audit-a', audit: {'great': 4});
    final second = submit(descriptionId: 'audit-a', audit: {'great': 5});
    final blocked = expectLater(second, throwsStateError);
    await _drainMicrotasks();

    canModify = false;
    repository.requests.first.complete();
    await first;
    await blocked;
    expect(repository.requests, hasLength(1));
  });

  test(
    'assignments and rating saves for one description stay ordered',
    () async {
      final first = submit(descriptionId: 'audit-a', audit: {'great': 4});
      final ids = ['profile-job-a'];
      final assignment = submit.assign(
        descriptionId: 'audit-a',
        profileJobIds: ids,
      );
      ids.add('profile-job-b');
      final last = submit(descriptionId: 'audit-a', audit: {'great': 5});
      await _drainMicrotasks();
      expect(repository.assignments, isEmpty);
      repository.requests.first.complete();
      await first;
      await _drainMicrotasks();
      expect(repository.assignments.single.ids, ['profile-job-a']);
      expect(repository.requests, hasLength(1));
      repository.assignments.single.result.complete();
      await assignment;
      await _drainMicrotasks();
      expect(repository.requests.last.counts['great'], 5);
      repository.requests.last.complete();
      await last;
    },
  );
}

Future<void> _drainMicrotasks() => Future<void>.delayed(Duration.zero);

class _AuditRepository implements AuditRepository {
  final List<_Request> requests = [];
  final assignments = <({List<String> ids, Completer<void> result})>[];

  @override
  Future<void> assignDescriptionAudit({
    required String descriptionId,
    required List<String> profileJobIds,
  }) {
    final request = (ids: profileJobIds, result: Completer<void>());
    assignments.add(request);
    return request.result.future;
  }

  @override
  Future<AuditDescriptionAudit> submitDescriptionAudit({
    required String descriptionId,
    required Map<String, int> audit,
  }) {
    final request = _Request(descriptionId, audit);
    requests.add(request);
    return request.result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Request {
  _Request(this.id, this.counts);

  final String id;
  final Map<String, int> counts;
  final Completer<AuditDescriptionAudit> result = Completer();

  void complete() {
    result.complete(
      AuditDescriptionAudit(
        uuid: id,
        // PATCH responses are allowed to omit the rating list.
        audit: const [],
        isGeneral: false,
        isMirror: false,
        auditMedia: const [],
        weightedScore: 0,
      ),
    );
  }
}
