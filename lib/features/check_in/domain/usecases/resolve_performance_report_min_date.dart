import '../entities/performance_report.dart';

/// Resolves report date bounds, including older human-readable API dates.
class ResolvePerformanceReportMinDate {
  const ResolvePerformanceReportMinDate();

  DateTime call(PerformanceReport? report, {DateTime? now}) {
    final currentDate = now ?? DateTime.now();
    final parsedCreatedAt = _resolveParsedPerformanceReportCreatedAt(
      report,
      currentDate,
    );
    final today = _normalizeCalendarDate(currentDate);
    if (parsedCreatedAt == null) {
      return today;
    }

    final normalizedCreatedAt = _normalizeCalendarDate(parsedCreatedAt);
    return normalizedCreatedAt.isAfter(today) ? today : normalizedCreatedAt;
  }

  DateTime _normalizeCalendarDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime? _resolveParsedPerformanceReportCreatedAt(
    PerformanceReport? report,
    DateTime currentDate,
  ) {
    final candidates = <String?>[
      report?.createdAt,
      report?.reportSnapshot['createdAt']?.toString(),
      report?.reportSnapshot['created_at']?.toString(),
      report?.profile.lastAuditLabel,
    ];

    for (final candidate in candidates) {
      final parsed = _parseReportCreatedAt(candidate, currentDate);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  DateTime? _parseReportCreatedAt(String? value, DateTime currentDate) {
    final trimmedValue = value?.trim() ?? '';
    if (trimmedValue.isEmpty) {
      return null;
    }

    final normalizedValue = trimmedValue
        .replaceAllMapped(
          RegExp(r'(\d)(st|nd|rd|th)\b', caseSensitive: false),
          (match) => match.group(1)!,
        )
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parsedDateTime = DateTime.tryParse(normalizedValue);
    if (parsedDateTime != null) {
      final localDateTime = parsedDateTime.toLocal();
      return DateTime(
        localDateTime.year,
        localDateTime.month,
        localDateTime.day,
      );
    }

    final isoDateMatch = RegExp(
      r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})',
    ).firstMatch(normalizedValue);
    if (isoDateMatch != null) {
      final year = int.tryParse(isoDateMatch.group(1)!);
      final month = int.tryParse(isoDateMatch.group(2)!);
      final day = int.tryParse(isoDateMatch.group(3)!);
      final resolved = _safeDate(year, month, day);
      if (resolved != null) {
        return resolved;
      }
    }

    const monthNames = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    final dayMonthYearMatch = RegExp(
      r'(\d{1,2})[\s/-]+([A-Za-z]+)(?:[\s/-]+(\d{4}))?',
    ).firstMatch(normalizedValue);
    if (dayMonthYearMatch != null) {
      final day = int.tryParse(dayMonthYearMatch.group(1)!);
      final month = monthNames[dayMonthYearMatch.group(2)!.toLowerCase()];
      final year =
          int.tryParse(dayMonthYearMatch.group(3) ?? '') ?? currentDate.year;
      final resolved = _safeDate(year, month, day);
      if (resolved != null) {
        return resolved;
      }
    }

    final monthDayYearMatch = RegExp(
      r'([A-Za-z]+)[\s/-]+(\d{1,2})(?:[\s/-]+(\d{4}))?',
    ).firstMatch(normalizedValue);
    if (monthDayYearMatch != null) {
      final month = monthNames[monthDayYearMatch.group(1)!.toLowerCase()];
      final day = int.tryParse(monthDayYearMatch.group(2)!);
      final year =
          int.tryParse(monthDayYearMatch.group(3) ?? '') ?? currentDate.year;
      final resolved = _safeDate(year, month, day);
      if (resolved != null) {
        return resolved;
      }
    }

    final numericDateMatch = RegExp(
      r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})',
    ).firstMatch(normalizedValue);
    if (numericDateMatch != null) {
      final first = int.tryParse(numericDateMatch.group(1)!);
      final second = int.tryParse(numericDateMatch.group(2)!);
      final year = int.tryParse(numericDateMatch.group(3)!);
      if (first != null && second != null && year != null) {
        final dayFirst = _safeDate(
          year,
          second > 12 ? first : second,
          second > 12 ? second : first,
        );
        if (dayFirst != null) {
          return dayFirst;
        }

        final monthFirst = _safeDate(year, first, second);
        if (monthFirst != null) {
          return monthFirst;
        }
      }
    }

    return null;
  }

  DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }

    return value;
  }
}
