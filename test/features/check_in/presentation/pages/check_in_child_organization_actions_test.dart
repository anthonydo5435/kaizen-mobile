import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_descriptions_list_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_media_comments_bottom_sheet.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_single_description.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  final requests = <http.Request>[];
  var mismatch = false;
  var ratings = <String, int>{};
  var media = <Map<String, Object?>>[];

  // The API executor retains its client; reuse one mock with fresh fixtures.
  final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object response;
    if (path.endsWith(ApiEndPoints.organizations)) {
      response = [
        {'uuid': 'child-org', 'name': 'Child', 'type': 'child'},
      ];
    } else if (path.endsWith(ApiEndPoints.quarterlyAuditDetail('quarterly-audit'))) {
      response = {
        'uuid': 'quarterly-audit',
        'profile_job': 'profile-job',
        'mismatch': mismatch,
        'profile': {'uuid': 'member', 'name': 'Member'},
        'job': {'uuid': 'seat', 'title': 'Operator'},
        'categories': [
          {'uuid': 'category', 'category_title': 'Responsibilities'},
        ],
        'descriptions': [
          {
            'uuid': 'seat-description',
            'category': 'category',
            'description': 'Complete the daily task',
            'audit_details': {...ratings, 'has_audit': true, 'audit_uuid': 'audit-description'},
          },
        ],
      };
    } else if (request.method == 'PATCH' &&
        path.endsWith(ApiEndPoints.auditDescription('audit-description'))) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      ratings = Map<String, int>.from(body['audit'] as Map);
      response = _descriptionAudit(ratings, media);
    } else if (request.method == 'PUT' &&
        path.endsWith(ApiEndPoints.createAuditDescriptionMedia('audit-description'))) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      media.add({'uuid': 'comment-${media.length}', 'comment': body['comment']});
      response = <String, Object?>{};
    } else if (path.endsWith(ApiEndPoints.auditMedia('existing-comment'))) {
      if (request.method == 'DELETE') {
        media.removeWhere((item) => item['uuid'] == 'existing-comment');
      }
      response = {'uuid': 'existing-comment', 'comments': <Object>[], 'total_comments': 0};
    } else if (path.endsWith(
      ApiEndPoints.quarterlyAuditDescriptionAudit(
        quarterlyAuditId: 'quarterly-audit',
        descriptionId: 'seat-description',
      ),
    )) {
      response = _descriptionAudit(ratings, media);
    } else if (path.endsWith(ApiEndPoints.quarterlyAudit)) {
      response = {'count': 0, 'current': 1, 'results': <Object>[]};
    } else {
      throw StateError('Unexpected request: ${request.method} $path');
    }
    return http.Response(jsonEncode(response), 200);
  });
  tearDownAll(client.close);

  setUp(() async {
    requests.clear();
    mismatch = false;
    ratings = {'great': 1, 'almost_there': 0, 'needs_improvement': 0};
    media = [
      {'uuid': 'existing-comment', 'comment': 'Existing observation'},
    ];
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    ApiCallExecutor.clearGetCache();
    AppManager.instance.resetSessionState();
    await http.runWithClient(
      () => AppManager.instance.fetchOrganizations(requireSuccess: true),
      () => client,
    );
  });
  tearDown(AppManager.instance.resetSessionState);

  for (final scenario in [(isOwner: true, daysAgo: 0), (isOwner: false, daysAgo: 6)]) {
    testWidgets(
      'child organisation allows list and detail actions (owner: ${scenario.isOwner}, age: ${scenario.daysAgo})',
      (tester) async {
        _setViewport(tester);
        await _saveUser(isOwner: scenario.isOwner);

        await http.runWithClient(() async {
          await tester.pumpWidget(_screen(daysAgo: scenario.daysAgo));
          await tester.pumpAndSettle();
          expect(AppManager.instance.isCurrentOrganizationChild, isTrue);
          // Other modules keep the general child-organisation restriction.
          expect(AppManager.instance.canCurrentOrganizationModifyContent, isFalse);
          expect(find.byIcon(Icons.lock_rounded), findsNothing);
          await _changeRating(tester);
          expect(ratings['great'], 2);
          await _changeRating(tester, decrement: true);
          expect(ratings['great'], 1);
          await _saveTextComment(tester, 'List observation');

          await _openDetails(tester);
          expect(find.byIcon(Icons.lock_rounded), findsNothing);
          await _changeRating(tester);
          expect(ratings['great'], 2);
          await _changeRating(tester, decrement: true);
          expect(ratings['great'], 1);
          await _saveTextComment(tester, 'Detail observation');

          final saves = requests.where((request) => request.method == 'PUT').toList();
          expect(saves, hasLength(2));
          expect(jsonDecode(saves[0].body), {'comment': 'List observation'});
          expect(jsonDecode(saves[1].body), {'comment': 'Detail observation'});

          await _openExistingComment(tester);
          final sheet = tester.widget<CheckInMediaCommentsBottomSheet>(
            find.byType(CheckInMediaCommentsBottomSheet),
          );
          expect(sheet.canDelete, isTrue);
          expect(sheet.canReply, isTrue);
          await _tap(tester, find.text('Delete'));
          expect(requests.where((request) => request.method == 'DELETE'), isEmpty);
          await _tap(tester, find.text('Yes'));
          final deletion = requests.singleWhere((request) => request.method == 'DELETE');
          expect(deletion.url.path, endsWith(ApiEndPoints.auditMedia('existing-comment')));
          expect(media.any((item) => item['uuid'] == 'existing-comment'), isFalse);
          await tester.pump(const Duration(seconds: 2));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }

  for (final scenario in [
    (name: 'expired Check-in', daysAgo: 7, mismatch: false, self: false, reviewer: true),
    (name: 'mismatched Check-in', daysAgo: 0, mismatch: true, self: false, reviewer: true),
    (name: 'self Check-in', daysAgo: 0, mismatch: false, self: true, reviewer: true),
    (
      name: 'account without reviewer access',
      daysAgo: 0,
      mismatch: false,
      self: false,
      reviewer: false,
    ),
  ]) {
    testWidgets('child organisation preserves guards for ${scenario.name}', (tester) async {
      _setViewport(tester);
      mismatch = scenario.mismatch;
      await _saveUser(isOwner: scenario.reviewer, reviewer: scenario.reviewer);

      await http.runWithClient(() async {
        await tester.pumpWidget(_screen(daysAgo: scenario.daysAgo, self: scenario.self));
        await tester.pumpAndSettle();
        _expectRatingsDisabled(tester);
        expect(requests.where((request) => request.method == 'PATCH'), isEmpty);
        final commentsAllowed = scenario.daysAgo < 7 && !scenario.mismatch;
        expect(
          find.byIcon(Icons.camera_alt_outlined),
          commentsAllowed ? findsOneWidget : findsNothing,
        );

        await _openDetails(tester);
        _expectRatingsDisabled(tester);
        expect(requests.where((request) => request.method == 'PATCH'), isEmpty);
        expect(
          find.byIcon(Icons.camera_alt_outlined),
          commentsAllowed ? findsOneWidget : findsNothing,
        );
        await _openExistingComment(tester);
        final sheet = tester.widget<CheckInMediaCommentsBottomSheet>(
          find.byType(CheckInMediaCommentsBottomSheet),
        );
        expect(sheet.canDelete, commentsAllowed);
        expect(sheet.canReply, commentsAllowed);
        expect(find.text('Delete'), commentsAllowed ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }
}

Map<String, Object?> _descriptionAudit(
  Map<String, int> ratings,
  List<Map<String, Object?>> media,
) => {
  'uuid': 'audit-description',
  'audit': ratings.entries.expand((entry) => List.filled(entry.value, entry.key)).toList(),
  'audit_media': media,
};

Future<void> _saveUser({required bool isOwner, bool reviewer = true}) async {
  final user = User(
    uuid: 'reviewer',
    isOwner: isOwner,
    roles: [reviewer ? 'team_lead' : 'team_member'],
    organizationUuid: 'child-org',
  );
  await AppPreference.saveUser(user);
  AppManager.instance.updateCurrentUser(user);
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _screen({required int daysAgo, bool self = false}) {
  final date = CustomFunctions.apiDateString(
    date: DateTime.now().subtract(Duration(days: daysAgo)),
  );
  return ChangeNotifierProvider<AppManager>.value(
    value: AppManager.instance,
    child: MaterialApp(
      home: CheckInDescriptionsListScreen(
        quarterlyAuditId: 'quarterly-audit',
        date: date,
        lastAuditDate: date,
        isSelfAudit: self,
      ),
    ),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'After tapping $finder');
}

Future<void> _changeRating(WidgetTester tester, {bool decrement = false}) async {
  await _tap(tester, decrement ? find.byIcon(Icons.keyboard_arrow_down_rounded) : find.text('1'));
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

Future<void> _saveTextComment(WidgetTester tester, String comment) async {
  await _tap(tester, find.byIcon(Icons.camera_alt_outlined));
  await _tap(tester, find.text(AppStrings.auditCommentOnly));
  await tester.enterText(
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
    comment,
  );
  await tester.pump();
  await _tap(tester, find.text(AppStrings.saveComment));
}

Future<void> _openDetails(WidgetTester tester) async {
  await _tap(tester, find.text('Complete the daily task'));
  expect(find.byType(SingleDescriptionDetails), findsOneWidget);
}

void _expectRatingsDisabled(WidgetTester tester) {
  final ratingButton = tester.widget<InkWell>(
    find.ancestor(of: find.text('1'), matching: find.byType(InkWell)).first,
  );
  expect(ratingButton.onTap, isNull);
}

Future<void> _openExistingComment(WidgetTester tester) async {
  await _tap(tester, find.text(AppStrings.auditExpandComments));
  await _tap(tester, find.text('Existing observation'));
}
