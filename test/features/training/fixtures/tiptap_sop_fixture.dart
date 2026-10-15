import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/utils/custom_functions.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_sop_editor_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_sop_engine_controller.dart';
import 'package:tiptap_flutter/tiptap_flutter.dart';

/// Exercises the Training document surface without a native WebView in tests.
class TiptapSopFixture {
  final editors = <TestSopEditor>[];

  TrainingSopEditorController create(String html, ValueChanged<String> onHtmlChanged) {
    final editor = TestSopEditor();
    editors.add(editor);
    return TrainingSopEditorController(
      initialHtml: html,
      editor: editor,
      onHtmlChanged: onHtmlChanged,
    );
  }
}

class TestSopEditor extends Fake implements EditorController, TrainingSopSurface {
  final _states = StreamController<EditorStatePayload>.broadcast();
  final _engineStates = StreamController<EngineState>.broadcast();
  final _metrics = BridgeMetrics();
  EditorStatePayload? _state;
  String html = '';
  bool disposed = false;
  int initializationCount = 0;
  bool editable = true;
  int keyboardDismissals = 0;
  Future<String>? nextHtml;

  @override
  bool get isReady => _state != null;
  @override
  EngineState get engineState => isReady ? EngineState.ready : EngineState.uninitialized;
  @override
  Stream<EngineState> get engineStateStream => _engineStates.stream;
  @override
  Stream<EditorStatePayload> get editorStateStream => _states.stream;
  @override
  EditorStatePayload? get editorState => _state;
  @override
  AnnotatedNode? get document => _state?.doc;
  @override
  SelectionState? get selection => _state?.selection;
  @override
  BridgeMetrics get metrics => _metrics;
  @override
  Widget get webViewWidget => const SizedBox.shrink();
  @override
  Stream<String> get linkTaps => const Stream.empty();
  @override
  Widget buildDocument({required double width, required double textScale}) =>
      StreamBuilder<EditorStatePayload>(
        stream: _states.stream,
        initialData: _state,
        builder: (_, _) => SingleChildScrollView(child: Html(data: html)),
      );
  @override
  Future<void> dismissKeyboard() async => keyboardDismissals += 1;

  @override
  Future<void> initialize({String? content, bool editable = true}) async {
    this.editable = editable;
    initializationCount += 1;
    replaceHtml(content ?? '');
    _engineStates.add(EngineState.ready);
  }

  void replaceHtml(String value, {bool bold = false}) {
    html = value;
    final text = CustomFunctions.stripHtmlTags(value, emptyText: '');
    _state = EditorStatePayload(
      editable: editable,
      doc: AnnotatedNode(
        type: 'doc',
        pos: 0,
        end: text.length + 4,
        content: [
          AnnotatedNode(
            type: 'paragraph',
            pos: 1,
            end: text.length + 3,
            content: [
              AnnotatedNode(
                type: 'text',
                pos: 2,
                end: text.length + 2,
                text: text,
                marks: bold ? const [MarkData(type: 'bold')] : null,
              ),
            ],
          ),
        ],
      ),
      activeMarks: bold ? const ['bold'] : const [],
      commandStates: {EditorCommand.toggleBold: CommandState(canExec: true, isActive: bold)},
    );
    _states.add(_state!);
  }

  @override
  Future<String> getHTML() {
    final pending = nextHtml;
    nextHtml = null;
    return pending ?? Future.value(html);
  }

  @override
  Future<void> execCommand(String commandName, [Map<String, dynamic>? args]) async {
    if (commandName == EditorCommand.toggleBold) {
      final text = CustomFunctions.stripHtmlTags(html, emptyText: '');
      replaceHtml('<p><strong>$text</strong></p>', bold: true);
    }
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(_states.close());
    unawaited(_engineStates.close());
  }
}
