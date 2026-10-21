import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/departments/presentation/pages/departments_screen.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  final updates = <http.Request>[];
  var organizationType = 'child';
  var departmentName = 'Operations';

  // The API executor retains its client; reuse one mock with fresh fixtures.
  final client = MockClient((request) async {
    final path = request.url.path;
    Object response;
    if (path.endsWith(ApiEndPoints.organizations)) {
      response = [
        {'uuid': 'org', 'name': 'Organisation', 'type': organizationType},
      ];
    } else if (request.method == 'PUT' &&
        path.endsWith(ApiEndPoints.departmentDetail('department'))) {
      updates.add(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      departmentName = body['name'] as String;
      response = <String, Object?>{};
    } else if (path.endsWith(ApiEndPoints.allDepartments)) {
      response = [
        {'uuid': 'department', 'name': departmentName, 'color_hex': '#7654AB'},
        {'uuid': 'privileged', 'name': 'Privileged', 'color_hex': '#7654AB'},
      ];
    } else {
      throw StateError('Unexpected request: ${request.method} $path');
    }
    return http.Response(jsonEncode(response), 200);
  });
  tearDownAll(client.close);

  setUp(() async {
    updates.clear();
    organizationType = 'child';
    departmentName = 'Operations';
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    ApiCallExecutor.clearGetCache();
    AppManager.instance.resetSessionState();
  });
  tearDown(AppManager.instance.resetSessionState);

  Future<void> loadScreen(WidgetTester tester, User user) async {
    AppManager.instance.updateCurrentUser(user);
    await AppManager.instance.fetchOrganizations(requireSuccess: true);
    await tester.pumpWidget(const MaterialApp(home: DepartmentsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('owner can edit and save a child department', (tester) async {
    await http.runWithClient(() async {
      await loadScreen(
        tester,
        User(
          isOwner: true,
          organizationUuid: 'org',
          roles: const ['team_member'],
        ),
      );
      expect(AppManager.instance.isCurrentOrganizationChild, isTrue);
      expect(AppManager.instance.canCurrentOrganizationModifyContent, isFalse);

      await tester.drag(find.text('Operations'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.departmentsEditTitle), findsOneWidget);

      final nameField = find.widgetWithText(TextField, 'Operations');
      await tester.enterText(nameField, 'Updated Operations');
      final saveButton = find.text(AppStrings.seatProfileSaveAction);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(updates, hasLength(1));
      expect(jsonDecode(updates.single.body), {
        'name': 'Updated Operations',
        'color_hex': '#7654AB',
      });
      expect(find.text(AppStrings.departmentsEditTitle), findsNothing);
      expect(find.text('Updated Operations'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('Privileged stays locked for an owner in a child organisation', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await loadScreen(tester, User(isOwner: true, organizationUuid: 'org'));
      await tester.drag(find.text('Privileged'), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      expect(find.text(AppStrings.departmentsEditTitle), findsNothing);
      expect(updates, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('an owner role without the flag cannot edit child departments', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await loadScreen(
        tester,
        User(isOwner: false, organizationUuid: 'org', roles: const ['owner']),
      );
      await tester.drag(find.text('Operations'), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      expect(find.text(AppStrings.departmentsEditTitle), findsNothing);
      expect(updates, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('non-owner department editing remains available in a parent', (
    tester,
  ) async {
    organizationType = 'parent';
    await http.runWithClient(() async {
      await loadScreen(
        tester,
        User(
          isOwner: false,
          organizationUuid: 'org',
          roles: const ['team_member'],
        ),
      );
      await tester.drag(find.text('Operations'), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}
