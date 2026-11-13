import 'paygrade_detail.dart';

class SharedPaygradesContent {
  const SharedPaygradesContent({
    required this.primary,
    required this.ancillary,
    required this.includesPayRates,
  });

  final PaygradeDetail primary;
  final PaygradeDetail ancillary;
  final bool includesPayRates;
}
