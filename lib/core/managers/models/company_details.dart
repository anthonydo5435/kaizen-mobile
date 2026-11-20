import 'company_billing_details.dart';

class CompanyDetails {
  const CompanyDetails({
    required this.uuid,
    required this.name,
    required this.type,
    required this.isDlc,
    required this.billing,
  });

  final String uuid;
  final String name;
  final String type;
  final bool isDlc;
  final CompanyBillingDetails? billing;

  factory CompanyDetails.fromApiJson(Map<String, dynamic> json) {
    final billingJson = json['billing'];
    final isInTrial =
        _readBool(json['is_in_trial']) ?? _readBool(json['isInTrial']);
    return CompanyDetails(
      uuid: _readString(json['uuid']) ?? '',
      name: _readString(json['name']) ?? '',
      type: _readString(json['type']) ?? '',
      isDlc: _readBool(json['is_dlc']) ?? false,
      billing: billingJson is Map<String, dynamic> || isInTrial != null
          ? CompanyBillingDetails.fromApiJson({
              if (billingJson is Map<String, dynamic>) ...billingJson,
              if (isInTrial != null) 'is_in_trial': isInTrial,
            })
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uuid': uuid,
      'name': name,
      'type': type,
      'is_dlc': isDlc,
      'billing': billing?.toJson(),
    };
  }

  static String? _readString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty || resolved == 'null') {
      return null;
    }

    return resolved;
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }

    return null;
  }
}
