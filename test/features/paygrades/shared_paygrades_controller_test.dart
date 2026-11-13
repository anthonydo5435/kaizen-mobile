import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/paygrades/data/models/shared_paygrades_content_model.dart';
import 'package:sparrowkaizen/features/paygrades/domain/entities/shared_paygrades_content.dart';
import 'package:sparrowkaizen/features/paygrades/domain/usecases/get_paygrades_usecase.dart';
import 'package:sparrowkaizen/features/paygrades/presentation/providers/paygrade_detail_controller.dart';

import 'shared_paygrades_fixture.dart';

void main() {
  late _SharedUseCase useCase;
  late PaygradeDetailController controller;
  final content = SharedPaygradesContentModel.fromApiJson(
    sharedPaygradesJson(),
  );

  setUp(() {
    useCase = _SharedUseCase();
    controller = PaygradeDetailController(useCase);
  });
  tearDown(() => controller.dispose());

  test(
    'switching tabs during and after loading uses one shared request',
    () async {
      final loading = controller.initializeShared('public-id');
      expect(controller.isLoading, isTrue);
      await controller.selectTab(PaygradeDetailTab.ancillary);
      useCase.requests.single.complete(content);
      await loading;
      expect(controller.detail?.payGrades.single.payRate, '50.00');
      await controller.selectTab(PaygradeDetailTab.primary);
      expect(controller.detail?.payGrades, hasLength(3));
      expect(controller.payRateLabel, 'Pay Rate (HR)');
      expect(useCase.ids, ['public-id']);
      expect(controller.isLoading, isFalse);
    },
  );

  test('failed shared requests can retry the same public endpoint', () async {
    final loading = controller.initializeShared('public-id');
    useCase.requests.single.completeError(StateError('expired link'));
    await loading;
    expect(controller.errorMessage, AppStrings.sharedPaygradesUnableToLoad);
    final retry = controller.retry();
    useCase.requests.last.complete(content);
    await retry;
    expect(controller.errorMessage, isNull);
    expect(controller.detail?.payGrades, hasLength(3));
    expect(useCase.ids, ['public-id', 'public-id']);
  });

  test('old link responses cannot replace a newer link', () async {
    final firstLoad = controller.initializeShared('old-link');
    final secondLoad = controller.initializeShared('new-link');
    useCase.requests.last.complete(content);
    await secondLoad;
    useCase.requests.first.completeError(StateError('old error'));
    await firstLoad;
    expect(controller.errorMessage, isNull);
    expect(controller.detail?.title, content.primary.title);
  });

  test(
    'shared mode blocks generation, creation, updates and deletion',
    () async {
      final loading = controller.initializeShared('public-id');
      useCase.requests.single.complete(content);
      await loading;
      final entry = controller.detail!.payGrades.first;
      expect(
        await controller.generatePaygradesWithAi(numPaygrades: 3),
        isFalse,
      );
      await controller.createPaygrade(
        title: 'new',
        description: '',
        promotionRequirement: '',
      );
      await controller.updatePaygrade(
        entry: entry,
        title: 'changed',
        description: '',
        promotionRequirement: '',
      );
      expect(await controller.deletePaygrade(entry), isFalse);
      expect(controller.canEditPayRate(entry), isFalse);
      await expectLater(
        controller.updatePayRate(entry: entry, payRate: '10'),
        throwsStateError,
      );
      // Unimplemented write methods on the fake throw if a guard is bypassed.
      expect(controller.detail!.payGrades.first.title, 'A1');
      expect(controller.detail!.payGrades, hasLength(3));
    },
  );

  test('empty IDs show an error without making a request', () async {
    await controller.initializeShared(' ');
    expect(controller.errorMessage, AppStrings.sharedPaygradesUnableToLoad);
    expect(controller.isLoading, isFalse);
    expect(useCase.requests, isEmpty);
  });

  test('closing the screen ignores an in-flight shared response', () async {
    final closingController = PaygradeDetailController(useCase);
    final loading = closingController.initializeShared('public-id');
    closingController.dispose();
    useCase.requests.single.complete(content);
    await expectLater(loading, completes);
  });
}

class _SharedUseCase extends Fake implements GetPaygradesUseCase {
  final List<String> ids = [];
  final List<Completer<SharedPaygradesContent>> requests = [];

  @override
  Future<SharedPaygradesContent> getSharedPaygrades(String publicId) {
    ids.add(publicId);
    final request = Completer<SharedPaygradesContent>();
    requests.add(request);
    return request.future;
  }
}
