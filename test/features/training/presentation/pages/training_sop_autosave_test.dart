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
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/training/domain/entities/seat_description_training_route.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/pages/edit_training_screen.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_sop_document_view.dart';

import '../../fixtures/tiptap_sop_fixture.dart';

void main() {
  final writes = <http.Request>[];
  final client = MockClient((request) async {
    if (request.method != 'GET') {
      writes.add(request);
      return http.Response('', 204);
    }
    final endpoint = request.url.path.replaceFirst(ApiEndPoints.version, '');
    final Object response;
    if (endpoint == ApiEndPoints.seatDescriptionTrainingModules('description')) {
      response = [
        {'uuid': 'lesson', 'title': 'Lesson'},
      ];
    } else if (endpoint == ApiEndPoints.trainingModuleDetail('lesson')) {
      response = {'uuid': 'lesson', 'title': 'Lesson'};
    } else if (endpoint == ApiEndPoints.trainingModuleDocument('lesson')) {
      response = {'uuid': 'document', 'text': '<p>Procedure</p>'};
    } else if (endpoint == ApiEndPoints.lmsPublicLink('description')) {
      response = {'active': false};
    } else {
      throw StateError('Unexpected request: $endpoint');
    }
    return http.Response(jsonEncode(response), 200, headers: {'content-type': 'application/json'});
  });
  tearDownAll(client.close);

  Future<TiptapSopFixture> openSop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'owner', isOwner: true, organizationUuid: 'org-id'),
    );
    ApiCallExecutor.clearGetCache();
    addTearDown(AppManager.instance.resetSessionState);
    addTearDown(ApiCallExecutor.clearGetCache);
    writes.clear();
    final fixture = TiptapSopFixture();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppManager>.value(value: AppManager.instance),
          Provider<TrainingSopEditorFactory>.value(value: fixture.create),
        ],
        child: const MaterialApp(
          home: EditTrainingScreen(
            trainingRoute: SeatDescriptionTrainingRoute(
              job: 'seat',
              category: 'category',
              description: 'description',
            ),
            canManageTraining: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_tab(AppStrings.trainingSopTab));
    // The native editor's caret continuously animates, so pump bounded frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(TrainingSopDocumentView), findsOneWidget);
    expect(fixture.editors.single.html, '<p>Procedure</p>');
    expect(writes, isEmpty);
    return fixture;
  }

  testWidgets('SOP toolbar edits autosave HTML and Done does not flush the debounce', (
    tester,
  ) async {
    await http.runWithClient(() async {
      final fixture = await openSop(tester);
      await tester.tap(find.byTooltip(AppStrings.trainingBoldAction));
      await tester.pump();
      await tester.tap(find.byTooltip(AppStrings.done));
      await tester.pump();
      expect(fixture.editors.single.keyboardDismissals, 0);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.tap(find.byTooltip(AppStrings.done));
      await tester.pump();
      expect(fixture.editors.single.keyboardDismissals, 1);
      expect(writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 349));
      expect(writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(writes, hasLength(1));
      expect(writes.single.method, 'PATCH');
      expect(
        writes.single.url.path,
        '${ApiEndPoints.version}${ApiEndPoints.trainingDocument('document')}',
      );
      expect(jsonDecode(writes.single.body), {
        'uuid': 'document',
        'text': '<p><strong>Procedure</strong></p>',
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(fixture.editors.single.disposed, isTrue);
    }, () => client);
  });

  testWidgets('pending SOP HTML survives switching tabs and the engine is reused', (tester) async {
    await http.runWithClient(() async {
      final fixture = await openSop(tester);
      final pendingHtml = Completer<String>();
      fixture.editors.single.nextHtml = pendingHtml.future;
      await tester.tap(find.byTooltip(AppStrings.trainingBoldAction));
      await tester.pump();
      await tester.tap(_tab(AppStrings.trainingVideoTab));
      await tester.pumpAndSettle();
      expect(fixture.editors.single.disposed, isFalse);
      expect(writes, isEmpty);
      pendingHtml.complete('<p><strong>Procedure</strong></p>');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(writes, hasLength(1));
      await tester.tap(_tab(AppStrings.trainingSopTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byType(TrainingSopDocumentView), findsOneWidget);
      expect(fixture.editors, hasLength(1));
      expect(fixture.editors.single.initializationCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(TrainingTabs), matching: find.text(label));
