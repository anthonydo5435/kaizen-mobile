class SeatDescriptionTrainingRoute {
  const SeatDescriptionTrainingRoute({
    required this.job,
    required this.category,
    required this.description,
    this.actualSeatProfileId,
    this.actualSeatProfileIdLookup,
    this.initialModuleId,
  });

  final String job;
  final String category;
  final String description;
  final String? actualSeatProfileId;

  /// Resolves the seat scope while the lesson is open.
  final Future<String?>? actualSeatProfileIdLookup;
  final String? initialModuleId;

  bool get hasDescription => description.trim().isNotEmpty;
  List<String> get additionalSeatProfileIds => [
    if (actualSeatProfileId case final id?) id,
  ];

  SeatDescriptionTrainingRoute withActualSeatProfileId(String id) =>
      SeatDescriptionTrainingRoute(
        job: job,
        category: category,
        description: description,
        actualSeatProfileId: id,
        initialModuleId: initialModuleId,
      );
}
