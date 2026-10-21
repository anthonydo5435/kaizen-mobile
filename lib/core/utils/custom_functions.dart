import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../../features/check_in/domain/entities/audit_details.dart';
import '../../features/check_in/domain/entities/quarterly_audit.dart';
import '../../features/login/domain/entities/user.dart';
import '../constants/app_strings.dart';
import '../network/api_endpoints.dart';
import '../widgets/custom_alert_dialogue.dart';

class CustomFunctions {
  static const List<String> _personalityAvatarAssets = <String>[
    'lib/assets/images/ENFJ_Mentor(F).png',
    'lib/assets/images/ENFJ_Mentor(M).png',
    'lib/assets/images/ENFP_Campaigner(F).png',
    'lib/assets/images/ENFP_Campaigner(M).png',
    'lib/assets/images/ENTJ_Commander(F).png',
    'lib/assets/images/ENTJ_Commander(M).png',
    'lib/assets/images/ENTP_Challenger(F).png',
    'lib/assets/images/ENTP_Challenger(M).png',
    'lib/assets/images/ESFJ_Caregiver(F).png',
    'lib/assets/images/ESFJ_Caregiver(M).png',
    'lib/assets/images/ESFP_Performer(F).png',
    'lib/assets/images/ESFP_Performer(M).png',
    'lib/assets/images/ESTJ_Director(F).png',
    'lib/assets/images/ESTJ_Director(M).png',
    'lib/assets/images/ESTP_Persuader(F).png',
    'lib/assets/images/ESTP_Persuader(M).png',
    'lib/assets/images/INFJ_Visionary(F).png',
    'lib/assets/images/INFJ_Visionary(M).png',
    'lib/assets/images/INFP_Mediator(F).png',
    'lib/assets/images/INFP_Mediator(M).png',
    'lib/assets/images/INTJ_Designer(F).png',
    'lib/assets/images/INTJ_Designer(M).png',
    'lib/assets/images/INTP_Thinker(F).png',
    'lib/assets/images/INTP_Thinker(M).png',
    'lib/assets/images/ISFJ_Protector(F).png',
    'lib/assets/images/ISFJ_Protector(M).png',
    'lib/assets/images/ISFP_Artist(F).png',
    'lib/assets/images/ISFP_Artist(M).png',
    'lib/assets/images/ISTJ_Inspector(F).png',
    'lib/assets/images/ISTJ_Inspector(M).png',
    'lib/assets/images/ISTP_Craftsman(F).png',
    'lib/assets/images/ISTP_Craftsman(M).png',
  ];

  static Future<void> showCustomAlert(
    BuildContext context,
    String title,
    String description,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CustomAlertDialog(title, description);
      },
    );
  }

  static String resolveName(User? user) {
    final candidates = [
      user?.name,
      [
        user?.firstName?.trim(),
        user?.lastName?.trim(),
      ].whereType<String>().where((value) => value.isNotEmpty).join(' '),
      user?.email?.split('@').first,
    ];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return 'Profile';
  }

  static String formatDeadlineInDays(String? deadline) {
    final value = deadline?.trim();
    if (value == null || value.isEmpty) {
      return 'No deadline';
    }

    final parsedDate = _parseDeadline(value);
    if (parsedDate == null) {
      return value;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );
    final differenceInDays = targetDate.difference(today).inDays;

    if (differenceInDays < 0) {
      final days = differenceInDays.abs();
      return '$days day${days == 1 ? '' : 's'}';
    }

    if (differenceInDays == 0) {
      return 'Today';
    }

    return '$differenceInDays day${differenceInDays == 1 ? '' : 's'}';
  }

  static String formatDate(String? value) {
    final resolved = value?.trim();
    if (resolved == null || resolved.isEmpty) {
      return 'No date';
    }

    final parsedDate = _parseDeadline(resolved);
    if (parsedDate == null) {
      return resolved;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = parsedDate.day.toString().padLeft(2, '0');
    final month = months[parsedDate.month - 1];

    return '$day $month, ${parsedDate.year}';
  }

  static String? resolvedText(String? value) {
    final resolved = value?.trim();
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    return resolved;
  }

  static ({int year, int quarter}) currentYearQuarter({DateTime? date}) {
    final resolvedDate = date ?? DateTime.now();

    return (
      year: resolvedDate.year,
      quarter: ((resolvedDate.month - 1) ~/ 3) + 1,
    );
  }

  static ({DateTime start, DateTime end}) currentQuarterDateRange({
    DateTime? date,
  }) {
    final resolvedDate = date ?? DateTime.now();
    final quarter = ((resolvedDate.month - 1) ~/ 3) + 1;
    final startMonth = ((quarter - 1) * 3) + 1;
    final start = DateTime(resolvedDate.year, startMonth, 1);
    final end = DateTime(resolvedDate.year, startMonth + 3, 0);
    return (start: start, end: end);
  }

  static String apiDateString({DateTime? date}) {
    final resolvedDate = date ?? DateTime.now();
    final year = resolvedDate.year.toString().padLeft(4, '0');
    final month = resolvedDate.month.toString().padLeft(2, '0');
    final day = resolvedDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static bool shouldStartNewAudit(AuditDetails? details) {
    final audits = details?.audits ?? const <AuditDetailItem>[];
    if (audits.isEmpty) {
      return true;
    }

    final todayDate = apiDateString();
    final hasMatchingAuditDate = audits.any(
      (audit) => isSameDate(audit.date, todayDate),
    );

    return !hasMatchingAuditDate;
  }

  static bool isAuditWithinContinueWindow(
    String? value, {
    int continueDays = 7,
    DateTime? referenceDate,
  }) {
    final resolved = value?.trim();
    if (resolved == null || resolved.isEmpty || continueDays <= 0) {
      return false;
    }

    final parsedDate = _parseDeadline(resolved);
    if (parsedDate == null) {
      return false;
    }

    final resolvedReferenceDate = referenceDate ?? DateTime.now();
    final today = DateTime(
      resolvedReferenceDate.year,
      resolvedReferenceDate.month,
      resolvedReferenceDate.day,
    );
    final targetDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );
    final differenceInDays = today.difference(targetDate).inDays;

    return differenceInDays >= 0 && differenceInDays < continueDays;
  }

  static QuarterlyAuditDescription? resolveTargetAuditDescription({
    required QuarterlyAudit quarterlyAudit,
    required bool shouldStartNewAudit,
  }) {
    final descriptions = quarterlyAudit.descriptions;
    if (descriptions.isEmpty) {
      return null;
    }

    if (shouldStartNewAudit) {
      for (final description in descriptions) {
        if (description.pass <= 0 && description.noPass <= 0) {
          return description;
        }
      }

      return descriptions.first;
    }

    for (final description in descriptions) {
      if (description.hasAudit ||
          description.pass > 0 ||
          description.noPass > 0) {
        return description;
      }
    }

    return descriptions.first;
  }

  static String resolveAuditCategoryTitle({
    required QuarterlyAudit audit,
    QuarterlyAuditDescription? description,
  }) {
    if (description == null) {
      return '';
    }

    for (final category in audit.categories) {
      if (category.uuid == description.category) {
        return category.categoryTitle;
      }
    }

    return '';
  }

  static String resolveAuditCategoryOption({
    required QuarterlyAudit audit,
    required QuarterlyAuditDescription description,
  }) {
    final title = resolveAuditCategoryTitle(
      audit: audit,
      description: description,
    ).trim();

    if (title.isNotEmpty) {
      return title;
    }

    return description.category.trim();
  }

  static String normalizeAuditMilestone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits == '30' || digits == '60' || digits == '90') {
      return '$digits Days';
    }

    return value.trim().isEmpty ? 'Unknown' : value.trim();
  }

  static String normalizeAuditType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'examination') {
      return 'Examination';
    }
    if (normalized == 'observation') {
      return 'Observation';
    }
    if (normalized == 'administrative') {
      return 'Administrative';
    }

    return value.trim().isEmpty ? 'Unknown' : value.trim();
  }

  static String resolveAuditTiming(QuarterlyAuditDescription description) {
    if (description.hasAudit) {
      return 'Inprogress';
    }
    if (isDateBeforeToday(description.lastAuditDate)) {
      return 'Overdue';
    }
    if (description.pass <= 0 && description.noPass <= 0) {
      return 'Available';
    }
    return 'Wait';
  }

  static bool shouldShowAuditDescription(
    QuarterlyAuditDescription description,
  ) {
    final isPastAuditDate = isDateBeforeToday(description.lastAuditDate);
    final hasPassOrNoPass = description.pass > 0 || description.noPass > 0;

    if (isPastAuditDate && !hasPassOrNoPass) {
      return false;
    }

    return true;
  }

  static String capitalizeFirstLetter(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  static String? displayStatus(String? value) {
    final resolved = resolvedText(value);
    if (resolved == null) {
      return null;
    }

    return resolved
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String normalizedStatus(String? status) {
    return status?.trim().toLowerCase().replaceAll('_', ' ') ?? '';
  }

  static bool isPendingApprovalStatus(String? status) {
    return normalizedStatus(status) == 'pending approval';
  }

  static bool isNoLongerNeededStatus(String? status) {
    final normalized = normalizedStatus(status);
    return normalized == 'no longer required' ||
        normalized == 'no longer needed';
  }

  static bool isPassedStatus(String? status) {
    final normalized = normalizedStatus(status);
    return normalized == 'passed' ||
        normalized == 'pass' ||
        normalized == 'complete' ||
        normalized == 'completed' ||
        normalized == 'compliant';
  }

  static bool isFailedStatus(String? status) {
    final normalized = normalizedStatus(status);
    return normalized == 'no pass' ||
        normalized == 'not passed' ||
        normalized == 'failed' ||
        normalized == 'fail';
  }

  static bool isPendingStatus(String? status) {
    return normalizedStatus(status) == 'pending';
  }

  static bool isCancelledStatus(String? status) {
    return normalizedStatus(status) == 'cancelled';
  }

  static String fileNameFromPath(
    String path, {
    String fallback = 'document.jpg',
  }) {
    final normalizedPath = path.replaceAll('\\', '/');
    final name = normalizedPath.split('/').last.trim();
    return name.isEmpty ? fallback : name;
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 KB';
    }

    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size = size / 1024;
      unitIndex++;
    }

    final formattedSize = unitIndex == 0 || size >= 10
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);

    return '$formattedSize ${units[unitIndex]}';
  }

  static String contentTypeFromPath(
    String path, {
    String fallback = 'image/jpeg',
  }) {
    final type = lookupMimeType(path) ?? fallback;
    debugPrint('Content-Type: $type');
    return type;
  }

  static bool hasAnsweredAllRequiredItems({
    required Iterable<String> requiredIds,
    required Map<String, String> answers,
  }) {
    final ids = requiredIds.where((id) => id.trim().isNotEmpty).toList();
    return ids.isNotEmpty &&
        ids.every((id) {
          final answer = answers[id]?.trim();
          return answer != null && answer.isNotEmpty;
        });
  }

  static String formatHoursMinutesSeconds(int seconds) {
    final duration = Duration(seconds: seconds < 0 ? 0 : seconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$hours:$minutes:$secs';
  }

  static bool isDeadlineOverdue(String? deadline) {
    final value = deadline?.trim();
    if (value == null || value.isEmpty) {
      return false;
    }

    final parsedDate = _parseDeadline(value);
    if (parsedDate == null) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );

    return targetDate.difference(today).inDays < 0;
  }

  static bool isDateBeforeToday(String? value) {
    final resolved = value?.trim();
    if (resolved == null || resolved.isEmpty) {
      return false;
    }

    final parsedDate = _parseDeadline(resolved);
    if (parsedDate == null) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );

    return targetDate.isBefore(today);
  }

  static bool isDateBefore(String? value, String? referenceValue) {
    final resolved = value?.trim();
    final resolvedReference = referenceValue?.trim();
    if (resolved == null ||
        resolved.isEmpty ||
        resolvedReference == null ||
        resolvedReference.isEmpty) {
      return false;
    }

    final parsedDate = _parseDeadline(resolved);
    final parsedReferenceDate = _parseDeadline(resolvedReference);
    if (parsedDate == null || parsedReferenceDate == null) {
      return false;
    }

    final targetDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );
    final referenceDate = DateTime(
      parsedReferenceDate.year,
      parsedReferenceDate.month,
      parsedReferenceDate.day,
    );

    return targetDate.isBefore(referenceDate);
  }

  static bool isSameDate(String? value, String? referenceValue) {
    final resolved = value?.trim();
    final resolvedReference = referenceValue?.trim();
    if (resolved == null ||
        resolved.isEmpty ||
        resolvedReference == null ||
        resolvedReference.isEmpty) {
      return false;
    }

    final parsedDate = _parseDeadline(resolved);
    final parsedReferenceDate = _parseDeadline(resolvedReference);
    if (parsedDate == null || parsedReferenceDate == null) {
      return resolved == resolvedReference;
    }

    return parsedDate.year == parsedReferenceDate.year &&
        parsedDate.month == parsedReferenceDate.month &&
        parsedDate.day == parsedReferenceDate.day;
  }

  static DateTime? _parseDeadline(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return null;
    }

    final timestamp = int.tryParse(trimmedValue);
    if (timestamp != null) {
      final isMilliseconds = trimmedValue.length >= 13;
      return DateTime.fromMillisecondsSinceEpoch(
        isMilliseconds ? timestamp : timestamp * 1000,
      );
    }

    return DateTime.tryParse(trimmedValue) ?? _parseFormattedDate(trimmedValue);
  }

  static DateTime? _parseFormattedDate(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    final numericMonthMatch = RegExp(
      r'^(\d{1,2})[\/\-\s]+(\d{1,2}),?\s+(\d{4})$',
    ).firstMatch(normalized);
    if (numericMonthMatch != null) {
      final month = int.tryParse(numericMonthMatch.group(1)!);
      final day = int.tryParse(numericMonthMatch.group(2)!);
      final year = int.tryParse(numericMonthMatch.group(3)!);
      return _safeDate(year: year, month: month, day: day);
    }

    final monthFirstMatch = RegExp(
      r'^([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})$',
    ).firstMatch(normalized);
    if (monthFirstMatch != null) {
      final month = _monthNumber(monthFirstMatch.group(1)!);
      final day = int.tryParse(monthFirstMatch.group(2)!);
      final year = int.tryParse(monthFirstMatch.group(3)!);
      return _safeDate(year: year, month: month, day: day);
    }

    final dayFirstMatch = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]{3,9}),?\s+(\d{4})$',
    ).firstMatch(normalized);
    if (dayFirstMatch != null) {
      final day = int.tryParse(dayFirstMatch.group(1)!);
      final month = _monthNumber(dayFirstMatch.group(2)!);
      final year = int.tryParse(dayFirstMatch.group(3)!);
      return _safeDate(year: year, month: month, day: day);
    }

    return null;
  }

  static int? _monthNumber(String value) {
    switch (value.trim().toLowerCase()) {
      case 'jan':
      case 'january':
        return 1;
      case 'feb':
      case 'february':
        return 2;
      case 'mar':
      case 'march':
        return 3;
      case 'apr':
      case 'april':
        return 4;
      case 'may':
        return 5;
      case 'jun':
      case 'june':
        return 6;
      case 'jul':
      case 'july':
        return 7;
      case 'aug':
      case 'august':
        return 8;
      case 'sep':
      case 'sept':
      case 'september':
        return 9;
      case 'oct':
      case 'october':
        return 10;
      case 'nov':
      case 'november':
        return 11;
      case 'dec':
      case 'december':
        return 12;
    }

    return null;
  }

  static DateTime? _safeDate({
    required int? year,
    required int? month,
    required int? day,
  }) {
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final parsedDate = DateTime(year, month, day);
    if (parsedDate.year != year ||
        parsedDate.month != month ||
        parsedDate.day != day) {
      return null;
    }

    return parsedDate;
  }

  static String? resolveImageUrl(String? imageUrl) {
    return resolveNetworkUrl(imageUrl);
  }

  static bool isAssetImagePath(String? imagePath) {
    final value = imagePath?.trim();
    return value != null && value.startsWith('lib/assets/images/');
  }

  static ImageProvider<Object> resolveImageProvider(
    String? imagePath, {
    String fallbackAssetPath = AppStrings.dummyProfileImagePath,
  }) {
    final value = imagePath?.trim();
    if (value != null && value.isNotEmpty) {
      if (isAssetImagePath(value)) {
        return AssetImage(value);
      }

      final networkUrl = resolveNetworkUrl(value);
      if (networkUrl != null) {
        return NetworkImage(networkUrl);
      }
    }

    return AssetImage(fallbackAssetPath);
  }

  static String? getPersonalityAvatar(String? typeCode, String? gender) {
    final imageCode = getPersonalityImageCode(typeCode);
    if (imageCode == null) {
      return null;
    }

    final genderCode = gender?.toLowerCase() == 'female' ? 'F' : 'M';
    final fallbackGenderCode = genderCode == 'F' ? 'M' : 'F';
    for (final assetPath in _personalityAvatarAssets) {
      if (assetPath.endsWith('$imageCode($genderCode).png')) {
        return assetPath;
      }
    }

    for (final assetPath in _personalityAvatarAssets) {
      if (assetPath.endsWith('$imageCode($fallbackGenderCode).png')) {
        return assetPath;
      }
    }

    return null;
  }

  static String? getPersonalityImageCode(String? typeCode) {
    final trimmed = typeCode?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed
        .replaceAll(RegExp(r'\s*-\s*'), '_')
        .replaceAll(RegExp(r'\s+'), '');
  }

  static String? resolveNetworkUrl(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.startsWith('//')) {
      return Uri.parse('https:$value').toString();
    }

    if (value.startsWith('/')) {
      return Uri.parse('${ApiEndPoints.baseUrl}$value').toString();
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      return null;
    }

    if (uri.hasScheme) {
      return uri.toString();
    }

    return Uri.parse('${ApiEndPoints.baseUrl}/$value').toString();
  }

  static String stripHtmlTags(
    String? value, {
    String emptyText = AppStrings.noContentAvailable,
  }) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return emptyText;
    }

    final withoutTags = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return withoutTags.isEmpty ? emptyText : withoutTags;
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) {
      return '00:00';
    }

    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$secs';
    }

    return '$minutes:$secs';
  }

  static String formatCommentTimeAgo(String? createdAt) {
    final milliseconds = int.tryParse(createdAt?.trim() ?? '');
    if (milliseconds == null) {
      return 'Just now';
    }

    final createdDate = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final difference = DateTime.now().difference(createdDate);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }

    return 'Just now';
  }

  static String displayCommentAuthorName({
    String? name,
    String? email,
    String fallback = 'Team Member',
  }) {
    final resolvedName = resolvedText(name);
    if (resolvedName != null) {
      return resolvedName;
    }

    final resolvedEmail = resolvedText(email);
    if (resolvedEmail != null) {
      return resolvedEmail;
    }

    return fallback;
  }

  static String displayCommentText(
    String? comment, {
    String fallback = 'No Comment',
  }) {
    return resolvedText(comment) ?? fallback;
  }

  static bool isWebmVideoUrl(String? url) {
    final resolvedUrl = resolveNetworkUrl(url);
    if (resolvedUrl == null) {
      return false;
    }

    final uri = Uri.tryParse(resolvedUrl);
    final path = uri?.path.toLowerCase() ?? resolvedUrl.toLowerCase();
    return path.endsWith('.webm');
  }

  static bool isApplePlatform([TargetPlatform? platform]) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    return resolvedPlatform == TargetPlatform.iOS ||
        resolvedPlatform == TargetPlatform.macOS;
  }

  static String urlWithoutQuery(String value) {
    final querySeparatorIndex = value.indexOf('?');
    if (querySeparatorIndex == -1) {
      return value;
    }

    return value.substring(0, querySeparatorIndex);
  }

  static String buildGreeting(User? user) {
    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 17 => 'Good afternoon',
      >= 17 && < 21 => 'Good evening',
      _ => 'Good night',
    };

    return '$greeting, ${_resolveDisplayName(user)}';
  }

  static String _resolveDisplayName(User? user) {
    final firstName = user?.firstName?.trim();
    if (firstName != null && firstName.isNotEmpty) {
      return CustomFunctions.capitalizeFirstLetter(firstName);
    }

    if (user?.isOwner == true) {
      return 'Owner';
    }

    final fullName = CustomFunctions.resolveName(user).trim();
    if (fullName.isEmpty || fullName == 'Profile') {
      return 'Owner';
    }

    return fullName.split(' ').first;
  }
}
