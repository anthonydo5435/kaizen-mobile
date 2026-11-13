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
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';
import 'package:sparrowkaizen/features/compliance/data/datasources/compliance_remote_data_source.dart';
import 'package:sparrowkaizen/features/compliance/data/repositories/compliance_repository_impl.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/compliance_tab_type.dart';
import 'package:sparrowkaizen/features/compliance/domain/usecases/get_compliance_documents_usecase.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/compliance_screen.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_document_controller.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/document_card.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';

void main() {
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) respondToSearch;
  final client = MockClient((request) async {
    requests.add(request);
    if (!request.url.queryParameters.containsKey('name')) {
      return _documentResponse('Original Document');
    }
    return respondToSearch(request);
  });

  setUp(() async {
    requests.clear();
    respondToSearch = (_) async =>
        _documentResponse('Server Result', definition: true);
    ApiCallExecutor.clearGetCache();
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
    final user = User(uuid: 'member', organizationUuid: 'org');
    await AppPreference.saveUser(user);
    AppManager.instance.updateCurrentUser(user);
  });
  tearDown(AppManager.instance.resetSessionState);
  tearDownAll(client.close);

  testWidgets('typing calls the document-type API only after 400 ms idle', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      final field = find.byType(TextField);
      final controller = tester
          .element(field)
          .read<ComplianceDocumentController>();
      expect(find.text('Original Document'), findsOneWidget);
      expect(find.byTooltip(AppStrings.clearSearch), findsNothing);
      expect(
        requests.single.url.path,
        endsWith('/document_compliance_assignments/my_document_compliances/'),
      );

      await tester.enterText(field, 'w');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(field, 'wa');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(field, 'wait');
      await tester.pump(const Duration(milliseconds: 399));
      expect(requests, hasLength(1));
      expect(
        find.byTooltip(AppStrings.clearSearch).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.element(field).read<ComplianceDocumentController>(),
        same(controller),
      );

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.last.url.path, endsWith('/compliance/document_type/'));
      expect(requests.last.url.queryParameters, {
        'name': 'wait',
        'page': '1',
        'page_size': '10',
      });
      expect(find.text('Server Result'), findsOneWidget);
      expect(find.text('Original Document'), findsNothing);

      await tester.enterText(field, ' wait & Safety ');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['name'], 'wait & Safety');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets(
    'clear cancels pending search and restores the original listing',
    (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester);
        await tester.enterText(find.byType(TextField), 'wait');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.byTooltip(AppStrings.clearSearch));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        expect(find.text('Original Document'), findsOneWidget);
        expect(find.byTooltip(AppStrings.clearSearch), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  testWidgets('clear stays available while loading and ignores a late result', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    respondToSearch = (_) => response.future;
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'wait');
      await tester.pump(const Duration(milliseconds: 400));
      expect(requests, hasLength(2));
      expect(find.byType(FastCircularProgressIndicator), findsOneWidget);
      expect(
        find.byTooltip(AppStrings.clearSearch).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(AppStrings.clearSearch));
      await tester.pumpAndSettle();
      expect(find.text('Original Document'), findsOneWidget);
      response.complete(_documentResponse('Late Result', definition: true));
      await tester.pumpAndSettle();
      expect(find.text('Original Document'), findsOneWidget);
      expect(find.text('Late Result'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('an older search cannot replace the latest search results', (
    tester,
  ) async {
    final older = Completer<http.Response>();
    final newer = Completer<http.Response>();
    respondToSearch = (request) => request.url.queryParameters['name'] == 'wait'
        ? older.future
        : newer.future;
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'wait');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'safety');
      await tester.pump(const Duration(milliseconds: 400));
      newer.complete(_documentResponse('Newest Result', definition: true));
      await tester.pumpAndSettle();
      older.complete(_documentResponse('Old Result', definition: true));
      await tester.pumpAndSettle();
      expect(find.text('Newest Result'), findsOneWidget);
      expect(find.text('Old Result'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets(
    'repeating a search fetches fresh results instead of cached results',
    (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester);
        await tester.enterText(find.byType(TextField), 'wait');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(AppStrings.clearSearch));
        await tester.pumpAndSettle();
        respondToSearch = (_) async =>
            _documentResponse('Fresh Result', definition: true);
        await tester.enterText(find.byType(TextField), 'wait');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(
          requests.where(
            (request) => request.url.queryParameters['name'] == 'wait',
          ),
          hasLength(2),
        );
        expect(find.text('Fresh Result'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  test(
    'search decodes document types and retains assigned-document metadata',
    () async {
      await http.runWithClient(() async {
        final useCase = GetComplianceDocumentsUseCase(
          ComplianceRepositoryImpl(ComplianceRemoteDataSource()),
        );
        respondToSearch = (_) async => _documentResponse(
          'Expiry Required Result',
          definition: true,
          requiresExpiry: true,
        );
        final types = await useCase(name: 'wait', forceRefresh: true);
        expect(types.single.hasExpiry, isTrue);
        expect(types.single.seatProfiles, ['QA']);

        respondToSearch = (_) async => _documentResponse('Assigned Result');
        final assignments = await useCase(name: 'safety', forceRefresh: true);
        expect(assignments.single.latestDocumentReason, 'Missing signature');
        expect(assignments.single.latestDocumentExpiryDate, '2027-04-05');
      }, () => client);
    },
  );

  testWidgets('search failures display feedback and clear recovers the list', (
    tester,
  ) async {
    respondToSearch = (_) async => http.Response('{}', 500);
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'wait');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.complianceDocumentSearchFailed),
        findsOneWidget,
      );
      expect(find.text(AppStrings.complianceNoDocumentsFound), findsNothing);
      await tester.tap(find.byTooltip(AppStrings.clearSearch));
      await tester.pumpAndSettle();
      expect(find.text('Original Document'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('empty search results display No Documents Found', (
    tester,
  ) async {
    respondToSearch = (_) async =>
        http.Response(jsonEncode({'results': []}), 200);
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'wait');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.complianceNoDocumentsFound), findsOneWidget);
      expect(find.byType(DocumentCard), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('refresh preserves the query and seat-profile filter', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      final controller = tester
          .element(find.byType(TextField))
          .read<ComplianceDocumentController>();
      controller.updateSelectedSeatProfiles({'QA'});
      await tester.enterText(find.byType(TextField), 'wait');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      respondToSearch = (_) async => _documentResponse(
        'Refreshed Result',
        definition: true,
        includeOtherSeat: true,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 450));
      await tester.pumpAndSettle();
      expect(
        requests.where(
          (request) => request.url.queryParameters['name'] == 'wait',
        ),
        hasLength(2),
      );
      expect(find.text('Refreshed Result'), findsOneWidget);
      expect(find.text('Other Seat Result'), findsNothing);
      expect(controller.selectedSeatProfiles, {'QA'});
      expect(controller.searchController.text, 'wait');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('leaving cancels debounce and ignores in-flight responses', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'wait');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
      expect(requests, hasLength(1));

      final response = Completer<http.Response>();
      respondToSearch = (_) => response.future;
      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'wait');
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        requests.where(
          (request) => request.url.queryParameters['name'] == 'wait',
        ),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(_documentResponse('Late Result', definition: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppManager>.value(
      value: AppManager.instance,
      child: const MaterialApp(
        home: ComplianceScreen(module: ComplianceTabType.document),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

http.Response _documentResponse(
  String name, {
  bool definition = false,
  bool requiresExpiry = false,
  bool includeOtherSeat = false,
}) => http.Response(
  jsonEncode({
    'count': includeOtherSeat ? 2 : 1,
    'next': null,
    'previous': null,
    'results': [
      {
        'uuid': name,
        'name': name,
        'jobs': [
          {'title': 'QA'},
        ],
        if (definition) ...{
          'expiry': requiresExpiry,
          'all_jobs': false,
        } else ...{
          'has_expiry': false,
          'status': 'compliant',
          'latest_document': {
            'status': 'rejected',
            'reason': 'Missing signature',
            'expiry_date': '2027-04-05',
          },
        },
      },
      if (includeOtherSeat)
        {
          'uuid': 'other-seat',
          'name': 'Other Seat Result',
          'jobs': [
            {'title': 'Operations'},
          ],
          'expiry': false,
          'all_jobs': false,
        },
    ],
  }),
  200,
);
