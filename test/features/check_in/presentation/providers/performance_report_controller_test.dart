import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_member.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/performance_report.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/performance_report_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

import '../../support/performance_report_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReportRepository repository;
  late CheckInController audit;
  late PerformanceReportController controller;

  setUp(() async {
    repository = ReportRepository();
    audit = reportAuditController(repository);
    controller = PerformanceReportController(
      checkInController: audit,
      loadUser: () async => User(isOwner: true),
    );
    await audit.initializePerformanceReport(reportProfile);
  });
  tearDown(() {
    controller.dispose();
    audit.dispose();
  });

  test(
    'profile switching preserves seat context and resets presentation state',
    () async {
      controller.selectCategory(1);
      controller.toggleCoreValues();
      controller.updateCommitment('Previous employee draft');
      await controller.selectProfile(reportProfiles[1]);
      final profile = repository.overviewProfiles.last;
      expect(profile.profileUuid, 'second');
      expect(profile.uuid, 'second');
      expect(profile.name, 'Employee Two');
      expect(profile.email, reportProfile.email);
      expect(profile.profileJob, reportProfile.profileJob);
      expect(profile.seatProfile, reportProfile.seatProfile);
      expect(profile.lastAuditDates, reportProfile.lastAuditDates);
      expect(profile.reviewerInitials, reportProfile.reviewerInitials);
      expect(profile.isFavorite, isTrue);
      expect(controller.selectedCategoryIndex, 0);
      expect(controller.isCoreValuesExpanded, isFalse);
      expect(controller.commentsController.text, isEmpty);
    },
  );

  test(
    'invalid and concurrent profile selections do not issue requests',
    () async {
      await controller.selectProfile(
        const AuditMemberProfile(
          uuid: ' ',
          name: '',
          email: '',
          imageUrl: null,
          onboarded: false,
        ),
      );
      expect(repository.overviewProfiles, hasLength(1));
      final pending = Completer<PerformanceReport>();
      repository.pendingOverview = pending.future;
      final switching = controller.selectProfile(reportProfiles[1]);
      await controller.selectProfile(reportProfiles[0]);
      expect(repository.overviewProfiles, hasLength(2));
      pending.complete(reportFixture());
      await switching;
    },
  );

  test(
    'category selection follows the current report and rejects invalid indexes',
    () async {
      controller.selectCategory(1);
      expect(controller.ratingRows.single.title, 'Team support');
      controller.selectCategory(-1);
      controller.selectCategory(100);
      expect(controller.selectedCategoryIndex, 1);
      await audit.generatePerformanceReportRemarks();
      expect(controller.selectedCategoryIndex, 1);
      controller.selectCategory(0);
      expect(controller.ratingRows.single.remarks, 'Generated guidance');
      controller.selectCategory(1);
      repository.buildReport = (profile) =>
          reportFixture(profile: profile, remarkVersion: 1);
      await audit.applyPerformanceReportCustomDateRange(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 2),
      );
      expect(controller.selectedCategoryIndex, 0);
    },
  );

  test(
    'draft sync enforces the limit and preserves the cursor on unrelated updates',
    () async {
      controller.updateCommitment('a' * 2050);
      expect(controller.commentsController.text.length, 2000);
      controller.commentsController.selection = const TextSelection.collapsed(
        offset: 10,
      );
      controller.toggleCoreValues();
      expect(controller.commentsController.selection.baseOffset, 10);
      await audit.selectCertifiedReport('certified');
      expect(controller.commentsController.text, 'Certified commitment');
      expect(controller.isCommitmentReadOnly, isTrue);
    },
  );

  test('permissions use the shared Check-in owner override', () async {
    expect(controller.canGenerateRemarks, isFalse);
    await controller.loadAccess();
    expect(controller.canGenerateRemarks, isTrue);
    expect(controller.isCommitmentReadOnly, isFalse);
  });

  test(
    'a pending access load and source updates are safe after disposal',
    () async {
      final pending = Completer<User?>();
      final disposed = PerformanceReportController(
        checkInController: audit,
        loadUser: () => pending.future,
      );
      final loading = disposed.loadAccess();
      disposed.dispose();
      pending.complete(User(isOwner: true));
      await loading;
      audit.updatePerformanceReportCommitment('Still active');
      expect(controller.commentsController.text, 'Still active');
    },
  );
}
