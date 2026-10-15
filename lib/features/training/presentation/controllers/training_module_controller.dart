import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/services/file_uploader.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../domain/entities/seat_description_training.dart';
import '../../domain/entities/shared_lesson_content.dart';
import '../../../check_in/domain/repositories/audit_repository.dart';
import '../models/view_training_tab_access.dart';
import 'training_sop_editor_controller.dart';

typedef TrainingSopEditorFactory =
    TrainingSopEditorController Function(
      String html,
      ValueChanged<String> onHtmlChanged,
    );

enum QuizGenerationDifficulty {
  easy('easy'),
  medium('medium'),
  hard('hard');

  const QuizGenerationDifficulty(this.apiValue);

  final String apiValue;
}

enum TrainingDocumentFormatKind { bold, italic, underline, heading, quote }

class TrainingDocumentFormatRange {
  const TrainingDocumentFormatRange({
    required this.kind,
    required this.start,
    required this.end,
  });

  final TrainingDocumentFormatKind kind;
  final int start;
  final int end;

  bool get isValid => end > start;

  TrainingDocumentFormatRange copyWith({
    TrainingDocumentFormatKind? kind,
    int? start,
    int? end,
  }) {
    return TrainingDocumentFormatRange(
      kind: kind ?? this.kind,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

class _TrainingParsedDocument {
  const _TrainingParsedDocument({required this.text, required this.formats});

  final String text;
  final List<TrainingDocumentFormatRange> formats;
}

class TrainingRichTextEditingController extends TextEditingController {
  TrainingRichTextEditingController({
    super.text,
    this.quoteColor = AppColors.hexd9deff,
  }) {
    _lastText = text;
    addListener(_handleTextChanged);
  }

  static final RegExp _numberedListPrefixPattern = RegExp(r'^\d+\.\s');

  final Color quoteColor;

  List<TrainingDocumentFormatRange> _formats =
      const <TrainingDocumentFormatRange>[];
  bool _isProgrammaticChange = false;
  String _lastText = '';

  void loadFromHtml(String? html) {
    final parsed = _parseHtmlDocument(html);
    _isProgrammaticChange = true;
    _formats = _mergeFormatRanges(parsed.formats);
    value = value.copyWith(
      text: parsed.text,
      selection: TextSelection.collapsed(offset: parsed.text.length),
      composing: TextRange.empty,
    );
    _lastText = parsed.text;
    _isProgrammaticChange = false;
    notifyListeners();
  }

  String toHtml() {
    return _serializeHtmlDocument(text, _formats);
  }

  void applyBold() {
    _applyInlineFormat(TrainingDocumentFormatKind.bold);
  }

  void applyItalic() {
    _applyInlineFormat(TrainingDocumentFormatKind.italic);
  }

  void applyUnderline() {
    _applyInlineFormat(TrainingDocumentFormatKind.underline);
  }

  void applyHeading() {
    _applyInlineFormat(TrainingDocumentFormatKind.heading);
  }

  void applyQuote() {
    _applyInlineFormat(TrainingDocumentFormatKind.quote);
  }

  void applyBulletList() {
    _toggleListPrefix(_ListFormatKind.bullet);
  }

  void applyNumberedList() {
    _toggleListPrefix(_ListFormatKind.numbered);
  }

  bool isFormatActive(TrainingDocumentFormatKind kind) {
    final resolvedSelection = _normalizedSelection(allowCollapsed: true);
    if (resolvedSelection == null) {
      return false;
    }

    final start = min(resolvedSelection.start, resolvedSelection.end);
    final end = max(resolvedSelection.start, resolvedSelection.end);
    if (start == end) {
      if (text.isEmpty) {
        return false;
      }

      final caretIndex = start.clamp(0, text.length);
      final probeStart = caretIndex == text.length && caretIndex > 0
          ? caretIndex - 1
          : caretIndex;
      final probeEnd = min(probeStart + 1, text.length);
      if (probeEnd <= probeStart) {
        return false;
      }

      return _hasFormatCoverage(kind: kind, start: probeStart, end: probeEnd);
    }

    return _hasFormatCoverage(kind: kind, start: start, end: end);
  }

  bool get isBulletListActive {
    final selectedBlock = _selectedBlockRange();
    if (selectedBlock == null) {
      return false;
    }

    final nonEmptyLines = _nonEmptyLines(selectedBlock.text.split('\n'));
    if (nonEmptyLines.isEmpty) {
      return false;
    }

    return nonEmptyLines.every(_isBulletedLine);
  }

  bool get isNumberedListActive {
    final selectedBlock = _selectedBlockRange();
    if (selectedBlock == null) {
      return false;
    }

    final nonEmptyLines = _nonEmptyLines(selectedBlock.text.split('\n'));
    if (nonEmptyLines.isEmpty) {
      return false;
    }

    return nonEmptyLines.every(_isNumberedLine);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final resolvedStyle = style ?? const TextStyle();
    final resolvedText = text;
    if (resolvedText.isEmpty || _formats.isEmpty) {
      return TextSpan(text: resolvedText, style: resolvedStyle);
    }

    final boundaries = <int>{0, resolvedText.length};
    for (final format in _formats) {
      final safeStart = format.start.clamp(0, resolvedText.length);
      final safeEnd = format.end.clamp(0, resolvedText.length);
      if (safeEnd <= safeStart) {
        continue;
      }
      boundaries.add(safeStart);
      boundaries.add(safeEnd);
    }

    final sortedBoundaries = boundaries.toList()..sort();
    final spans = <InlineSpan>[];
    for (var index = 0; index < sortedBoundaries.length - 1; index++) {
      final start = sortedBoundaries[index];
      final end = sortedBoundaries[index + 1];
      if (end <= start) {
        continue;
      }

      final segmentText = resolvedText.substring(start, end);
      final activeKinds = _formats
          .where((format) => format.start <= start && format.end >= end)
          .map((format) => format.kind)
          .toSet();
      spans.add(
        TextSpan(
          text: segmentText,
          style: _styleForKinds(resolvedStyle, activeKinds),
        ),
      );
    }

    return TextSpan(style: resolvedStyle, children: spans);
  }

  void _applyInlineFormat(TrainingDocumentFormatKind kind) {
    final resolvedSelection = _normalizedSelection();
    if (resolvedSelection == null) {
      return;
    }

    final start = min(resolvedSelection.start, resolvedSelection.end);
    final end = max(resolvedSelection.start, resolvedSelection.end);
    if (_hasFormatCoverage(kind: kind, start: start, end: end)) {
      _formats = _removeFormatCoverage(kind: kind, start: start, end: end);
    } else {
      _formats = _mergeFormatRanges(<TrainingDocumentFormatRange>[
        ..._formats,
        TrainingDocumentFormatRange(kind: kind, start: start, end: end),
      ]);
    }
    notifyListeners();
  }

  void _toggleListPrefix(_ListFormatKind kind) {
    final selectedBlock = _selectedBlockRange();
    if (selectedBlock == null) {
      return;
    }

    final lines = selectedBlock.text.split('\n');
    final nonEmptyLines = _nonEmptyLines(lines);
    final shouldRemove = switch (kind) {
      _ListFormatKind.bullet =>
        nonEmptyLines.isNotEmpty && nonEmptyLines.every(_isBulletedLine),
      _ListFormatKind.numbered =>
        nonEmptyLines.isNotEmpty && nonEmptyLines.every(_isNumberedLine),
    };

    var numberedLineIndex = 0;
    final transformedBlock = lines
        .map((line) {
          if (line.trim().isEmpty) {
            return line;
          }

          if (shouldRemove) {
            return _stripListPrefix(line);
          }

          final plainLine = _stripListPrefix(line);
          return switch (kind) {
            _ListFormatKind.bullet => '• $plainLine',
            _ListFormatKind.numbered => '${++numberedLineIndex}. $plainLine',
          };
        })
        .join('\n');

    _replaceTextRange(
      start: selectedBlock.start,
      end: selectedBlock.end,
      replacement: transformedBlock,
      selectionStart: selectedBlock.start,
      selectionEnd: selectedBlock.start + transformedBlock.length,
    );
  }

  void _replaceTextRange({
    required int start,
    required int end,
    required String replacement,
    required int selectionStart,
    required int selectionEnd,
  }) {
    final currentText = text;
    final safeStart = start.clamp(0, currentText.length);
    final safeEnd = end.clamp(safeStart, currentText.length);
    final updatedText = currentText.replaceRange(
      safeStart,
      safeEnd,
      replacement,
    );
    final removedLength = safeEnd - safeStart;
    final insertedLength = replacement.length;
    _formats = _adjustFormatRangesForTextChange(
      _formats,
      changedStart: safeStart,
      removedLength: removedLength,
      insertedLength: insertedLength,
    );

    _isProgrammaticChange = true;
    value = value.copyWith(
      text: updatedText,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: selectionEnd,
      ),
      composing: TextRange.empty,
    );
    _lastText = updatedText;
    _isProgrammaticChange = false;
    notifyListeners();
  }

  TextSelection? _normalizedSelection({bool allowCollapsed = false}) {
    final selection = value.selection;
    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      return null;
    }

    final start = min(selection.start, selection.end);
    final end = max(selection.start, selection.end);
    if (!allowCollapsed && start == end) {
      return null;
    }

    return TextSelection(baseOffset: start, extentOffset: end);
  }

  bool _hasFormatCoverage({
    required TrainingDocumentFormatKind kind,
    required int start,
    required int end,
  }) {
    return _formats.any(
      (format) =>
          format.kind == kind && format.start <= start && format.end >= end,
    );
  }

  List<TrainingDocumentFormatRange> _removeFormatCoverage({
    required TrainingDocumentFormatKind kind,
    required int start,
    required int end,
  }) {
    final updatedRanges = <TrainingDocumentFormatRange>[];

    for (final format in _formats) {
      if (format.kind != kind || format.end <= start || format.start >= end) {
        updatedRanges.add(format);
        continue;
      }

      if (format.start < start) {
        updatedRanges.add(format.copyWith(end: start));
      }
      if (format.end > end) {
        updatedRanges.add(format.copyWith(start: end));
      }
    }

    return _mergeFormatRanges(updatedRanges);
  }

  ({int start, int end, String text})? _selectedBlockRange() {
    final resolvedSelection = _normalizedSelection();
    if (resolvedSelection == null) {
      return null;
    }

    final currentText = text;
    final start = min(resolvedSelection.start, resolvedSelection.end);
    final end = max(resolvedSelection.start, resolvedSelection.end);
    final blockStart = start == 0
        ? 0
        : currentText.lastIndexOf('\n', start - 1) + 1;
    final blockEndCandidate = currentText.indexOf('\n', end);
    final blockEnd = blockEndCandidate == -1
        ? currentText.length
        : blockEndCandidate;
    return (
      start: blockStart,
      end: blockEnd,
      text: currentText.substring(blockStart, blockEnd),
    );
  }

  Iterable<String> _nonEmptyLines(List<String> lines) {
    return lines.where((line) => line.trim().isNotEmpty);
  }

  bool _isBulletedLine(String line) {
    return line.startsWith('• ');
  }

  bool _isNumberedLine(String line) {
    return _numberedListPrefixPattern.hasMatch(line);
  }

  String _stripListPrefix(String line) {
    if (_isBulletedLine(line)) {
      return line.substring(2);
    }

    return line.replaceFirst(_numberedListPrefixPattern, '');
  }

  void _handleTextChanged() {
    if (_isProgrammaticChange) {
      return;
    }

    if (_lastText == text) {
      return;
    }

    final diff = _resolveTextDiff(_lastText, text);
    _formats = _adjustFormatRangesForTextChange(
      _formats,
      changedStart: diff.start,
      removedLength: diff.removedLength,
      insertedLength: diff.insertedLength,
    );
    _lastText = text;
    notifyListeners();
  }

  TextStyle _styleForKinds(
    TextStyle baseStyle,
    Set<TrainingDocumentFormatKind> kinds,
  ) {
    var resolvedStyle = baseStyle;
    if (kinds.contains(TrainingDocumentFormatKind.bold)) {
      resolvedStyle = resolvedStyle.copyWith(fontWeight: FontWeight.w700);
    }
    if (kinds.contains(TrainingDocumentFormatKind.italic)) {
      resolvedStyle = resolvedStyle.copyWith(fontStyle: FontStyle.italic);
    }
    if (kinds.contains(TrainingDocumentFormatKind.underline)) {
      resolvedStyle = resolvedStyle.copyWith(
        decoration: TextDecoration.underline,
      );
    }
    if (kinds.contains(TrainingDocumentFormatKind.heading)) {
      resolvedStyle = resolvedStyle.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: (resolvedStyle.fontSize ?? 13) + 3,
        height: 1.45,
      );
    }
    if (kinds.contains(TrainingDocumentFormatKind.quote)) {
      resolvedStyle = resolvedStyle.copyWith(
        fontStyle: FontStyle.italic,
        color: quoteColor,
      );
    }

    return resolvedStyle;
  }

  @override
  void dispose() {
    removeListener(_handleTextChanged);
    super.dispose();
  }
}

enum _ListFormatKind { bullet, numbered }

({int start, int removedLength, int insertedLength}) _resolveTextDiff(
  String previousText,
  String nextText,
) {
  var prefixLength = 0;
  while (prefixLength < previousText.length &&
      prefixLength < nextText.length &&
      previousText.codeUnitAt(prefixLength) ==
          nextText.codeUnitAt(prefixLength)) {
    prefixLength++;
  }

  var previousSuffixIndex = previousText.length - 1;
  var nextSuffixIndex = nextText.length - 1;
  while (previousSuffixIndex >= prefixLength &&
      nextSuffixIndex >= prefixLength &&
      previousText.codeUnitAt(previousSuffixIndex) ==
          nextText.codeUnitAt(nextSuffixIndex)) {
    previousSuffixIndex--;
    nextSuffixIndex--;
  }

  final removedLength = previousSuffixIndex < prefixLength
      ? 0
      : previousSuffixIndex - prefixLength + 1;
  final insertedLength = nextSuffixIndex < prefixLength
      ? 0
      : nextSuffixIndex - prefixLength + 1;

  return (
    start: prefixLength,
    removedLength: removedLength,
    insertedLength: insertedLength,
  );
}

List<TrainingDocumentFormatRange> _adjustFormatRangesForTextChange(
  List<TrainingDocumentFormatRange> formats, {
  required int changedStart,
  required int removedLength,
  required int insertedLength,
}) {
  final changedEnd = changedStart + removedLength;
  final delta = insertedLength - removedLength;
  final adjustedRanges = <TrainingDocumentFormatRange>[];

  for (final format in formats) {
    var start = format.start;
    var end = format.end;

    if (end <= changedStart) {
      adjustedRanges.add(format);
      continue;
    }

    if (start >= changedEnd) {
      adjustedRanges.add(
        format.copyWith(start: start + delta, end: end + delta),
      );
      continue;
    }

    if (start < changedStart && end > changedEnd) {
      adjustedRanges.add(format.copyWith(end: end + delta));
      continue;
    }

    if (start < changedStart && end > changedStart && end <= changedEnd) {
      adjustedRanges.add(format.copyWith(end: changedStart));
      continue;
    }

    if (start >= changedStart && start < changedEnd && end > changedEnd) {
      adjustedRanges.add(
        format.copyWith(start: changedStart + insertedLength, end: end + delta),
      );
    }
  }

  return _mergeFormatRanges(adjustedRanges);
}

List<TrainingDocumentFormatRange> _mergeFormatRanges(
  List<TrainingDocumentFormatRange> ranges,
) {
  final sortedRanges =
      ranges
          .where((range) => range.isValid)
          .map(
            (range) => TrainingDocumentFormatRange(
              kind: range.kind,
              start: min(range.start, range.end),
              end: max(range.start, range.end),
            ),
          )
          .toList()
        ..sort((left, right) {
          final kindComparison = left.kind.index.compareTo(right.kind.index);
          if (kindComparison != 0) {
            return kindComparison;
          }
          final startComparison = left.start.compareTo(right.start);
          if (startComparison != 0) {
            return startComparison;
          }
          return left.end.compareTo(right.end);
        });

  final mergedRanges = <TrainingDocumentFormatRange>[];
  for (final range in sortedRanges) {
    if (mergedRanges.isEmpty) {
      mergedRanges.add(range);
      continue;
    }

    final previous = mergedRanges.last;
    if (previous.kind == range.kind && previous.end >= range.start) {
      mergedRanges[mergedRanges.length - 1] = previous.copyWith(
        end: max(previous.end, range.end),
      );
      continue;
    }

    mergedRanges.add(range);
  }

  return mergedRanges;
}

_TrainingParsedDocument _parseHtmlDocument(String? html) {
  final source = html?.trim() ?? '';
  if (source.isEmpty) {
    return const _TrainingParsedDocument(
      text: '',
      formats: <TrainingDocumentFormatRange>[],
    );
  }

  final buffer = StringBuffer();
  final formats = <TrainingDocumentFormatRange>[];
  final tokens = RegExp(r'<[^>]+>|[^<]+').allMatches(source);
  final tagStack = <TrainingDocumentFormatKind, List<int>>{
    for (final kind in TrainingDocumentFormatKind.values) kind: <int>[],
  };

  var insideOrderedList = false;
  var orderedListIndex = 0;
  var pendingBlockBreaks = 0;

  void appendNewLine({int count = 1}) {
    final existing = buffer.toString();
    final trailingNewLines =
        RegExp(r'\n*$').firstMatch(existing)?.group(0)?.length ?? 0;
    final needed = max(0, count - trailingNewLines);
    if (needed > 0) {
      buffer.write('\n' * needed);
    }
  }

  void flushBlockBreaks() {
    if (buffer.isNotEmpty && pendingBlockBreaks > 0) {
      appendNewLine(count: pendingBlockBreaks);
    }
    pendingBlockBreaks = 0;
  }

  void appendText(String value) {
    if (value.isEmpty || (pendingBlockBreaks > 0 && value.trim().isEmpty)) {
      return;
    }
    flushBlockBreaks();
    buffer.write(
      value
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>'),
    );
  }

  void openStyle(TrainingDocumentFormatKind kind) {
    flushBlockBreaks();
    tagStack[kind]!.add(buffer.length);
  }

  void closeStyle(TrainingDocumentFormatKind kind) {
    final positions = tagStack[kind]!;
    if (positions.isEmpty) {
      return;
    }
    final start = positions.removeLast();
    final end = buffer.length;
    if (end > start) {
      formats.add(
        TrainingDocumentFormatRange(kind: kind, start: start, end: end),
      );
    }
  }

  for (final match in tokens) {
    final token = match.group(0) ?? '';
    if (token.startsWith('<')) {
      final tag = RegExp(
        r'^<\s*(/?)\s*([a-z][a-z0-9]*)\b',
        caseSensitive: false,
      ).firstMatch(token);
      if (tag == null) continue;
      final normalized = '<${tag.group(1)}${tag.group(2)!.toLowerCase()}>';
      if (normalized == '<br>') {
        // Explicit breaks are additive. Block spacing is satisfied by these
        // breaks when the next text arrives, so save/reload cannot double it.
        buffer.write('\n');
        continue;
      }

      if (normalized == '<p>' || normalized == '<div>') {
        flushBlockBreaks();
        continue;
      }

      if (normalized == '</p>' || normalized == '</div>') {
        pendingBlockBreaks = max(pendingBlockBreaks, 2);
        continue;
      }

      if (normalized == '<strong>' || normalized == '<b>') {
        openStyle(TrainingDocumentFormatKind.bold);
        continue;
      }

      if (normalized == '</strong>' || normalized == '</b>') {
        closeStyle(TrainingDocumentFormatKind.bold);
        continue;
      }

      if (normalized == '<em>' || normalized == '<i>') {
        openStyle(TrainingDocumentFormatKind.italic);
        continue;
      }

      if (normalized == '</em>' || normalized == '</i>') {
        closeStyle(TrainingDocumentFormatKind.italic);
        continue;
      }

      if (normalized == '<u>') {
        openStyle(TrainingDocumentFormatKind.underline);
        continue;
      }

      if (normalized == '</u>') {
        closeStyle(TrainingDocumentFormatKind.underline);
        continue;
      }

      if (normalized == '<blockquote>') {
        openStyle(TrainingDocumentFormatKind.quote);
        continue;
      }

      if (normalized == '</blockquote>') {
        closeStyle(TrainingDocumentFormatKind.quote);
        pendingBlockBreaks = max(pendingBlockBreaks, 2);
        continue;
      }

      if (RegExp(r'<h[1-6]>').hasMatch(normalized)) {
        openStyle(TrainingDocumentFormatKind.heading);
        continue;
      }

      if (RegExp(r'</h[1-6]>').hasMatch(normalized)) {
        closeStyle(TrainingDocumentFormatKind.heading);
        pendingBlockBreaks = max(pendingBlockBreaks, 2);
        continue;
      }

      if (normalized == '<ul>') {
        insideOrderedList = false;
        continue;
      }

      if (normalized == '<ol>') {
        insideOrderedList = true;
        orderedListIndex = 0;
        continue;
      }

      if (normalized == '<li>') {
        appendText(insideOrderedList ? '${++orderedListIndex}. ' : '\u2022 ');
        continue;
      }

      if (normalized == '</li>') {
        pendingBlockBreaks = max(pendingBlockBreaks, 1);
        continue;
      }

      continue;
    }

    appendText(token);
  }

  for (final kind in TrainingDocumentFormatKind.values) {
    while (tagStack[kind]!.isNotEmpty) {
      closeStyle(kind);
    }
  }

  final resolvedText = buffer.toString().trimRight();
  final trimmedFormats = formats
      .map(
        (range) => TrainingDocumentFormatRange(
          kind: range.kind,
          start: min(range.start, resolvedText.length),
          end: min(range.end, resolvedText.length),
        ),
      )
      .where((range) => range.isValid)
      .toList(growable: false);

  return _TrainingParsedDocument(
    text: resolvedText,
    formats: _mergeFormatRanges(trimmedFormats),
  );
}

String _serializeHtmlDocument(
  String source,
  List<TrainingDocumentFormatRange> formats,
) {
  final resolvedText = source.trim();
  if (resolvedText.isEmpty) {
    return '';
  }

  final safeFormats = _mergeFormatRanges(
    formats,
  ).where((range) => range.end <= resolvedText.length).toList(growable: false);
  final openTags = <int, List<String>>{};
  final closeTags = <int, List<String>>{};

  String tagNameFor(TrainingDocumentFormatKind kind) {
    return switch (kind) {
      TrainingDocumentFormatKind.bold => 'strong',
      TrainingDocumentFormatKind.italic => 'em',
      TrainingDocumentFormatKind.underline => 'u',
      TrainingDocumentFormatKind.heading => 'h3',
      TrainingDocumentFormatKind.quote => 'blockquote',
    };
  }

  for (final range in safeFormats) {
    final tagName = tagNameFor(range.kind);
    openTags.putIfAbsent(range.start, () => <String>[]).add(tagName);
    closeTags.putIfAbsent(range.end, () => <String>[]).add(tagName);
  }

  final buffer = StringBuffer();
  for (var index = 0; index <= resolvedText.length; index++) {
    final closing = closeTags[index];
    if (closing != null) {
      for (final tagName in closing.reversed) {
        buffer.write('</$tagName>');
      }
    }

    final opening = openTags[index];
    if (opening != null) {
      for (final tagName in opening) {
        buffer.write('<$tagName>');
      }
    }

    if (index == resolvedText.length) {
      continue;
    }

    final character = resolvedText[index];
    if (character == '\n') {
      buffer.write('<br>');
      continue;
    }

    buffer.write(
      character
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;'),
    );
  }

  return buffer.toString();
}

class TrainingModuleController extends ChangeNotifier {
  TrainingModuleController(
    this._auditRepository, {
    FileUploader? fileUploader,
    bool canManageTraining = false,
    bool canViewQuizAndAssignment = false,
    TrainingSopEditorFactory? sopEditorFactory,
    Future<SharedLessonContent> Function(String publicId)?
    sharedLessonDetailLoader,
  }) : _sopEditorFactory = sopEditorFactory,
       _fileUploader = fileUploader ?? const FileUploader(),
       _canManageTraining = canManageTraining,
       _canViewQuizAndAssignment =
           canManageTraining || canViewQuizAndAssignment,
       _sharedLessonDetailLoader = sharedLessonDetailLoader {
    newLessonTitleController.addListener(_handleNewLessonTitleChanged);
    moduleTitleController.addListener(_handleModuleTitleChanged);
    summaryController.addListener(_handleSummaryChanged);
    documentController.addListener(_handleDocumentChanged);
    assignmentTitleController.addListener(_handleAssignmentDraftChanged);
    assignmentDescriptionController.addListener(_handleAssignmentDraftChanged);
  }

  static const int minQuizQuestionCount = 1;
  static const int maxQuizQuestionCount = 10;
  static const int minQuizOptionsPerQuestion = 2;
  static const int maxQuizOptionsPerQuestion = 4;
  static const int maxTrainingVideoTitleLength = 128;
  static final Uuid _uuidGenerator = const Uuid();

  static String generateClientUuid() => _uuidGenerator.v1();

  final AuditRepository _auditRepository;
  final TrainingSopEditorFactory? _sopEditorFactory;
  final Future<SharedLessonContent> Function(String publicId)?
  _sharedLessonDetailLoader;
  final FileUploader _fileUploader;
  final bool _canManageTraining;
  final bool _canViewQuizAndAssignment;
  bool _isDisposed = false;
  final TextEditingController newLessonTitleController =
      TextEditingController();
  final TextEditingController moduleTitleController = TextEditingController();
  final TextEditingController summaryController = TextEditingController();
  final TextEditingController assignmentTitleController =
      TextEditingController();
  final TrainingRichTextEditingController documentController =
      TrainingRichTextEditingController(quoteColor: AppColors.grey2);
  final TrainingRichTextEditingController assignmentDescriptionController =
      TrainingRichTextEditingController(quoteColor: AppColors.grey2);
  bool _lastAssignmentDraftHasTitle = false;
  final Map<String, String> _moduleLocalVideoPaths = <String, String>{};

  bool _isLoading = false;
  bool _isDocumentLoading = false;
  int _documentRequestVersion = 0;
  bool _isAssignmentLoading = false;
  bool _isQuestionsLoading = false;
  bool _isCreatingNewLessonDraft = false;
  String? _moduleIdBeforeNewLessonDraft;
  bool _isCreatingModule = false;
  bool _isUploadingVideo = false;
  bool _isDeletingVideo = false;
  bool _isUploadingThumbnail = false;
  String? _errorMessage;
  String? _documentErrorMessage;
  String? _assignmentErrorMessage;
  String? _questionsErrorMessage;
  String? _summarySnackBarMessage;
  List<SeatDescriptionTrainingModule> _modules =
      const <SeatDescriptionTrainingModule>[];
  SeatDescriptionTrainingModuleDetail? _selectedModuleDetail;
  SeatDescriptionTrainingDocument? _selectedModuleDocument;
  SeatDescriptionTrainingAssignment? _selectedModuleAssignment;
  List<SeatDescriptionTrainingQuestion> _selectedModuleQuestions =
      const <SeatDescriptionTrainingQuestion>[];
  String _selectedModuleId = '';
  bool _hasResolvedAssignment = false;
  bool _hasResolvedQuestions = false;
  int _quizGenerationQuestionCount = 3;
  int _quizGenerationOptionsPerQuestion = 4;
  QuizGenerationDifficulty _quizGenerationDifficulty =
      QuizGenerationDifficulty.medium;
  bool _replaceExistingQuestions = true;
  bool _isGeneratingQuiz = false;
  bool _isGeneratingSop = false;
  bool _isGeneratingAssignment = false;
  bool _isGeneratingSummary = false;
  bool _isAddingQuestion = false;
  bool _isEditingSummary = false;
  bool _isSavingModuleTitle = false;
  bool _isSavingSummary = false;
  bool? _editingSummaryVisibility;
  bool _isSavingDocument = false;
  bool _isSavingAssignment = false;
  bool _isSyncingModuleTitleController = false;
  bool _isSyncingSummaryController = false;
  bool _lastSummaryDraftHasContent = false;
  bool _isSyncingDocumentController = false;
  bool _isSyncingAssignmentController = false;
  String? _savingQuestionId;
  String? _deletingQuestionId;
  String? _deletingQuestionOptionKey;
  String? _deletingModuleId;
  String? _updatingModuleVisibilityId;
  String _jobId = '';
  String _descriptionId = '';
  int _summarySnackBarSequence = 0;
  String _lastSavedModuleTitle = '';
  String _lastSavedSummaryText = '';
  int _summaryEditorVersion = 0;
  String _lastSavedDocumentHtml = '';
  String _documentDraftHtml = '';
  int _documentEditorVersion = 0;
  TrainingSopEditorController? _sopEditorController;
  String _lastSavedAssignmentTitle = '';
  String _lastSavedAssignmentHtml = '';
  String _lastObservedAssignmentTitle = '';
  String _lastObservedAssignmentHtml = '';
  int _assignmentDraftVersion = 0;
  int _assignmentEditorVersion = 0;
  Timer? _moduleTitleAutoSaveDebounce;
  Timer? _summaryAutoSaveDebounce;
  Timer? _summaryWritingTimer;
  Completer<bool>? _summaryWritingCompletion;
  Timer? _documentAutoSaveDebounce;
  Timer? _assignmentAutoSaveDebounce;

  bool get isLoading => _isLoading;
  bool get isDocumentLoading => _isDocumentLoading;
  bool get hasResolvedSelectedModuleDocument =>
      _selectedModuleDocument != null || _documentErrorMessage != null;
  bool get isAssignmentLoading => _isAssignmentLoading;
  bool get isGeneratingAssignment => _isGeneratingAssignment;
  bool get isQuestionsLoading => _isQuestionsLoading;
  bool get isCreatingNewLessonDraft => _isCreatingNewLessonDraft;
  bool get isCreatingModule => _isCreatingModule;
  bool get isUploadingVideo => _isUploadingVideo;
  bool get isDeletingVideo => _isDeletingVideo;
  bool get isUploadingThumbnail => _isUploadingThumbnail;
  bool get isUpdatingVideoActions => _isDeletingVideo || _isUploadingThumbnail;
  String? get errorMessage => _errorMessage;
  String? get documentErrorMessage => _documentErrorMessage;
  String? get assignmentErrorMessage => _assignmentErrorMessage;
  String? get questionsErrorMessage => _questionsErrorMessage;
  String? get summarySnackBarMessage => _summarySnackBarMessage;
  List<SeatDescriptionTrainingModule> get modules => _modules;
  String get selectedModuleId => _selectedModuleId;
  bool get hasSelectedModule => _selectedModuleId.trim().isNotEmpty;
  String? get selectedModuleLocalVideoPath {
    final selectedModuleId = _selectedModuleId.trim();
    if (selectedModuleId.isEmpty) {
      return null;
    }

    final path = _moduleLocalVideoPaths[selectedModuleId]?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }

    return path;
  }

  SeatDescriptionTrainingModuleDetail? get selectedModuleDetail =>
      _selectedModuleDetail;
  SeatDescriptionTrainingDocument? get selectedModuleDocument =>
      _selectedModuleDocument;
  SeatDescriptionTrainingAssignment? get selectedModuleAssignment =>
      _selectedModuleAssignment;
  List<SeatDescriptionTrainingQuestion> get selectedModuleQuestions =>
      _selectedModuleQuestions;
  int get quizGenerationQuestionCount => _quizGenerationQuestionCount;
  int get quizGenerationOptionsPerQuestion => _quizGenerationOptionsPerQuestion;
  QuizGenerationDifficulty get quizGenerationDifficulty =>
      _quizGenerationDifficulty;
  bool get replaceExistingQuestions => _replaceExistingQuestions;
  bool get isGeneratingQuiz => _isGeneratingQuiz;
  bool get isGeneratingSop => _isGeneratingSop;
  bool get isGeneratingSummary => _isGeneratingSummary;
  bool get isWritingSummary => _summaryWritingTimer?.isActive ?? false;
  bool get isAddingQuestion => _isAddingQuestion;
  bool get isEditingSummary => _isEditingSummary;
  bool get isSavingModuleTitle => _isSavingModuleTitle;
  bool get isSavingSummary => _isSavingSummary;
  bool get summaryVisibilityValue =>
      _editingSummaryVisibility ??
      _selectedModuleDetail?.isPubliclyAvailable ??
      false;
  bool get isSavingDocument => _isSavingDocument;
  String get documentHtml => _documentDraftHtml;
  int get documentEditorVersion => _documentEditorVersion;
  TrainingSopEditorController get sopEditorController {
    final existingEditor = _sopEditorController;
    if (existingEditor != null) return existingEditor;
    final moduleId = _selectedModuleId;
    final editorVersion = _documentEditorVersion;
    // Keep the engine and pending HTML reads alive when its pager page unmounts.
    void onHtmlChanged(String html) => updateDocumentHtml(
      moduleId: moduleId,
      editorVersion: editorVersion,
      html: html,
    );
    final editor =
        _sopEditorFactory?.call(_documentDraftHtml, onHtmlChanged) ??
        TrainingSopEditorController(
          initialHtml: _documentDraftHtml,
          onHtmlChanged: onHtmlChanged,
        );
    _sopEditorController = editor;
    unawaited(editor.initialize());
    return editor;
  }

  bool get isSavingAssignment => _isSavingAssignment;
  String? get savingQuestionId => _savingQuestionId;
  String? get deletingQuestionId => _deletingQuestionId;
  String? get deletingQuestionOptionKey => _deletingQuestionOptionKey;
  String? get deletingModuleId => _deletingModuleId;
  String? get updatingModuleVisibilityId => _updatingModuleVisibilityId;
  bool get canManageTraining => _canManageTraining;
  bool get canSubmitNewLessonTitle =>
      _canManageTraining &&
      !_isCreatingModule &&
      newLessonTitleController.text.trim().isNotEmpty;
  bool get canAccessSelectedModuleExtras =>
      !_isCreatingNewLessonDraft && hasSelectedModule;
  int get maxAccessibleTabIndex => maxTrainingTabIndex(
    hasSelectedModule: canAccessSelectedModuleExtras,
    canViewQuizAndAssignment: _canViewQuizAndAssignment,
  );
  bool get hasSelectedModuleVideo {
    final video = _selectedModuleDetail?.trainingVideo;
    if (video == null) {
      return false;
    }

    final videoId = video.uuid.trim();
    final videoUrl = video.url?.trim() ?? '';
    return videoId.isNotEmpty || videoUrl.isNotEmpty;
  }

  bool get hasSelectedModuleVideoTranscript =>
      _selectedModuleDetail?.trainingVideo?.transcript?.trim().isNotEmpty ??
      false;
  // A generated summary can arrive before the cached video transcript updates.
  bool get hasSelectedModuleSummary => CustomFunctions.stripHtmlTags(
    _selectedModuleDetail?.description,
    emptyText: '',
  ).isNotEmpty;

  bool get canUploadSelectedModuleVideo =>
      _canManageTraining &&
      !_isCreatingNewLessonDraft &&
      hasSelectedModule &&
      !_isUploadingVideo &&
      !_isDeletingVideo &&
      !_isUploadingThumbnail &&
      !_isLoading;
  bool get canGenerateSopForSelectedModule =>
      _canManageTraining &&
      hasSelectedModule &&
      hasSelectedModuleVideo &&
      (hasSelectedModuleVideoTranscript || hasSelectedModuleSummary) &&
      !_isGeneratingSop;
  bool get canGenerateSummaryForSelectedModule =>
      canEditSelectedModuleSummary &&
      hasSelectedModuleVideo &&
      hasSelectedModuleSummary &&
      summaryController.text.trim().isNotEmpty &&
      !_isDisposed &&
      !_isLoading &&
      !_isUploadingVideo &&
      !_isDeletingVideo &&
      !_isUploadingThumbnail &&
      !_isSavingSummary &&
      !_isGeneratingSummary;
  bool get canGenerateQuizForSelectedModule =>
      _canManageTraining &&
      hasSelectedModule &&
      hasSelectedModuleVideo &&
      (hasSelectedModuleVideoTranscript || hasSelectedModuleSummary) &&
      !_isGeneratingQuiz;
  bool get canAddQuestionToSelectedModule =>
      _canManageTraining &&
      hasSelectedModule &&
      hasSelectedModuleVideo &&
      !_isAddingQuestion;
  bool get canEditSelectedModuleTitle =>
      _canManageTraining && hasSelectedModule && !_isCreatingNewLessonDraft;
  bool get canEditSelectedModuleSummary =>
      _canManageTraining && hasSelectedModule && !_isCreatingNewLessonDraft;
  bool get canEditSelectedModuleDocument =>
      _canManageTraining && hasSelectedModule && !_isCreatingNewLessonDraft;
  bool get canEditSelectedModuleAssignment =>
      _canManageTraining && hasSelectedModule && !_isCreatingNewLessonDraft;
  bool get canGenerateAssignmentForSelectedModule =>
      _canManageTraining &&
      hasSelectedModule &&
      !_isGeneratingAssignment &&
      !_isAssignmentLoading;
  bool get hasAssignmentDraftContent =>
      assignmentTitleController.text.trim().isNotEmpty ||
      assignmentDescriptionController.text.trim().isNotEmpty;
  bool get hasAssignmentTitle =>
      assignmentTitleController.text.trim().isNotEmpty;
  // Existing assignments may have no title; editing their instructions does
  // not require sending or changing the title in a partial update.
  bool get _hasValidAssignmentDraftTitle =>
      hasAssignmentTitle ||
      (hasPersistedSelectedModuleAssignment &&
          _lastSavedAssignmentTitle.isEmpty);
  bool get hasAssignmentChanges =>
      assignmentTitleController.text.trim() != _lastSavedAssignmentTitle ||
      assignmentDescriptionController.toHtml().trim() !=
          _lastSavedAssignmentHtml;
  bool get canSaveSelectedModuleAssignment =>
      canEditSelectedModuleAssignment &&
      _hasResolvedAssignment &&
      !_isAssignmentLoading &&
      !_isSavingAssignment &&
      _hasValidAssignmentDraftTitle;
  bool get hasSelectedModuleDocumentText {
    final text = _selectedModuleDocument?.text?.trim();
    return text != null && text.isNotEmpty;
  }

  bool get hasSelectedModuleAssignmentContent =>
      _selectedModuleAssignment?.hasContent ??
      _selectedModuleDetail?.hasAssignmentContent ??
      false;
  String? get selectedModuleAssignmentInstructions =>
      _selectedModuleAssignment?.instructions ??
      _selectedModuleDetail?.assignmentInstructions;
  bool get hasSelectedModuleAssignmentInstructions =>
      assignmentDescriptionController.text.trim().isNotEmpty;
  bool get hasResolvedSelectedModuleAssignment => _hasResolvedAssignment;
  bool get hasPersistedSelectedModuleAssignment =>
      _selectedModuleAssignment?.uuid.trim().isNotEmpty ?? false;

  bool isDeletingModule(String moduleId) =>
      _deletingModuleId == moduleId.trim();
  bool isUpdatingModuleVisibility(String moduleId) =>
      _updatingModuleVisibilityId == moduleId.trim();
  bool isSavingQuestion(String questionId) =>
      _savingQuestionId == questionId.trim();

  bool isDeletingQuestion(String questionId) =>
      _deletingQuestionId == questionId.trim();
  int get summarySnackBarSequence => _summarySnackBarSequence;
  int get selectedModuleIndex =>
      _modules.indexWhere((module) => module.uuid == _selectedModuleId);
  int get totalModules => _modules.length;
  bool get hasPersistedSelectedModule => selectedModuleIndex >= 0;
  SeatDescriptionTrainingModule? get selectedModule {
    final index = selectedModuleIndex;
    if (index < 0 || index >= _modules.length) {
      return null;
    }

    return _modules[index];
  }

  bool get isSelectedModulePubliclyAvailable =>
      _selectedModuleDetail?.isPubliclyAvailable ??
      selectedModule?.isPubliclyAvailable ??
      false;

  int get selectedModuleNumber =>
      hasPersistedSelectedModule ? selectedModuleIndex + 1 : 0;
  bool get canSelectPreviousModule =>
      !_isCreatingNewLessonDraft &&
      hasPersistedSelectedModule &&
      selectedModuleIndex > 0;
  bool get canSelectNextModule =>
      !_isCreatingNewLessonDraft &&
      hasPersistedSelectedModule &&
      selectedModuleIndex < _modules.length - 1;
  bool get canSelectFirstModuleFromDraft =>
      _isCreatingNewLessonDraft && _modules.isNotEmpty;
  bool get canSwipeBetweenModules =>
      canSelectPreviousModule ||
      canSelectNextModule ||
      canSelectFirstModuleFromDraft;

  String get selectedModuleTitle {
    if (_isCreatingNewLessonDraft) {
      return newLessonTitleController.text.trim();
    }

    final detailTitle = _selectedModuleDetail?.title.trim();
    if (detailTitle != null && detailTitle.isNotEmpty) {
      return detailTitle;
    }

    for (final module in _modules) {
      if (module.uuid == _selectedModuleId) {
        return module.title;
      }
    }

    return '';
  }

  Future<void> selectPreviousModule() async {
    if (!canSelectPreviousModule) {
      return;
    }

    await selectModule(_modules[selectedModuleIndex - 1].uuid);
  }

  Future<void> selectNextModule() async {
    if (canSelectNextModule) {
      await selectModule(_modules[selectedModuleIndex + 1].uuid);
      return;
    }

    if (canSelectFirstModuleFromDraft) {
      await selectModule(_modules.first.uuid);
    }
  }

  Future<void> initialize({
    required String jobId,
    required String descriptionId,
    String? initialModuleId,
    bool startNewLessonWhenEmpty = false,
  }) async {
    final resolvedJobId = jobId.trim();
    final resolvedDescriptionId = descriptionId.trim();
    if (resolvedDescriptionId.isEmpty) {
      _errorMessage = AppStrings.loginSomethingWentWrong;
      notifyListeners();
      return;
    }

    _jobId = resolvedJobId;
    _descriptionId = resolvedDescriptionId;
    _isLoading = true;
    _errorMessage = null;
    _isCreatingNewLessonDraft = false;
    _isCreatingModule = false;
    _moduleIdBeforeNewLessonDraft = null;
    _isUploadingVideo = false;
    _moduleLocalVideoPaths.clear();
    _modules = const <SeatDescriptionTrainingModule>[];
    _selectedModuleId = '';
    _selectedModuleDetail = null;
    _updatingModuleVisibilityId = null;
    _resetSelectedModuleExtras();
    _resetEditors();
    newLessonTitleController.clear();
    notifyListeners();

    try {
      final modules = await _auditRepository.getSeatDescriptionTrainingModules(
        descriptionId: resolvedDescriptionId,
      );
      _modules = modules;

      if (modules.isEmpty && startNewLessonWhenEmpty && _canManageTraining) {
        _isLoading = false;
        startCreatingNewLessonDraft();
        return;
      }

      if (modules.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final resolvedInitialModuleId = initialModuleId?.trim() ?? '';
      var selectedModuleId = modules.first.uuid;
      for (final module in modules) {
        if (module.uuid == resolvedInitialModuleId) {
          selectedModuleId = module.uuid;
          break;
        }
      }
      _selectedModuleId = selectedModuleId;
      _syncTitleEditorText();
      notifyListeners();
      await _loadSelectedModuleDetail();
    } catch (error) {
      _errorMessage = error.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initializeSharedLesson(String lessonId) async {
    final resolvedLessonId = lessonId.trim();
    if (resolvedLessonId.isEmpty) {
      _errorMessage = AppStrings.trainingSharedLessonUnavailable;
      notifyListeners();
      return;
    }

    _jobId = '';
    _descriptionId = '';
    _isCreatingNewLessonDraft = false;
    _moduleIdBeforeNewLessonDraft = null;
    _moduleLocalVideoPaths.clear();
    _modules = const <SeatDescriptionTrainingModule>[];
    _selectedModuleId = resolvedLessonId;
    _selectedModuleDetail = null;
    _errorMessage = null;
    _resetSelectedModuleExtras();
    _resetEditors();
    newLessonTitleController.clear();
    await _loadSelectedModuleDetail();
    if (_isDisposed) return;

    final detail = _selectedModuleDetail;
    if (detail == null) {
      _errorMessage = AppStrings.trainingSharedLessonUnavailable;
      notifyListeners();
      return;
    }

    _modules = <SeatDescriptionTrainingModule>[
      SeatDescriptionTrainingModule(
        uuid: resolvedLessonId,
        actualId: detail.actualId,
        title: detail.title,
        thumbnailLink: detail.previewThumbnailLink,
        isPubliclyAvailable: detail.isPubliclyAvailable,
      ),
    ];
    notifyListeners();
  }

  Future<void> selectModule(String moduleId) async {
    final resolvedModuleId = moduleId.trim();
    if (resolvedModuleId.isEmpty) {
      return;
    }

    if (_selectedModuleId == resolvedModuleId &&
        _selectedModuleDetail != null &&
        _errorMessage == null) {
      return;
    }

    _isCreatingNewLessonDraft = false;
    _selectedModuleId = resolvedModuleId;
    _moduleIdBeforeNewLessonDraft = null;
    _selectedModuleDetail = null;
    _resetSelectedModuleExtras();
    _resetEditors();
    _syncTitleEditorText();
    await _loadSelectedModuleDetail();
  }

  void startCreatingNewLessonDraft() {
    if (!_canManageTraining || _isCreatingModule) {
      return;
    }

    if (!_isCreatingNewLessonDraft) {
      _moduleIdBeforeNewLessonDraft = _selectedModuleId;
    }
    _isCreatingNewLessonDraft = true;
    _errorMessage = null;
    _selectedModuleId = '';
    _selectedModuleDetail = null;
    _updatingModuleVisibilityId = null;
    _resetSelectedModuleExtras();
    _resetEditors();
    newLessonTitleController.clear();
    notifyListeners();
  }

  Future<void> cancelCreatingNewLessonDraft() async {
    if (!_isCreatingNewLessonDraft || _isCreatingModule) {
      return;
    }

    final previousModuleId = _moduleIdBeforeNewLessonDraft;
    _isCreatingNewLessonDraft = false;
    _moduleIdBeforeNewLessonDraft = null;
    _errorMessage = null;
    newLessonTitleController.clear();

    if (_modules.isEmpty) {
      notifyListeners();
      return;
    }

    final moduleId = _modules.any((module) => module.uuid == previousModuleId)
        ? previousModuleId!
        : _modules.first.uuid;
    await selectModule(moduleId);
  }

  Future<bool> createModuleFromDraft() async {
    final resolvedTitle = newLessonTitleController.text.trim();
    if (!_canManageTraining ||
        _isCreatingModule ||
        resolvedTitle.isEmpty ||
        _jobId.isEmpty ||
        _descriptionId.isEmpty) {
      return false;
    }

    _isCreatingModule = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final createdModule = await _auditRepository
          .createSeatDescriptionTrainingModule(
            jobId: _jobId,
            descriptionId: _descriptionId,
            title: resolvedTitle,
          );
      final refreshedModules = await _auditRepository
          .getSeatDescriptionTrainingModules(descriptionId: _descriptionId);
      final resolvedModules = refreshedModules.isNotEmpty
          ? refreshedModules
          : <SeatDescriptionTrainingModule>[createdModule];
      final selectedModule = resolvedModules.last;

      _modules = List<SeatDescriptionTrainingModule>.from(
        resolvedModules,
        growable: false,
      );
      _isCreatingNewLessonDraft = false;
      _moduleIdBeforeNewLessonDraft = null;
      _selectedModuleId = selectedModule.uuid;
      _selectedModuleDetail = _buildModuleDetailFromModule(selectedModule);
      _updatingModuleVisibilityId = null;
      _resetSelectedModuleExtras();
      _resetEditors();
      _syncTitleEditorText();
      _syncSummaryEditorText();
      newLessonTitleController.clear();
      notifyListeners();
      unawaited(_loadSelectedModuleDetail());
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isCreatingModule = false;
      notifyListeners();
    }
  }

  Future<void> loadDocumentForSelectedModule() async {
    if (_selectedModuleDocument != null) {
      return;
    }

    try {
      await refreshDocumentForSelectedModule();
    } catch (_) {
      // Error state is already stored for the UI by refreshDocumentForSelectedModule.
    }
  }

  Future<void> refreshDocumentForSelectedModule() async {
    if (_selectedModuleId.isEmpty ||
        _isDocumentLoading ||
        _sharedLessonDetailLoader != null) {
      return;
    }

    final moduleId = _selectedModuleId;
    final requestVersion = ++_documentRequestVersion;
    _isDocumentLoading = true;
    _documentErrorMessage = null;
    notifyListeners();

    try {
      final document = await _auditRepository
          .getSeatDescriptionTrainingModuleDocument(moduleId: moduleId);
      if (requestVersion != _documentRequestVersion) return;
      _selectedModuleDocument = document;
      _syncDocumentEditorText();
    } catch (error) {
      if (requestVersion != _documentRequestVersion) return;
      _documentErrorMessage = error.toString();
      rethrow;
    } finally {
      if (requestVersion == _documentRequestVersion) {
        _isDocumentLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadAssignmentForSelectedModule() async {
    if (_selectedModuleId.isEmpty ||
        _isAssignmentLoading ||
        _hasResolvedAssignment) {
      return;
    }

    try {
      await refreshAssignmentForSelectedModule();
    } catch (_) {
      // Error state is already stored for the UI by refreshAssignmentForSelectedModule.
    }
  }

  Future<void> refreshAssignmentForSelectedModule() async {
    if (_selectedModuleId.isEmpty ||
        _isAssignmentLoading ||
        _sharedLessonDetailLoader != null) {
      return;
    }

    _isAssignmentLoading = true;
    _assignmentErrorMessage = null;
    notifyListeners();

    try {
      final assignment = await _auditRepository
          .getSeatDescriptionTrainingModuleAssignment(
            moduleId: _selectedModuleId,
          );
      _selectedModuleAssignment = assignment;
      _hasResolvedAssignment = true;
      _applySelectedModuleAssignment(
        title: assignment.title,
        instructions: assignment.instructions,
        notifyListenersAfterUpdate: false,
      );
      _syncAssignmentEditorText();
    } catch (error) {
      if (error is ApiError && error.statusCode == 404) {
        _selectedModuleAssignment = const SeatDescriptionTrainingAssignment(
          uuid: '',
          title: null,
          instructions: null,
        );
        _hasResolvedAssignment = true;
        _applySelectedModuleAssignment(
          title: null,
          instructions: null,
          notifyListenersAfterUpdate: false,
        );
        _syncAssignmentEditorText();
        return;
      }

      _assignmentErrorMessage = error.toString();
      rethrow;
    } finally {
      _isAssignmentLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadQuestionsForSelectedModule() async {
    if (_selectedModuleId.isEmpty ||
        _isQuestionsLoading ||
        _hasResolvedQuestions) {
      return;
    }

    try {
      await refreshQuestionsForSelectedModule();
    } catch (_) {
      // Error state is already stored for the UI by refreshQuestionsForSelectedModule.
    }
  }

  Future<void> refreshQuestionsForSelectedModule() async {
    if (_selectedModuleId.isEmpty ||
        _isQuestionsLoading ||
        _sharedLessonDetailLoader != null) {
      return;
    }

    _isQuestionsLoading = true;
    _questionsErrorMessage = null;
    notifyListeners();

    try {
      final questions = await _auditRepository
          .getSeatDescriptionTrainingModuleQuestions(
            moduleId: _selectedModuleId,
          );
      _updateSelectedModuleQuestions(questions);
    } catch (error) {
      _questionsErrorMessage = error.toString();
      rethrow;
    } finally {
      _isQuestionsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addQuestionToSelectedModule({
    required String questionText,
    required List<String> optionTexts,
    required int correctOptionIndex,
    File? questionImage,
  }) async {
    if (!_canManageTraining ||
        _selectedModuleId.isEmpty ||
        _isAddingQuestion ||
        !hasSelectedModuleVideo) {
      return false;
    }

    final moduleId = _selectedModuleId;
    final resolvedQuestion = questionText.trim();
    final resolvedOptionTexts = optionTexts
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    if (resolvedQuestion.isEmpty ||
        resolvedOptionTexts.length < 2 ||
        correctOptionIndex < 0 ||
        correctOptionIndex >= resolvedOptionTexts.length) {
      return false;
    }

    final options = resolvedOptionTexts
        .map(
          (text) => SeatDescriptionTrainingQuestionOption(
            uuid: generateClientUuid(),
            text: text,
          ),
        )
        .toList(growable: false);
    final correctOptionUuid = options[correctOptionIndex].uuid;

    _isAddingQuestion = true;
    _questionsErrorMessage = null;
    notifyListeners();

    try {
      final imageId = questionImage == null
          ? null
          : await _auditRepository.uploadTrainingQuestionImage(
              fileName: CustomFunctions.fileNameFromPath(questionImage.path),
              fileBytes: await questionImage.readAsBytes(),
              contentType: CustomFunctions.contentTypeFromPath(
                questionImage.path,
              ),
            );
      final createdQuestion = await _auditRepository
          .addSeatDescriptionTrainingQuestion(
            moduleId: moduleId,
            questionText: resolvedQuestion,
            options: options,
            correctOptionUuid: correctOptionUuid,
            imageId: imageId,
          );
      if (_selectedModuleId == moduleId) {
        _appendSelectedQuestion(createdQuestion);
      }
      return true;
    } catch (error) {
      _questionsErrorMessage = error.toString();
      return false;
    } finally {
      _isAddingQuestion = false;
      notifyListeners();
    }
  }

  void resetQuizGenerationForm() {
    _quizGenerationQuestionCount = 3;
    _quizGenerationOptionsPerQuestion = 4;
    _quizGenerationDifficulty = QuizGenerationDifficulty.medium;
    _replaceExistingQuestions = true;
    _questionsErrorMessage = null;
    notifyListeners();
  }

  void incrementQuizQuestionCount() {
    if (_quizGenerationQuestionCount >= maxQuizQuestionCount) {
      return;
    }

    _quizGenerationQuestionCount += 1;
    notifyListeners();
  }

  void decrementQuizQuestionCount() {
    if (_quizGenerationQuestionCount <= minQuizQuestionCount) {
      return;
    }

    _quizGenerationQuestionCount -= 1;
    notifyListeners();
  }

  void incrementQuizOptionsPerQuestion() {
    if (_quizGenerationOptionsPerQuestion >= maxQuizOptionsPerQuestion) {
      return;
    }

    _quizGenerationOptionsPerQuestion += 1;
    notifyListeners();
  }

  void decrementQuizOptionsPerQuestion() {
    if (_quizGenerationOptionsPerQuestion <= minQuizOptionsPerQuestion) {
      return;
    }

    _quizGenerationOptionsPerQuestion -= 1;
    notifyListeners();
  }

  void setQuizGenerationDifficulty(QuizGenerationDifficulty difficulty) {
    if (_quizGenerationDifficulty == difficulty) {
      return;
    }

    _quizGenerationDifficulty = difficulty;
    notifyListeners();
  }

  void setReplaceExistingQuestions(bool value) {
    if (_replaceExistingQuestions == value) {
      return;
    }

    _replaceExistingQuestions = value;
    notifyListeners();
  }

  Future<bool> generateQuizForSelectedModule() async {
    if (!canGenerateQuizForSelectedModule) {
      return false;
    }

    _isGeneratingQuiz = true;
    _questionsErrorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.generateSeatDescriptionTrainingModuleQuiz(
        moduleId: _selectedModuleId,
        numQuestions: _quizGenerationQuestionCount,
        optionsPerQuestion: _quizGenerationOptionsPerQuestion,
        difficultyLevel: _quizGenerationDifficulty.apiValue,
        replaceExistingQuestions: _replaceExistingQuestions,
      );
      await refreshQuestionsForSelectedModule();
      return true;
    } catch (error) {
      _questionsErrorMessage = error.toString();
      return false;
    } finally {
      _isGeneratingQuiz = false;
      notifyListeners();
    }
  }

  Future<bool> generateSummaryForSelectedModule({bool animate = true}) async {
    if (!canGenerateSummaryForSelectedModule) {
      return false;
    }

    final moduleId = _selectedModuleId;
    final editorVersion = _summaryEditorVersion;
    _summaryAutoSaveDebounce?.cancel();
    _isGeneratingSummary = true;
    notifyListeners();

    try {
      final description = await _auditRepository
          .generateSeatDescriptionTrainingModuleSummary(moduleId: moduleId);
      if (_isDisposed || editorVersion != _summaryEditorVersion) {
        return false;
      }

      _isEditingSummary = false;
      _editingSummaryVisibility = null;
      _applySelectedModuleDescription(
        description,
        notifyListenersAfterUpdate: false,
        syncEditorText: false,
      );
      final summaryText = CustomFunctions.stripHtmlTags(
        description,
        emptyText: '',
      );
      _lastSavedSummaryText = summaryText;
      if (!animate || summaryText.isEmpty) {
        _setSummaryEditorText(summaryText);
        return true;
      }
      return await _writeGeneratedSummary(summaryText, editorVersion);
    } catch (error) {
      if (!_isDisposed && editorVersion == _summaryEditorVersion) {
        _emitSummarySnackBar(
          error is ApiError && error.statusCode == 404
              ? AppStrings.trainingNoSummaryAvailableSnackBar
              : error.toString(),
        );
      }
      return false;
    } finally {
      if (!_isDisposed && editorVersion == _summaryEditorVersion) {
        _isGeneratingSummary = false;
        notifyListeners();
        _scheduleSummaryAutoSaveIfNeeded();
      }
    }
  }

  Future<bool> _writeGeneratedSummary(String text, int editorVersion) {
    // Reveal whole graphemes and cap the effect at roughly three seconds.
    final characters = text.characters.toList(growable: false);
    final charactersPerTick = max(1, (characters.length / 120).ceil());
    var visibleCharacters = 0;
    final completion = Completer<bool>();
    _summaryWritingCompletion = completion;
    _setSummaryEditorText('');
    _summaryWritingTimer = Timer.periodic(const Duration(milliseconds: 24), (
      timer,
    ) {
      if (_isDisposed || editorVersion != _summaryEditorVersion) {
        _cancelSummaryWriting();
        return;
      }

      visibleCharacters = min(
        visibleCharacters + charactersPerTick,
        characters.length,
      );
      _setSummaryEditorText(characters.take(visibleCharacters).join());
      if (visibleCharacters == characters.length) {
        timer.cancel();
        _summaryWritingTimer = null;
        _summaryWritingCompletion = null;
        completion.complete(true);
      }
    });
    notifyListeners();
    return completion.future;
  }

  void _cancelSummaryWriting() {
    _summaryWritingTimer?.cancel();
    _summaryWritingTimer = null;
    final completion = _summaryWritingCompletion;
    _summaryWritingCompletion = null;
    if (completion != null && !completion.isCompleted) {
      completion.complete(false);
    }
  }

  Future<bool> generateSopForSelectedModule() async {
    if (!canGenerateSopForSelectedModule) {
      return false;
    }

    _isGeneratingSop = true;
    _documentErrorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.generateSeatDescriptionTrainingModuleSop(
        moduleId: _selectedModuleId,
      );
      await refreshDocumentForSelectedModule();
      return true;
    } catch (error) {
      _documentErrorMessage = error.toString();
      return false;
    } finally {
      _isGeneratingSop = false;
      notifyListeners();
    }
  }

  Future<bool> generateAssignmentForSelectedModule() async {
    if (!canGenerateAssignmentForSelectedModule) {
      return false;
    }

    final moduleId = _selectedModuleId;
    _isGeneratingAssignment = true;
    _assignmentErrorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.generateSeatDescriptionTrainingModuleAssignment(
        moduleId: moduleId,
      );
      await refreshAssignmentForSelectedModule();
      return true;
    } catch (error) {
      _assignmentErrorMessage = error.toString();
      return false;
    } finally {
      _isGeneratingAssignment = false;
      notifyListeners();
    }
  }

  Future<bool> _saveSelectedModuleTitleForSelectedModule() async {
    final resolvedModuleId = _selectedModuleUpdateId;
    final title = moduleTitleController.text.trim();
    if (!canEditSelectedModuleTitle ||
        resolvedModuleId.isEmpty ||
        _isSavingModuleTitle ||
        title.isEmpty) {
      return false;
    }

    _isSavingModuleTitle = true;
    notifyListeners();

    try {
      await _auditRepository.updateSeatDescriptionTrainingModule(
        moduleId: resolvedModuleId,
        title: title,
      );
      _applySelectedModuleTitle(title, notifyListenersAfterUpdate: false);
      return true;
    } catch (error) {
      _emitSummarySnackBar(error.toString());
      return false;
    } finally {
      _isSavingModuleTitle = false;
      notifyListeners();
      _scheduleModuleTitleAutoSaveIfNeeded();
    }
  }

  Future<bool> saveSelectedModuleTitleForSelectedModule(String title) async {
    final resolvedTitle = title.trim();
    if (!canEditSelectedModuleTitle || resolvedTitle.isEmpty) {
      return false;
    }

    _moduleTitleAutoSaveDebounce?.cancel();
    _isSyncingModuleTitleController = true;
    moduleTitleController.value = moduleTitleController.value.copyWith(
      text: resolvedTitle,
      selection: TextSelection.collapsed(offset: resolvedTitle.length),
      composing: TextRange.empty,
    );
    _isSyncingModuleTitleController = false;
    return _saveSelectedModuleTitleForSelectedModule();
  }

  Future<bool> _saveSelectedModuleSummaryTextForSelectedModule() async {
    final resolvedModuleId = _selectedModuleId.trim();
    final description = summaryController.text.trim();
    if (!canEditSelectedModuleSummary ||
        resolvedModuleId.isEmpty ||
        _isSavingSummary ||
        _isGeneratingSummary ||
        description == _lastSavedSummaryText) {
      return false;
    }

    final editorVersion = _summaryEditorVersion;
    _isSavingSummary = true;
    notifyListeners();

    try {
      await _auditRepository.updateSeatDescriptionTrainingModule(
        moduleId: resolvedModuleId,
        description: description,
      );
      if (editorVersion != _summaryEditorVersion) return true;

      _lastSavedSummaryText = description;
      _applySelectedModuleDescription(
        description.isEmpty ? null : description,
        notifyListenersAfterUpdate: false,
        syncEditorText: false,
      );
      return true;
    } catch (error) {
      if (editorVersion == _summaryEditorVersion) {
        _emitSummarySnackBar(error.toString());
      }
      return false;
    } finally {
      if (editorVersion == _summaryEditorVersion) {
        _isSavingSummary = false;
        notifyListeners();
        // Keep typing during a save queued without retrying an unchanged failure.
        if (summaryController.text.trim() != description) {
          _scheduleSummaryAutoSaveIfNeeded();
        } else {
          _summaryAutoSaveDebounce?.cancel();
        }
      }
    }
  }

  void startEditingSummary() {
    if (!canEditSelectedModuleSummary ||
        _isEditingSummary ||
        _isGeneratingSummary) {
      return;
    }

    _isEditingSummary = true;
    _editingSummaryVisibility =
        _selectedModuleDetail?.isPubliclyAvailable ?? false;
    _summaryTextToController();
    notifyListeners();
  }

  void cancelEditingSummary() {
    if (!_isEditingSummary) {
      return;
    }

    _isEditingSummary = false;
    _editingSummaryVisibility = null;
    _summaryTextToController();
    notifyListeners();
  }

  void setEditingSummaryVisibility(bool value) {
    if (!canEditSelectedModuleSummary ||
        !_isEditingSummary ||
        _editingSummaryVisibility == value) {
      return;
    }

    _editingSummaryVisibility = value;
    notifyListeners();
  }

  Future<bool> saveSummaryForSelectedModule() async {
    final resolvedModuleId = _selectedModuleId.trim();
    if (!canEditSelectedModuleSummary ||
        resolvedModuleId.isEmpty ||
        _isSavingSummary ||
        _isGeneratingSummary) {
      return false;
    }

    _isSavingSummary = true;
    notifyListeners();

    try {
      final description = summaryController.text.trim();
      final isPubliclyAvailable = summaryVisibilityValue;
      await _auditRepository.updateSeatDescriptionTrainingModuleSummary(
        moduleId: resolvedModuleId,
        description: description,
        isPubliclyAvailable: isPubliclyAvailable,
      );
      _isEditingSummary = false;
      _editingSummaryVisibility = null;
      _applySelectedModuleDescription(
        description.isEmpty ? null : description,
        notifyListenersAfterUpdate: false,
      );
      _applySelectedModuleVisibility(
        isPubliclyAvailable,
        notifyListenersAfterUpdate: false,
      );
      return true;
    } catch (error) {
      _emitSummarySnackBar(error.toString());
      return false;
    } finally {
      _isSavingSummary = false;
      notifyListeners();
    }
  }

  Future<bool> updateModuleVisibility({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) async {
    final resolvedModuleId = moduleId.trim();
    if (!_canManageTraining || resolvedModuleId.isEmpty) {
      return false;
    }

    final targetModule = _findModuleById(resolvedModuleId);
    if (targetModule == null ||
        _updatingModuleVisibilityId == resolvedModuleId ||
        _deletingModuleId == resolvedModuleId) {
      return false;
    }

    if (targetModule.isPubliclyAvailable == isPubliclyAvailable) {
      return true;
    }

    _updatingModuleVisibilityId = resolvedModuleId;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.updateSeatDescriptionTrainingModuleVisibility(
        moduleId: targetModule.resolvedParentModuleId,
        isPubliclyAvailable: isPubliclyAvailable,
      );
      _applyModuleVisibilityInList(
        moduleId: resolvedModuleId,
        isPubliclyAvailable: isPubliclyAvailable,
      );
      if (_selectedModuleId == resolvedModuleId) {
        if (_isEditingSummary) {
          _editingSummaryVisibility = isPubliclyAvailable;
        }
        _applySelectedModuleVisibility(
          isPubliclyAvailable,
          notifyListenersAfterUpdate: false,
        );
      }
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _updatingModuleVisibilityId = null;
      notifyListeners();
    }
  }

  Future<bool> saveDocumentForSelectedModule() async {
    if (_isDisposed) return false;
    final resolvedModuleId = _selectedModuleId.trim();
    if (!canEditSelectedModuleDocument ||
        resolvedModuleId.isEmpty ||
        _isSavingDocument) {
      return false;
    }

    final editorVersion = _documentEditorVersion;
    final documentId = _selectedModuleDocument?.uuid ?? '';
    final text = _documentDraftHtml.trim();
    _isSavingDocument = true;
    _documentErrorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.updateSeatDescriptionTrainingModuleDocument(
        moduleId: resolvedModuleId,
        documentId: documentId,
        text: text,
      );
      if (_isDisposed || editorVersion != _documentEditorVersion) return false;
      _selectedModuleDocument = SeatDescriptionTrainingDocument(
        uuid: documentId,
        text: text.isEmpty ? null : text,
      );
      _lastSavedDocumentHtml = text;
      return true;
    } catch (error) {
      if (_isDisposed || editorVersion != _documentEditorVersion) return false;
      _documentErrorMessage = error.toString();
      return false;
    } finally {
      if (!_isDisposed && editorVersion == _documentEditorVersion) {
        _isSavingDocument = false;
        notifyListeners();
        _scheduleDocumentAutoSaveIfNeeded();
      }
    }
  }

  void updateDocumentHtml({
    required String moduleId,
    required int editorVersion,
    required String html,
  }) {
    if (_isDisposed ||
        !canEditSelectedModuleDocument ||
        _isDocumentLoading ||
        moduleId != _selectedModuleId ||
        editorVersion != _documentEditorVersion ||
        html == _documentDraftHtml) {
      return;
    }
    _documentDraftHtml = html;
    _scheduleDocumentAutoSaveIfNeeded();
  }

  Future<bool> saveAssignmentForSelectedModule() async {
    if (_isDisposed) return false;
    _assignmentAutoSaveDebounce?.cancel();
    final resolvedModuleId = _selectedModuleId.trim();
    final title = assignmentTitleController.text.trim();
    if (!canEditSelectedModuleAssignment ||
        resolvedModuleId.isEmpty ||
        !_hasResolvedAssignment ||
        _isAssignmentLoading ||
        _isSavingAssignment) {
      return false;
    }

    if (!_hasValidAssignmentDraftTitle) {
      _emitSummarySnackBar(AppStrings.trainingAssignmentTitleRequired);
      return false;
    }

    if (!hasAssignmentChanges) {
      return true;
    }

    final draftVersion = _assignmentDraftVersion;
    final editorVersion = _assignmentEditorVersion;
    final instructions = assignmentDescriptionController.toHtml().trim();
    final assignmentId = _selectedModuleAssignment?.uuid.trim() ?? '';
    _isSavingAssignment = true;
    _assignmentErrorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.updateSeatDescriptionTrainingModuleAssignment(
        moduleId: resolvedModuleId,
        assignmentId: assignmentId.isNotEmpty ? assignmentId : null,
        title: assignmentId.isEmpty || title != _lastSavedAssignmentTitle
            ? title
            : null,
        instructions: instructions,
      );
      if (editorVersion != _assignmentEditorVersion) return true;
      if (_selectedModuleId == resolvedModuleId) {
        if (assignmentId.isEmpty) {
          final persistedAssignment = await _auditRepository
              .getSeatDescriptionTrainingModuleAssignment(
                moduleId: resolvedModuleId,
              );
          if (editorVersion != _assignmentEditorVersion) return true;
          _selectedModuleAssignment = persistedAssignment;
          _applySelectedModuleAssignment(
            title: persistedAssignment.title,
            instructions: persistedAssignment.instructions,
            notifyListenersAfterUpdate: false,
          );
          _lastSavedAssignmentTitle =
              persistedAssignment.title?.trim() ?? title;
          _lastSavedAssignmentHtml =
              persistedAssignment.instructions?.trim() ?? instructions;
        } else {
          _applySelectedModuleAssignment(
            title: title,
            instructions: instructions,
            notifyListenersAfterUpdate: false,
          );
          _lastSavedAssignmentTitle = title;
          _lastSavedAssignmentHtml = instructions;
        }
        _hasResolvedAssignment = true;

        // PATCH already saved this draft; reloading it would move the cursor.
        if (assignmentId.isEmpty &&
            assignmentTitleController.text.trim() == title &&
            assignmentDescriptionController.toHtml().trim() == instructions) {
          _syncAssignmentEditorText();
        }
      }
      return true;
    } catch (error) {
      if (editorVersion == _assignmentEditorVersion) {
        _assignmentErrorMessage = error.toString();
        _emitSummarySnackBar(error.toString());
      }
      return false;
    } finally {
      if (editorVersion == _assignmentEditorVersion) {
        _isSavingAssignment = false;
        notifyListeners();
        if (_assignmentDraftVersion != draftVersion) {
          _scheduleAssignmentAutoSaveIfNeeded();
        }
      }
    }
  }

  void applyDocumentBoldFormatting() {
    documentController.applyBold();
  }

  void applyDocumentItalicFormatting() {
    documentController.applyItalic();
  }

  void applyDocumentUnderlineFormatting() {
    documentController.applyUnderline();
  }

  void applyDocumentBulletListFormatting() {
    documentController.applyBulletList();
  }

  void applyDocumentNumberedListFormatting() {
    documentController.applyNumberedList();
  }

  void applyDocumentQuoteFormatting() {
    documentController.applyQuote();
  }

  void applyDocumentHeadingFormatting() {
    documentController.applyHeading();
  }

  void applyAssignmentBoldFormatting() {
    assignmentDescriptionController.applyBold();
  }

  void applyAssignmentItalicFormatting() {
    assignmentDescriptionController.applyItalic();
  }

  void applyAssignmentUnderlineFormatting() {
    assignmentDescriptionController.applyUnderline();
  }

  void applyAssignmentBulletListFormatting() {
    assignmentDescriptionController.applyBulletList();
  }

  void applyAssignmentNumberedListFormatting() {
    assignmentDescriptionController.applyNumberedList();
  }

  void applyAssignmentQuoteFormatting() {
    assignmentDescriptionController.applyQuote();
  }

  void applyAssignmentHeadingFormatting() {
    assignmentDescriptionController.applyHeading();
  }

  Future<bool> uploadVideoForSelectedModule(File videoFile) async {
    final resolvedModuleId = _selectedModuleId.trim();
    if (!canUploadSelectedModuleVideo || resolvedModuleId.isEmpty) {
      return false;
    }

    _isUploadingVideo = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fileName = CustomFunctions.fileNameFromPath(videoFile.path);
      final presignedUpload = await _fileUploader.generatePresignedUpload(
        key: 'lms',
        fileName: fileName,
      );
      final normalizedUploadUrl = presignedUpload.uploadUrl.trim();

      await _fileUploader.uploadBinaryFile(
        uploadUrl: normalizedUploadUrl,
        fileBytes: await videoFile.readAsBytes(),
        contentType: CustomFunctions.contentTypeFromPath(videoFile.path),
      );

      final videoUrl =
          presignedUpload.fileUrl?.trim() ??
          _fileUploader.publicUrlFromUploadUrl(normalizedUploadUrl);

      final videoDurationInSeconds = await _resolveVideoDurationInSeconds(
        videoFile,
      );
      final videoTitle = _buildTrainingVideoTitle(fileName);
      final uploadedVideo = await _auditRepository
          .addSeatDescriptionTrainingModuleVideo(
            moduleId: resolvedModuleId,
            videoUuid: generateClientUuid(),
            title: videoTitle,
            videoUrl: videoUrl,
            duration: videoDurationInSeconds,
          );
      _moduleLocalVideoPaths[resolvedModuleId] = videoFile.path;
      _applySelectedModuleVideo(uploadedVideo);
      _applySelectedModuleDescription(null);
      unawaited(_refreshUploadedVideoTranscript(resolvedModuleId));
      _generateSelectedModuleSummaryInBackground(resolvedModuleId);
      return true;
    } catch (error) {
      _errorMessage = _resolveVideoUploadErrorMessage(error);
      return false;
    } finally {
      _isUploadingVideo = false;
      notifyListeners();
    }
  }

  void applyBackgroundUploadedVideo({
    required String moduleId,
    required SeatDescriptionTrainingVideo video,
    required String localVideoPath,
  }) {
    final resolvedModuleId = moduleId.trim();
    final resolvedLocalVideoPath = localVideoPath.trim();
    if (resolvedModuleId.isEmpty) {
      return;
    }

    if (resolvedLocalVideoPath.isNotEmpty) {
      _moduleLocalVideoPaths[resolvedModuleId] = resolvedLocalVideoPath;
    }

    if (_selectedModuleId != resolvedModuleId) {
      return;
    }

    _errorMessage = null;
    if (_selectedModuleDetail != null) {
      _applySelectedModuleVideo(video);
      _applySelectedModuleDescription(null);
      unawaited(_refreshUploadedVideoTranscript(resolvedModuleId));
      return;
    }

    notifyListeners();
    unawaited(_loadSelectedModuleDetail());
  }

  Future<bool> deleteVideoForSelectedModule() async {
    final resolvedModuleId = _selectedModuleId.trim();
    final resolvedVideoId =
        _selectedModuleDetail?.trainingVideo?.uuid.trim() ?? '';
    if (!_canManageTraining ||
        resolvedModuleId.isEmpty ||
        resolvedVideoId.isEmpty ||
        _isDeletingVideo ||
        _isUploadingVideo ||
        _isUploadingThumbnail) {
      return false;
    }

    _isDeletingVideo = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.deleteSeatDescriptionTrainingModuleVideo(
        videoId: resolvedVideoId,
      );
      _moduleLocalVideoPaths.remove(resolvedModuleId);
      _removeSelectedModuleVideo();
      await _loadSelectedModuleDetail();
      return true;
    } catch (error) {
      _errorMessage = error is ApiError
          ? error.message
          : AppStrings.trainingVideoDeleteFailed;
      return false;
    } finally {
      _isDeletingVideo = false;
      notifyListeners();
    }
  }

  Future<bool> uploadThumbnailForSelectedModule(File imageFile) async {
    if (!_canManageTraining ||
        _descriptionId.isEmpty ||
        _selectedModuleId.trim().isEmpty ||
        _isUploadingThumbnail ||
        _isUploadingVideo ||
        _isDeletingVideo) {
      return false;
    }

    _isUploadingThumbnail = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fileName = CustomFunctions.fileNameFromPath(imageFile.path);
      final contentType = CustomFunctions.contentTypeFromPath(
        imageFile.path,
        fallback: 'image/jpeg',
      );
      final uploadedImage = await _fileUploader.uploadOnboardingImage(
        fileName: fileName,
        fileBytes: await imageFile.readAsBytes(),
        contentType: contentType,
      );
      final refreshedModules = await _auditRepository
          .getSeatDescriptionTrainingModules(
            descriptionId: _descriptionId,
            forceRefresh: true,
          );
      final selectedModule = _resolveSelectedModuleForThumbnailUpdate(
        refreshedModules,
      );
      if (selectedModule == null) {
        _errorMessage = AppStrings.trainingThumbnailUploadFailed;
        return false;
      }

      await _auditRepository.updateSeatDescriptionTrainingModuleThumbnail(
        moduleId: selectedModule.resolvedParentModuleId,
        thumbnailUrl: uploadedImage.image,
      );
      _modules = List<SeatDescriptionTrainingModule>.from(
        refreshedModules,
        growable: false,
      );
      _selectedModuleId = selectedModule.uuid;
      _applySelectedModuleThumbnail(uploadedImage.image);
      return true;
    } catch (error) {
      _errorMessage = error is ApiError
          ? error.message
          : AppStrings.trainingThumbnailUploadFailed;
      return false;
    } finally {
      _isUploadingThumbnail = false;
      notifyListeners();
    }
  }

  Future<bool> deleteModule(String moduleId) async {
    final resolvedModuleId = moduleId.trim();
    if (!_canManageTraining ||
        resolvedModuleId.isEmpty ||
        _descriptionId.isEmpty) {
      return false;
    }

    if (_deletingModuleId == resolvedModuleId) {
      return false;
    }

    final currentSelectedModuleId = _selectedModuleId.trim();
    _deletingModuleId = resolvedModuleId;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.deleteSeatDescriptionTrainingModule(
        moduleId: resolvedModuleId,
      );
      _moduleLocalVideoPaths.remove(resolvedModuleId);

      final refreshedModules = await _auditRepository
          .getSeatDescriptionTrainingModules(descriptionId: _descriptionId);
      _modules = refreshedModules;

      if (refreshedModules.isEmpty) {
        _selectedModuleId = '';
        _selectedModuleDetail = null;
        _resetSelectedModuleExtras();
        _resetEditors();
        notifyListeners();
        return true;
      }

      final canKeepCurrentSelection =
          currentSelectedModuleId.isNotEmpty &&
          currentSelectedModuleId != resolvedModuleId &&
          refreshedModules.any(
            (module) => module.uuid == currentSelectedModuleId,
          );

      if (canKeepCurrentSelection) {
        _selectedModuleId = currentSelectedModuleId;
        _syncSelectedModuleSummaryFromDetail();
        notifyListeners();
        return true;
      }

      _selectedModuleId = refreshedModules.first.uuid;
      _selectedModuleDetail = null;
      _resetSelectedModuleExtras();
      _resetEditors();
      await _loadSelectedModuleDetail();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _deletingModuleId = null;
      notifyListeners();
    }
  }

  Future<bool> deleteQuestionOption({
    required String questionId,
    required String optionId,
  }) async {
    final resolvedQuestionId = questionId.trim();
    final resolvedOptionId = optionId.trim();
    if (!_canManageTraining ||
        resolvedQuestionId.isEmpty ||
        resolvedOptionId.isEmpty) {
      return false;
    }

    final targetQuestion = _findQuestionById(resolvedQuestionId);
    if (targetQuestion == null) {
      return false;
    }

    final deleteKey = '$resolvedQuestionId::$resolvedOptionId';
    if (_deletingQuestionOptionKey == deleteKey ||
        _savingQuestionId == resolvedQuestionId ||
        _deletingQuestionId == resolvedQuestionId) {
      return false;
    }

    final remainingOptions = targetQuestion.options
        .where((option) => option.uuid != resolvedOptionId)
        .toList(growable: false);
    final currentCorrectOptionUuid = targetQuestion.selectedOptionUuid?.trim();
    final hasCurrentCorrectOption = remainingOptions.any(
      (option) => option.uuid == currentCorrectOptionUuid,
    );
    final resolvedCorrectOptionUuid = hasCurrentCorrectOption
        ? currentCorrectOptionUuid
        : null;

    _deletingQuestionOptionKey = deleteKey;
    _questionsErrorMessage = null;
    notifyListeners();

    try {
      final updatedQuestion = await _auditRepository
          .updateSeatDescriptionTrainingQuestion(
            questionId: resolvedQuestionId,
            questionText: targetQuestion.question,
            options: remainingOptions,
            correctOptionUuid: resolvedCorrectOptionUuid,
          );
      _replaceSelectedQuestion(updatedQuestion);
      return true;
    } catch (error) {
      _questionsErrorMessage = error.toString();
      return false;
    } finally {
      _deletingQuestionOptionKey = null;
      notifyListeners();
    }
  }

  Future<bool> saveQuestion({
    required String questionId,
    required List<SeatDescriptionTrainingQuestionOption> options,
    String? correctOptionUuid,
  }) async {
    final resolvedQuestionId = questionId.trim();
    if (!_canManageTraining || resolvedQuestionId.isEmpty) {
      return false;
    }

    final targetQuestion = _findQuestionById(resolvedQuestionId);
    if (targetQuestion == null ||
        _savingQuestionId == resolvedQuestionId ||
        _deletingQuestionId == resolvedQuestionId) {
      return false;
    }

    final resolvedOptions = options
        .map(
          (option) => SeatDescriptionTrainingQuestionOption(
            uuid: option.uuid.trim().isEmpty
                ? generateClientUuid()
                : option.uuid.trim(),
            text: option.text.trim(),
          ),
        )
        .where((option) => option.text.isNotEmpty)
        .toList(growable: false);
    if (resolvedOptions.length < minQuizOptionsPerQuestion) {
      _questionsErrorMessage = AppStrings.trainingQuestionMinOptionsRequired;
      notifyListeners();
      return false;
    }

    final resolvedCorrectOptionUuid = correctOptionUuid?.trim() ?? '';
    final hasResolvedCorrectOption = resolvedOptions.any(
      (option) => option.uuid == resolvedCorrectOptionUuid,
    );
    final safeCorrectOptionUuid = hasResolvedCorrectOption
        ? resolvedCorrectOptionUuid
        : resolvedOptions.first.uuid;

    _savingQuestionId = resolvedQuestionId;
    _questionsErrorMessage = null;
    notifyListeners();

    try {
      final updatedQuestion = await _auditRepository
          .updateSeatDescriptionTrainingQuestion(
            questionId: resolvedQuestionId,
            questionText: targetQuestion.question,
            options: resolvedOptions,
            correctOptionUuid: safeCorrectOptionUuid,
          );
      _replaceSelectedQuestion(updatedQuestion);
      return true;
    } catch (error) {
      _questionsErrorMessage = error.toString();
      return false;
    } finally {
      _savingQuestionId = null;
      notifyListeners();
    }
  }

  Future<bool> deleteQuestion({required String questionId}) async {
    final resolvedQuestionId = questionId.trim();
    if (!_canManageTraining || resolvedQuestionId.isEmpty) {
      return false;
    }

    final targetQuestion = _findQuestionById(resolvedQuestionId);
    if (targetQuestion == null ||
        _savingQuestionId == resolvedQuestionId ||
        _deletingQuestionId == resolvedQuestionId) {
      return false;
    }

    _deletingQuestionId = resolvedQuestionId;
    _questionsErrorMessage = null;
    notifyListeners();

    try {
      await _auditRepository.deleteSeatDescriptionTrainingQuestion(
        questionId: resolvedQuestionId,
      );
      final updatedQuestions = _selectedModuleQuestions
          .where((question) => question.uuid != targetQuestion.uuid)
          .toList(growable: false);
      _updateSelectedModuleQuestions(updatedQuestions);
      return true;
    } catch (error) {
      _questionsErrorMessage = error.toString();
      return false;
    } finally {
      _deletingQuestionId = null;
      notifyListeners();
    }
  }

  Future<void> _loadSelectedModuleDetail() async {
    if (_selectedModuleId.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_sharedLessonDetailLoader != null) {
        final sharedLesson = await _sharedLessonDetailLoader(_selectedModuleId);
        if (_isDisposed) return;
        _selectedModuleDetail = sharedLesson.module;
        _selectedModuleDocument = sharedLesson.document;
        _selectedModuleAssignment = sharedLesson.assignment;
        _hasResolvedAssignment = true;
        _syncDocumentEditorText();
      } else {
        final detail = await _auditRepository
            .getSeatDescriptionTrainingModuleDetail(
              moduleId: _selectedModuleId,
            );
        if (_isDisposed) return;
        _selectedModuleDetail = detail;
      }
      if (_selectedModuleDetail?.trainingVideo == null) {
        _moduleLocalVideoPaths.remove(_selectedModuleId.trim());
      }
      _syncTitleEditorText();
      _syncSummaryEditorText();
      _syncAssignmentEditorText();
      _updateSelectedModuleQuestions(
        _selectedModuleDetail?.questions ??
            const <SeatDescriptionTrainingQuestion>[],
      );
      if (_sharedLessonDetailLoader != null) {
        _hasResolvedQuestions = true;
      }
      _syncSelectedModuleSummaryFromDetail();
    } catch (error) {
      if (_isDisposed) return;
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _updateSelectedModuleQuestions(
    List<SeatDescriptionTrainingQuestion> questions,
  ) {
    _selectedModuleQuestions = List<SeatDescriptionTrainingQuestion>.from(
      questions,
      growable: false,
    );
    _hasResolvedQuestions = _selectedModuleQuestions.isNotEmpty;

    final detail = _selectedModuleDetail;
    if (detail == null) {
      return;
    }

    _selectedModuleDetail = SeatDescriptionTrainingModuleDetail(
      uuid: detail.uuid,
      actualId: detail.actualId,
      title: detail.title,
      thumbnails: List<String>.from(detail.thumbnails, growable: false),
      description: detail.description,
      assignmentTitle: detail.assignmentTitle,
      assignmentInstructions: detail.assignmentInstructions,
      questions: _selectedModuleQuestions,
      thumbnailLink: detail.thumbnailLink,
      trainingVideo: detail.trainingVideo,
      isPubliclyAvailable: detail.isPubliclyAvailable,
      learningTrackCount: detail.learningTrackCount,
    );
  }

  void _replaceSelectedQuestion(
    SeatDescriptionTrainingQuestion updatedQuestion,
  ) {
    final updatedQuestions = _selectedModuleQuestions
        .map(
          (question) => question.uuid == updatedQuestion.uuid
              ? updatedQuestion
              : question,
        )
        .toList(growable: false);
    _updateSelectedModuleQuestions(updatedQuestions);
  }

  void _appendSelectedQuestion(SeatDescriptionTrainingQuestion question) {
    final updatedQuestions = List<SeatDescriptionTrainingQuestion>.from(
      _selectedModuleQuestions,
      growable: true,
    )..add(question);
    _updateSelectedModuleQuestions(updatedQuestions);
  }

  SeatDescriptionTrainingQuestion? _findQuestionById(String questionId) {
    for (final question in _selectedModuleQuestions) {
      if (question.uuid == questionId) {
        return question;
      }
    }

    return null;
  }

  SeatDescriptionTrainingModule? _findModuleById(String moduleId) {
    for (final module in _modules) {
      if (module.uuid == moduleId) {
        return module;
      }
    }

    return null;
  }

  SeatDescriptionTrainingModuleDetail _buildModuleDetailFromModule(
    SeatDescriptionTrainingModule module,
  ) {
    return SeatDescriptionTrainingModuleDetail(
      uuid: module.uuid,
      actualId: module.actualId,
      title: module.title,
      thumbnails: const <String>[],
      description: null,
      assignmentTitle: null,
      assignmentInstructions: null,
      questions: const <SeatDescriptionTrainingQuestion>[],
      thumbnailLink: module.thumbnailLink,
      trainingVideo: null,
      isPubliclyAvailable: module.isPubliclyAvailable,
      learningTrackCount: 0,
    );
  }

  void _syncSelectedModuleSummaryFromDetail() {
    final detail = _selectedModuleDetail;
    if (detail == null) {
      return;
    }

    final currentModule = _findModuleById(detail.uuid);
    final resolvedDetailThumbnailLink = detail.thumbnailLink?.trim();
    final resolvedModuleThumbnailLink = currentModule?.thumbnailLink?.trim();
    final resolvedThumbnailLink =
        (resolvedDetailThumbnailLink?.isNotEmpty ?? false)
        ? resolvedDetailThumbnailLink
        : (resolvedModuleThumbnailLink?.isNotEmpty ?? false)
        ? resolvedModuleThumbnailLink
        : null;

    final updatedModule = SeatDescriptionTrainingModule(
      uuid: detail.uuid,
      actualId: detail.actualId,
      title: detail.title,
      thumbnailLink: resolvedThumbnailLink,
      isPubliclyAvailable: detail.isPubliclyAvailable,
    );
    _modules = _modules
        .map(
          (module) =>
              module.uuid == updatedModule.uuid ? updatedModule : module,
        )
        .toList(growable: false);
  }

  void _applySelectedModuleDescription(
    String? description, {
    bool notifyListenersAfterUpdate = true,
    bool syncEditorText = true,
  }) {
    final detail = _selectedModuleDetail;
    if (detail == null) {
      return;
    }

    _selectedModuleDetail = SeatDescriptionTrainingModuleDetail(
      uuid: detail.uuid,
      actualId: detail.actualId,
      title: detail.title,
      thumbnails: List<String>.from(detail.thumbnails, growable: false),
      description: description?.trim(),
      assignmentTitle: detail.assignmentTitle,
      assignmentInstructions: detail.assignmentInstructions,
      questions: List<SeatDescriptionTrainingQuestion>.from(
        detail.questions,
        growable: false,
      ),
      thumbnailLink: detail.thumbnailLink,
      trainingVideo: detail.trainingVideo,
      isPubliclyAvailable: detail.isPubliclyAvailable,
      learningTrackCount: detail.learningTrackCount,
    );
    if (syncEditorText) {
      _syncSummaryEditorText();
    }
    if (notifyListenersAfterUpdate) {
      notifyListeners();
    }
  }

  void _applySelectedModuleTitle(
    String title, {
    bool notifyListenersAfterUpdate = true,
  }) {
    final detail = _selectedModuleDetail;
    final resolvedTitle = title.trim();

    if (detail != null) {
      _selectedModuleDetail = SeatDescriptionTrainingModuleDetail(
        uuid: detail.uuid,
        actualId: detail.actualId,
        title: resolvedTitle,
        thumbnails: List<String>.from(detail.thumbnails, growable: false),
        description: detail.description,
        assignmentTitle: detail.assignmentTitle,
        assignmentInstructions: detail.assignmentInstructions,
        questions: List<SeatDescriptionTrainingQuestion>.from(
          detail.questions,
          growable: false,
        ),
        thumbnailLink: detail.thumbnailLink,
        trainingVideo: detail.trainingVideo,
        isPubliclyAvailable: detail.isPubliclyAvailable,
        learningTrackCount: detail.learningTrackCount,
      );
    }

    _modules = _modules
        .map(
          (module) => module.uuid == _selectedModuleId
              ? SeatDescriptionTrainingModule(
                  uuid: module.uuid,
                  actualId: module.actualId,
                  title: resolvedTitle,
                  thumbnailLink: module.thumbnailLink,
                  isPubliclyAvailable: module.isPubliclyAvailable,
                )
              : module,
        )
        .toList(growable: false);
    _syncTitleEditorText();
    if (notifyListenersAfterUpdate) {
      notifyListeners();
    }
  }

  void _applySelectedModuleAssignment({
    String? title,
    String? instructions,
    bool notifyListenersAfterUpdate = true,
  }) {
    final detail = _selectedModuleDetail;
    final resolvedTitle = title?.trim();
    final resolvedInstructions = instructions?.trim();
    _selectedModuleAssignment = SeatDescriptionTrainingAssignment(
      uuid: _selectedModuleAssignment?.uuid ?? '',
      title: resolvedTitle?.isNotEmpty == true ? resolvedTitle : null,
      instructions: resolvedInstructions?.isNotEmpty == true
          ? resolvedInstructions
          : null,
    );

    if (detail != null) {
      _selectedModuleDetail = SeatDescriptionTrainingModuleDetail(
        uuid: detail.uuid,
        actualId: detail.actualId,
        title: detail.title,
        thumbnails: List<String>.from(detail.thumbnails, growable: false),
        description: detail.description,
        assignmentTitle: _selectedModuleAssignment?.title,
        assignmentInstructions: _selectedModuleAssignment?.instructions,
        questions: List<SeatDescriptionTrainingQuestion>.from(
          detail.questions,
          growable: false,
        ),
        thumbnailLink: detail.thumbnailLink,
        trainingVideo: detail.trainingVideo,
        isPubliclyAvailable: detail.isPubliclyAvailable,
        learningTrackCount: detail.learningTrackCount,
      );
    }

    if (notifyListenersAfterUpdate) {
      notifyListeners();
    }
  }

  void _applySelectedModuleVisibility(
    bool isPubliclyAvailable, {
    bool notifyListenersAfterUpdate = true,
  }) {
    final detail = _selectedModuleDetail;
    if (detail == null) {
      return;
    }

    _selectedModuleDetail = SeatDescriptionTrainingModuleDetail(
      uuid: detail.uuid,
      actualId: detail.actualId,
      title: detail.title,
      thumbnails: List<String>.from(detail.thumbnails, growable: false),
      description: detail.description,
      assignmentTitle: detail.assignmentTitle,
      assignmentInstructions: detail.assignmentInstructions,
      questions: List<SeatDescriptionTrainingQuestion>.from(
        detail.questions,
        growable: false,
      ),
      thumbnailLink: detail.thumbnailLink,
      trainingVideo: detail.trainingVideo,
      isPubliclyAvailable: isPubliclyAvailable,
      learningTrackCount: detail.learningTrackCount,
    );
    _applyModuleVisibilityInList(
      moduleId: detail.uuid,
      isPubliclyAvailable: isPubliclyAvailable,
    );
    if (notifyListenersAfterUpdate) {
      notifyListeners();
    }
  }

  void _applyModuleVisibilityInList({
    required String moduleId,
    required bool isPubliclyAvailable,
  }) {
    _modules = _modules
        .map(
          (module) => module.uuid == moduleId
              ? SeatDescriptionTrainingModule(
                  uuid: module.uuid,
                  actualId: module.actualId,
                  title: module.title,
                  thumbnailLink: module.thumbnailLink,
                  isPubliclyAvailable: isPubliclyAvailable,
                )
              : module,
        )
        .toList(growable: false);
  }

  void applyGeneratedSummaryForModule({
    required String moduleId,
    String? description,
  }) {
    final resolvedModuleId = moduleId.trim();
    if (resolvedModuleId.isEmpty || _selectedModuleId != resolvedModuleId) {
      return;
    }

    _applySelectedModuleDescription(description);
    unawaited(_refreshUploadedVideoTranscript(resolvedModuleId));
  }

  Future<void> _refreshUploadedVideoTranscript(String moduleId) async {
    final video = _selectedModuleDetail?.trainingVideo;
    if (_isDisposed ||
        _selectedModuleId != moduleId ||
        video == null ||
        (video.transcript?.trim().isNotEmpty ?? false)) {
      return;
    }

    try {
      final detail = await _auditRepository
          .getSeatDescriptionTrainingModuleDetail(
            moduleId: moduleId,
            forceRefresh: true,
          );
      final refreshedVideo = detail.trainingVideo;
      if (_isDisposed ||
          _selectedModuleId != moduleId ||
          !identical(_selectedModuleDetail?.trainingVideo, video) ||
          refreshedVideo?.uuid != video.uuid ||
          !(refreshedVideo?.transcript?.trim().isNotEmpty ?? false)) {
        return;
      }

      // Only merge the transcript; preserve local video previews and editor drafts.
      _applySelectedModuleVideo(
        SeatDescriptionTrainingVideo(
          uuid: video.uuid,
          title: video.title,
          url: video.url,
          duration: video.duration,
          transcript: refreshedVideo!.transcript,
        ),
      );
    } catch (error) {
      if (!_isDisposed) {
        debugPrint(
          'Unable to refresh the uploaded training transcript: $error',
        );
      }
    }
  }

  void _applySelectedModuleVideo(SeatDescriptionTrainingVideo video) {
    final detail = _selectedModuleDetail;
    if (detail == null) {
      return;
    }

    _selectedModuleDetail = SeatDescriptionTrainingModuleDetail(
      uuid: detail.uuid,
      actualId: detail.actualId,
      title: detail.title,
      thumbnails: List<String>.from(detail.thumbnails, growable: false),
      description: detail.description,
      assignmentTitle: detail.assignmentTitle,
      assignmentInstructions: detail.assignmentInstructions,
      questions: List<SeatDescriptionTrainingQuestion>.from(
        detail.questions,
        growable: false,
      ),
      thumbnailLink: detail.thumbnailLink,
      trainingVideo: video,
      isPubliclyAvailable: detail.isPubliclyAvailable,
      learningTrackCount: detail.learningTrackCount,
    );
    notifyListeners();
  }

  void _removeSelectedModuleVideo() {
    final detail = _selectedModuleDetail;
    if (detail == null) {
      return;
    }

    _selectedModuleDetail = SeatDescriptionTrainingModuleDetail(
      uuid: detail.uuid,
      actualId: detail.actualId,
      title: detail.title,
      thumbnails: List<String>.from(detail.thumbnails, growable: false),
      description: detail.description,
      assignmentTitle: detail.assignmentTitle,
      assignmentInstructions: detail.assignmentInstructions,
      questions: List<SeatDescriptionTrainingQuestion>.from(
        detail.questions,
        growable: false,
      ),
      thumbnailLink: detail.thumbnailLink,
      trainingVideo: null,
      isPubliclyAvailable: detail.isPubliclyAvailable,
      learningTrackCount: detail.learningTrackCount,
    );
    notifyListeners();
  }

  void _applySelectedModuleThumbnail(String thumbnailUrl) {
    final detail = _selectedModuleDetail;
    final resolvedThumbnailUrl = thumbnailUrl.trim();
    if (detail == null || resolvedThumbnailUrl.isEmpty) {
      return;
    }

    _selectedModuleDetail = SeatDescriptionTrainingModuleDetail(
      uuid: detail.uuid,
      actualId: detail.actualId,
      title: detail.title,
      thumbnails: <String>[resolvedThumbnailUrl],
      description: detail.description,
      assignmentTitle: detail.assignmentTitle,
      assignmentInstructions: detail.assignmentInstructions,
      questions: List<SeatDescriptionTrainingQuestion>.from(
        detail.questions,
        growable: false,
      ),
      thumbnailLink: resolvedThumbnailUrl,
      trainingVideo: detail.trainingVideo,
      isPubliclyAvailable: detail.isPubliclyAvailable,
      learningTrackCount: detail.learningTrackCount,
    );
    _syncSelectedModuleSummaryFromDetail();
    notifyListeners();
  }

  SeatDescriptionTrainingModule? _resolveSelectedModuleForThumbnailUpdate(
    List<SeatDescriptionTrainingModule> modules,
  ) {
    final selectedModuleId = _selectedModuleId.trim();
    if (selectedModuleId.isEmpty) {
      return null;
    }

    for (final module in modules) {
      if (module.uuid == selectedModuleId) {
        return module;
      }
    }

    final selectedModuleActualId = _selectedModuleDetail?.actualId.trim() ?? '';
    if (selectedModuleActualId.isEmpty) {
      return null;
    }

    for (final module in modules) {
      if (module.actualId == selectedModuleActualId ||
          module.uuid == selectedModuleActualId) {
        return module;
      }
    }

    return null;
  }

  Future<int> _resolveVideoDurationInSeconds(File videoFile) async {
    final controller = VideoPlayerController.file(videoFile);
    try {
      await controller.initialize();
      final seconds = controller.value.duration.inSeconds;
      return seconds < 0 ? 0 : seconds;
    } catch (error) {
      debugPrint('Unable to resolve training video duration: $error');
      return 0;
    } finally {
      await controller.dispose();
    }
  }

  String _buildTrainingVideoTitle(String fileName) {
    final trimmedName = fileName.trim();
    if (trimmedName.length <= maxTrainingVideoTitleLength) {
      return trimmedName;
    }

    final extensionIndex = trimmedName.lastIndexOf('.');
    if (extensionIndex <= 0 || extensionIndex >= trimmedName.length - 1) {
      return trimmedName.substring(0, maxTrainingVideoTitleLength);
    }

    final extension = trimmedName.substring(extensionIndex);
    final availableBaseLength = maxTrainingVideoTitleLength - extension.length;
    if (availableBaseLength <= 0) {
      return trimmedName.substring(0, maxTrainingVideoTitleLength);
    }

    final baseName = trimmedName.substring(0, extensionIndex);
    final resolvedBaseLength = availableBaseLength.clamp(0, baseName.length);
    final truncatedBaseName = baseName.substring(0, resolvedBaseLength);
    return '$truncatedBaseName$extension';
  }

  String _resolveVideoUploadErrorMessage(Object error) {
    return AppStrings.trainingVideoUploadFailed;
  }

  void _handleNewLessonTitleChanged() {
    if (_isCreatingNewLessonDraft) {
      notifyListeners();
    }
  }

  void _handleModuleTitleChanged() {
    _scheduleModuleTitleAutoSaveIfNeeded();
  }

  void _handleSummaryChanged() {
    _scheduleSummaryAutoSaveIfNeeded();
    final hasContent = summaryController.text.trim().isNotEmpty;
    if (_isSyncingSummaryController ||
        hasContent == _lastSummaryDraftHasContent) {
      return;
    }
    _lastSummaryDraftHasContent = hasContent;
    notifyListeners();
  }

  void _handleDocumentChanged() {
    if (_isSyncingDocumentController) return;
    _documentDraftHtml = documentController.toHtml();
    _scheduleDocumentAutoSaveIfNeeded();
  }

  void _handleAssignmentDraftChanged() {
    final title = assignmentTitleController.text.trim();
    final html = assignmentDescriptionController.toHtml().trim();
    final hasContentChanged =
        title != _lastObservedAssignmentTitle ||
        html != _lastObservedAssignmentHtml;
    _lastObservedAssignmentTitle = title;
    _lastObservedAssignmentHtml = html;
    // Selection and composing updates must not delay a pending content save.
    if (!_isSyncingAssignmentController && hasContentChanged) {
      _assignmentDraftVersion += 1;
      _scheduleAssignmentAutoSaveIfNeeded();
    }

    final hasTitle = hasAssignmentTitle;
    if (_lastAssignmentDraftHasTitle == hasTitle) {
      return;
    }
    _lastAssignmentDraftHasTitle = hasTitle;
    notifyListeners();
  }

  String get _selectedModuleUpdateId {
    final detail = _selectedModuleDetail;
    if (detail != null) {
      return detail.resolvedParentModuleId;
    }

    for (final module in _modules) {
      if (module.uuid == _selectedModuleId) {
        return module.resolvedParentModuleId;
      }
    }

    return _selectedModuleId.trim();
  }

  void _resetEditors() {
    _disposeSopEditor();
    _documentEditorVersion += 1;
    _summaryEditorVersion += 1;
    _cancelSummaryWriting();
    _assignmentEditorVersion += 1;
    _moduleTitleAutoSaveDebounce?.cancel();
    _summaryAutoSaveDebounce?.cancel();
    _documentAutoSaveDebounce?.cancel();
    _assignmentAutoSaveDebounce?.cancel();
    _isEditingSummary = false;
    _isSavingModuleTitle = false;
    _isSavingSummary = false;
    _isGeneratingSummary = false;
    _editingSummaryVisibility = null;
    _isSavingDocument = false;
    _isSavingAssignment = false;
    _lastSavedModuleTitle = '';
    _lastSavedSummaryText = '';
    _lastSavedDocumentHtml = '';
    _documentDraftHtml = '';
    _lastSavedAssignmentTitle = '';
    _lastSavedAssignmentHtml = '';
    _isSyncingModuleTitleController = true;
    moduleTitleController.clear();
    _isSyncingModuleTitleController = false;
    _isSyncingSummaryController = true;
    summaryController.clear();
    _lastSummaryDraftHasContent = false;
    _isSyncingSummaryController = false;
    _isSyncingAssignmentController = true;
    assignmentTitleController.clear();
    _isSyncingDocumentController = true;
    documentController.clear();
    _isSyncingDocumentController = false;
    assignmentDescriptionController.clear();
    _isSyncingAssignmentController = false;
  }

  void _resetSelectedModuleExtras() {
    _documentRequestVersion += 1;
    _isDocumentLoading = false;
    _selectedModuleDocument = null;
    _selectedModuleAssignment = null;
    _selectedModuleQuestions = const <SeatDescriptionTrainingQuestion>[];
    _documentErrorMessage = null;
    _assignmentErrorMessage = null;
    _questionsErrorMessage = null;
    _isAssignmentLoading = false;
    _hasResolvedAssignment = false;
    _hasResolvedQuestions = false;
  }

  void _syncSummaryEditorText() {
    if (_isEditingSummary) {
      return;
    }

    _summaryTextToController();
  }

  void _syncTitleEditorText() {
    _titleTextToController();
  }

  void _syncDocumentEditorText() {
    _documentTextToController();
  }

  void _syncAssignmentEditorText() {
    _assignmentTextToController();
  }

  void _summaryTextToController() {
    final summaryText = CustomFunctions.stripHtmlTags(
      _selectedModuleDetail?.description?.trim() ?? '',
      emptyText: '',
    );
    _lastSavedSummaryText = summaryText;
    _setSummaryEditorText(summaryText);
  }

  void _setSummaryEditorText(String text) {
    _lastSummaryDraftHasContent = text.trim().isNotEmpty;
    if (summaryController.text == text) {
      return;
    }

    _isSyncingSummaryController = true;
    summaryController.value = summaryController.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    _isSyncingSummaryController = false;
  }

  void _titleTextToController() {
    final titleText = selectedModuleTitle;
    _lastSavedModuleTitle = titleText;
    if (moduleTitleController.text == titleText) {
      return;
    }

    _isSyncingModuleTitleController = true;
    moduleTitleController.value = moduleTitleController.value.copyWith(
      text: titleText,
      selection: TextSelection.collapsed(offset: titleText.length),
      composing: TextRange.empty,
    );
    _isSyncingModuleTitleController = false;
  }

  void _documentTextToController() {
    final documentText = _selectedModuleDocument?.text?.trim() ?? '';
    _disposeSopEditor();
    _documentEditorVersion += 1;
    _documentAutoSaveDebounce?.cancel();
    _isSavingDocument = false;
    _documentDraftHtml = documentText;
    _isSyncingDocumentController = true;
    documentController.loadFromHtml(documentText);
    _lastSavedDocumentHtml = documentText;
    _isSyncingDocumentController = false;
  }

  void _disposeSopEditor() {
    _sopEditorController?.dispose();
    _sopEditorController = null;
  }

  void _assignmentTextToController() {
    final selectedAssignment = _selectedModuleAssignment;
    final assignmentTitle = selectedAssignment != null
        ? selectedAssignment.title?.trim() ?? ''
        : _selectedModuleDetail?.assignmentTitle?.trim() ?? '';
    final assignmentInstructions = selectedAssignment != null
        ? selectedAssignment.instructions?.trim() ?? ''
        : _selectedModuleDetail?.assignmentInstructions?.trim() ?? '';
    _isSyncingAssignmentController = true;
    assignmentTitleController.value = assignmentTitleController.value.copyWith(
      text: assignmentTitle,
      selection: TextSelection.collapsed(offset: assignmentTitle.length),
      composing: TextRange.empty,
    );
    assignmentDescriptionController.loadFromHtml(assignmentInstructions);
    _lastSavedAssignmentTitle = assignmentTitleController.text.trim();
    _lastSavedAssignmentHtml = assignmentDescriptionController.toHtml().trim();
    _isSyncingAssignmentController = false;
  }

  void _scheduleModuleTitleAutoSaveIfNeeded() {
    if (_isSyncingModuleTitleController || !canEditSelectedModuleTitle) {
      return;
    }

    final currentTitle = moduleTitleController.text.trim();
    if (currentTitle == _lastSavedModuleTitle || currentTitle.isEmpty) {
      _moduleTitleAutoSaveDebounce?.cancel();
      return;
    }

    _moduleTitleAutoSaveDebounce?.cancel();
    _moduleTitleAutoSaveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveSelectedModuleTitleForSelectedModule());
    });
  }

  void _scheduleSummaryAutoSaveIfNeeded() {
    if (_isSyncingSummaryController ||
        _isGeneratingSummary ||
        !canEditSelectedModuleSummary) {
      return;
    }

    final currentSummary = summaryController.text.trim();
    if (currentSummary == _lastSavedSummaryText) {
      _summaryAutoSaveDebounce?.cancel();
      return;
    }

    _summaryAutoSaveDebounce?.cancel();
    _summaryAutoSaveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveSelectedModuleSummaryTextForSelectedModule());
    });
  }

  void _scheduleDocumentAutoSaveIfNeeded() {
    if (_isDisposed ||
        _isSyncingDocumentController ||
        _isDocumentLoading ||
        _isSavingDocument ||
        !canEditSelectedModuleDocument) {
      return;
    }

    final currentText = _documentDraftHtml.trim();
    final savedText = _lastSavedDocumentHtml;
    if (currentText == savedText) {
      _documentAutoSaveDebounce?.cancel();
      return;
    }

    _documentAutoSaveDebounce?.cancel();
    _documentAutoSaveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(saveDocumentForSelectedModule());
    });
  }

  void _scheduleAssignmentAutoSaveIfNeeded() {
    if (_isDisposed ||
        _isSyncingAssignmentController ||
        !canEditSelectedModuleAssignment ||
        !_hasResolvedAssignment ||
        _isAssignmentLoading ||
        _isSavingAssignment) {
      return;
    }

    if (!_hasValidAssignmentDraftTitle || !hasAssignmentChanges) {
      _assignmentAutoSaveDebounce?.cancel();
      return;
    }

    _assignmentAutoSaveDebounce?.cancel();
    _assignmentAutoSaveDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(saveAssignmentForSelectedModule());
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeSopEditor();
    _cancelSummaryWriting();
    _documentRequestVersion += 1;
    _summaryEditorVersion += 1;
    _assignmentEditorVersion += 1;
    newLessonTitleController.removeListener(_handleNewLessonTitleChanged);
    moduleTitleController.removeListener(_handleModuleTitleChanged);
    summaryController.removeListener(_handleSummaryChanged);
    documentController.removeListener(_handleDocumentChanged);
    assignmentTitleController.removeListener(_handleAssignmentDraftChanged);
    assignmentDescriptionController.removeListener(
      _handleAssignmentDraftChanged,
    );
    _moduleTitleAutoSaveDebounce?.cancel();
    _summaryAutoSaveDebounce?.cancel();
    _documentAutoSaveDebounce?.cancel();
    _assignmentAutoSaveDebounce?.cancel();
    newLessonTitleController.dispose();
    moduleTitleController.dispose();
    summaryController.dispose();
    assignmentTitleController.dispose();
    documentController.dispose();
    assignmentDescriptionController.dispose();
    super.dispose();
  }

  void _generateSelectedModuleSummaryInBackground(String moduleId) {
    unawaited(
      _auditRepository
          .generateSeatDescriptionTrainingModuleSummary(moduleId: moduleId)
          .then((generatedDescription) {
            if (_isDisposed || _selectedModuleId != moduleId) {
              return;
            }

            _applySelectedModuleDescription(generatedDescription);
            unawaited(_refreshUploadedVideoTranscript(moduleId));
          })
          .catchError((Object error) {
            if (_isDisposed) return;
            if (error is ApiError && error.statusCode == 404) {
              if (_selectedModuleId == moduleId) {
                _applySelectedModuleDescription(null);
                unawaited(_refreshUploadedVideoTranscript(moduleId));
              }
              _emitSummarySnackBar(
                AppStrings.trainingNoSummaryAvailableSnackBar,
              );
              return;
            }

            debugPrint('Unable to generate training summary: $error');
          }),
    );
  }

  void _emitSummarySnackBar(String message) {
    final resolvedMessage = message.trim();
    if (resolvedMessage.isEmpty) {
      return;
    }

    _summarySnackBarMessage = resolvedMessage;
    _summarySnackBarSequence++;
    notifyListeners();
  }
}
