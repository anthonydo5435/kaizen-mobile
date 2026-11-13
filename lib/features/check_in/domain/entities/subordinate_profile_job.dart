import 'seat_audit.dart';

class SubordinateProfileJob {
  const SubordinateProfileJob({
    required this.uuid,
    required this.title,
    required this.isPrimary,
    required this.profile,
    required this.createdAt,
  });

  final String uuid;
  final String title;
  final bool isPrimary;
  final SeatAuditProfile profile;
  final String createdAt;
}
