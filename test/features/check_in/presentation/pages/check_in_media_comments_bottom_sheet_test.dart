import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/presentation/pages/check_in_media_comments_bottom_sheet.dart';

void main() {
  final saved = <Map<String, dynamic>>[];
  var replies = <Map<String, Object?>>[];
  final client = MockClient((request) async {
    if (request.method == 'PUT') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      saved.add(body);
      replies.add(_comment('added', body['comment'] as String));
      return http.Response(jsonEncode(replies.last), 200);
    }
    return http.Response(
      jsonEncode({
        'uuid': 'media',
        'comments': [_comment('parent', 'Observation', replies: replies)],
        'total_comments': 1,
      }),
      200,
    );
  });
  tearDownAll(client.close);

  setUp(() async {
    saved.clear();
    replies = [_comment('reply', 'Existing reply')];
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('token');
    ApiCallExecutor.clearGetCache();
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets(
      'replies expand, cancel and send through the rendered sheet ($scale)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await http.runWithClient(() async {
          await tester.pumpWidget(_screen(canReply: true, scale: scale));
          await tester.pumpAndSettle();
          expect(find.text('Observation'), findsOneWidget);
          expect(find.text('Existing reply'), findsNothing);
          await _tap(tester, find.text(AppStrings.auditMediaShowReplies(1)));
          expect(find.text('Existing reply'), findsOneWidget);

          await _tap(tester, find.text(AppStrings.actionReply));
          expect(
            find.text(AppStrings.auditMediaReplyingTo('Author')),
            findsOneWidget,
          );
          await _tap(tester, find.text(AppStrings.actionCancel));
          expect(
            find.text(AppStrings.auditMediaReplyingTo('Author')),
            findsNothing,
          );
          await _tap(tester, find.text(AppStrings.actionReply));
          await tester.enterText(find.byType(TextField), 'New reply');
          await _tap(tester, find.byIcon(Icons.send_rounded));
          expect(saved.single, {'comment': 'New reply', 'parent': 'parent'});
          expect(find.text('New reply'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }

  testWidgets(
    'read-only media remains visible without reply, delete or upload actions',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_screen(canReply: false));
        await tester.pumpAndSettle();
        expect(find.text('Observation'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.text(AppStrings.auditDelete), findsNothing);
        expect(find.text(AppStrings.auditMediaUploadPrompt), findsNothing);
        expect(saved, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}

Widget _screen({required bool canReply, double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: CheckInMediaCommentsBottomSheet(
      descriptionId: 'description',
      selectedMedia: const AuditDescriptionMedia(
        uuid: 'media',
        media: '',
        type: '',
        comment: null,
        unreadCount: 0,
      ),
      mediaList: const [],
      onMediaChanged: () async {},
      isReadOnly: true,
      canReply: canReply,
    ),
  ),
);

Map<String, Object?> _comment(
  String id,
  String text, {
  List<Map<String, Object?>> replies = const [],
}) => {
  'uuid': id,
  'comment': text,
  'created_at': DateTime.now().toIso8601String(),
  'author': {'uuid': 'author', 'name': 'Author', 'email': 'author@example.com'},
  'replies': replies,
};

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
