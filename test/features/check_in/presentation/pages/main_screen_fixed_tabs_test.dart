import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_bottom_nav_bar.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_member_status.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/performance_snapshot_screen.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/performance_snapshot_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/widgets/check_in_member_card.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
    final user = User(
      uuid: 'lead',
      roles: ['dept_lead'],
      organizationUuid: 'org',
    );
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
  });
  tearDown(AppManager.instance.resetSessionState);

  for (final performance in [false, true]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        '${performance ? 'Performance' : 'Check-in'} tabs remain fixed while content scrolls ($textScale)',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final client = MockClient(
            (_) async => http.Response(jsonEncode(_page), 200),
          );
          addTearDown(client.close);

          await http.runWithClient(() async {
            await tester.pumpWidget(
              ChangeNotifierProvider<AppManager>.value(
                value: AppManager.instance,
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(textScale),
                      padding: const EdgeInsets.only(top: 44, bottom: 34),
                      viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
                    ),
                    child: child!,
                  ),
                  home: performance
                      ? const PerformanceSnapshotScreen()
                      : const CheckInScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final tab = find.text(
              performance
                  ? AppStrings.myReportsTitle
                  : AppStrings.auditMyCheckInsTab,
            );
            final tabBounds = tester.getRect(tab);
            final listing = find.byType(ListView).first;
            expect(find.descendant(of: listing, matching: tab), findsNothing);
            expect(find.byType(CheckInMemberCard), findsWidgets);
            final scrollable = find
                .descendant(of: listing, matching: find.byType(Scrollable))
                .first;
            final position = tester.state<ScrollableState>(scrollable).position;

            await tester.drag(listing, const Offset(0, -300));
            await tester.pumpAndSettle();
            expect(position.pixels, greaterThan(0));
            expect(tester.getRect(tab), tabBounds);
            expect(tab.hitTestable(), findsOneWidget);

            // Variable-height cards refine the estimated extent as the end mounts.
            for (var attempt = 0; attempt < 3; attempt++) {
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
            }
            expect(tester.getRect(tab), tabBounds);
            expect(
              tester.getRect(find.byType(CheckInMemberCard).last).bottom,
              lessThanOrEqualTo(
                tester.getRect(find.byType(AppBottomNavBar)).top - 12,
              ),
            );

            await tester.tap(tab);
            await tester.pumpAndSettle();
            final context = tester.element(listing);
            if (performance) {
              expect(
                context.read<PerformanceSnapshotController>().selectedTab,
                PerformanceSnapshotTab.myReports,
              );
            } else {
              expect(
                context.read<CheckInController>().state.selectedStatus,
                AuditMemberStatus.deactivated,
              );
            }
            expect(tester.getRect(tab), tabBounds);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }, () => client);
        },
      );
    }
  }
}

final _page = {
  'count': 30,
  'current': 1,
  'next': null,
  'previous': null,
  'results': List.generate(
    30,
    (index) => {
      'uuid': 'audit-$index',
      'profile_job': 'profile-job-$index',
      'profile': {
        'uuid': 'profile-$index',
        'name': 'Member $index',
        'onboarded': true,
      },
      'job': {'uuid': 'job-$index', 'title': 'Seat $index'},
      'overall_score': 4,
      'confidence_level': 80,
    },
  ),
};
