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

  test('only paid status or the trial flag allow paid features', () {
    expect(manager.hasRestrictedBillingStatus, isTrue);
    expect(manager.showBillingBanner, isFalse);

    manager.saveActiveCompany(_companyWithBillingStatus('paid'));
    expect(manager.hasRestrictedBillingStatus, isFalse);
    expect(manager.showBillingBanner, isFalse);
    expect(manager.showTrialBanner, isFalse);

    for (final status in ['unpaid', 'canceled', 'active', 'trialing', null]) {
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
}) {
  return CompanyDetails.fromApiJson({
    'uuid': uuid,
    'billing': {'status': status, 'is_in_trial': isInTrial},
  });
}
