import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/domain/usecases/get_audit_overview_usecase.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AuditRepository repository;
  late CheckInController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    await http.runWithClient(
      () => AppManager.instance.fetchOrganizations(requireSuccess: true),
      () => MockClient(
        (_) async => http.Response(
          jsonEncode([
            {'uuid': 'child-org', 'name': 'Child', 'type': 'child'},
          ]),
          200,
        ),
      ),
    );

    repository = _AuditRepository();
    controller = CheckInController(
      GetAuditOverviewUseCase(repository),
      null,
      null,
      null,
      null,
      null,
      null,
      repository,
    );
  });

  tearDown(() {
    controller.dispose();
    AppManager.instance.resetSessionState();
  });

  for (final isOwner in [true, false]) {
    test(
      'child organisation allows Check-in writes (owner: $isOwner)',
      () async {
        AppManager.instance.updateCurrentUser(
          User(
            isOwner: isOwner,
            roles: const ['team_lead'],
            organizationUuid: 'child-org',
          ),
        );
        expect(AppManager.instance.isCurrentOrganizationChild, isTrue);
        expect(AppManager.instance.canCurrentOrganizationModifyContent, isTrue);
        expect(
          AppManager.instance.currentUserCanOpenTrainingModuleCreateFlow,
          isTrue,
        );
        expect(
          AppManager.instance.currentUserCanOpenSeatProfileCreateFlow,
          isTrue,
        );

        final saved = await controller.submitAuditDescriptionSelection(
          quarterlyAuditId: 'quarter',
          seatDescriptionId: 'seat-description',
          descriptionId: 'audit-description',
          audit: {'great': 2},
        );
        expect(saved.uuid, 'audit-description');
        expect(repository.savedRatings, {'great': 2});

        await controller.createAuditDescriptionComment(
          descriptionId: 'audit-description',
          comment: 'Check-in observation',
        );
        expect(repository.savedComment, 'Check-in observation');

        expect(
          await controller.createAuditDescriptionMediaComment(
            descriptionId: 'audit-description',
            comment: 'Discussion comment',
          ),
          isTrue,
        );
        expect(repository.savedMediaComment, 'Discussion comment');
      },
    );
  }
}

class _AuditRepository extends Fake implements AuditRepository {
  Map<String, int>? savedRatings;
  String? savedComment;
  String? savedMediaComment;

  @override
  Future<AuditDescriptionAudit> submitDescriptionAudit({
    required String descriptionId,
    required Map<String, int> audit,
  }) async {
    savedRatings = audit;
    return AuditDescriptionAudit(
      uuid: descriptionId,
      audit: const [],
      isGeneral: false,
      isMirror: false,
      auditMedia: const [],
      weightedScore: 0,
    );
  }

  @override
  Future<void> createAuditDescriptionComment({
    required String descriptionId,
    required String comment,
  }) async {
    savedComment = comment;
  }

  @override
  Future<void> createAuditDescriptionMedia({
    required String descriptionId,
    required String comment,
    String? mediaUrl,
    String? mediaType,
  }) async {
    savedMediaComment = comment;
  }
}
