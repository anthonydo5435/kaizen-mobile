import '../../../../core/network/api_error.dart';
import '../../domain/entities/performance_report.dart';

class CertifiedReportsPageModel {
  const CertifiedReportsPageModel({
    required this.results,
    required this.next,
    required this.current,
  });

  final List<CertifiedReportOption> results;
  final String? next;
  final int current;

  factory CertifiedReportsPageModel.fromApiJson(dynamic json) {
    final items = json is List
        ? json
        : json is Map
        ? json['results']
        : null;
    if (items is! List) throw const ApiError.invalidResponse();

    return CertifiedReportsPageModel(
      results: items
          .whereType<Map>()
          .map(
            (item) => CertifiedReportOption(
              uuid: _readString(item['uuid']) ?? '',
              displayName:
                  _readString(item['date_range']) ??
                  _readString(item['display_name']) ??
                  '',
              createdAt: _readString(item['created_at']),
            ),
          )
          .where(
            (option) => option.uuid.isNotEmpty && option.displayName.isNotEmpty,
          )
          .toList(growable: false),
      next: json is Map ? _readString(json['next']) : null,
      current: json is Map ? int.tryParse('${json['current']}') ?? 1 : 1,
    );
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
