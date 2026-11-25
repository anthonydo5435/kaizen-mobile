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

  test('billing without an access flag allows paid, active, or trial', () {
    expect(manager.hasRestrictedBillingStatus, isTrue);
    expect(manager.showBillingBanner, isFalse);

    for (final status in ['paid', 'active']) {
      manager.saveActiveCompany(_companyWithBillingStatus(status));
      expect(manager.hasRestrictedBillingStatus, isFalse, reason: status);
      expect(manager.showBillingBanner, isFalse, reason: status);
      expect(manager.showTrialBanner, isFalse, reason: status);
    }

    for (final status in ['unpaid', 'canceled', 'trialing', null]) {
      manager.saveActiveCompany(_companyWithBillingStatus(status));
      expect(manager.hasRestrictedBillingStatus, isTrue, reason: '$status');
      expect(manager.showBillingBanner, isTrue, reason: '$status');

      manager.saveActiveCompany(
        _companyWithBillingStatus(status, isInTrial: true),
      );
      expect(
        manager.hasRestrictedBillingStatus,
        isFalse,
        reason: '$status in trial',
      );
      expect(manager.showBillingBanner, isFalse, reason: '$status in trial');
      expect(manager.showTrialBanner, isTrue, reason: '$status in trial');
    }

    manager.saveActiveCompany(CompanyDetails.fromApiJson({'uuid': 'company'}));
    expect(manager.hasRestrictedBillingStatus, isTrue);
    expect(manager.showBillingBanner, isTrue);
  });

  test('active billing follows the saved server access flag', () async {
    for (final canUsePaidFeatures in [true, false]) {
      final company = _companyWithBillingStatus(
        'active',
        canUsePaidFeatures: canUsePaidFeatures,
      );
      manager.saveActiveCompany(company);
      expect(manager.hasRestrictedBillingStatus, !canUsePaidFeatures);
      expect(manager.showBillingBanner, !canUsePaidFeatures);
      expect(manager.showTrialBanner, isFalse);

      await AppPreference.saveActiveCompany(company);
      manager.resetSessionState();
      await manager.hydrateCurrentUser();
      expect(manager.hasRestrictedBillingStatus, !canUsePaidFeatures);
    }
  });

  test('server denial replaces a dismissed trial banner with billing', () {
    manager.saveActiveCompany(
      _companyWithBillingStatus('trialing', isInTrial: true),
    );
    manager.dismissBillingBanner();
    manager.saveActiveCompany(
      _companyWithBillingStatus(
        'trialing',
        isInTrial: true,
        canUsePaidFeatures: false,
      ),
    );

    expect(manager.hasRestrictedBillingStatus, isTrue);
    expect(manager.showBillingBanner, isTrue);
    expect(manager.showTrialBanner, isFalse);
  });

  test(
    'a company-level trial flag is restored with the saved company',
    () async {
      final company = CompanyDetails.fromApiJson({
        'uuid': 'company',
        'isInTrial': true,
      });
      await AppPreference.saveActiveCompany(company);
      await manager.hydrateCurrentUser();
      expect(manager.billingDetails?.isInTrial, isTrue);
      expect(manager.hasRestrictedBillingStatus, isFalse);

      manager.saveActiveCompany(
        CompanyDetails.fromApiJson({
          'uuid': 'company',
          'billing': {'status': 'unpaid', 'isInTrial': false},
        }),
      );
      expect(manager.hasRestrictedBillingStatus, isTrue);
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

    manager.saveActiveCompany(_companyWithBillingStatus('paid'));
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
