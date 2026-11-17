class SeatAuditPage {
  const SeatAuditPage({
    required this.count,
    required this.next,
    required this.previous,
    required this.current,
    required this.results,
  });

  final int count;
  final String? next;
  final String? previous;
  final int current;
  final List<SeatAudit> results;
}

class SeatAudit {
  const SeatAudit({
    required this.uuid,
    required this.job,
    required this.overallScore,
    required this.lastAuditDate,
    required this.profiles,
  });

  final String uuid;
  final SeatAuditJob job;
  final double overallScore;
  final String? lastAuditDate;
  final List<SeatAuditProfile> profiles;
}

class SeatAuditJob {
  const SeatAuditJob({required this.uuid, required this.title});

  final String uuid;
  final String title;
}

class SeatAuditProfile {
  const SeatAuditProfile({
    required this.uuid,
    required this.name,
    required this.userUuid,
    required this.email,
    required this.image,
    required this.onboarded,
  });

  final String uuid;
  final String name;
  final String userUuid;
  final String email;
  final String? image;
  final bool onboarded;
}
