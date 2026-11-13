class LmsPublicLink {
  LmsPublicLink({
    required this.url,
    required Iterable<String> trainingModuleUuids,
  }) : trainingModuleUuids = List.unmodifiable(trainingModuleUuids);

  final String url;
  final List<String> trainingModuleUuids;
}
