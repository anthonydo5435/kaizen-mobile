enum AppMenuType {
  home,
  learningTracks,
  compliance,
  library,
  audits,
  performanceSnapshot,
  seatProfiles,
  paygrades,
  departments,
  kaizenGpt,
  setting,
  profile;

  bool get isBottomNavigationTab => switch (this) {
    library || audits || performanceSnapshot || learningTracks => true,
    _ => false,
  };
}
