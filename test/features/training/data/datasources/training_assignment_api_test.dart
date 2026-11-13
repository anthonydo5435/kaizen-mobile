import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/network/api_endpoints.dart';
import 'package:sparrowkaizen/core/network/api_processor.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/features/training/data/datasources/training_library_remote_data_source.dart';
import 'package:sparrowkaizen/features/training/data/repositories/training_library_repository_impl.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_module_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
  });

  for (final identifier in <Map<String, dynamic>>[
    {'uuid': 'assignment'},
    {'id': 42},
  ]) {
    testWidgets('assignment content edits debounce a PATCH using $identifier', (
      tester,
    ) async {
      final api = _AssignmentApi(identifier);
      final controller = TrainingModuleController(
        TrainingLibraryRepositoryImpl(
          TrainingLibraryRemoteDataSource(apiCallExecutor: api),
        ),
        canManageTraining: true,
      );
      addTearDown(controller.dispose);
      await controller.initialize(jobId: 'seat', descriptionId: 'description');
      await controller.loadAssignmentForSelectedModule();
      await tester.pump(const Duration(seconds: 1));
      expect(api.writes, isEmpty);

      controller.assignmentDescriptionController.text = 'First edit';
      await tester.pump(const Duration(milliseconds: 300));
      controller.assignmentDescriptionController.loadFromHtml(
        '<p><strong>Latest edit</strong></p>',
      );
      await tester.pump(const Duration(milliseconds: 399));
      expect(api.writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));

      expect(api.writes, hasLength(1));
      expect(api.writes.single.method, ApiCallType.patch);
      final assignmentId = identifier.values.single;
      expect(api.writes.single.endpoint, 'training_assignment/$assignmentId/');
      expect(api.writes.single.parameters, {
        'instructions': '<strong>Latest edit</strong>',
      });
      expect(controller.hasAssignmentChanges, isFalse);
      expect(controller.summarySnackBarMessage, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(api.writes, hasLength(1));
    });
  }
}

class _AssignmentApi extends ApiCallExecutor {
  _AssignmentApi(this.identifier);

  final Map<String, dynamic> identifier;
  final writes =
      <
        ({
          ApiCallType method,
          String endpoint,
          Map<String, dynamic>? parameters,
        })
      >[];

  @override
  Future<Response> processApi<Response>({
    required ApiCallType apiCallType,
    required String endpoint,
    required Response Function(dynamic json) decoder,
    Map<String, dynamic>? parameters,
    Map<String, String>? headers,
    String? authToken,
    bool allowAutoRefresh = true,
    bool allowConflictRetry = true,
    bool invalidateCacheBeforeRequest = false,
  }) async {
    if (apiCallType != ApiCallType.get) {
      writes.add((
        method: apiCallType,
        endpoint: endpoint,
        parameters: parameters,
      ));
      return decoder(null);
    }
    if (endpoint ==
        ApiEndPoints.seatDescriptionTrainingModules('description')) {
      return decoder([
        {'uuid': 'module', 'title': 'Lesson'},
      ]);
    }
    if (endpoint == ApiEndPoints.trainingModuleDetail('module')) {
      return decoder({'uuid': 'module', 'title': 'Lesson'});
    }
    if (endpoint == ApiEndPoints.trainingModuleAssignment('module')) {
      return decoder({
        ...identifier,
        'title': 'Practice',
        'instructions': '<p>Original instructions</p>',
      });
    }
    throw StateError('Unexpected request: $endpoint');
  }
}
