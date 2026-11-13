import '../../domain/entities/department.dart';
import '../../domain/entities/seat_profile_detail.dart';
import 'department_model.dart';

class SeatProfileDetailModel extends SeatProfileDetail {
  const SeatProfileDetailModel({
    required super.id,
    required super.actualId,
    required super.title,
    required super.department,
    required super.paygradeUnit,
    required super.categories,
  });

  factory SeatProfileDetailModel.fromApiJson(Map<String, dynamic> json) {
    final department = _readDepartment(json['department']);
    final categories =
        ((json['job_categories'] ?? json['categories']) as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SeatProfileCategoryModel.fromApiJson)
            .toList(growable: false) ??
        const <SeatProfileCategory>[];

    return SeatProfileDetailModel(
      id: json['uuid']?.toString().trim() ?? '',
      actualId: json['actual_id']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      department: department,
      paygradeUnit: json['paygrade_unit']?.toString().trim() ?? '',
      categories: categories,
    );
  }

  factory SeatProfileDetailModel.fromSharedContentJson(
    Map<String, dynamic> json,
  ) {
    final content = json['content'];
    if (json['view_type'] != 'seat_profile' || content is! Map) {
      throw const FormatException('Invalid shared seat profile response');
    }

    final data = Map<String, dynamic>.from(content);
    final categoryItems = data['categories'];
    final categories = categoryItems is List
        ? categoryItems
              .asMap()
              .entries
              .where((entry) => entry.value is Map)
              .map((entry) {
                final category = Map<String, dynamic>.from(entry.value as Map);
                final parsed = SeatProfileCategoryModel.fromApiJson(category);
                return SeatProfileCategory(
                  id: 'shared-category-${entry.key}',
                  title: parsed.title,
                  weightPercent: parsed.weightPercent,
                  descriptions: parsed.descriptions,
                );
              })
              .toList(growable: false)
        : const <SeatProfileCategory>[];
    final departmentName = data['department_name']?.toString().trim() ?? '';

    return SeatProfileDetailModel(
      id: '',
      actualId: '',
      title: data['title']?.toString().trim() ?? '',
      department: departmentName.isEmpty
          ? null
          : Department(id: '', name: departmentName),
      paygradeUnit: '',
      categories: categories,
    );
  }
}

class SeatProfileCategoryModel extends SeatProfileCategory {
  const SeatProfileCategoryModel({
    required super.id,
    required super.title,
    required super.weightPercent,
    required super.descriptions,
  });

  factory SeatProfileCategoryModel.fromApiJson(Map<String, dynamic> json) {
    final descriptions =
        ((json['job_category_descriptions'] ?? json['descriptions']) as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SeatProfileDescriptionModel.fromApiJson)
            .toList(growable: false) ??
        const <SeatProfileDescription>[];

    return SeatProfileCategoryModel(
      id: json['uuid']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      weightPercent: _readDouble(json['weight_percent']) ?? 0,
      descriptions: descriptions,
    );
  }
}

class SeatProfileDescriptionModel extends SeatProfileDescription {
  const SeatProfileDescriptionModel({
    required super.id,
    required super.actualId,
    required super.name,
    required super.auditSpecifics,
    required super.auditFactorType,
    required super.milestoneDays,
  });

  factory SeatProfileDescriptionModel.fromApiJson(Map<String, dynamic> json) {
    return SeatProfileDescriptionModel(
      id: json['uuid']?.toString().trim() ?? '',
      actualId: json['actual_id']?.toString().trim() ?? '',
      name: json['description']?.toString().trim() ?? '',
      auditSpecifics: json['job_specifics']?.toString().trim() ?? '',
      auditFactorType: _readDescriptionAuditFactorType(json),
      milestoneDays: json['milestone_day']?.toString().trim() ?? '',
    );
  }
}

String _readDescriptionAuditFactorType(Map<String, dynamic> json) {
  const candidateKeys = <String>[
    'audit_factor_type',
    'auditFactorType',
    'check_in_type',
    'checkInType',
    'audit_type',
    'auditType',
  ];

  final directMatch = _findFirstNonEmptyStringForKeys(json, candidateKeys);
  if (directMatch != null) {
    return directMatch;
  }

  return '';
}

String? _findFirstNonEmptyStringForKeys(
  Map<String, dynamic> source,
  List<String> candidateKeys,
) {
  for (final key in candidateKeys) {
    final resolved = _readNestedString(source[key]);
    if (resolved != null) {
      return resolved;
    }
  }

  for (final entry in source.entries) {
    final value = entry.value;
    if (value is Map<String, dynamic>) {
      final resolved = _findFirstNonEmptyStringForKeys(value, candidateKeys);
      if (resolved != null) {
        return resolved;
      }
      continue;
    }

    if (value is Map) {
      final resolved = _findFirstNonEmptyStringForKeys(
        Map<String, dynamic>.from(value),
        candidateKeys,
      );
      if (resolved != null) {
        return resolved;
      }
      continue;
    }

    if (value is List) {
      for (final item in value) {
        if (item is Map<String, dynamic>) {
          final resolved = _findFirstNonEmptyStringForKeys(item, candidateKeys);
          if (resolved != null) {
            return resolved;
          }
        } else if (item is Map) {
          final resolved = _findFirstNonEmptyStringForKeys(
            Map<String, dynamic>.from(item),
            candidateKeys,
          );
          if (resolved != null) {
            return resolved;
          }
        }
      }
    }
  }

  return null;
}

String? _readNestedString(dynamic value) {
  if (value is String) {
    final resolved = value.trim();
    return resolved.isEmpty ? null : resolved;
  }

  if (value is Map<String, dynamic>) {
    for (final nestedKey in const <String>['value', 'label', 'name', 'title']) {
      final resolved = _readNestedString(value[nestedKey]);
      if (resolved != null) {
        return resolved;
      }
    }
  } else if (value is Map) {
    return _readNestedString(Map<String, dynamic>.from(value));
  }

  return null;
}

double? _readDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

Department? _readDepartment(dynamic value) {
  if (value is Map<String, dynamic>) {
    return DepartmentModel.fromApiJson(value);
  }

  if (value is Map) {
    return DepartmentModel.fromApiJson(Map<String, dynamic>.from(value));
  }

  return null;
}
