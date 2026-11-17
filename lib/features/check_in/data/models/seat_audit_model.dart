import '../../domain/entities/seat_audit.dart';

class SeatAuditPageModel extends SeatAuditPage {
  const SeatAuditPageModel({
    required super.count,
    required super.next,
    required super.previous,
    required super.current,
    required super.results,
  });

  factory SeatAuditPageModel.fromJson(Map<String, dynamic> json) {
    final results = json['results'];
    return SeatAuditPageModel(
      count: _readInt(json['count']) ?? 0,
      next: _readString(json['next']),
      previous: _readString(json['previous']),
      current: _readInt(json['current']) ?? 1,
      results: results is List
          ? results
                .whereType<Map<String, dynamic>>()
                .map(SeatAuditModel.fromJson)
                .toList(growable: false)
          : const <SeatAudit>[],
    );
  }
}

class SeatAuditModel extends SeatAudit {
  const SeatAuditModel({
    required super.uuid,
    required super.job,
    required super.overallScore,
    required super.lastAuditDate,
    required super.profiles,
  });

  factory SeatAuditModel.fromJson(Map<String, dynamic> json) {
    final job = json['job'];
    final profiles = json['profiles'];
    return SeatAuditModel(
      uuid: _readString(json['uuid']) ?? '',
      job: SeatAuditJobModel.fromJson(
        job is Map<String, dynamic> ? job : const <String, dynamic>{},
      ),
      overallScore: double.tryParse('${json['overall_score']}') ?? 0,
      lastAuditDate: _readString(json['last_audit_date']),
      profiles: profiles is List
          ? profiles
                .whereType<Map<String, dynamic>>()
                .map(SeatAuditProfileModel.fromJson)
                .toList(growable: false)
          : const <SeatAuditProfile>[],
    );
  }
}

class SeatAuditJobModel extends SeatAuditJob {
  const SeatAuditJobModel({required super.uuid, required super.title});

  factory SeatAuditJobModel.fromJson(Map<String, dynamic> json) {
    return SeatAuditJobModel(
      uuid: _readString(json['uuid']) ?? '',
      title: _readString(json['title']) ?? '',
    );
  }
}

class SeatAuditProfileModel extends SeatAuditProfile {
  const SeatAuditProfileModel({
    required super.uuid,
    required super.name,
    required super.userUuid,
    required super.email,
    required super.image,
    required super.onboarded,
  });

  factory SeatAuditProfileModel.fromJson(Map<String, dynamic> json) {
    return SeatAuditProfileModel(
      uuid: _readString(json['uuid']) ?? '',
      name: _readString(json['name']) ?? '',
      userUuid: _readString(json['user_uuid']) ?? '',
      email: _readString(json['email']) ?? '',
      image: _readString(json['image']),
      onboarded: json['onboarded'] == true,
    );
  }
}

String? _readString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _readInt(Object? value) => int.tryParse('$value');
