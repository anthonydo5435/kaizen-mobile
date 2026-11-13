import 'dart:async';
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
import 'package:sparrowkaizen/features/check_in/presentation/pages/View_all_team_members.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_single_description.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_description_card.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_member_card.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

const _openedDate = '2026-10-15';

void main() {
  final requests = <http.Request>[];
  var audits = <String, Map<String, Object?>>{};
  Future<http.Response?> Function(http.Request)? intercept;
  final client = MockClient((request) async {
    requests.add(request);
    final intercepted = await intercept?.call(request);
    if (intercepted != null) return intercepted;
    for (final id in ['a', 'b', 'c']) {
      if (request.url.path.endsWith(
        ApiEndPoints.quarterlyAuditDetail('audit-$id'),
      )) {
        return http.Response(jsonEncode(audits[id]), 200);
      }
      if (request.url.path.endsWith(_descriptionEndpoint(id))) {
        return http.Response(jsonEncode(_specificAudit(id)), 200);
      }
    }
    if (request.url.path.endsWith(ApiEndPoints.quarterlyAudit)) {
      final members = request.url.queryParameters['search'] == 'Bob'
          ? ['b']
          : ['a', 'b', 'c'];
      return http.Response(
        jsonEncode({
          'count': members.length,
          'current': 1,
          'results': members.map(_member).toList(),
        }),
        200,
      );
    }
    throw StateError('Unexpected request: ${request.method} ${request.url}');
  });
  tearDownAll(client.close);

  setUp(() async {
    requests.clear();
    intercept = null;
    audits = {
      for (final id in ['a', 'b', 'c']) id: _audit(id),
    };
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    ApiCallExecutor.clearGetCache();
    AppManager.instance.resetSessionState();
    final user = User(uuid: 'reviewer', isOwner: true);
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
  });
  tearDown(AppManager.instance.resetSessionState);

  Future<_NavigationObserver> mount(
    WidgetTester tester, {
    String date = _openedDate,
  }) async {
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = _NavigationObserver();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppManager>.value(
        value: AppManager.instance,
        child: MaterialApp(
          navigatorObservers: [observer],
          home: CheckInDescriptionsListScreen(
            quarterlyAuditId: 'audit-a',
            date: date,
            lastAuditDate: date,
            year: 2026,
            quarter: 4,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return observer;
  }

  testWidgets(
    'description team requests omit the period on open, pagination, search and favorites',
    (tester) async {
      intercept = (request) async {
        if (request.method == 'PATCH' &&
            request.url.path.endsWith(ApiEndPoints.favoriteSubordinate)) {
          return http.Response('{}', 200);
        }
        if (!request.url.path.endsWith(ApiEndPoints.quarterlyAudit)) {
          return null;
        }
        final query = request.url.queryParameters;
        final page = int.parse(query['page']!);
        final search = query['search'];
        final members = search == 'Bob'
            ? ['b']
            : page == 1
            ? ['a', 'b']
            : ['c'];
        return http.Response(
          jsonEncode({
            'count': search == 'Bob' ? 1 : 3,
            'current': page,
            'next': search == null && page == 1 ? '?page=2' : null,
            'results': members.map(_member).toList(),
          }),
          200,
        );
      };
      await http.runWithClient(() async {
        await mount(tester);
        final controller = _controller(tester);
        http.Request lastTeamRequest() => requests.lastWhere(
          (request) => request.url.path.endsWith(ApiEndPoints.quarterlyAudit),
        );
        expect(lastTeamRequest().url.queryParameters, {
          'page': '1',
          'page_size': '10',
        });
        await controller.loadNextTeamMembersPage();
        await tester.pumpAndSettle();
        expect(lastTeamRequest().url.queryParameters, {
          'page': '2',
          'page_size': '10',
        });
        expect(controller.state.mainList?.results, hasLength(3));

        controller.updateTeamMembersSearchQuery('Bob');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(lastTeamRequest().url.queryParameters, {
          'page': '1',
          'page_size': '10',
          'search': 'Bob',
        });

        await controller.toggleFavoriteSubordinate(
          profileJobId: 'profile-job-b',
          isFavorite: false,
        );
        expect(lastTeamRequest().url.queryParameters, {
          'page': '1',
          'page_size': '1',
          'search': 'Bob',
        });
        await controller.resetTeamMembersSearch();
        await tester.pumpAndSettle();
        expect(lastTeamRequest().url.queryParameters, {
          'page': '1',
          'page_size': '10',
        });
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets(
    'a member loads details and its first description for today in the same screen',
    (tester) async {
      await http.runWithClient(() async {
        final today = CustomFunctions.apiDateString();
        final observer = await mount(tester);
        final controller = _controller(tester);
        final openingRequest = requests.singleWhere(
          (request) => request.url.path.endsWith(
            ApiEndPoints.quarterlyAuditDetail('audit-a'),
          ),
        );
        expect(openingRequest.method, 'GET');
        expect(openingRequest.url.query, 'date=$_openedDate');
        expect(controller.state.quarterlyAuditDate, _openedDate);
        expect(controller.state.quarterlyAudit?.profileName, 'Alice');
        expect(controller.state.quarterlyAudit?.jobTitle, 'Operator a');
        expect(
          controller.state.quarterlyAudit?.descriptions.map(
            (item) => item.uuid,
          ),
          ['a-first', 'a-second'],
        );
        final requestCount = requests.length;
        await tester.tap(
          find.byKey(const ValueKey('check-in-team-member-audit-a')),
        );
        await tester.pumpAndSettle();
        expect(requests.length, requestCount);

        controller.updateDescriptionSearchQuery('a task');
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('check-in-team-member-audit-b')),
        );
        await tester.pumpAndSettle();
        expect(observer.pushes, 1);
        expect(find.byType(CheckInDescriptionsListScreen), findsOneWidget);
        expect(requests.skip(requestCount).map((request) => request.url.path), [
          endsWith(ApiEndPoints.quarterlyAuditDetail('audit-b')),
          endsWith(_descriptionEndpoint('b')),
        ]);
        for (final request in requests.skip(requestCount)) {
          expect(request.method, 'GET');
          expect(request.url.query, 'date=$today');
        }
        expect(controller.state.quarterlyAuditDate, today);
        expect(controller.state.quarterlyAudit?.profileName, 'Bob');
        expect(controller.state.quarterlyAudit?.jobTitle, 'Operator b');
        expect(
          controller.state.quarterlyAudit?.descriptions.map(
            (item) => item.uuid,
          ),
          ['b-first', 'b-second'],
        );
        expect(
          controller.state.selectedQuarterlyAuditDescriptionUuid,
          'b-first',
        );
        expect(controller.descriptionSearchQuery, isEmpty);
        expect(controller.state.mainList?.results, hasLength(3));
        final firstCard = tester.widget<CheckInDescriptionCard>(
          find.byKey(const ValueKey('audit-b:b-first')),
        );
        expect(firstCard.description.great, 2);
        expect(firstCard.description.almostThere, 1);
        expect(firstCard.description.auditUuid, 'resolved-b');
        expect(firstCard.date, today);

        final loadedRequests = requests.length;
        await tester.tap(
          find.byKey(const ValueKey('check-in-team-member-audit-b')),
        );
        await tester.pumpAndSettle();
        expect(requests.length, loadedRequests);

        final descriptionCard = find.byKey(const ValueKey('audit-b:b-first'));
        await tester.ensureVisible(descriptionCard);
        await tester.tap(find.text('b task 1'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SingleDescriptionDetails>(
                find.byType(SingleDescriptionDetails),
              )
              .date,
          today,
        );
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets('call logs include the same date as outgoing details requests', (
    tester,
  ) async {
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      await http.runWithClient(() async {
        final today = CustomFunctions.apiDateString();
        await mount(tester);
        await tester.tap(
          find.byKey(const ValueKey('check-in-team-member-audit-b')),
        );
        await tester.pumpAndSettle();
        final detailsRequests = requests
            .where((request) => request.url.path.endsWith('/details/'))
            .toList();
        expect(detailsRequests, hasLength(2));
        expect(detailsRequests.first.url.query, 'date=$_openedDate');
        expect(detailsRequests.last.url.query, 'date=$today');
        for (final request in detailsRequests) {
          expect(messages, contains('Call ${request.url} 200'));
        }

        final selectedRequest = detailsRequests.last;
        await _controller(
          tester,
        ).loadQuarterlyAuditForDate(quarterlyAuditId: 'audit-b', date: today);
        expect(
          requests.where((request) => request.url == selectedRequest.url),
          hasLength(1),
        );
        expect(
          messages.where(
            (message) => message == 'Call ${selectedRequest.url} 200',
          ),
          hasLength(2),
        );
        expect(messages, hasLength(requests.length + 1));
        ApiCallExecutor.clearGetCache();
        expect(messages, everyElement(startsWith('Call ')));
        expect(tester.takeException(), isNull);
      }, () => client);
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  testWidgets(
    'the reported details display while the first description request is pending',
    (tester) async {
      final pending = Completer<http.Response>();
      final date = CustomFunctions.apiDateString();
      final descriptionEndpoint = ApiEndPoints.quarterlyAuditDescriptionAudit(
        quarterlyAuditId: _reportedAuditUuid,
        descriptionId: _reportedDescriptionUuid,
      );
      await http.runWithClient(() async {
        await mount(tester, date: date);
        final controller = _controller(tester);
        final requestCount = requests.length;
        intercept = (request) async {
          if (request.url.path.endsWith(
            ApiEndPoints.quarterlyAuditDetail('audit-b'),
          )) {
            return http.Response(
              jsonEncode(_reportedDetails),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path.contains('/descriptions/')) {
            return pending.future;
          }
          return null;
        };
        await tester.tap(
          find.byKey(const ValueKey('check-in-team-member-audit-b')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        try {
          expect(controller.state.isLoading, isFalse);
          expect(controller.state.quarterlyAudit?.uuid, _reportedAuditUuid);
          expect(find.text('Frontend dev'), findsOneWidget);
          expect(find.text('Haseem Assistant'), findsOneWidget);
          expect(find.text('Collaborates on UI Design'), findsOneWidget);
          expect(
            requests.skip(requestCount).map((request) => request.url.path),
            [
              endsWith(ApiEndPoints.quarterlyAuditDetail('audit-b')),
              endsWith(descriptionEndpoint),
            ],
          );
          for (final request in requests.skip(requestCount)) {
            expect(request.url.query, 'date=$date');
          }
        } finally {
          pending.complete(http.Response('{}', 400));
          await tester.pumpAndSettle();
        }
        expect(controller.state.quarterlyAudit?.uuid, _reportedAuditUuid);
        expect(find.text('Collaborates on UI Design'), findsOneWidget);
        expect(
          find.text(AppStrings.auditUnableToLoadDescriptionDetails),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets('member description count objects keep the rendered ratings', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    const counts = {'great': 7, 'almost_there': 3, 'needs_improvement': 2};
    final details = _audit('b');
    final descriptions = details['descriptions']! as List;
    (descriptions.first as Map)['audit_details'] = {
      ...counts,
      'has_audit': true,
      'audit_uuid': 'summary-b-0',
    };
    await http.runWithClient(() async {
      await mount(tester);
      intercept = (request) async {
        if (request.url.path.endsWith(
          ApiEndPoints.quarterlyAuditDetail('audit-b'),
        )) {
          return http.Response(jsonEncode(details), 200);
        }
        if (request.url.path.endsWith(_descriptionEndpoint('b'))) {
          return pending.future;
        }
        return null;
      };
      await tester.tap(
        find.byKey(const ValueKey('check-in-team-member-audit-b')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final firstCard = find.byKey(const ValueKey('audit-b:b-first'));
      void expectRenderedCounts() {
        expect(
          tester.widget<CheckInDescriptionCard>(firstCard).description.great,
          7,
        );
        for (final count in counts.values) {
          expect(
            find.descendant(of: firstCard, matching: find.text('$count')),
            findsOneWidget,
          );
        }
      }

      try {
        expectRenderedCounts();
      } finally {
        pending.complete(
          http.Response(
            jsonEncode({'uuid': 'resolved-b', 'audit': counts}),
            200,
          ),
        );
        await tester.pumpAndSettle();
      }
      expectRenderedCounts();
      final description = tester
          .widget<CheckInDescriptionCard>(firstCard)
          .description;
      expect(description.almostThere, 3);
      expect(description.needsImprovement, 2);
      expect(description.auditUuid, 'resolved-b');
      final secondCard = tester.widget<CheckInDescriptionCard>(
        find.byKey(const ValueKey('audit-b:b-second')),
      );
      expect(secondCard.description.great, 77);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  for (final scenario in [
    (name: 'missing', response: <String, Object?>{}, great: 77),
    (name: 'empty', response: <String, Object?>{'audit': {}}, great: 77),
    (
      name: 'partial',
      response: <String, Object?>{
        'audit': {'almost_there': 3},
      },
      great: 77,
    ),
    (
      name: 'zero',
      response: <String, Object?>{
        'audit': {'great': 0, 'almost_there': 0, 'needs_improvement': 0},
      },
      great: 0,
    ),
  ]) {
    testWidgets(
      '${scenario.name} description counts preserve or update the matching card',
      (tester) async {
        await http.runWithClient(() async {
          await mount(tester);
          intercept = (request) async {
            if (request.url.path.endsWith(_descriptionEndpoint('b'))) {
              return http.Response(
                jsonEncode({'uuid': 'resolved-b', ...scenario.response}),
                200,
              );
            }
            return null;
          };
          await tester.tap(
            find.byKey(const ValueKey('check-in-team-member-audit-b')),
          );
          await tester.pumpAndSettle();
          final firstCard = tester.widget<CheckInDescriptionCard>(
            find.byKey(const ValueKey('audit-b:b-first')),
          );
          expect(firstCard.description.great, scenario.great);
          expect(
            firstCard.description.almostThere,
            scenario.name == 'partial' ? 3 : 0,
          );
          expect(firstCard.description.needsImprovement, 0);
          expect(firstCard.description.auditUuid, 'resolved-b');
          final secondCard = tester.widget<CheckInDescriptionCard>(
            find.byKey(const ValueKey('audit-b:b-second')),
          );
          expect(secondCard.description.great, 77);
          expect(tester.takeException(), isNull);
        }, () => client);
      },
    );
  }

  testWidgets('reading an empty description audit keeps its unaudited status', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await mount(tester, date: CustomFunctions.apiDateString());
      final controller = _controller(tester);
      intercept = (request) async {
        if (request.url.path.endsWith(
          ApiEndPoints.quarterlyAuditDetail('audit-b'),
        )) {
          return http.Response(
            jsonEncode(_reportedDetails),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.contains('/descriptions/')) {
          return http.Response(
            jsonEncode({'uuid': _reportedDescriptionAuditUuid, 'audit': []}),
            200,
          );
        }
        return null;
      };
      await tester.tap(
        find.byKey(const ValueKey('check-in-team-member-audit-b')),
      );
      await tester.pumpAndSettle();
      final audit = controller.state.quarterlyAudit!;
      expect(audit.uuid, _reportedAuditUuid);
      expect(audit.categories, hasLength(5));
      expect(audit.descriptions.single.hasAudit, isFalse);
      expect(
        audit.descriptions.single.auditUuid,
        _reportedDescriptionAuditUuid,
      );
      expect(audit.descriptions.single.jobSpecifics, '🤝 TEAM integration');
      expect(find.text('Collaborates on UI Design'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('a delayed description read preserves ratings saved meanwhile', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final date = CustomFunctions.apiDateString();
      await mount(tester, date: date);
      final controller = _controller(tester);
      final member = controller.state.mainList!.results.firstWhere(
        (member) => member.uuid == 'audit-b',
      );
      intercept = (request) async {
        if (request.url.path.endsWith(_descriptionEndpoint('b'))) {
          return pending.future;
        }
        if (request.method == 'PATCH' &&
            request.url.path.endsWith(
              ApiEndPoints.auditDescription('summary-b-0'),
            )) {
          return http.Response(jsonEncode({'uuid': 'summary-b-0'}), 200);
        }
        return null;
      };
      final selection = controller.selectSingleAuditMember(member);
      await tester.pump();
      try {
        expect(controller.state.isLoading, isFalse);
        await controller.submitAuditDescriptionSelection(
          quarterlyAuditId: 'audit-b',
          seatDescriptionId: 'b-first',
          descriptionId: 'summary-b-0',
          audit: {'great': 5, 'almost_there': 0, 'needs_improvement': 0},
        );
      } finally {
        pending.complete(
          http.Response(
            jsonEncode({
              'uuid': 'resolved-b',
              'audit': ['great'],
            }),
            200,
          ),
        );
        await selection;
        await tester.pumpAndSettle();
      }
      expect(controller.state.quarterlyAudit?.descriptions.first.great, 5);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  for (final search in [false, true]) {
    testWidgets(
      'See More selection${search ? ' from search' : ''} loads in place',
      (tester) async {
        await http.runWithClient(() async {
          final today = CustomFunctions.apiDateString();
          final observer = await mount(tester);
          final controller = _controller(tester);
          await tester.tap(find.text(AppStrings.auditSeeMore));
          await tester.pumpAndSettle();
          if (search) {
            await tester.enterText(
              find.descendant(
                of: find.byType(ViewAllTeamMembers),
                matching: find.byType(TextField),
              ),
              'Bob',
            );
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pumpAndSettle();
            expect(controller.state.mainList?.results, hasLength(1));
          }
          final requestCount = requests.length;
          final member = find.byWidgetPredicate(
            (widget) =>
                widget is CheckInMemberCard && widget.member.name == 'Bob',
          );
          final button = find.descendant(
            of: member,
            matching: find.text(AppStrings.checkInTitle),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byType(ViewAllTeamMembers), findsNothing);
          expect(
            observer.pushes,
            2,
          ); // Initial screen and the member dialog only.
          expect(
            requests.skip(requestCount).map((request) => request.url.path),
            [
              endsWith(ApiEndPoints.quarterlyAuditDetail('audit-b')),
              endsWith(_descriptionEndpoint('b')),
            ],
          );
          for (final request in requests.skip(requestCount)) {
            expect(request.method, 'GET');
            expect(request.url.query, 'date=$today');
          }
          expect(controller.state.quarterlyAuditDate, today);
          expect(controller.state.quarterlyAudit?.uuid, 'audit-b');
          expect(controller.teamMembersSearchQuery, isEmpty);
          expect(controller.state.mainList?.results, hasLength(3));
          expect(tester.takeException(), isNull);
        }, () => client);
      },
    );
  }

  testWidgets('members without descriptions skip the second request', (
    tester,
  ) async {
    audits['b'] = {..._audit('b'), 'descriptions': <Object>[]};
    await http.runWithClient(() async {
      await mount(tester);
      final controller = _controller(tester);
      final requestCount = requests.length;
      await tester.tap(
        find.byKey(const ValueKey('check-in-team-member-audit-b')),
      );
      await tester.pumpAndSettle();
      expect(requests.length, requestCount + 1);
      expect(
        requests.last.url.query,
        'date=${CustomFunctions.apiDateString()}',
      );
      expect(controller.state.quarterlyAudit?.uuid, 'audit-b');
      expect(controller.state.selectedQuarterlyAuditDescriptionUuid, isNull);
      expect(find.text(AppStrings.auditNoMatchingDescriptions), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('switching members recalculates self check-in permissions', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await mount(tester);
      await tester.tap(
        find.byKey(const ValueKey('check-in-team-member-audit-c')),
      );
      await tester.pumpAndSettle();
      expect(_controller(tester).state.isSelfAudit, isTrue);
      expect(
        tester
            .widgetList<CheckInDescriptionCard>(
              find.byType(CheckInDescriptionCard),
            )
            .every((card) => card.isSelfAudit),
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('check-in-team-member-audit-b')),
      );
      await tester.pumpAndSettle();
      expect(_controller(tester).state.isSelfAudit, isFalse);
      expect(
        tester
            .widgetList<CheckInDescriptionCard>(
              find.byType(CheckInDescriptionCard),
            )
            .every((card) => !card.isSelfAudit),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  for (final stage in ['details', 'description']) {
    testWidgets(
      'a failed $stage request retains available details and reports the error',
      (tester) async {
        await http.runWithClient(() async {
          await mount(tester);
          intercept = (request) async {
            final endpoint = stage == 'details'
                ? ApiEndPoints.quarterlyAuditDetail('audit-b')
                : _descriptionEndpoint('b');
            return request.url.path.endsWith(endpoint)
                ? http.Response('{}', 400)
                : null;
          };
          await tester.tap(
            find.byKey(const ValueKey('check-in-team-member-audit-b')),
          );
          await tester.pumpAndSettle();
          expect(
            _controller(tester).state.quarterlyAudit?.uuid,
            stage == 'details' ? 'audit-a' : 'audit-b',
          );
          expect(_controller(tester).state.isLoading, isFalse);
          expect(
            _controller(tester).state.quarterlyAuditDate,
            stage == 'details' ? _openedDate : CustomFunctions.apiDateString(),
          );
          expect(
            find.text(
              stage == 'details'
                  ? AppStrings.auditDetailsLoadFailed
                  : AppStrings.auditUnableToLoadDescriptionDetails,
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }, () => client);
      },
    );

    testWidgets(
      'an older $stage response cannot replace a later member selection',
      (tester) async {
        final pending = Completer<http.Response>();
        await http.runWithClient(() async {
          await mount(tester);
          final controller = _controller(tester);
          final members = controller.state.mainList!.results;
          intercept = (request) async {
            final endpoint = stage == 'details'
                ? ApiEndPoints.quarterlyAuditDetail('audit-b')
                : _descriptionEndpoint('b');
            return request.url.path.endsWith(endpoint) ? pending.future : null;
          };
          final olderSelection = controller.selectSingleAuditMember(
            members.firstWhere((member) => member.uuid == 'audit-b'),
          );
          await tester.pump();
          expect(controller.state.isLoading, stage == 'details');
          await controller.selectSingleAuditMember(
            members.firstWhere((member) => member.uuid == 'audit-c'),
          );
          pending.complete(
            http.Response(
              jsonEncode(
                stage == 'details' ? audits['b'] : _specificAudit('b'),
              ),
              200,
            ),
          );
          await olderSelection;
          await tester.pumpAndSettle();
          expect(controller.state.quarterlyAudit?.uuid, 'audit-c');
          expect(
            controller.state.selectedQuarterlyAuditDescriptionUuid,
            'c-first',
          );
          expect(
            requests.where(
              (request) => request.url.path.endsWith(_descriptionEndpoint('b')),
            ),
            hasLength(stage == 'details' ? 0 : 1),
          );
          expect(tester.takeException(), isNull);
        }, () => client);
      },
    );
  }
}

CheckInController _controller(WidgetTester tester) => tester
    .element(find.byType(CheckInDescriptionCard).first)
    .read<CheckInController>();

String _descriptionEndpoint(String id) =>
    ApiEndPoints.quarterlyAuditDescriptionAudit(
      quarterlyAuditId: 'audit-$id',
      descriptionId: '$id-first',
    );

Map<String, Object?> _member(String id) => {
  'uuid': 'audit-$id',
  'profile_job': 'profile-job-$id',
  'profile': {
    'uuid': id == 'c' ? 'reviewer' : 'profile-$id',
    'name': switch (id) {
      'a' => 'Alice',
      'b' => 'Bob',
      _ => 'Reviewer',
    },
    'onboarded': true,
  },
  'job': {'uuid': 'seat-$id', 'title': 'Operator $id'},
  'last_audit_date': _openedDate,
};

Map<String, Object?> _audit(String id) => {
  ..._member(id),
  'categories': [
    {'uuid': 'category', 'category_title': 'Responsibilities'},
  ],
  'descriptions': List.generate(
    2,
    (index) => {
      'uuid': '$id-${index == 0 ? 'first' : 'second'}',
      'category': 'category',
      'description': '$id task ${index + 1}',
      'audit_details': {
        'has_audit': true,
        'audit_uuid': 'summary-$id-$index',
        'great': 77,
      },
    },
  ),
};

Map<String, Object?> _specificAudit(String id) => {
  'uuid': 'resolved-$id',
  'audit': ['great', 'great', 'almost_there'],
};

class _NavigationObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

const _reportedAuditUuid = '6b10b11b-ad45-435e-90cc-c426e4510808';
const _reportedDescriptionUuid = 'c76fbd8a-1a48-4604-ac0e-08466a90732c';
const _reportedDescriptionAuditUuid = 'd6b34293-907f-4f20-bbe4-fd867b78e623';

// The reported response, with the remote avatar omitted for widget testing.
const _reportedDetails = {
  'uuid': _reportedAuditUuid,
  'is_open_seat': false,
  'job': {
    'uuid': '48b7e158-c1d8-4c4f-aa7b-cf28928c82e3',
    'title': 'Frontend dev',
  },
  'profile': {
    'uuid': '2095f56d-0917-403a-b3aa-b98405460dcd',
    'name': 'Haseem Assistant',
    'user_uuid': 'ccaf92a0-a5da-4227-a8b6-e1f136a75c3d',
    'email': 'haseemhussain761@gmail.com',
    'onboarded': true,
  },
  'profile_job': '8b131d82-b6ab-452b-9fa8-b88755843e52',
  'mismatch': false,
  'categories': [
    {
      'uuid': '74ebecaa-ff75-4ec0-94c3-9724d3f9be7f',
      'category_title': 'UI Development',
    },
    {
      'uuid': '8fcd8c65-7354-4b50-8a09-063cef632ab1',
      'category_title': 'Code Maintenance',
    },
    {
      'uuid': '882c5cac-05be-46e8-a60d-865b40e7d767',
      'category_title': 'Testing Debugging',
    },
    {
      'uuid': 'e0807e7a-1c60-4138-8dec-fd9fad9bba72',
      'category_title': 'Cross-team Collaboration',
    },
    {
      'uuid': '888e34f5-cf86-4ce2-bb91-c82e87446467',
      'category_title': 'Documentation Writing',
    },
  ],
  'descriptions': [
    {
      'uuid': _reportedDescriptionUuid,
      'category': '74ebecaa-ff75-4ec0-94c3-9724d3f9be7f',
      'training_route': {
        'category': '2f557c8b-74e0-4469-a83e-940f0a1e2e9b',
        'description': '1daf0e02-c4da-4709-89e3-9f40208f34f5',
      },
      'is_mirror': false,
      'description': 'Collaborates on UI Design',
      'job_specifics': '🤝 TEAM integration',
      'audit_details': {
        'great': 0,
        'needs_improvement': 0,
        'almost_there': 0,
        'has_audit': false,
        'audit_uuid': _reportedDescriptionAuditUuid,
      },
      'milestone_day': '60',
      'last_audit_date': null,
      'confidence_level': 0.0,
      'audit_factor_type': 'interview',
    },
  ],
};
