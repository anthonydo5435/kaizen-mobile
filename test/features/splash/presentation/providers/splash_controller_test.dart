import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/network/api_error.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/deep_link_service.dart';
import 'package:sparrowkaizen/features/login/data/datasources/auth_remote_data_source.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/splash/presentation/providers/splash_controller.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    await AppPreference.setAuthToken('test-token');
    AppManager.instance.resetSessionState();
  });
  tearDown(() async {
    await DeepLinkService.instance.dispose();
    AppManager.instance.resetSessionState();
  });

  final failures = <String, Object>{
    'HTML response': ApiError.requestFailed(
      502,
      message: '<!DOCTYPE html><html><body>Bad Gateway</body></html>',
    ),
    'long API diagnostic': ApiError.requestFailed(
      500,
      message: List.filled(1000, 'Internal server diagnostic').join('\n'),
    ),
    'JSON parsing exception': const FormatException(
      'Unexpected character',
      '<html><body>Server unavailable</body></html>',
    ),
    'unexpected exception': StateError('Internal startup details'),
    'HTTP status error': ApiError.requestFailed(503),
    'invalid response': const ApiError.invalidResponse(),
  };
  for (final failure in failures.entries) {
    testWidgets('${failure.key} shows only the friendly startup message', (
      tester,
    ) async {
      final datasource = _FailingAuthRemoteDataSource(failure.value);
      final controller = SplashController(authRemoteDataSource: datasource);
      addTearDown(controller.dispose);
      final context = await _pumpContext(tester);

      final operation = controller.initialize(context);
      await tester.pump(const Duration(seconds: 2));
      await operation;

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, AppStrings.splashStartupFailed);
      expect(AppPreference.getAuthToken(), 'test-token');
      expect(datasource.calls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final message in [
    AppStrings.apiUnableToConnectServer,
    AppStrings.apiRequestTimedOut,
  ]) {
    testWidgets('startup preserves the known network message: $message', (
      tester,
    ) async {
      final controller = SplashController(
        authRemoteDataSource: _FailingAuthRemoteDataSource(
          ApiError.requestFailed(0, message: message),
        ),
      );
      addTearDown(controller.dispose);
      final context = await _pumpContext(tester);

      final operation = controller.initialize(context);
      await tester.pump(const Duration(seconds: 2));
      await operation;

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, message);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retry clears the old error and repeats startup', (tester) async {
    final datasource = _FailingAuthRemoteDataSource(
      ApiError.requestFailed(502, message: '<html>Bad Gateway</html>'),
    );
    final controller = SplashController(authRemoteDataSource: datasource);
    addTearDown(controller.dispose);
    final context = await _pumpContext(tester);
    final operation = controller.initialize(context);
    await tester.pump(const Duration(seconds: 2));
    await operation;
    expect(controller.errorMessage, AppStrings.splashStartupFailed);

    datasource.error = ApiError.requestFailed(
      0,
      message: AppStrings.apiRequestTimedOut,
    );
    final retry = controller.retry(context);
    expect(controller.isLoading, isTrue);
    expect(controller.errorMessage, isNull);
    await retry;

    expect(datasource.calls, 2);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, AppStrings.apiRequestTimedOut);
    expect(AppPreference.getAuthToken(), 'test-token');
    expect(tester.takeException(), isNull);
  });
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (value) {
          context = value;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return context;
}

class _FailingAuthRemoteDataSource extends Fake
    implements AuthRemoteDataSource {
  _FailingAuthRemoteDataSource(this.error);

  Object error;
  int calls = 0;

  @override
  Future<User> fetchUserDetail({required String accessToken}) async {
    calls++;
    throw error;
  }
}
