import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/compliance_video_transcript.dart';

class ComplianceVideoController extends ChangeNotifier {
  ComplianceVideoController(String? transcript)
    : _transcriptSource = transcript,
      _transcript = ComplianceVideoTranscript.parse(transcript);

  String? _transcriptSource;
  ComplianceVideoTranscript _transcript;
  int? _activeTranscriptIndex;
  String? _activeTranscriptText;
  String? _activeTranscriptProgressText;
  List<int> _activeTranscriptWordEnds = const [];
  Duration? _lastPlaybackPosition;
  bool _animateActiveTranscript = true;
  bool _isCcEnabled = false;
  bool _arePlaybackControlsVisible = true;
  Rect? _videoBounds;
  VoidCallback? _revealControlsHandler;
  bool _isDisposed = false;
  int? _seekingIndex;
  String? _seekError;
  Future<bool> Function(Duration)? _seekHandler;
  Completer<Future<bool> Function(Duration)?>? _seekHandlerReady;

  List<ComplianceTranscriptLine> get transcriptLines => _transcript.lines;
  int? get activeTranscriptIndex => _activeTranscriptIndex;
  ComplianceTranscriptLine? get activeTranscriptLine =>
      _activeTranscriptIndex == null
      ? null
      : transcriptLines[_activeTranscriptIndex!];
  String? get activeTranscriptText => _activeTranscriptText;
  String? get activeTranscriptProgressText => _activeTranscriptProgressText;
  bool get isCcEnabled => _isCcEnabled;
  bool get hasVisibleActiveTranscript =>
      !_isCcEnabled && activeTranscriptLine != null;
  bool get arePlaybackControlsVisible => _arePlaybackControlsVisible;
  Rect? get videoBounds => _videoBounds;
  bool get isSeeking => _seekingIndex != null;
  int? get seekingIndex => _seekingIndex;
  String? get seekError => _seekError;

  void updateTranscript(String? transcript) {
    if (_isDisposed || transcript == _transcriptSource) return;
    _transcriptSource = transcript;
    _transcript = ComplianceVideoTranscript.parse(transcript);
    final position = _lastPlaybackPosition;
    _activeTranscriptIndex = position == null
        ? null
        : _transcript.activeLineAt(position);
    _updateActiveTranscriptWordEnds();
    _updateActiveTranscriptText();
    _seekError = null;
    notifyListeners();
  }

  void toggleCc() {
    if (_isDisposed) return;
    _isCcEnabled = !_isCcEnabled;
    _updateActiveTranscriptText();
    notifyListeners();
  }

  void updatePlaybackControlsVisibility(bool visible) {
    if (_isDisposed || _arePlaybackControlsVisible == visible) return;
    _arePlaybackControlsVisible = visible;
    notifyListeners();
  }

  void updateVideoBounds(Rect? bounds) {
    if (_isDisposed || _videoBounds == bounds) return;
    _videoBounds = bounds;
    notifyListeners();
  }

  void setRevealControlsHandler(VoidCallback? handler) {
    if (_isDisposed) return;
    _revealControlsHandler = handler;
  }

  void revealPlaybackControls() => _revealControlsHandler?.call();

  void setSeekHandler(Future<bool> Function(Duration)? handler) {
    if (_isDisposed) return;
    _seekHandler = handler;
    if (handler != null) {
      _seekHandlerReady?.complete(handler);
      _seekHandlerReady = null;
    }
  }

  void clearSeekError() {
    if (_isDisposed || _seekError == null) return;
    _seekError = null;
    notifyListeners();
  }

  Future<bool> seekToTranscriptLine(int index) async {
    if (_isDisposed ||
        isSeeking ||
        index < 0 ||
        index >= transcriptLines.length) {
      return false;
    }
    final start = transcriptLines[index].start;
    if (start == null) return false;
    _seekingIndex = index;
    _seekError = null;
    notifyListeners();
    try {
      final handler =
          _seekHandler ??
          await (_seekHandlerReady ??=
                  Completer<Future<bool> Function(Duration)?>())
              .future
              .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (_isDisposed) return false;
      final succeeded = handler != null && await handler(start);
      if (_isDisposed) return false;
      if (succeeded && identical(handler, _seekHandler)) return true;
      _seekError = AppStrings.trainingTranscriptSeekFailed;
      return false;
    } catch (_) {
      if (!_isDisposed) _seekError = AppStrings.trainingTranscriptSeekFailed;
      return false;
    } finally {
      if (!_isDisposed) {
        _seekingIndex = null;
        notifyListeners();
      }
    }
  }

  void updatePlaybackPosition(Duration position, {bool animate = true}) {
    if (_isDisposed) return;
    final index = _transcript.activeLineAt(position);
    final previousIndex = _activeTranscriptIndex;
    final previousText = _activeTranscriptText;
    final previousProgressText = _activeTranscriptProgressText;
    _lastPlaybackPosition = position;
    _animateActiveTranscript = animate;
    if (index != previousIndex) {
      _activeTranscriptIndex = index;
      _updateActiveTranscriptWordEnds();
    }
    _updateActiveTranscriptText();
    if (index != previousIndex ||
        _activeTranscriptText != previousText ||
        _activeTranscriptProgressText != previousProgressText) {
      notifyListeners();
    }
  }

  void _updateActiveTranscriptWordEnds() {
    // Slice the original cue at word boundaries to retain breaks and spacing.
    _activeTranscriptWordEnds = RegExp(r'\S+')
        .allMatches(activeTranscriptLine?.text ?? '')
        .map((match) => match.end)
        .toList(growable: false);
  }

  void _updateActiveTranscriptText() {
    final line = activeTranscriptLine;
    _activeTranscriptText = line?.text;
    _activeTranscriptProgressText = line?.text;
    if (line == null || _isCcEnabled) return;

    final wordCount = _activeTranscriptWordEnds.length;
    if (wordCount < 2) return;
    final elapsed = (_lastPlaybackPosition ?? line.start!) - line.start!;
    // Pace words over the cue instead of finishing after a short typing timer.
    // A final cue without an end uses a slower 450 ms per word fallback.
    final duration = line.end == null
        ? Duration(milliseconds: 450 * wordCount)
        : line.end! - line.start!;
    if (duration <= Duration.zero) return;
    final visibleWords =
        (1 + elapsed.inMicroseconds * wordCount ~/ duration.inMicroseconds)
            .clamp(1, wordCount);
    if (visibleWords < wordCount) {
      _activeTranscriptProgressText = line.text.substring(
        0,
        _activeTranscriptWordEnds[visibleWords - 1],
      );
    }
    if (_animateActiveTranscript) {
      _activeTranscriptText = _activeTranscriptProgressText;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _revealControlsHandler = null;
    _seekHandler = null;
    _seekHandlerReady?.complete(null);
    _seekHandlerReady = null;
    super.dispose();
  }
}
