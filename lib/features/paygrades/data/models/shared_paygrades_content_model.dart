import '../../../../core/network/api_error.dart';
import '../../domain/entities/shared_paygrades_content.dart';
import 'paygrade_detail_model.dart';

class SharedPaygradesContentModel extends SharedPaygradesContent {
  const SharedPaygradesContentModel({
    required super.primary,
    required super.ancillary,
    required super.includesPayRates,
  });

  factory SharedPaygradesContentModel.fromApiJson(Map<String, dynamic> json) {
    final content = json['content'];
    if (json['view_type'] != 'paygrades' || content is! Map<String, dynamic>) {
      throw const ApiError.invalidResponse();
    }

    final includesPayRates = content['includes_pay_rates'] == true;
    PaygradeDetailModel readTab(String type) {
      final entries = content[type] ?? const <dynamic>[];
      if (entries is! List ||
          entries.any((entry) => entry is! Map<String, dynamic>)) {
        throw const ApiError.invalidResponse();
      }

      return PaygradeDetailModel.fromApiJson({
        'title': content['title'],
        'department': content['department_name'],
        'paygrade_unit': content['paygrade_unit'],
        'pay_grades': entries
            .cast<Map<String, dynamic>>()
            .map(
              (entry) => {
                ...entry,
                'type': type,
                'pay_rate': includesPayRates ? entry['pay_rate'] : null,
              },
            )
            .toList(growable: false),
      });
    }

    return SharedPaygradesContentModel(
      primary: readTab('primary'),
      ancillary: readTab('ancillary'),
      includesPayRates: includesPayRates,
    );
  }
}
