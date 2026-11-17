import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/check_in/data/models/audit_details_model.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_details.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/seat_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/subordinate_profile_job.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_details_usecase.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late CheckInController controller;
  var disposed = false;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.saveUser(User(isOwner: true));
    repository = _Repository();
    controller = CheckInController(
      GetAuditOverviewUseCase(repository),
      GetAuditDetailsUseCase(repository),
      null,
      null,
      null,
      null,
      null,
      repository,
    );
    disposed = false;
  });
  tearDown(() {
    if (!disposed) controller.dispose();
  });

  test(
    'a pending subordinate list does not block the General Seat details',
    () async {
      final pending = Completer<List<SubordinateProfileJob>>();
      repository.loadProfiles = (_) => pending.future;
      await controller.initializeDetails(
        '',
        seatId: 'seat-a',
        year: 2026,
        quarter: 4,
      );
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.details?.jobUuid, 'seat-a');
      expect(controller.isSubordinateProfileJobsLoading, isTrue);
      expect(repository.requests.single.seatId, 'seat-a');
      pending.complete([_profileJob('a')]);
      await _flush();
      expect(controller.subordinateProfileJobs.single.uuid, 'profile-job-a');
      expect(controller.isSubordinateProfileJobsLoading, isFalse);
    },
  );

  test(
    'quarter and date-range changes reuse the seat-specific subordinate list',
    () async {
      await controller.initializeDetails(
        '',
        seatId: 'seat-a',
        year: 2026,
        quarter: 4,
      );
      await _flush();
      await controller.selectDetailsQuarter('2026 - Q1');
      await controller.applyDetailsDateRange(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 20),
      );
      expect(repository.requests, hasLength(1));
      expect(
        controller.subordinateProfileJobs.single.profile.name,
        'Member seat-a',
      );
    },
  );

  test(
    'late responses cannot replace a newer seat and normal details clear the list',
    () async {
      final pending = Completer<List<SubordinateProfileJob>>();
      repository.loadProfiles = (seatId) => seatId == 'seat-a'
          ? pending.future
          : Future.value([_profileJob(seatId)]);
      await controller.initializeDetails('', seatId: 'seat-a');
      await controller.initializeDetails('', seatId: 'seat-b');
      await _flush();
      pending.complete([_profileJob('seat-a')]);
      await _flush();
      expect(
        controller.subordinateProfileJobs.single.uuid,
        'profile-job-seat-b',
      );
      await controller.initializeDetails('normal-profile-job');
      expect(controller.subordinateProfileJobs, isEmpty);
      expect(controller.isSubordinateProfileJobsLoading, isFalse);
      expect(repository.requests.map((request) => request.seatId), [
        'seat-a',
        'seat-b',
      ]);
    },
  );

  test(
    'subordinate failure leaves details usable and can retry an empty list',
    () async {
      repository.loadProfiles = (_) => Future.error(StateError('offline'));
      await controller.initializeDetails('', seatId: 'seat-a');
      await _flush();
      expect(controller.state.details, isNotNull);
      expect(controller.hasDetailsLoadError, isFalse);
      expect(
        controller.subordinateProfileJobsError,
        AppStrings.auditSubordinateProfilesLoadError,
      );
      expect(controller.isSubordinateProfileJobsLoading, isFalse);
      repository.loadProfiles = (_) => Future.value([]);
      await controller.loadSubordinateProfileJobs(forceRefresh: true);
      expect(repository.requests.last.forceRefresh, isTrue);
      expect(controller.subordinateProfileJobs, isEmpty);
      expect(controller.subordinateProfileJobsError, isNull);
      await controller.loadSubordinateProfileJobs();
      expect(repository.requests, hasLength(2));
    },
  );

  test(
    'a pending subordinate response does not notify after disposal',
    () async {
      final pending = Completer<List<SubordinateProfileJob>>();
      repository.loadProfiles = (_) => pending.future;
      var notifications = 0;
      controller.addListener(() => notifications++);
      await controller.initializeDetails('', seatId: 'seat-a');
      final beforeDispose = notifications;
      controller.dispose();
      disposed = true;
      pending.complete([_profileJob('seat-a')]);
      await _flush();
      expect(notifications, beforeDispose);
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

SubordinateProfileJob _profileJob(String id) => SubordinateProfileJob(
  uuid: 'profile-job-$id',
  title: 'Backend Dev',
  isPrimary: false,
  createdAt: '1778063413000',
  profile: SeatAuditProfile(
    uuid: 'profile-$id',
    name: 'Member $id',
    userUuid: 'user-$id',
    email: '$id@example.com',
    image: null,
    onboarded: true,
  ),
);

class _Repository extends Fake implements AuditRepository {
  final requests = <({String seatId, bool forceRefresh})>[];
  Future<List<SubordinateProfileJob>> Function(String)? loadProfiles;

  @override
  Future<List<SubordinateProfileJob>> getSubordinateProfileJobs({
    required String seatId,
    bool forceRefresh = false,
  }) {
    requests.add((seatId: seatId, forceRefresh: forceRefresh));
    return loadProfiles?.call(seatId) ?? Future.value([_profileJob(seatId)]);
  }

  @override
  Future<AuditDetails> getSeatAuditDetails({
    required String seatId,
    required DateTime startDate,
    required DateTime endDate,
  }) async => _details(seatId);

  @override
  Future<AuditDetails> getAuditDetails({
    required String profileJobId,
    required int year,
    required int quarter,
    String? profileUuid,
    DateTime? startDate,
    DateTime? endDate,
  }) async => _details('normal-seat');
}

AuditDetails _details(String seatId) => AuditDetailsModel.fromApiJson({
  'uuid': 'audit-$seatId',
  'job': {'uuid': seatId, 'title': 'Backend Dev'},
  'profiles': [],
  'audits': [],
});
