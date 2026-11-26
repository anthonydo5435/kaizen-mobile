import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/managers/models/company_details.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = AppManager.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    manager.resetSessionState();
  });
  tearDown(manager.resetSessionState);

  test('a missing access flag restricts all billing statuses', () {
    expect(manager.canUsePaidFeatures, isFalse);
    expect(manager.showBillingBanner, isFalse);

    for (final status in ['paid', 'active', 'unpaid', 'trialing', null]) {
      for (final isInTrial in [false, true]) {
        manager.saveActiveCompany(
          _companyWithBillingStatus(status, isInTrial: isInTrial),
        );
        final reason = 'status: $status, isInTrial: $isInTrial';
        expect(manager.canUsePaidFeatures, isFalse, reason: reason);
        expect(manager.showBillingBanner, isTrue, reason: reason);
        expect(manager.showTrialBanner, isFalse, reason: reason);
      }
    }

    manager.saveActiveCompany(CompanyDetails.fromApiJson({'uuid': 'company'}));
    expect(manager.canUsePaidFeatures, isFalse);
    expect(manager.showBillingBanner, isTrue);
  });

  test('paid access follows the saved server flag across statuses', () async {
    for (final status in ['paid', 'active', 'canceled', null]) {
      for (final canUsePaidFeatures in [true, false]) {
        final company = _companyWithBillingStatus(
          status,
          canUsePaidFeatures: canUsePaidFeatures,
        );
        manager.saveActiveCompany(company);
        expect(manager.canUsePaidFeatures, canUsePaidFeatures);
        expect(manager.showBillingBanner, !canUsePaidFeatures);
        expect(manager.showTrialBanner, isFalse);

        await AppPreference.saveActiveCompany(company);
        manager.resetSessionState();
        await manager.hydrateCurrentUser();
        expect(manager.canUsePaidFeatures, canUsePaidFeatures);
      }
    }
  });

  test('server denial replaces a dismissed trial banner with billing', () {
    manager.saveActiveCompany(
      _companyWithBillingStatus(
        'trialing',
        isInTrial: true,
        canUsePaidFeatures: true,
      ),
    );
    expect(manager.showTrialBanner, isTrue);
    manager.dismissBillingBanner();
    manager.saveActiveCompany(
      _companyWithBillingStatus(
        'trialing',
        isInTrial: true,
        canUsePaidFeatures: false,
      ),
    );

    expect(manager.canUsePaidFeatures, isFalse);
    expect(manager.showBillingBanner, isTrue);
    expect(manager.showTrialBanner, isFalse);
  });

  test(
    'a company-level trial flag is restored with the saved company',
    () async {
      final company = CompanyDetails.fromApiJson({
        'uuid': 'company',
        'isInTrial': true,
        'billing': {'canUsePaidFeatures': true},
      });
      await AppPreference.saveActiveCompany(company);
      await manager.hydrateCurrentUser();
      expect(manager.billingDetails?.isInTrial, isTrue);
      expect(manager.canUsePaidFeatures, isTrue);

      manager.saveActiveCompany(
        CompanyDetails.fromApiJson({
          'uuid': 'company',
          'billing': {'status': 'unpaid', 'isInTrial': false},
        }),
      );
      expect(manager.canUsePaidFeatures, isFalse);
    },
  );

  test('refreshing canceled billing preserves the banner dismissal', () {
    final canceledCompany = _companyWithBillingStatus('canceled');
    manager.saveActiveCompany(canceledCompany);
    manager.dismissBillingBanner();

    manager.saveActiveCompany(_companyWithBillingStatus('canceled'));
    expect(manager.showBillingBanner, isFalse);

    manager.saveBillingDetails(canceledCompany.billing);
    expect(manager.showBillingBanner, isFalse);

    manager.saveActiveCompany(
      _companyWithBillingStatus('paid', canUsePaidFeatures: true),
    );
    manager.saveActiveCompany(canceledCompany);
    expect(manager.showBillingBanner, isTrue);

    manager.dismissBillingBanner();
    manager.saveActiveCompany(
      _companyWithBillingStatus('canceled', uuid: 'other-company'),
    );
    expect(manager.showBillingBanner, isTrue);
  });
}

CompanyDetails _companyWithBillingStatus(
  String? status, {
  String uuid = 'company',
  bool isInTrial = false,
  bool? canUsePaidFeatures,
}) {
  return CompanyDetails.fromApiJson({
    'uuid': uuid,
    'billing': {
      'status': status,
      'is_in_trial': isInTrial,
      if (canUsePaidFeatures != null)
        'can_use_paid_features': canUsePaidFeatures,
    },
  });
}
