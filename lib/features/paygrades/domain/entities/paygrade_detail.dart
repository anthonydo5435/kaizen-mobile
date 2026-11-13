class PaygradeDetail {
  const PaygradeDetail({
    required this.id,
    required this.title,
    required this.paygradeUnit,
    required this.department,
    required this.payGrades,
  });

  final String id;
  final String title;
  final String paygradeUnit;
  final String department;
  final List<PaygradeEntry> payGrades;
}

class PaygradeEntry {
  const PaygradeEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.payRate,
    required this.level,
    required this.description,
    required this.promotionRequirement,
  });

  final String id;
  final String type;
  final String title;
  final String payRate;
  final int level;
  final String description;
  final String promotionRequirement;

  static bool isValidPayRate(String value) {
    final rate = value.trim();
    return RegExp(r'^\d+(\.\d+)?$').hasMatch(rate) &&
        (double.tryParse(rate)?.isFinite ?? false);
  }
}
