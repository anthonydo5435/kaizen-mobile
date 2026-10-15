import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tiptap_flutter/tiptap_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_strings.dart';
import 'training_sop_engine_controller.dart';

/// Owns the native editor and publishes HTML only when its document changes.
class TrainingSopEditorController extends ChangeNotifier {
  TrainingSopEditorController({
    required this.initialHtml,
    required this.onHtmlChanged,
    EditorController? editor,
  }) : editor = editor ?? TrainingSopEngineController();

  final String initialHtml;
  final ValueChanged<String> onHtmlChanged;
  final EditorController editor;
  StreamSubscription<EditorStatePayload>? _stateSubscription;
  StreamSubscription<String>? _linkSubscription;
  bool _isReady = false;
  bool _isEditable = true;
  bool _isDisposed = false;
  bool _isReadingHtml = false;
  int _contentRevision = 0;
  String? _documentSnapshot;
  String? _errorMessage;

  bool get isReady => _isReady;
  String? get errorMessage => _errorMessage;

  Future<void> initialize({bool editable = true}) async {
    _isEditable = editable;
    _stateSubscription = editor.editorStateStream.listen(_handleEditorState);
    if (editor case final TrainingSopSurface surface) {
      _linkSubscription = surface.linkTaps.listen((href) => unawaited(_openLink(href)));
    }
    try {
      // Pass the original HTML directly to Tiptap, including blank paragraphs
      // and hard breaks. Loading/normalization must never trigger autosave.
      await editor.initialize(content: initialHtml, editable: editable);
      if (_isDisposed) return;
      _documentSnapshot = _snapshot(editor.document);
      _isReady = true;
      notifyListeners();
    } catch (_) {
      _showError();
    }
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null || !const ['https', 'http', 'mailto', 'tel'].contains(uri.scheme)) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showError();
      }
    } catch (_) {
      _showError();
    }
  }

  Future<void> dismissKeyboard() async {
    if (editor case final TrainingSopSurface surface) {
      await surface.dismissKeyboard();
    }
  }

  void _handleEditorState(EditorStatePayload state) {
    if (_isDisposed) return;
    final snapshot = _snapshot(state.doc);
    // The engine can announce ready before delivering its initial document.
    if (_documentSnapshot == null) {
      _documentSnapshot = snapshot;
      return;
    }
    if (snapshot == _documentSnapshot) return;
    _documentSnapshot = snapshot;
    if (!_isReady || !_isEditable || !state.editable) return;
    _contentRevision += 1;
    unawaited(_publishHtml());
  }

  String? _snapshot(AnnotatedNode? document) =>
      document == null ? null : jsonEncode(document.toJson());

  Future<void> _publishHtml() async {
    if (_isReadingHtml) return;
    _isReadingHtml = true;
    try {
      // An older asynchronous serialization must not replace newer typing.
      while (!_isDisposed) {
        final revision = _contentRevision;
        final html = await editor.getHTML();
        if (_isDisposed) return;
        if (revision != _contentRevision) continue;
        onHtmlChanged(html);
        return;
      }
    } catch (_) {
      _showError();
    } finally {
      _isReadingHtml = false;
    }
  }

  Future<void> format(String command, [Map<String, dynamic>? arguments]) async {
    if (!_isReady || !_isEditable || _isDisposed) return;
    try {
      await editor.execCommand(command, arguments);
    } catch (_) {
      _showError();
    }
  }

  void _showError() {
    if (_isDisposed) return;
    _errorMessage = AppStrings.trainingSopEditorError;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_stateSubscription?.cancel());
    unawaited(_linkSubscription?.cancel());
    editor.dispose();
    super.dispose();
  }
}
