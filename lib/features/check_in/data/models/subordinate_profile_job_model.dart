import '../../domain/entities/subordinate_profile_job.dart';
import 'seat_audit_model.dart';

class SubordinateProfileJobModel extends SubordinateProfileJob {
  const SubordinateProfileJobModel({
    required super.uuid,
    required super.title,
    required super.isPrimary,
    required super.profile,
    required super.createdAt,
  });

  factory SubordinateProfileJobModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    return SubordinateProfileJobModel(
      uuid: json['uuid']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      isPrimary: json['is_primary'] == true,
      profile: SeatAuditProfileModel.fromJson(
        profile is Map<String, dynamic> ? profile : const <String, dynamic>{},
      ),
      createdAt: json['created_at']?.toString().trim() ?? '',
    );
  }
}
